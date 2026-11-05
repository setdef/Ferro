// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! Waits for hotkey events with Ruby's global VM lock released (plan 004,
//! decision 6, and Follow-up: the GVL is never held).
//!
//! An event comes when a person presses a key, so holding the GVL through
//! the wait would stop every other Ruby thread until then. The wait has an
//! unblocking function: crossbeam cannot cancel a `recv` from outside, so
//! the wait is a `select!` over the event channel and a one-slot cancel
//! channel, which the unblocking function fills. Ctrl-C, `Thread#raise`,
//! and `Thread#kill` end the wait; an interrupt that raises nothing (a
//! trap that returns, `Thread#wakeup`) lets it start again.
//!
//! The wait never runs with the GVL held. It goes through
//! `rb_thread_call_without_gvl`, which always runs it, and which runs
//! Ruby's pending interrupts before releasing the GVL and after taking it
//! back (`thread.c:319-343`, `:1628-1638` at Ruby v4.0.9). An interrupt
//! that raises jumps out of that function with `longjmp`, so the call runs
//! inside magnus's `protect`, which catches the jump and returns it as an
//! `Err` for magnus to raise again once every Rust value of the call has
//! been dropped. The jump skips only the closure `protect` runs, which
//! owns nothing.
//!
//! An interrupt that raises after the wait received an event discards the
//! event with the call's return value, and the event cannot be read
//! again: it has left global-hotkey's channel, whose sender global-hotkey
//! keeps private, so nothing can put it back. That happens when the
//! interrupt arrives after the event did but before Ruby's check, or when
//! both are ready together and `select!` picks the event, as it picks one
//! of two ready channels at random. Ruby's own IO does the same:
//! `rb_thread_io_blocking_call` checks interrupts after a read or write
//! returns (`thread.c:1986-1999` at Ruby v4.0.9), and one that raises
//! there discards what it read. The passage on
//! `rb_thread_call_without_gvl` calls that check harmful for work that has
//! finished and recommends `rb_thread_call_without_gvl2` for such work
//! (`thread.c:1685-1699`). This module rejects that function on purpose:
//! it skips the work while any interrupt is pending (`thread.c:320-327`),
//! and an interrupt Ruby holds back stays pending, which led the gem's
//! previous design to poll the channel with the GVL held, in a loop that
//! stalled every other thread until an event came or the timeout passed.
//!
//! The work never touches Ruby: callers convert every argument to Rust
//! values first and build Ruby values after it returns. It catches its own
//! panics, since a panic cannot unwind out of the `extern "C"` function
//! Ruby calls.
//!
//! The design is ferro-rfd's (`gems/rfd`, plan 002, Follow-up: the GVL is
//! never held), itself ferro-arboard's (plan 001, Follow-up: the GVL is
//! never held), whose author, Kerrick Long, licenses this copy as
//! Apache-2.0 OR MIT with the rest of ferro-global-hotkey. magnus 0.9.3
//! does not wrap `rb_thread_call_without_gvl`, so this module calls rb-sys
//! directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::time::Instant;

use crossbeam_channel::{bounded, select, Receiver, Sender};
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
    unblock: Unblock,
) -> Result<(), Error> {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<F, T>;
    let (ubf, ubf_data) = unblock;
    let data = ptr::from_mut(call).cast::<c_void>();
    let nil = ruby.qnil().as_raw();
    protect(|| {
        // SAFETY: The caller holds the GVL, as magnus guarantees for any
        // `&Ruby`. Ruby runs `function` with `data` exactly once, on this
        // thread, with the GVL released, and returns after it does, unless
        // an interrupt raises first (`thread.c:1594-1643`, `:1737-1742`
        // at Ruby v4.0.9). `run` touches no Ruby object, which the NOTE in
        // `thread.c:1709-1716` requires, and never unwinds. The unblocking
        // function is `interrupt` below, whose argument outlives this call,
        // and Ruby clears it before returning (`blocking_region_end`,
        // `thread.c:1546-1551`, under the lock Ruby holds while calling
        // it, `:346-351`, `:353-383`). An interrupt that raises jumps out
        // of this call with `longjmp`, either before the GVL is released
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
            rb_sys::rb_thread_call_without_gvl(Some(function), data, Some(ubf), ubf_data);
        }
        nil
    })?;
    Ok(())
}

/// The loop, with Ruby's call passed in so tests can drive it.
///
/// Each try asks Ruby to run the work, and the loop ends once it has. An
/// `Err` from a try (the exception an interrupt raised) is returned, and
/// drops the work unrun or its outcome unread. With Ruby's plain call
/// the second pass cannot happen, since the call always runs the work
/// unless it raises; the loop stays defensive, and
/// `a_try_that_did_not_run_the_work_runs_again` pins it.
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

/// What a read from an event channel found.
#[derive(Debug, PartialEq, Eq)]
pub enum Received<T> {
    Message(T),
    Timeout,
    Disconnected,
}

/// What one wait ended with: a result, or an interrupt that sends the
/// caller around again.
#[derive(Debug, PartialEq, Eq)]
pub enum Wait<T> {
    Done(Received<T>),
    Interrupted,
}

/// Waits for a message on `receiver` until `deadline`, or until `cancel`
/// receives. With the GVL released, this is the whole wait.
pub fn wait_unlocked<T>(
    receiver: &Receiver<T>,
    deadline: Option<Instant>,
    cancel: &Receiver<()>,
) -> Wait<T> {
    let message = |result: Result<T, crossbeam_channel::RecvError>| {
        Wait::Done(result.map_or(Received::Disconnected, Received::Message))
    };
    deadline.map_or_else(
        || {
            select! {
                recv(receiver) -> result => message(result),
                recv(cancel) -> _ => Wait::Interrupted,
            }
        },
        |deadline| {
            select! {
                recv(receiver) -> result => message(result),
                recv(cancel) -> _ => Wait::Interrupted,
                default(deadline.saturating_duration_since(Instant::now())) => Wait::Done(Received::Timeout),
            }
        },
    )
}

/// Ruby's unblocking function: fills the wait's cancel channel.
extern "C" fn interrupt(data: *mut c_void) {
    // SAFETY: `data` is the `Sender<()>` that `recv` keeps alive until
    // `rb_thread_call_without_gvl` returns or jumps, and Ruby calls this
    // only before then (see `release_and_run`). Ruby calls it from another
    // thread, perhaps another Ractor's, holding the waiting thread's
    // interrupt lock, and never from a signal handler, which only an
    // `RB_NOGVL_UBF_ASYNC_SAFE` call allows (`thread_pthread.c:2684-2686`,
    // `thread.c:1621-1624` at Ruby v4.0.9). `try_send` on a bounded channel
    // takes crossbeam's own lock, which no Ruby lock guards, wakes the
    // waiting thread, and never blocks; `Sender` is `Sync`, so a shared
    // reference may be used from this thread.
    #[allow(unsafe_code)]
    let cancel = unsafe { &*data.cast_const().cast::<Sender<()>>() };
    // A panic cannot unwind out of an `extern "C"` function; `try_send`
    // does not panic, and if it did, the wait would only go on.
    let _ = panic::catch_unwind(AssertUnwindSafe(|| cancel.try_send(())));
}

/// The wait's loop, with one released wait passed in so tests can drive
/// it: waits again while a wait ends interrupted, and returns what the
/// first one that finishes gives, or the first `Err`.
fn wait_until_done<T, E>(
    mut wait_once: impl FnMut() -> Result<std::thread::Result<Wait<T>>, E>,
) -> Result<std::thread::Result<Received<T>>, E> {
    loop {
        match wait_once()? {
            Ok(Wait::Done(found)) => return Ok(Ok(found)),
            Err(payload) => return Ok(Err(payload)),
            Ok(Wait::Interrupted) => {}
        }
    }
}

/// Waits for a message on `receiver` with the GVL released, until
/// `deadline` if there is one, letting Ruby interrupt the wait.
///
/// Returns what the read found, or the payload of a panic, or the
/// exception an interrupt raised. Ruby runs an interrupt as each wait
/// returns; one that raises nothing (a trap that returns,
/// `Thread#wakeup`) lets the wait start again. An interrupt that raises
/// after the wait received a message discards it, the trade-off the
/// module documentation explains.
pub fn recv<T>(
    ruby: &Ruby,
    receiver: &Receiver<T>,
    deadline: Option<Instant>,
) -> Result<std::thread::Result<Received<T>>, Error> {
    wait_until_done(|| {
        let (cancel, cancelled) = bounded::<()>(1);
        let unblock: Unblock = (
            interrupt,
            ptr::from_ref(&cancel).cast_mut().cast::<c_void>(),
        );
        drive(
            Call::new(|| wait_unlocked(receiver, deadline, &cancelled)),
            |call| release_and_run(ruby, call, unblock),
        )
    })
}

#[cfg(test)]
mod tests {
    use super::{drive, interrupt, run, wait_unlocked, wait_until_done, Call, Received, Wait};
    use crossbeam_channel::{bounded, unbounded};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::time::{Duration, Instant};

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

    /// The late-interrupt trade-off: a message the wait received is
    /// dropped with the work's value when the interrupt raises after it,
    /// and has left its channel, so a second read finds nothing.
    #[test]
    fn an_interrupt_that_raises_after_the_wait_drops_the_message_it_received() {
        let (events, receiver) = unbounded::<u32>();
        let (_cancel, cancelled) = bounded::<()>(1);
        events.send(3).expect("the receiver is open");
        let outcome = drive(
            Call::new(|| wait_unlocked(&receiver, None, &cancelled)),
            |call| {
                call_run(call);
                Err("Interrupt")
            },
        );
        assert!(matches!(outcome, Err("Interrupt")));
        assert!(receiver.try_recv().is_err());
    }

    #[test]
    fn a_wait_ended_by_an_interrupt_that_raised_nothing_waits_again() {
        let waits = Cell::new(0);
        let outcome = wait_until_done(|| -> Result<_, ()> {
            waits.set(waits.get() + 1);
            Ok(Ok(if waits.get() < 3 {
                Wait::Interrupted
            } else {
                Wait::Done(Received::Message(9))
            }))
        });
        assert!(matches!(outcome, Ok(Ok(Received::Message(9)))));
        assert_eq!(waits.get(), 3);
    }

    #[test]
    fn a_wait_ends_on_an_interrupt_that_raised_or_a_panic() {
        let raised =
            wait_until_done(|| -> Result<std::thread::Result<Wait<u8>>, _> { Err("Interrupt") });
        assert_eq!(raised.err(), Some("Interrupt"));

        let panicked = wait_until_done(|| -> Result<std::thread::Result<Wait<u8>>, ()> {
            Ok(Err(Box::new("inside")))
        });
        let payload = panicked.expect("no interrupt").expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn a_wait_returns_the_message_that_arrives() {
        let (events, receiver) = unbounded();
        let (_cancel, cancelled) = bounded::<()>(1);
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(50));
            events.send(7_u32).expect("the receiver is open");
        });
        assert_eq!(
            wait_unlocked(&receiver, None, &cancelled),
            Wait::Done(Received::Message(7))
        );
    }

    /// Ruby's unblocking function, called from another thread as Ruby's
    /// timer thread calls it, ends a wait that has no deadline and leaves
    /// the channel's messages alone.
    #[test]
    fn the_unblocking_function_ends_a_wait_and_keeps_later_messages() {
        let (events, receiver) = unbounded::<u32>();
        let (cancel, cancelled) = bounded::<()>(1);
        let address = ptr::from_ref(&cancel) as usize;
        let interrupter = std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(50));
            interrupt(address as *mut c_void);
        });
        let (done, finished) = bounded(1);
        let waiter = std::thread::spawn({
            let receiver = receiver.clone();
            move || {
                let _ = done.send(wait_unlocked(&receiver, None, &cancelled));
            }
        });
        assert_eq!(
            finished.recv_timeout(Duration::from_secs(10)),
            Ok(Wait::Interrupted)
        );
        waiter.join().expect("the waiter ran");
        interrupter.join().expect("the interrupter ran");
        events.send(9).expect("the receiver is open");
        assert_eq!(receiver.try_recv(), Ok(9));
    }

    #[test]
    fn a_wait_with_a_deadline_times_out() {
        let (_events, receiver) = unbounded::<u32>();
        let (_cancel, cancelled) = bounded::<()>(1);
        let started = Instant::now();
        let outcome = wait_unlocked(
            &receiver,
            Some(started + Duration::from_millis(100)),
            &cancelled,
        );
        assert_eq!(outcome, Wait::Done(Received::Timeout));
        assert!(started.elapsed() >= Duration::from_millis(100));
    }

    #[test]
    fn a_closed_channel_reads_as_disconnected() {
        let (events, receiver) = unbounded::<u32>();
        drop(events);
        let (_cancel, cancelled) = bounded::<()>(1);
        assert_eq!(
            wait_unlocked(&receiver, None, &cancelled),
            Wait::Done(Received::Disconnected)
        );
    }
}
