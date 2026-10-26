// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! Waits for hotkey events with Ruby's global VM lock released (plan 004,
//! decision 6).
//!
//! An event comes when a person presses a key, so holding the GVL through
//! the wait would stop every other Ruby thread until then. The wait has an
//! unblocking function: crossbeam cannot cancel a `recv` from outside, so
//! the wait is a `select!` over the event channel and a one-slot cancel
//! channel, which the unblocking function fills. Ctrl-C, `Thread#raise`,
//! and `Thread#kill` end the wait, and an event that arrives during it
//! usually stays in its channel for the next read. When the event and the
//! interrupt are both ready, `select!` picks one at random: picking the
//! event returns it, and then the interrupt's exception replaces that
//! return value in Ruby, so the event is lost. global-hotkey's channel
//! keeps its sender private, so nothing can put the event back.
//!
//! The work never touches Ruby: callers convert every argument to Rust
//! values first and build Ruby values after it returns. It catches its own
//! panics, since a panic cannot unwind out of the `extern "C"` function
//! Ruby calls.
//!
//! The retry loop and its tests are ferro-rfd's (`gems/rfd`, plan 002,
//! decision 4), itself built on ferro-arboard's (plan 001, decision 14).
//! Their author, Kerrick Long, licenses this copy as Apache-2.0 OR MIT
//! with the rest of ferro-global-hotkey. magnus 0.9.3 does not wrap
//! `rb_thread_call_without_gvl2`, so this module calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::time::Instant;

use crossbeam_channel::{bounded, select, Receiver, Sender, TryRecvError};
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
fn release_and_run<F: FnOnce(Gvl) -> T, T>(call: &mut Call<F, T>, unblock: Unblock) {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<F, T>;
    let (ubf, ubf_data) = unblock;
    // SAFETY: Ruby calls `function` with `data1` at most once, on this
    // thread, with the GVL released, and returns after it does
    // (`thread.c:1594-1643`, `:1730-1735` at Ruby v4.0.9). `run` touches no
    // Ruby object, which the NOTE in `thread.c:1709-1716` requires, and
    // never unwinds. The unblocking function is `interrupt` below, whose
    // argument outlives the call, and Ruby clears it before returning
    // (`blocking_region_end`, `thread.c:1546-1551`, and
    // `unblock_function_clear` takes the lock Ruby holds while calling it,
    // `thread.c:346-351`, `:375-383`). The caller holds the GVL here, as
    // magnus guarantees for any `&Ruby`.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_thread_call_without_gvl2(
            Some(function),
            ptr::from_mut(call).cast::<c_void>(),
            Some(ubf),
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

/// What a read from an event channel found.
#[derive(Debug, PartialEq, Eq)]
pub enum Received<T> {
    Message(T),
    Timeout,
    Disconnected,
}

/// What one wait ended with: a result, or an interrupt (or, on the
/// fallback path, an empty channel) that sends the caller around again.
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

/// Reads `receiver` once without waiting, for the path where the work runs
/// with the GVL held: a message, a passed deadline, or `Interrupted` to try
/// again.
pub fn poll_once<T>(receiver: &Receiver<T>, deadline: Option<Instant>) -> Wait<T> {
    match receiver.try_recv() {
        Ok(message) => Wait::Done(Received::Message(message)),
        Err(TryRecvError::Disconnected) => Wait::Done(Received::Disconnected),
        Err(TryRecvError::Empty) if deadline.is_some_and(|deadline| Instant::now() >= deadline) => {
            Wait::Done(Received::Timeout)
        }
        Err(TryRecvError::Empty) => Wait::Interrupted,
    }
}

/// Ruby's unblocking function: fills the wait's cancel channel.
extern "C" fn interrupt(data: *mut c_void) {
    // SAFETY: `data` is the `Sender<()>` that `recv` keeps alive until
    // `rb_thread_call_without_gvl2` returns, and Ruby calls this only
    // before then (see `release_and_run`). `try_send` on a bounded channel
    // takes crossbeam's own lock and wakes the waiting thread; it touches
    // nothing of Ruby's and never blocks.
    #[allow(unsafe_code)]
    let cancel = unsafe { &*data.cast_const().cast::<Sender<()>>() };
    let _ = cancel.try_send(());
}

/// Waits for a message on `receiver` with the GVL released, until
/// `deadline` if there is one, letting Ruby interrupt the wait.
///
/// Returns what the read found, or the payload of a panic, or the
/// exception an interrupt raised. An interrupt that raises nothing (a trap
/// that returns) waits again.
pub fn recv<T>(
    ruby: &Ruby,
    receiver: &Receiver<T>,
    deadline: Option<Instant>,
) -> Result<std::thread::Result<Received<T>>, Error> {
    loop {
        let (cancel, cancelled) = bounded::<()>(1);
        let unblock: Unblock = (
            interrupt,
            ptr::from_ref(&cancel).cast_mut().cast::<c_void>(),
        );
        let mut call = Call::new(|gvl| match gvl {
            Gvl::Released => wait_unlocked(receiver, deadline, &cancelled),
            Gvl::Held => poll_once(receiver, deadline),
        });
        let outcome = drive(
            &mut call,
            |call| release_and_run(call, unblock),
            || ruby.thread_check_ints(),
        )?;
        match outcome {
            Ok(Wait::Done(found)) => return Ok(Ok(found)),
            Err(payload) => return Ok(Err(payload)),
            Ok(Wait::Interrupted) => ruby.thread_check_ints()?,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        drive, interrupt, poll_once, run, wait_unlocked, Call, Gvl, Received, Wait, TRIES,
    };
    use crossbeam_channel::{bounded, unbounded};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::time::{Duration, Instant};

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
        assert_eq!(
            wait_unlocked(&receiver, None, &cancelled),
            Wait::Interrupted
        );
        interrupter.join().expect("the interrupter ran");
        events.send(9).expect("the receiver is open");
        assert_eq!(poll_once(&receiver, None), Wait::Done(Received::Message(9)));
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
        assert_eq!(
            poll_once(&receiver, None),
            Wait::Done(Received::Disconnected)
        );
    }

    #[test]
    fn a_poll_with_the_gvl_held_retries_until_its_deadline_passes() {
        let (_events, receiver) = unbounded::<u32>();
        assert_eq!(poll_once(&receiver, None), Wait::Interrupted);
        let future = Instant::now() + Duration::from_secs(60);
        assert_eq!(poll_once(&receiver, Some(future)), Wait::Interrupted);
        let past = Instant::now().checked_sub(Duration::from_millis(1));
        assert_eq!(poll_once(&receiver, past), Wait::Done(Received::Timeout));
    }
}
