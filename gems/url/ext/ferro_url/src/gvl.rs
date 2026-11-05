// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Runs url's `socket_addrs` on a thread of its own and waits for it with
//! Ruby's global VM lock released, so an interrupt ends the wait (plan
//! 005, decision 11, and Follow-up: the GVL is never held).
//!
//! `socket_addrs` resolves a domain through the system's resolver (url
//! 2.5.8 `src/lib.rs:1361-1365`), which can wait seconds for DNS, and std
//! cannot cancel a lookup. Holding the GVL through it would stop every
//! other Ruby thread, and releasing it around the lookup itself would leave
//! Ctrl-C, `Thread#raise`, and `Timeout` waiting until the resolver
//! answers. So the lookup runs on a new thread, and the Ruby thread waits on
//! a channel with the GVL released and an unblocking function that sends
//! the channel a message of its own. On an interrupt the wait ends, the
//! interrupt runs, and the lookup thread is abandoned to finish alone, as
//! Ruby's own `Addrinfo.getaddrinfo` abandons its resolver thread
//! (`ext/socket/raddrinfo.c:489-498`, `:554-618` at Ruby v4.0.9). An
//! interrupt that raises nothing (`Thread#wakeup`, a trap that returns)
//! lets the wait start again.
//!
//! If the operating system will not start the thread, the gem falls back to
//! url's own behavior rather than raising an error of its own (ADR 001,
//! 2026-11-05, the error rule): the lookup runs on the calling thread, with
//! the GVL still released, and no interrupt can end it, as Ruby says of a
//! call without an unblocking function (`thread.c:1676-1679` warns that
//! built-in or missing ones leave a program deaf to Control+C, and
//! `thread.c:367-372` calls an unblocking function only when it is non-null).
//!
//! The wait and the fallback never run with the GVL held. Both go through
//! `rb_thread_call_without_gvl`, which always runs its function, and which
//! runs Ruby's pending interrupts before releasing the GVL, proceeding even
//! when the thread is marked as raising, and again after taking it back
//! (`thread.c:319-343`, `:1628-1638`). An interrupt that raises
//! (`Thread#raise`, `Thread#kill`, Ctrl-C) jumps out of that function with
//! `longjmp`, so the call runs inside magnus's `protect`, which catches the
//! jump and returns it as an `Err` for magnus to raise again once every
//! Rust value of the call has been dropped. The jump skips only the
//! closure `protect` runs, which owns nothing.
//!
//! An interrupt that arrives after the lookup answered, but before the GVL
//! is back, raises then, which discards the addresses. Ruby's own IO does
//! the same: `rb_thread_io_blocking_call` checks interrupts after a read or
//! write returns (`thread.c:1986-1999`), and one that raises there discards
//! what it read. The passage on `rb_thread_call_without_gvl` calls that
//! check harmful for work that has finished and recommends
//! `rb_thread_call_without_gvl2` for such work (`thread.c:1685-1699`). This
//! module rejects that function on purpose: it skips the work while any
//! interrupt is pending (`thread.c:320-327`), and an interrupt Ruby holds
//! back stays pending, as inside a user-defined `Exception#backtrace`
//! (`thread.c:2625`), so the gem's previous design retried with the GVL
//! held, forever. A lookup has no side effect to lose, and without the
//! release the interrupt would fire as the method returned all the same.
//!
//! The work runs with no Ruby API in reach: callers convert every argument
//! to Rust values first and build Ruby values after it returns, and the
//! work never sees a `Ruby` handle. It catches its own panics, since a
//! panic cannot unwind out of the `extern "C"` function Ruby calls. Every
//! other url call is short and keeps the GVL: getting it back after a
//! release waits for each thread that wants it to use up its time slice,
//! which Ruby warns about for short calls (`thread.c:1721-1723`).
//!
//! The design is ferro-arboard's (`gems/arboard`, plan 001, Follow-up: the
//! GVL is never held). magnus 0.9.3 does not wrap
//! `rb_thread_call_without_gvl`, so this module calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
#[cfg(feature = "test-hooks")]
use std::sync::atomic::AtomicBool;
#[cfg(any(test, feature = "test-hooks"))]
use std::sync::atomic::AtomicUsize;
#[cfg(any(test, feature = "test-hooks"))]
use std::sync::atomic::Ordering;
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;

use magnus::rb_sys::{protect, AsRawValue};
use magnus::{Error, Ruby};

/// How many times work has run with the GVL released in this process, for
/// the tests (`Native.gvl_releases`, a hook that only a build with the
/// `test-hooks` feature has): each wait for the lookup thread, and each
/// lookup run on the calling thread. Only such a build, and this module's
/// own tests, count at all.
#[cfg(any(test, feature = "test-hooks"))]
pub static RELEASES: AtomicUsize = AtomicUsize::new(0);

/// How many lookups have run on the calling thread because no thread could
/// start, for the tests (`Native.gvl_fallbacks`, a hook).
#[cfg(feature = "test-hooks")]
pub static FALLBACKS: AtomicUsize = AtomicUsize::new(0);

/// Whether `start` refuses to start a thread, as an operating system out
/// of threads would, so the tests reach the fallback
/// (`Native.gvl_refuse_threads`, a hook).
#[cfg(feature = "test-hooks")]
pub static REFUSE_THREADS: AtomicBool = AtomicBool::new(false);

/// What reaches the waiting Ruby thread: the work's outcome, or the
/// unblocking function's word that Ruby wants the thread back.
pub enum Message<T> {
    Done(thread::Result<T>),
    Interrupted,
}

/// The channel a wait reads, and what one wait read.
pub struct Wait<T> {
    receiver: Receiver<Message<T>>,
    seen: Option<Message<T>>,
}

impl<T> Wait<T> {
    /// Waits for the next message, blocking the calling thread.
    fn wait(&mut self) {
        // The unblocking function's sender lives as long as the wait, so
        // the channel never disconnects while anyone waits on it.
        self.seen = Some(self.receiver.recv().unwrap_or(Message::Interrupted));
    }
}

/// The function Ruby runs without the GVL: one wait for a message.
extern "C" fn wait<T>(data: *mut c_void) -> *mut c_void {
    // SAFETY: `data` is the `&mut Wait<T>` that `release_and_wait` (or a
    // test) passed, and it outlives this call: `rb_nogvl` calls `func`
    // synchronously on the calling thread and returns only after it does
    // (`thread.c:1628-1631` at Ruby v4.0.9), so nothing else holds the
    // reference meanwhile. The unblocking function's argument is the
    // channel's sender, a different object.
    #[allow(unsafe_code)]
    let state = unsafe { &mut *data.cast::<Wait<T>>() };
    #[cfg(any(test, feature = "test-hooks"))]
    RELEASES.fetch_add(1, Ordering::Relaxed);
    state.wait();
    ptr::null_mut()
}

/// The unblocking function: tells the waiting thread to return.
extern "C" fn interrupt<T>(data: *mut c_void) {
    // SAFETY: `data` is the `&Sender<Message<T>>` that `release_and_wait`
    // (or a test) passed, which outlives `rb_thread_call_without_gvl`. Ruby
    // calls this only between registering it and clearing it, both under
    // the thread's interrupt lock, which Ruby also holds while calling it
    // (`thread.c:319-351`, `:353-383` at Ruby v4.0.9), and it clears it
    // before returning (`blocking_region_end`, `thread.c:1546-1551`). Ruby
    // calls it from another thread, perhaps another Ractor's, and never
    // from a signal handler, which only an `RB_NOGVL_UBF_ASYNC_SAFE` call
    // allows (`thread_pthread.c:2683-2685`, `thread.c:1621-1625`). `Sender`
    // is `Sync`, so a shared
    // reference may be used from that thread, and sending on an unbounded
    // channel never blocks and touches nothing of Ruby's.
    #[allow(unsafe_code)]
    let sender = unsafe { &*data.cast_const().cast::<Sender<Message<T>>>() };
    // A panic cannot unwind out of an `extern "C"` function; `send` does
    // not panic, and if it did, the wait would only go on.
    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        let _ = sender.send(Message::Interrupted);
    }));
}

/// Asks Ruby to run one wait with the GVL released, inside `protect`,
/// interruptible through `sender`.
///
/// Returns the exception a pending interrupt raised, before the wait ran
/// or after it, in which case what it read is dropped with `state`.
fn release_and_wait<T>(
    ruby: &Ruby,
    state: &mut Wait<T>,
    sender: &Sender<Message<T>>,
) -> Result<(), Error> {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = wait::<T>;
    let ubf: unsafe extern "C" fn(*mut c_void) = interrupt::<T>;
    let data = ptr::from_mut(state).cast::<c_void>();
    let ubf_data = ptr::from_ref(sender).cast_mut().cast::<c_void>();
    let nil = ruby.qnil().as_raw();
    protect(|| {
        // SAFETY: The caller holds the GVL, as magnus guarantees for any
        // `&Ruby`. Ruby runs `function` with `data` exactly once, on this
        // thread, with the GVL released, and returns after it does, unless
        // an interrupt raises first (`thread.c:1594-1643`, `:1737-1742`
        // at Ruby v4.0.9). `wait` touches no Ruby object, which the NOTE in
        // `thread.c:1709-1716` requires, and never unwinds; `interrupt` is
        // the unblocking function (see its SAFETY comment). An interrupt
        // that raises jumps out of this call with `longjmp`, either before
        // the GVL is released (`unblock_function_set`, `thread.c:328-329`)
        // or after it is taken back (`thread.c:1636-1638`). `protect`
        // (magnus `src/rb_sys.rs:186-191`, `src/error.rs:449-510`) runs
        // this closure under `rb_protect`, so the jump lands there and
        // skips only this closure and magnus's adapter, which hold raw
        // pointers and a `VALUE`, nothing with a destructor; `state` and
        // `sender` live in the caller's frames and drop normally. magnus's
        // own `thread_check_ints` jumps over its closure the same way
        // (`src/thread.rs:404-410`).
        #[allow(unsafe_code)]
        unsafe {
            rb_sys::rb_thread_call_without_gvl(Some(function), data, Some(ubf), ubf_data);
        }
        nil
    })?;
    Ok(())
}

/// The wait loop, with Ruby's call passed in so tests can drive it.
///
/// Each try waits once. The work's outcome ends the loop. A try that read
/// the unblocking function's message, an interrupt that raised nothing,
/// waits again. An `Err` from a try (the exception an interrupt raised) is
/// returned, abandons the work, and drops whatever the try read.
pub fn drive<T, E>(
    mut state: Wait<T>,
    mut try_released: impl FnMut(&mut Wait<T>) -> Result<(), E>,
) -> Result<thread::Result<T>, E> {
    loop {
        state.seen = None;
        try_released(&mut state)?;
        if let Some(Message::Done(outcome)) = state.seen.take() {
            return Ok(outcome);
        }
    }
}

/// A new wait, and the work started on its own thread, which sends its
/// outcome, a panic included, to the wait's channel; or the work itself,
/// handed back, when no thread could start.
pub fn start<T: Send + 'static, F: FnOnce() -> T + Send + 'static>(
    work: F,
) -> Result<(Wait<T>, Sender<Message<T>>), F> {
    start_with(work, |job| {
        #[cfg(feature = "test-hooks")]
        if REFUSE_THREADS.load(Ordering::Relaxed) {
            return Err(std::io::Error::other("the tests refused a thread"));
        }
        thread::Builder::new()
            .name("ferro-url lookup".to_owned())
            .spawn(job)
            .map(drop)
    })
}

/// `start`, with the thread made by `spawn`, so tests can refuse one.
fn start_with<T: Send + 'static, F: FnOnce() -> T + Send + 'static>(
    work: F,
    spawn: impl FnOnce(Box<dyn FnOnce() + Send>) -> std::io::Result<()>,
) -> Result<(Wait<T>, Sender<Message<T>>), F> {
    let (sender, receiver) = mpsc::channel();
    let worker = sender.clone();
    // The work waits in a slot both sides can reach, so a thread that never
    // starts, whose job std drops unrun, leaves it for the caller.
    let slot = Arc::new(Mutex::new(Some(work)));
    let theirs = Arc::clone(&slot);
    let job = Box::new(move || {
        let work = theirs.lock().unwrap_or_else(PoisonError::into_inner).take();
        if let Some(work) = work {
            let outcome = panic::catch_unwind(AssertUnwindSafe(work));
            let _ = worker.send(Message::Done(outcome));
        }
    });
    if spawn(job).is_err() {
        // std drops the job of a thread that did not start without running
        // it, so the work is still in the slot. Had the job run and taken
        // it, it would send its outcome, and the wait below would get it.
        let unrun = slot.lock().unwrap_or_else(PoisonError::into_inner).take();
        if let Some(work) = unrun {
            return Err(work);
        }
    }
    Ok((
        Wait {
            receiver,
            seen: None,
        },
        sender,
    ))
}

/// Runs `work` on a thread of its own and waits for it with the GVL
/// released, returning its outcome (its value, or its panic's payload), or
/// the exception an interrupt raised, in which case the thread is left to
/// finish alone and its outcome, if it came, is dropped. If no thread can
/// start, `work` runs here instead, with the GVL released and no way to
/// interrupt it. The work never sees a `Ruby` handle.
pub fn in_background<T: Send + 'static>(
    ruby: &Ruby,
    work: impl FnOnce() -> T + Send + 'static,
) -> Result<thread::Result<T>, Error> {
    match start(work) {
        Ok((state, sender)) => drive(state, |state| release_and_wait(ruby, state, &sender)),
        Err(work) => in_place(ruby, work),
    }
}

/// The work `in_place` runs, and its outcome once it has run.
struct Job<F, T> {
    work: Option<F>,
    outcome: Option<thread::Result<T>>,
}

impl<F: FnOnce() -> T, T> Job<F, T> {
    const fn new(work: F) -> Self {
        Self {
            work: Some(work),
            outcome: None,
        }
    }

    /// Runs the work, if it has not run, catching a panic as the outcome.
    fn run(&mut self) {
        if let Some(work) = self.work.take() {
            self.outcome = Some(panic::catch_unwind(AssertUnwindSafe(work)));
        }
    }
}

/// The function Ruby runs without the GVL: the job's work, once.
extern "C" fn run_job<F: FnOnce() -> T, T>(data: *mut c_void) -> *mut c_void {
    // SAFETY: `data` is the `&mut Job<F, T>` that `release_and_run` (or a
    // test) passed, and it outlives this call: `rb_nogvl` calls `func`
    // synchronously on the calling thread and returns only after it does
    // (`thread.c:1628-1631` at Ruby v4.0.9), so nothing else holds the
    // reference meanwhile.
    #[allow(unsafe_code)]
    let job = unsafe { &mut *data.cast::<Job<F, T>>() };
    #[cfg(any(test, feature = "test-hooks"))]
    RELEASES.fetch_add(1, Ordering::Relaxed);
    job.run();
    ptr::null_mut()
}

/// Asks Ruby to run the job with the GVL released and no unblocking
/// function, inside `protect`.
///
/// Returns the exception a pending interrupt raised, before the job ran
/// (then `job` still holds the work) or after (then it holds the outcome).
fn release_and_run<F: FnOnce() -> T, T>(ruby: &Ruby, job: &mut Job<F, T>) -> Result<(), Error> {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run_job::<F, T>;
    let data = ptr::from_mut(job).cast::<c_void>();
    let nil = ruby.qnil().as_raw();
    protect(|| {
        // SAFETY: The caller holds the GVL, as magnus guarantees for any
        // `&Ruby`. Ruby runs `function` with `data` exactly once, on this
        // thread, with the GVL released, and returns after it does, unless
        // an interrupt raises first (`thread.c:1594-1643`, `:1737-1742`
        // at Ruby v4.0.9). `run_job` touches no Ruby object, which the NOTE
        // in `thread.c:1709-1716` requires, and never unwinds. A null
        // unblocking function is allowed: Ruby calls one only when it is
        // non-null (`thread.c:367-372`). An interrupt that raises jumps out
        // of this call with `longjmp`, either before the GVL is released
        // (`unblock_function_set`, `thread.c:328-329`) or after it is taken
        // back (`thread.c:1636-1638`). `protect` (magnus
        // `src/rb_sys.rs:186-191`, `src/error.rs:449-510`) runs this
        // closure under `rb_protect`, so the jump lands there and skips
        // only this closure and magnus's adapter, which hold raw pointers
        // and a `VALUE`, nothing with a destructor; `job` lives in the
        // caller's frame and drops normally. magnus's own
        // `thread_check_ints` jumps over its closure the same way
        // (`src/thread.rs:404-410`).
        #[allow(unsafe_code)]
        unsafe {
            rb_sys::rb_thread_call_without_gvl(Some(function), data, None, ptr::null_mut());
        }
        nil
    })?;
    Ok(())
}

/// The fallback's one call, with Ruby's call passed in so tests can drive it.
///
/// Ruby runs the job's function unless an interrupt raises first, so one
/// call is enough. An `Err` from it (the exception an interrupt raised) is
/// returned, and drops the work unrun or its outcome unread.
fn run_once<F: FnOnce() -> T, T, E>(
    mut job: Job<F, T>,
    try_released: impl FnOnce(&mut Job<F, T>) -> Result<(), E>,
) -> Result<thread::Result<T>, E> {
    try_released(&mut job)?;
    Ok(job
        .outcome
        .take()
        .unwrap_or_else(|| Err(Box::new("Ruby returned without running the lookup"))))
}

/// Runs `work` on this thread with the GVL released, for when no thread
/// can start. Without an unblocking function no interrupt ends it, as
/// Ruby warns (`thread.c:1676-1679` at Ruby v4.0.9; an unblocking function
/// runs only when non-null, `thread.c:367-372`), so the lookup runs as
/// url runs it; an interrupt that arrives meanwhile raises once it
/// returns, discarding its outcome.
fn in_place<T, F: FnOnce() -> T>(ruby: &Ruby, work: F) -> Result<thread::Result<T>, Error> {
    #[cfg(feature = "test-hooks")]
    FALLBACKS.fetch_add(1, Ordering::Relaxed);
    run_once(Job::new(work), |job| release_and_run(ruby, job))
}

#[cfg(test)]
mod tests {
    use super::{
        drive, interrupt, run_job, run_once, start, start_with, wait, Job, Message, Wait, RELEASES,
    };
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::sync::atomic::Ordering;
    use std::sync::mpsc::{self, Sender};

    /// One wait as Ruby runs it, through the function Ruby calls.
    fn call_wait<T>(state: &mut Wait<T>) {
        wait::<T>(ptr::from_mut(state).cast::<c_void>());
    }

    /// The unblocking function, as Ruby calls it.
    fn call_interrupt<T>(sender: &Sender<Message<T>>) {
        interrupt::<T>(ptr::from_ref(sender).cast_mut().cast::<c_void>());
    }

    fn call_run_job<F: FnOnce() -> T, T>(job: &mut Job<F, T>) {
        run_job::<F, T>(ptr::from_mut(job).cast::<c_void>());
    }

    /// A lookup that answers `value` only once `answer` is sent to, so a
    /// test decides when it finishes, with no clock.
    fn gated(value: u8) -> (Wait<u8>, Sender<Message<u8>>, Sender<()>) {
        let (answer, gate) = mpsc::channel::<()>();
        let (state, sender) = start(move || {
            let _ = gate.recv();
            value
        })
        .ok()
        .expect("a thread");
        (state, sender, answer)
    }

    #[test]
    fn a_thread_that_cannot_start_hands_the_work_back() {
        let refused = start_with(|| 7, |_job| Err(std::io::Error::other("no threads left")));
        let work = refused.err().expect("the work comes back");
        assert_eq!(work(), 7);
    }

    #[test]
    fn a_started_thread_runs_the_work_once() {
        let (state, sender) = start_with(
            || 7,
            |job| {
                std::thread::spawn(job);
                Ok(())
            },
        )
        .ok()
        .expect("a thread");
        let outcome = drive(state, |state| -> Result<(), ()> {
            call_wait(state);
            Ok(())
        });
        drop(sender);
        assert!(matches!(outcome, Ok(Ok(7))));
    }

    // Other tests run `wait` on other threads at the same time, so this
    // looks only for its own increment.
    #[test]
    fn a_wait_counts_a_release_and_reads_the_lookups_answer() {
        let (state, sender, answer) = gated(7);
        let before = RELEASES.load(Ordering::Relaxed);
        answer.send(()).expect("the lookup waits");
        let outcome = drive(state, |state| -> Result<(), ()> {
            call_wait(state);
            Ok(())
        });
        drop(sender);
        assert!(matches!(outcome, Ok(Ok(7))));
        assert!(RELEASES.load(Ordering::Relaxed) > before);
    }

    #[test]
    fn a_panicking_lookup_ends_the_wait_with_its_payload() {
        let (state, _sender) = start(|| -> u8 { panic!("inside") }).ok().expect("a thread");
        let outcome = drive(state, |state| -> Result<(), ()> {
            call_wait(state);
            Ok(())
        });
        let payload = outcome.expect("no interrupt").expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn the_unblocking_function_ends_a_wait_the_lookup_has_not_answered() {
        let (mut state, sender, _answer) = gated(7);
        call_interrupt(&sender);
        call_wait(&mut state);
        assert!(matches!(state.seen, Some(Message::Interrupted)));
    }

    #[test]
    fn an_interrupt_that_raises_abandons_a_lookup_that_never_answers() {
        let (state, sender, _answer) = gated(7);
        let outcome = drive(state, |state| {
            call_interrupt(&sender);
            call_wait(state);
            Err("Interrupt")
        });
        assert_eq!(outcome.err(), Some("Interrupt"));
    }

    #[test]
    fn an_interrupt_that_raises_nothing_waits_again_for_the_lookup() {
        let (state, sender, answer) = gated(7);
        let tries = Cell::new(0);
        let outcome = drive(state, |state| -> Result<(), ()> {
            tries.set(tries.get() + 1);
            if tries.get() == 1 {
                call_interrupt(&sender);
            } else {
                answer.send(()).expect("the lookup waits");
            }
            call_wait(state);
            Ok(())
        });
        assert!(matches!(outcome, Ok(Ok(7))));
        assert_eq!(tries.get(), 2);
    }

    #[test]
    fn an_interrupt_that_raises_after_the_lookup_answered_drops_its_value() {
        struct Value(Sender<()>);
        impl Drop for Value {
            fn drop(&mut self) {
                let _ = self.0.send(());
            }
        }
        let (dropped, drops) = mpsc::channel();
        let (state, _sender) = start(move || Value(dropped)).ok().expect("a thread");
        let outcome = drive(state, |state| {
            call_wait(state);
            assert!(matches!(state.seen, Some(Message::Done(Ok(_)))));
            Err("Interrupt")
        });
        assert!(matches!(outcome, Err("Interrupt")));
        assert!(drops.try_recv().is_ok());
    }

    #[test]
    fn run_job_runs_the_work_once_counts_a_release_and_keeps_its_value() {
        let runs = Cell::new(0);
        let before = RELEASES.load(Ordering::Relaxed);
        let mut job = Job::new(|| {
            runs.set(runs.get() + 1);
            7
        });
        call_run_job(&mut job);
        call_run_job(&mut job);
        assert!(matches!(job.outcome, Some(Ok(7))));
        assert_eq!(runs.get(), 1);
        assert!(RELEASES.load(Ordering::Relaxed) > before);
    }

    #[test]
    fn run_job_catches_a_panic_as_the_outcome() {
        let mut job = Job::new(|| -> u8 { panic!("inside") });
        call_run_job(&mut job);
        let payload = job.outcome.expect("the work ran").expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn a_fallback_call_that_ran_the_work_returns_its_outcome() {
        let tries = Cell::new(0);
        let outcome = run_once(Job::new(|| 5), |job| -> Result<(), ()> {
            tries.set(tries.get() + 1);
            call_run_job(job);
            Ok(())
        });
        assert!(matches!(outcome, Ok(Ok(5))));
        assert_eq!(tries.get(), 1);
    }

    #[test]
    fn an_interrupt_that_raises_before_the_fallback_drops_the_work_unrun() {
        let ran = Cell::new(false);
        let outcome = run_once(Job::new(|| ran.set(true)), |_| Err("Interrupt"));
        assert_eq!(outcome.err(), Some("Interrupt"));
        assert!(!ran.get());
    }

    #[test]
    fn an_interrupt_that_raises_after_the_fallback_drops_its_value() {
        struct Value<'a>(&'a Cell<bool>);
        impl Drop for Value<'_> {
            fn drop(&mut self) {
                self.0.set(true);
            }
        }
        let dropped = Cell::new(false);
        let outcome = run_once(Job::new(|| Value(&dropped)), |job| {
            call_run_job(job);
            Err("Interrupt")
        });
        assert!(matches!(outcome, Err("Interrupt")));
        assert!(dropped.get());
    }
}
