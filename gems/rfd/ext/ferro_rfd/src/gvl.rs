// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! Runs rfd's work with Ruby's global VM lock released (plan 002,
//! decision 4).
//!
//! A dialog waits for a person, so holding the GVL through one would stop
//! every other Ruby thread until the person answers. Two kinds of work run
//! here:
//!
//! - A sync dialog, through [`without_gvl`], with no unblocking function.
//!   rfd cannot cancel a dialog, so `Thread#kill`, `Thread#raise`, and
//!   Ctrl-C take effect once it closes. Ruby documents that a call without
//!   one "will not stop for Control+C" (`thread.c:1676-1679` at Ruby
//!   v4.0.9), and process exit waits for it, since Ruby kills the other
//!   threads and then waits for each to finish (`thread.c:484-493`).
//! - Waiting on a future, through [`wait`], with an unblocking function.
//!   Waiting is only parking the thread until rfd's waker unparks it, so
//!   an interrupt can unpark it too: the wait ends, the future stays
//!   pending, and the interrupt runs.
//!
//! The work never runs with the GVL held. It goes through
//! `rb_thread_call_without_gvl`, which always runs it, and which runs
//! Ruby's pending interrupts before releasing the GVL and after taking it
//! back (`thread.c:319-343`, `:1628-1638`). An interrupt that raises
//! (`Thread#raise`, `Thread#kill`, Ctrl-C) jumps out of that function with
//! `longjmp`, so the call runs inside magnus's `protect`, which catches the
//! jump and returns it as an `Err` for magnus to raise again once every
//! Rust value of the call has been dropped. The jump skips only the
//! closure `protect` runs, which owns nothing.
//!
//! An interrupt that arrives while the work runs is raised after it
//! returns, which discards what the work returned, a dialog's answer among
//! them. Ruby's own IO does the same: `rb_thread_io_blocking_call` checks
//! interrupts after a read or write returns (`thread.c:1986-1999` at Ruby
//! v4.0.9), and one that raises there discards what it read. The passage
//! on `rb_thread_call_without_gvl` calls that check harmful for work that
//! has finished and recommends `rb_thread_call_without_gvl2` for such work
//! (`thread.c:1685-1699`). This module rejects that function on purpose:
//! it skips the work while any interrupt is pending (`thread.c:320-327`),
//! and an interrupt Ruby holds back stays pending, which led the gem's
//! previous design to run the work with the GVL held, stalling every
//! other thread. A future's answer is not lost: [`wait`]'s caller keeps
//! what `poll` finished with (`future.rs`).
//!
//! The work never touches Ruby: callers convert every argument to Rust
//! values first and build Ruby values after it returns. It catches its own
//! panics, since a panic cannot unwind out of the `extern "C"` function
//! Ruby calls.
//!
//! The design is ferro-arboard's (`gems/arboard`, plan 001, Follow-up: the
//! GVL is never held), whose author, Kerrick Long, licenses this copy as
//! MIT with the rest of ferro-rfd. magnus 0.9.3 does not wrap
//! `rb_thread_call_without_gvl`, so this module calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, PoisonError};
use std::task::{Context, Poll, Wake, Waker};
use std::thread::Thread;

use magnus::rb_sys::{protect, AsRawValue};
use magnus::{Error, Ruby};

/// One piece of work, and the slot its outcome lands in.
struct Call<F, T> {
    work: Option<F>,
    outcome: Option<std::thread::Result<T>>,
}

impl<F: FnOnce() -> T, T> Call<F, T> {
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

/// The function Ruby runs without the GVL. It runs the work once, catching
/// a panic as the outcome, and touches nothing of Ruby's.
extern "C" fn run<F: FnOnce() -> T, T>(data: *mut c_void) -> *mut c_void {
    // SAFETY: `data` is the `&mut Call<F, T>` that `release_and_run` (or a
    // test) passed in, and it outlives this call: `rb_nogvl` calls `func`
    // synchronously on the calling thread and returns only after it does
    // (`thread.c:1628-1631` at Ruby v4.0.9), so nothing else holds the
    // reference meanwhile. The unblocking function's argument is a
    // different object.
    #[allow(unsafe_code)]
    let call = unsafe { &mut *data.cast::<Call<F, T>>() };
    call.run();
    ptr::null_mut()
}

/// An unblocking function and its argument, for Ruby to call when it
/// interrupts the thread while the work runs.
type Unblock = (unsafe extern "C" fn(*mut c_void), *mut c_void);

/// Asks Ruby to run the work with the GVL released, inside `protect`.
///
/// Returns the exception a pending interrupt raised, before the work ran
/// (then `call` still holds it) or after (then `call` holds its outcome).
fn release_and_run<F: FnOnce() -> T, T>(
    ruby: &Ruby,
    call: &mut Call<F, T>,
    unblock: Option<Unblock>,
) -> Result<(), Error> {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<F, T>;
    let (ubf, ubf_data) = unblock.map_or((None, ptr::null_mut()), |(ubf, data)| (Some(ubf), data));
    let data = ptr::from_mut(call).cast::<c_void>();
    let nil = ruby.qnil().as_raw();
    protect(|| {
        // SAFETY: The caller holds the GVL, as magnus guarantees for any
        // `&Ruby`. Ruby runs `function` with `data` exactly once, on this
        // thread, with the GVL released, and returns after it does, unless
        // an interrupt raises first (`thread.c:1594-1643`, `:1737-1742`
        // at Ruby v4.0.9). `run` touches no Ruby object, which the NOTE in
        // `thread.c:1709-1716` requires, and never unwinds. A null
        // unblocking function is allowed: Ruby calls one only when it is
        // non-null (`thread.c:367-372`). A non-null one is `interrupt`
        // below, whose argument outlives this call, and Ruby clears it
        // before returning (`blocking_region_end`, `thread.c:1546-1551`,
        // under the lock Ruby holds while calling it, `:346-351`,
        // `:353-383`). An interrupt that raises jumps out of this call with
        // `longjmp`, either before the GVL is released
        // (`unblock_function_set`, `thread.c:328`) or after it is taken
        // back (`thread.c:1636-1638`). `protect` (magnus
        // `src/rb_sys.rs:186-191`, `src/error.rs:449-510`) runs this
        // closure under `rb_protect`, so the jump lands there and skips
        // only this closure and magnus's adapter, which hold raw pointers
        // and a `VALUE`, nothing with a destructor; `call` and everything
        // it owns live in the caller's frame and drop normally. magnus's
        // own `thread_check_ints` jumps over its closure the same way
        // (`src/thread.rs:404-410`).
        #[allow(unsafe_code)]
        unsafe {
            rb_sys::rb_thread_call_without_gvl(Some(function), data, ubf, ubf_data);
        }
        nil
    })?;
    Ok(())
}

/// The loop, with Ruby's call passed in so tests can drive it.
///
/// Each try asks Ruby to run the work, and the loop ends once it has. An
/// `Err` from a try (the exception an interrupt raised) is returned, and
/// drops the work unrun or its outcome unread.
fn drive<F: FnOnce() -> T, T, E>(
    mut call: Call<F, T>,
    mut try_released: impl FnMut(&mut Call<F, T>) -> Result<(), E>,
) -> Result<std::thread::Result<T>, E> {
    loop {
        try_released(&mut call)?;
        if let Some(outcome) = call.outcome.take() {
            return Ok(outcome);
        }
    }
}

/// Runs `work` with the GVL released and returns its outcome: its value,
/// or the payload of the panic it raised. Or returns the exception an
/// interrupt raised: one already pending raises before `work` runs, and
/// one that arrives while it runs raises after, discarding its value.
pub fn without_gvl<F: FnOnce() -> T, T>(
    ruby: &Ruby,
    work: F,
) -> Result<std::thread::Result<T>, Error> {
    drive(Call::new(work), |call| release_and_run(ruby, call, None))
}

/// The native thread waiting on a future, and whether Ruby has
/// interrupted it.
///
/// The thread is recorded where the wait parks, inside the released
/// region, not where the waiter is made: a Ruby thread may resume on
/// another native thread after Ruby runs its interrupts, as it can under
/// the M:N scheduler (always on in Ractors other than the main one, Ruby
/// NEWS for 3.3.0), and the waker must unpark the thread that parked.
#[derive(Default)]
pub struct Waiter {
    thread: Mutex<Option<Thread>>,
    interrupted: AtomicBool,
}

impl Waiter {
    /// A waiter whose thread is not known yet.
    pub fn new() -> Arc<Self> {
        Arc::new(Self::default())
    }

    /// Records the current native thread as the one to unpark.
    fn park_here(&self) {
        *self.thread.lock().unwrap_or_else(PoisonError::into_inner) = Some(std::thread::current());
    }

    /// Unparks the recorded thread, if one has parked here.
    fn unpark(&self) {
        if let Some(thread) = self
            .thread
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .as_ref()
        {
            thread.unpark();
        }
    }

    /// Marks the wait interrupted and wakes the thread. An interrupt that
    /// comes before the thread is recorded is seen at its next check.
    pub fn interrupt(&self) {
        self.interrupted.store(true, Ordering::Release);
        self.unpark();
    }

    fn take_interrupt(&self) -> bool {
        self.interrupted.swap(false, Ordering::AcqRel)
    }
}

impl Wake for Waiter {
    fn wake(self: Arc<Self>) {
        self.unpark();
    }

    fn wake_by_ref(self: &Arc<Self>) {
        self.unpark();
    }
}

/// Ruby's unblocking function for [`wait`]: interrupts the waiter.
extern "C" fn interrupt(data: *mut c_void) {
    // SAFETY: `data` is the `Waiter` that `wait` keeps alive (in its `Arc`)
    // until `rb_thread_call_without_gvl` returns or jumps, and Ruby calls
    // this only before then (see `release_and_run`). Ruby calls it from
    // another thread, perhaps another Ractor's, holding the waiting
    // thread's interrupt lock, and never from a signal handler, which only
    // an `RB_NOGVL_UBF_ASYNC_SAFE` call allows (`thread_pthread.c:2684-2686`,
    // `thread.c:1621-1624` at Ruby v4.0.9). It stores a flag and unparks a
    // thread under the waiter's own lock, which no Ruby lock guards and
    // which is held only to read or replace the thread; `Waiter` is
    // `Sync`, so a shared reference may be used from this thread.
    #[allow(unsafe_code)]
    let waiter = unsafe { &*data.cast_const().cast::<Waiter>() };
    // A panic cannot unwind out of an `extern "C"` function; `interrupt`
    // does not panic, and if it did, the wait would only go on.
    let _ = panic::catch_unwind(AssertUnwindSafe(|| waiter.interrupt()));
}

/// Polls `poll` until it is ready or the waiter is interrupted, parking
/// the thread between polls. `Poll::Pending` means interrupted.
pub fn poll_until<T>(
    waiter: &Arc<Waiter>,
    mut poll: impl FnMut(&mut Context<'_>) -> Poll<T>,
) -> Poll<T> {
    waiter.park_here();
    let waker = Waker::from(Arc::clone(waiter));
    let mut context = Context::from_waker(&waker);
    loop {
        if let Poll::Ready(value) = poll(&mut context) {
            return Poll::Ready(value);
        }
        if waiter.take_interrupt() {
            return Poll::Pending;
        }
        std::thread::park();
    }
}

/// The wait's loop, with one released wait passed in so tests can drive
/// it: waits again while a wait ends interrupted, and returns what the
/// first one that finishes gives, or the first `Err`.
fn wait_until_ready<T, E>(
    mut wait_once: impl FnMut() -> Result<std::thread::Result<Poll<T>>, E>,
) -> Result<std::thread::Result<T>, E> {
    loop {
        match wait_once()? {
            Ok(Poll::Ready(value)) => return Ok(Ok(value)),
            Err(payload) => return Ok(Err(payload)),
            Ok(Poll::Pending) => {}
        }
    }
}

/// Waits for `poll` to be ready with the GVL released, letting Ruby
/// interrupt the wait (plan 002, decision 3).
///
/// Returns the ready value, or the payload of a panic in `poll`, or the
/// exception an interrupt raised; then the caller still holds whatever
/// `poll` polls, unfinished, and may wait on it again. Ruby runs an
/// interrupt as each wait returns; one that raises nothing (a trap that
/// returns, `Thread#wakeup`) lets the wait start again. An interrupt that
/// raises after `poll` was ready discards the value it returned, the
/// trade-off the module documentation explains, so a caller that must not
/// lose it stores it from `poll` instead.
pub fn wait<T>(
    ruby: &Ruby,
    mut poll: impl FnMut(&mut Context<'_>) -> Poll<T>,
) -> Result<std::thread::Result<T>, Error> {
    wait_until_ready(|| {
        let waiter = Waiter::new();
        let unblock: Unblock = (interrupt, Arc::as_ptr(&waiter).cast_mut().cast::<c_void>());
        drive(Call::new(|| poll_until(&waiter, &mut poll)), |call| {
            release_and_run(ruby, call, Some(unblock))
        })
    })
}

#[cfg(test)]
mod tests {
    use super::{drive, interrupt, poll_until, run, wait_until_ready, Call, Waiter};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::sync::Arc;
    use std::task::Poll;

    fn call_run<F: FnOnce() -> T, T>(call: &mut Call<F, T>) {
        run::<F, T>(ptr::from_mut(call).cast::<c_void>());
    }

    #[test]
    fn run_runs_the_work_once_and_keeps_its_value() {
        let runs = Cell::new(0);
        let mut call = Call::new(|| {
            runs.set(runs.get() + 1);
            7
        });
        call_run(&mut call);
        call_run(&mut call);
        assert!(matches!(call.outcome, Some(Ok(7))));
        assert_eq!(runs.get(), 1);
    }

    #[test]
    fn run_catches_a_panic_as_the_outcome() {
        let mut call = Call::new(|| -> u8 { panic!("inside") });
        call_run(&mut call);
        let payload = call
            .outcome
            .expect("the work ran")
            .expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn a_try_that_ran_the_work_returns_its_outcome() {
        let tries = Cell::new(0);
        let outcome = drive(Call::new(|| 5), |call| -> Result<(), ()> {
            tries.set(tries.get() + 1);
            call_run(call);
            Ok(())
        });
        assert!(matches!(outcome, Ok(Ok(5))));
        assert_eq!(tries.get(), 1);
    }

    #[test]
    fn a_try_that_did_not_run_the_work_runs_again() {
        let tries = Cell::new(0);
        let outcome = drive(Call::new(|| 5), |call| -> Result<(), ()> {
            tries.set(tries.get() + 1);
            if tries.get() > 1 {
                call_run(call);
            }
            Ok(())
        });
        assert!(matches!(outcome, Ok(Ok(5))));
        assert_eq!(tries.get(), 2);
    }

    #[test]
    fn an_interrupt_that_raises_before_the_work_drops_it_unrun() {
        let ran = Cell::new(false);
        let outcome = drive(Call::new(|| ran.set(true)), |_| Err("Interrupt"));
        assert_eq!(outcome.err(), Some("Interrupt"));
        assert!(!ran.get());
    }

    #[test]
    fn an_interrupt_that_raises_after_the_work_drops_its_value() {
        struct Value<'a>(&'a Cell<bool>);
        impl Drop for Value<'_> {
            fn drop(&mut self) {
                self.0.set(true);
            }
        }
        let dropped = Cell::new(false);
        let outcome = drive(Call::new(|| Value(&dropped)), |call| {
            call_run(call);
            Err("Interrupt")
        });
        assert!(matches!(outcome, Err("Interrupt")));
        assert!(dropped.get());
    }

    #[test]
    fn a_wait_ended_by_an_interrupt_that_raised_nothing_waits_again() {
        let waits = Cell::new(0);
        let outcome = wait_until_ready(|| -> Result<_, ()> {
            waits.set(waits.get() + 1);
            Ok(Ok(if waits.get() < 3 {
                Poll::Pending
            } else {
                Poll::Ready(9)
            }))
        });
        assert!(matches!(outcome, Ok(Ok(9))));
        assert_eq!(waits.get(), 3);
    }

    #[test]
    fn a_wait_ends_on_an_interrupt_that_raised_or_a_panic() {
        let raised =
            wait_until_ready(|| -> Result<std::thread::Result<Poll<u8>>, _> { Err("Interrupt") });
        assert_eq!(raised.err(), Some("Interrupt"));

        let panicked = wait_until_ready(|| -> Result<std::thread::Result<Poll<u8>>, ()> {
            Ok(Err(Box::new("inside")))
        });
        let payload = panicked.expect("no interrupt").expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn the_unblocking_function_interrupts_its_waiter() {
        let waiter = Waiter::new();
        interrupt(Arc::as_ptr(&waiter).cast_mut().cast::<c_void>());
        let outcome: Poll<()> = poll_until(&waiter, |_| Poll::Pending);
        assert_eq!(outcome, Poll::Pending);
    }

    #[test]
    fn poll_until_waits_for_the_waker() {
        let waiter = Waiter::new();
        let mut polls = 0;
        let outcome = poll_until(&waiter, |context| {
            polls += 1;
            if polls == 3 {
                Poll::Ready(polls)
            } else {
                let waker = context.waker().clone();
                std::thread::spawn(move || waker.wake());
                Poll::Pending
            }
        });
        assert_eq!(outcome, Poll::Ready(3));
    }

    /// A waiter made on one thread and waited on from another wakes the
    /// thread that waits, as a Ruby thread that moved native threads needs.
    #[test]
    fn the_waker_unparks_the_thread_that_parked_not_the_one_that_made_it() {
        let waiter = Waiter::new();
        let (done, result) = std::sync::mpsc::channel();
        std::thread::spawn(move || {
            let mut polls = 0;
            let outcome = poll_until(&waiter, |context| {
                polls += 1;
                if polls == 2 {
                    Poll::Ready(polls)
                } else {
                    let waker = context.waker().clone();
                    std::thread::spawn(move || {
                        std::thread::sleep(std::time::Duration::from_millis(50));
                        waker.wake();
                    });
                    Poll::Pending
                }
            });
            let _ = done.send(outcome);
        });
        let outcome = result
            .recv_timeout(std::time::Duration::from_secs(5))
            .expect("the waiting thread was woken");
        assert_eq!(outcome, Poll::Ready(2));
    }

    #[test]
    fn poll_until_stops_when_interrupted_and_keeps_the_future_pending() {
        let waiter = Waiter::new();
        let other = std::sync::Arc::clone(&waiter);
        let interrupter = std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_millis(50));
            other.interrupt();
        });
        let outcome: Poll<()> = poll_until(&waiter, |_| Poll::Pending);
        interrupter.join().expect("the interrupter ran");
        assert_eq!(outcome, Poll::Pending);
    }
}
