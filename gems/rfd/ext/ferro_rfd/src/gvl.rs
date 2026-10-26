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
//!   threads and then waits for each to finish.
//! - Waiting on a future, through [`wait`], with an unblocking function.
//!   Waiting is only parking the thread until rfd's waker unparks it, so
//!   an interrupt can unpark it too: the wait ends, the future stays
//!   pending, and the interrupt runs.
//!
//! The work never touches Ruby: callers convert every argument to Rust
//! values first and build Ruby values after it returns. It catches its own
//! panics, since a panic cannot unwind out of the `extern "C"` function
//! Ruby calls.
//!
//! The retry loop and its tests are ferro-arboard's (`gems/arboard`, plan
//! 001, decision 14), whose author, Kerrick Long, licenses this copy as
//! MIT with the rest of ferro-rfd. magnus 0.9.3 does not wrap
//! `rb_thread_call_without_gvl2`, so this module calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, PoisonError};
use std::task::{Context, Poll, Wake, Waker};
use std::thread::Thread;

use magnus::{Error, Ruby};

/// Whether the work runs with the GVL released or, on the fallback path,
/// held.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Gvl {
    Released,
    Held,
}

/// How many times `drive` lets Ruby skip the work for a pending interrupt
/// before running it with the GVL held.
pub const TRIES: usize = 3;

/// One piece of work, and the slot its outcome lands in.
pub struct Call<F, T> {
    work: Option<F>,
    outcome: Option<std::thread::Result<T>>,
}

impl<F: FnOnce(Gvl) -> T, T> Call<F, T> {
    pub const fn new(work: F) -> Self {
        Self {
            work: Some(work),
            outcome: None,
        }
    }

    /// Runs the work, if it has not run, catching a panic as the outcome.
    fn run(&mut self, gvl: Gvl) {
        if let Some(work) = self.work.take() {
            self.outcome = Some(panic::catch_unwind(AssertUnwindSafe(|| work(gvl))));
        }
    }
}

/// The function Ruby runs without the GVL. It runs the work once, catching
/// a panic as the outcome, and touches nothing of Ruby's.
extern "C" fn run<F: FnOnce(Gvl) -> T, T>(data: *mut c_void) -> *mut c_void {
    // SAFETY: `data` is the `&mut Call<F, T>` that `release_and_run` (or a
    // test) passed in, and it outlives this call: `rb_nogvl` calls `func`
    // synchronously on the calling thread and returns only after it does
    // (`thread.c:1594-1643` at Ruby v4.0.9), so nothing else holds the
    // reference meanwhile.
    #[allow(unsafe_code)]
    let call = unsafe { &mut *data.cast::<Call<F, T>>() };
    call.run(Gvl::Released);
    ptr::null_mut()
}

/// An unblocking function and its argument, for Ruby to call when it
/// interrupts the thread while the work runs.
type Unblock = (unsafe extern "C" fn(*mut c_void), *mut c_void);

/// Asks Ruby to run the work with the GVL released. Ruby may skip it when
/// an interrupt is pending; then `call` still holds the work.
fn release_and_run<F: FnOnce(Gvl) -> T, T>(call: &mut Call<F, T>, unblock: Option<Unblock>) {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<F, T>;
    let (ubf, ubf_data) = unblock.map_or((None, ptr::null_mut()), |(ubf, data)| (Some(ubf), data));
    // SAFETY: Ruby calls `function` with `data1` at most once, on this
    // thread, with the GVL released, and returns after it does
    // (`thread.c:1594-1643`, `:1730-1735` at Ruby v4.0.9). `run` touches no
    // Ruby object, which the NOTE in `thread.c:1709-1716` requires, and
    // never unwinds. A null unblocking function is allowed: Ruby calls one
    // only when it is non-null (`thread.c:367-369`). A non-null one is
    // `interrupt` below, whose argument outlives the call, and Ruby clears
    // it before returning (`blocking_region_end`, `thread.c:1546-1551`,
    // and `unblock_function_clear` takes the lock Ruby holds while calling
    // it, `thread.c:346-351`, `:375-383`). The caller holds the GVL here,
    // as magnus guarantees for any `&Ruby`.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_thread_call_without_gvl2(
            Some(function),
            ptr::from_mut(call).cast::<c_void>(),
            ubf,
            ubf_data,
        );
    }
}

/// The retry loop, with Ruby's two calls passed in so tests can drive it.
///
/// Each try asks for the work to run unlocked. When it was skipped for a
/// pending interrupt, `check_ints` runs that interrupt; an `Err` from it
/// (the exception the interrupt raised) is returned and the work never
/// runs. After `TRIES` skips, the work runs with the GVL held. Running the
/// interrupts clears every pending flag a handler does not mask, so a try
/// is skipped again only when an interrupt is already being raised or a
/// new one arrives each time.
pub fn drive<F: FnOnce(Gvl) -> T, T, E>(
    call: &mut Call<F, T>,
    mut try_unlocked: impl FnMut(&mut Call<F, T>),
    mut check_ints: impl FnMut() -> Result<(), E>,
) -> Result<std::thread::Result<T>, E> {
    for _ in 0..TRIES {
        try_unlocked(call);
        if let Some(outcome) = call.outcome.take() {
            return Ok(outcome);
        }
        check_ints()?;
    }
    call.run(Gvl::Held);
    Ok(call
        .outcome
        .take()
        .unwrap_or_else(|| Err(Box::new("the work had already run"))))
}

/// Runs `work` with the GVL released and returns its outcome: its value,
/// or the payload of the panic it raised.
///
/// It uses `rb_thread_call_without_gvl2`, not `rb_thread_call_without_gvl`:
/// the latter checks interrupts after reacquiring the GVL and may raise
/// from there (`thread.c:1636-1638`), a `longjmp` across these Rust frames.
/// The `2` variant instead skips the work when an interrupt is already
/// pending, and the interrupt then runs through magnus's protected
/// `thread_check_ints`, which returns any exception it raises as an `Err`.
pub fn without_gvl<F: FnOnce(Gvl) -> T, T>(
    ruby: &Ruby,
    work: F,
) -> Result<std::thread::Result<T>, Error> {
    let mut call = Call::new(work);
    drive(
        &mut call,
        |call| release_and_run(call, None),
        || ruby.thread_check_ints(),
    )
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
    // until `rb_thread_call_without_gvl2` returns, and Ruby calls this only
    // before then (see `release_and_run`). It stores a flag and unparks a
    // thread under the waiter's own lock, which no Ruby lock guards and
    // which is held only to read or replace the thread.
    #[allow(unsafe_code)]
    let waiter = unsafe { &*data.cast_const().cast::<Waiter>() };
    waiter.interrupt();
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

/// Waits for `poll` to be ready with the GVL released, letting Ruby
/// interrupt the wait (plan 002, decision 3).
///
/// Returns the ready value, or the payload of a panic in `poll`, or the
/// exception an interrupt raised; then the caller still holds whatever
/// `poll` polls, unfinished, and may wait on it again. An interrupt that
/// raises nothing (a trap that returns) waits again. On the rare path
/// where Ruby skips every try, `poll` runs once with the GVL held, and if
/// that finds nothing ready the wait starts over.
pub fn wait<T>(
    ruby: &Ruby,
    mut poll: impl FnMut(&mut Context<'_>) -> Poll<T>,
) -> Result<std::thread::Result<T>, Error> {
    loop {
        let waiter = Waiter::new();
        let unblock: Unblock = (interrupt, Arc::as_ptr(&waiter).cast_mut().cast::<c_void>());
        let mut call = Call::new(|gvl| match gvl {
            Gvl::Released => poll_until(&waiter, &mut poll),
            Gvl::Held => {
                waiter.park_here();
                let waker = Waker::from(Arc::clone(&waiter));
                poll(&mut Context::from_waker(&waker))
            }
        });
        let outcome = drive(
            &mut call,
            |call| release_and_run(call, Some(unblock)),
            || ruby.thread_check_ints(),
        )?;
        match outcome {
            Ok(Poll::Ready(value)) => return Ok(Ok(value)),
            Err(payload) => return Ok(Err(payload)),
            // Interrupted, or polled once with the GVL held: run any
            // interrupt (an exception ends the wait), then wait again.
            Ok(Poll::Pending) => ruby.thread_check_ints()?,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{drive, poll_until, run, Call, Gvl, Waiter, TRIES};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::task::Poll;

    fn call_run<F: FnOnce(Gvl) -> T, T>(call: &mut Call<F, T>) {
        run::<F, T>(ptr::from_mut(call).cast::<c_void>());
    }

    #[test]
    fn run_runs_the_work_once_unlocked_and_keeps_its_value() {
        let mut runs = 0;
        let mut call = Call::new(|gvl| {
            runs += 1;
            gvl
        });
        call_run(&mut call);
        call_run(&mut call);
        assert!(matches!(call.outcome, Some(Ok(Gvl::Released))));
        drop(call);
        assert_eq!(runs, 1);
    }

    #[test]
    fn run_catches_a_panic_as_the_outcome() {
        let mut call = Call::new(|_| -> u8 { panic!("inside") });
        call_run(&mut call);
        let payload = call
            .outcome
            .expect("the work ran")
            .expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn a_skipped_try_checks_interrupts_then_runs_unlocked() {
        let tries = Cell::new(0);
        let checks = Cell::new(0);
        let mut call = Call::new(|gvl| gvl);
        let outcome = drive(
            &mut call,
            |call| {
                tries.set(tries.get() + 1);
                if tries.get() == 2 {
                    call_run(call);
                }
            },
            || -> Result<(), ()> {
                checks.set(checks.get() + 1);
                Ok(())
            },
        );
        assert!(matches!(outcome, Ok(Ok(Gvl::Released))));
        assert_eq!((tries.get(), checks.get()), (2, 1));
    }

    #[test]
    fn after_every_try_is_skipped_the_work_runs_with_the_gvl_held() {
        let tries = Cell::new(0);
        let checks = Cell::new(0);
        let mut call = Call::new(|gvl| gvl);
        let outcome = drive(
            &mut call,
            |_| tries.set(tries.get() + 1),
            || -> Result<(), ()> {
                checks.set(checks.get() + 1);
                Ok(())
            },
        );
        assert!(matches!(outcome, Ok(Ok(Gvl::Held))));
        assert_eq!((tries.get(), checks.get()), (TRIES, TRIES));
    }

    #[test]
    fn an_interrupt_that_raises_drops_the_work_unrun() {
        let ran = Cell::new(false);
        let mut call = Call::new(|_| ran.set(true));
        let outcome = drive(&mut call, |_| {}, || Err("Interrupt"));
        assert_eq!(outcome.err(), Some("Interrupt"));
        drop(call);
        assert!(!ran.get());
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
