// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Runs notify-rust's work with Ruby's global VM lock released (plan 003,
//! decision 6).
//!
//! Showing a notification talks to D-Bus, the notification center, or a
//! toast, and waiting for one waits for a person, so holding the GVL
//! through either would stop every other Ruby thread. Three kinds of work
//! run here:
//!
//! - A call notify-rust cannot cancel, through [`without_gvl`], with no
//!   unblocking function. `Thread#kill`, `Thread#raise`, and Ctrl-C take
//!   effect once it returns. Ruby documents that a call without one "will
//!   not stop for Control+C" (`thread.c:1676-1679` at Ruby v4.0.9), and
//!   process exit waits for it, since Ruby kills the other threads and
//!   then waits for each to finish (`rb_thread_terminate_all`,
//!   `thread.c:484-493`).
//! - A wait for the Linux handle's lock, through [`wait_until`], with the
//!   lock's [`Unblock`] (`lock.rs`), and then the work that turn allows.
//! - Polling one of notify-rust's futures on Linux, through [`wait`], with
//!   an unblocking function. Waiting is only parking the thread until the
//!   future's waker unparks it, so an interrupt can unpark it too: the wait
//!   ends, and the caller drops the future.
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
//! An interrupt that arrives just after the work returned, before Ruby
//! takes the GVL back, raises there and discards what the work produced,
//! as Ruby's IO path does (`rb_thread_io_blocking_call`,
//! `thread.c:1986-1999`, which checks interrupts after the call
//! returned): a response a wait received, a handle `show` made (the
//! notification is shown all the same), an action `handle_action` saw.
//! Without the release the same interrupt would fire as the method
//! returned and discard it all the same.
//!
//! The comment at `thread.c:1694-1699` calls that check after the work
//! finished harmful and recommends `rb_thread_call_without_gvl2` instead.
//! That function was rejected: it skips the work while any interrupt is
//! pending, which led to running the work with the GVL held (plan 003,
//! Follow-up: the GVL is never held).
//!
//! The work runs with no Ruby API in reach: callers convert every argument
//! to Rust values first and build Ruby values after it returns, and the
//! work never sees a `Ruby` handle. It catches its own panics, since a
//! panic cannot unwind out of the `extern "C"` function Ruby calls.
//!
//! This module is ferro-arboard's (`gems/arboard`, plan 001, Follow-up:
//! the GVL is never held), with the future wait of ferro-rfd's (plan 002,
//! decision 4). Their author, Kerrick Long, licenses this copy as MIT OR
//! Apache-2.0 with the rest of ferro-notify-rust. magnus 0.9.3 does not
//! wrap `rb_thread_call_without_gvl`, so this module calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
#[cfg(all(unix, not(target_os = "macos")))]
use std::sync::atomic::AtomicBool;
use std::sync::atomic::{AtomicUsize, Ordering};
#[cfg(all(unix, not(target_os = "macos")))]
use std::sync::{Arc, Mutex, PoisonError};
#[cfg(all(unix, not(target_os = "macos")))]
use std::task::{Context, Poll, Wake, Waker};
#[cfg(all(unix, not(target_os = "macos")))]
use std::thread::Thread;

use magnus::rb_sys::{protect, AsRawValue};
use magnus::{Error, Ruby};

/// How many times work has run with the GVL released in this process.
///
/// The tests read it (`Native.gvl_releases`) to tell that a call released
/// the GVL. Whether another Ruby thread actually runs meanwhile is up to
/// Ruby's scheduler: from Ruby 4.0.6 on, a thread returning from a short
/// blocking region takes the GVL straight back when the thread it woke has
/// not started yet (`thread_pthread.c:846-867` and `:1055-1066` at
/// v4.0.9).
pub static RELEASES: AtomicUsize = AtomicUsize::new(0);

/// What Ruby calls when it wants the thread back from work running without
/// the GVL: Ruby's unblocking function.
///
/// Ruby calls it from another thread, possibly another Ractor's, without
/// the GVL, holding the waiting thread's interrupt lock (`thread.c:353-383`
/// at Ruby v4.0.9), hence `Sync`. It touches nothing of Ruby's, never
/// unwinds, and never waits for long.
pub trait Unblock: Sync {
    fn unblock(&self);
}

/// The unblocking function of work nothing can cancel, which Ruby is never
/// given: [`release_and_run`] passes a null one instead.
struct Uncancellable;

impl Unblock for Uncancellable {
    fn unblock(&self) {}
}

/// One piece of work: a wait that may give up, the work it lets run, and
/// the slot their outcome lands in.
struct Call<W, F, T> {
    wait: W,
    work: Option<F>,
    outcome: Option<std::thread::Result<T>>,
}

impl<W: FnMut() -> Option<G>, F: FnOnce(G) -> T, G, T> Call<W, F, T> {
    const fn new(wait: W, work: F) -> Self {
        Self {
            wait,
            work: Some(work),
            outcome: None,
        }
    }

    /// Waits and, if the wait did not give up, runs the work, catching a
    /// panic in either as the outcome.
    fn run(&mut self) {
        let Some(work) = self.work.take() else {
            return;
        };
        match panic::catch_unwind(AssertUnwindSafe(&mut self.wait)) {
            Ok(Some(ready)) => {
                self.outcome = Some(panic::catch_unwind(AssertUnwindSafe(|| work(ready))));
            }
            Ok(None) => self.work = Some(work),
            Err(payload) => self.outcome = Some(Err(payload)),
        }
    }
}

/// The function Ruby runs without the GVL. It runs the call once and
/// touches nothing of Ruby's.
extern "C" fn run<W: FnMut() -> Option<G>, F: FnOnce(G) -> T, G, T>(
    data: *mut c_void,
) -> *mut c_void {
    // SAFETY: `data` is the `&mut Call` that `release_and_run` (or a test)
    // passed in, and it outlives this call: `rb_nogvl` calls `func`
    // synchronously on the calling thread and returns only after it does
    // (`thread.c:1628-1631` at Ruby v4.0.9), so nothing else holds the
    // reference meanwhile. The unblocking function's argument is a
    // different object, which the call only borrows shared.
    #[allow(unsafe_code)]
    let call = unsafe { &mut *data.cast::<Call<W, F, T>>() };
    RELEASES.fetch_add(1, Ordering::Relaxed);
    call.run();
    ptr::null_mut()
}

/// Ruby's unblocking function: passes Ruby's request on to `U`.
extern "C" fn interrupt<U: Unblock>(data: *mut c_void) {
    // SAFETY: `data` is the `&U` that `release_and_run` passed, which
    // outlives `rb_thread_call_without_gvl`. Ruby calls this only between
    // registering it and clearing it, both under the thread's interrupt
    // lock, which Ruby also holds while calling it (`thread.c:319-351`,
    // `:353-383` at Ruby v4.0.9), and it clears it before returning
    // (`blocking_region_end`, `thread.c:1546-1551`). Ruby never calls it
    // from a signal handler, which only an `RB_NOGVL_UBF_ASYNC_SAFE` call
    // allows (`thread_pthread.c:2684-2686`, `thread.c:1621-1624`). `U` is
    // `Sync`, so a shared reference may be used from this thread.
    #[allow(unsafe_code)]
    let unblock = unsafe { &*data.cast_const().cast::<U>() };
    // A panic cannot unwind out of an `extern "C"` function; `unblock`
    // does not panic, and if it did, the wait would only go on.
    let _ = panic::catch_unwind(AssertUnwindSafe(|| unblock.unblock()));
}

/// Asks Ruby to run the call with the GVL released, inside `protect`, and
/// with `unblock` as its unblocking function, or none.
///
/// Returns the exception a pending interrupt raised, before the call ran
/// or after it, which leaves the outcome in `call`.
fn release_and_run<W: FnMut() -> Option<G>, F: FnOnce(G) -> T, G, T, U: Unblock>(
    ruby: &Ruby,
    call: &mut Call<W, F, T>,
    unblock: Option<&U>,
) -> Result<(), Error> {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<W, F, G, T>;
    let ubf: unsafe extern "C" fn(*mut c_void) = interrupt::<U>;
    let (ubf, ubf_data) = unblock.map_or((None, ptr::null_mut()), |unblock| {
        (
            Some(ubf),
            ptr::from_ref(unblock).cast_mut().cast::<c_void>(),
        )
    });
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
        // non-null (`thread.c:367-369`). A non-null one is `interrupt` (see
        // its SAFETY comment), whose argument the caller keeps alive past
        // this call. An interrupt that raises jumps out of this call with
        // `longjmp`, either before the GVL is released
        // (`unblock_function_set`, `thread.c:328`) or after it is taken
        // back (`thread.c:1636-1638`). `protect` (magnus
        // `src/error.rs:449-510`) runs this closure under `rb_protect`, so
        // the jump lands there and skips only this closure and magnus's
        // adapter, which hold raw pointers and a `VALUE`, nothing with a
        // destructor; `call` and everything it owns live in the caller's
        // frame and drop normally. magnus's own `thread_check_ints` jumps
        // over its closure the same way (`src/thread.rs:404-410`).
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
/// Each try runs the call. When the wait gave up for an interrupt that
/// raised nothing (a signal trap that returned, `Thread#wakeup`), the call
/// runs again. An `Err` from a try (the exception an interrupt raised) is
/// returned, and drops the work unrun or the outcome unread.
fn drive<W: FnMut() -> Option<G>, F: FnOnce(G) -> T, G, T, E>(
    mut call: Call<W, F, T>,
    mut try_released: impl FnMut(&mut Call<W, F, T>) -> Result<(), E>,
) -> Result<std::thread::Result<T>, E> {
    loop {
        try_released(&mut call)?;
        if let Some(outcome) = call.outcome.take() {
            return Ok(outcome);
        }
    }
}

/// Runs `work` with the GVL released and no unblocking function, and
/// returns its outcome: its value, or the payload of the panic it raised.
/// Or returns the exception an interrupt raised, before `work` ran or
/// after it returned, which discards its value.
pub fn without_gvl<F: FnOnce() -> T, T>(
    ruby: &Ruby,
    work: F,
) -> Result<std::thread::Result<T>, Error> {
    drive(Call::new(|| Some(()), |()| work()), |call| {
        release_and_run(ruby, call, None::<&Uncancellable>)
    })
}

/// Waits with the GVL released until `wait` gives what `work` needs, runs
/// `work` on it, and returns its outcome: its value, or the payload of the
/// panic it or `wait` raised. Or returns the exception an interrupt
/// raised.
///
/// `wait` returns `None` to give up after `unblock` ran; Ruby then runs
/// the interrupt, and unless it raised, `wait` runs again.
#[cfg(all(unix, not(target_os = "macos")))]
pub fn wait_until<W, F, G, T, U>(
    ruby: &Ruby,
    unblock: &U,
    wait: W,
    work: F,
) -> Result<std::thread::Result<T>, Error>
where
    W: FnMut() -> Option<G>,
    F: FnOnce(G) -> T,
    U: Unblock,
{
    drive(Call::new(wait, work), |call| {
        release_and_run(ruby, call, Some(unblock))
    })
}

#[cfg(all(unix, not(target_os = "macos")))]
/// The native thread waiting on a future, and whether Ruby has
/// interrupted it.
///
/// The thread is recorded where the wait parks, inside the released
/// region, not where the waiter is made: a Ruby thread may resume on
/// another native thread between tries, as it can under the M:N scheduler
/// (always on in Ractors other than the main one, Ruby NEWS for 3.3.0),
/// and the waker must unpark the thread that parked.
#[derive(Default)]
pub struct Waiter {
    thread: Mutex<Option<Thread>>,
    interrupted: AtomicBool,
}

#[cfg(all(unix, not(target_os = "macos")))]
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

#[cfg(all(unix, not(target_os = "macos")))]
impl Wake for Waiter {
    fn wake(self: Arc<Self>) {
        self.unpark();
    }

    fn wake_by_ref(self: &Arc<Self>) {
        self.unpark();
    }
}

#[cfg(all(unix, not(target_os = "macos")))]
/// Ruby's unblocking function for [`wait`]: interrupts the waiter. It
/// stores a flag and unparks a thread under the waiter's own lock, which
/// no Ruby lock guards and which is held only to read or replace the
/// thread.
impl Unblock for Waiter {
    fn unblock(&self) {
        self.interrupt();
    }
}

#[cfg(all(unix, not(target_os = "macos")))]
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

#[cfg(all(unix, not(target_os = "macos")))]
/// Waits for `poll` to be ready with the GVL released, letting Ruby
/// interrupt the wait (plan 003, decision 6).
///
/// Returns the ready value, or the payload of a panic in `poll`, or the
/// exception an interrupt raised; then the caller still holds whatever
/// `poll` polls, unfinished, and may wait on it again. An interrupt that
/// raises nothing (a trap that returns) waits again. An interrupt that
/// raises just after `poll` was ready discards the value, as
/// [`without_gvl`] says.
pub fn wait<T>(
    ruby: &Ruby,
    mut poll: impl FnMut(&mut Context<'_>) -> Poll<T>,
) -> Result<std::thread::Result<T>, Error> {
    let waiter = Waiter::new();
    wait_until(
        ruby,
        &*waiter,
        || match poll_until(&waiter, &mut poll) {
            Poll::Ready(value) => Some(value),
            Poll::Pending => None,
        },
        |value| value,
    )
}

#[cfg(test)]
mod tests {
    use super::{drive, interrupt, run, Call, Unblock, RELEASES};
    #[cfg(all(unix, not(target_os = "macos")))]
    use super::{poll_until, Waiter};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::sync::atomic::{AtomicBool, Ordering};
    #[cfg(all(unix, not(target_os = "macos")))]
    use std::task::Poll;

    fn call_run<W: FnMut() -> Option<G>, F: FnOnce(G) -> T, G, T>(call: &mut Call<W, F, T>) {
        run::<W, F, G, T>(ptr::from_mut(call).cast::<c_void>());
    }

    #[test]
    fn run_runs_the_work_once_on_what_the_wait_gave() {
        let runs = Cell::new(0);
        let mut call = Call::new(
            || Some(4),
            |ready| {
                runs.set(runs.get() + 1);
                ready * 2
            },
        );
        call_run(&mut call);
        call_run(&mut call);
        assert!(matches!(call.outcome, Some(Ok(8))));
        assert_eq!(runs.get(), 1);
    }

    #[test]
    fn a_wait_that_gives_up_keeps_the_work_for_the_next_run() {
        let waits = Cell::new(0);
        let mut call = Call::new(
            || {
                waits.set(waits.get() + 1);
                (waits.get() > 1).then_some(3)
            },
            |ready| ready,
        );
        call_run(&mut call);
        assert!(call.outcome.is_none());
        call_run(&mut call);
        assert!(matches!(call.outcome, Some(Ok(3))));
    }

    // Other tests run `run` on other threads at the same time, so this
    // looks only for its own increment.
    #[test]
    fn running_unlocked_counts_a_release() {
        let before = RELEASES.load(Ordering::Relaxed);
        let mut call = Call::new(|| Some(()), |()| ());
        call_run(&mut call);
        assert!(RELEASES.load(Ordering::Relaxed) > before);
    }

    #[test]
    fn run_catches_a_panic_in_the_work_or_the_wait_as_the_outcome() {
        let mut call = Call::new(|| Some(()), |()| -> u8 { panic!("inside") });
        call_run(&mut call);
        let payload = call
            .outcome
            .expect("the work ran")
            .expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));

        let mut call = Call::new(|| -> Option<()> { panic!("waiting") }, |()| 0_u8);
        call_run(&mut call);
        let payload = call
            .outcome
            .expect("the wait ran")
            .expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"waiting"));
    }

    #[test]
    fn a_try_that_gave_up_runs_again() {
        let tries = Cell::new(0);
        let call = Call::new(|| (tries.get() > 1).then_some(5), |ready| ready);
        let outcome = drive(call, |call| -> Result<(), ()> {
            tries.set(tries.get() + 1);
            call_run(call);
            Ok(())
        });
        assert!(matches!(outcome, Ok(Ok(5))));
        assert_eq!(tries.get(), 2);
    }

    #[test]
    fn an_interrupt_that_raises_before_the_work_drops_it_unrun() {
        let ran = Cell::new(false);
        let call = Call::new(|| Some(()), |()| ran.set(true));
        let outcome = drive(call, |_| Err("Interrupt"));
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
        let call = Call::new(|| Some(()), |()| Value(&dropped));
        let outcome = drive(call, |call| {
            call_run(call);
            Err("Interrupt")
        });
        assert!(matches!(outcome, Err("Interrupt")));
        assert!(dropped.get());
    }

    #[test]
    fn the_unblocking_function_reaches_its_argument() {
        struct Flag(AtomicBool);
        impl Unblock for Flag {
            fn unblock(&self) {
                self.0.store(true, Ordering::Relaxed);
            }
        }
        let flag = Flag(AtomicBool::new(false));
        interrupt::<Flag>(ptr::from_ref(&flag).cast_mut().cast::<c_void>());
        assert!(flag.0.load(Ordering::Relaxed));
    }

    #[cfg(all(unix, not(target_os = "macos")))]
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

    #[cfg(all(unix, not(target_os = "macos")))]
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
                    std::thread::spawn(move || waker.wake());
                    Poll::Pending
                }
            });
            let _ = done.send(outcome);
        });
        // The timeout only turns a lost wake into a failure rather than a
        // hang: no run passes by it.
        let outcome = result
            .recv_timeout(std::time::Duration::from_secs(30))
            .expect("the waiting thread was woken");
        assert_eq!(outcome, Poll::Ready(2));
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    #[test]
    fn unblocking_stops_poll_until_and_keeps_the_future_pending() {
        let waiter = Waiter::new();
        let (polled, polls) = std::sync::mpsc::channel();
        let other = std::sync::Arc::clone(&waiter);
        let interrupter = std::thread::spawn(move || {
            polls.recv().expect("the wait polls");
            other.unblock();
        });
        let outcome: Poll<()> = poll_until(&waiter, |_| {
            let _ = polled.send(());
            Poll::Pending
        });
        interrupter.join().expect("the interrupter ran");
        assert_eq!(outcome, Poll::Pending);
    }
}
