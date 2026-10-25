// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Runs an arboard call with Ruby's global VM lock released, for the calls
//! that can block (plan 001, decision 14).
//!
//! Only some calls block for long: on Linux, a `Set` with `wait`,
//! `wait_until`, or `wait_once` serves the clipboard until another program
//! takes it (arboard `src/platform/linux/x11.rs:281-296`; on Wayland,
//! `wayland.rs:63-68` runs wl-clipboard-rs in the foreground), and a read
//! polls the owning program for up to four seconds (`x11.rs:101`,
//! `:371-378`). Holding the GVL through those would stop every other Ruby
//! thread. Releasing it has a cost too: getting it back waits for each
//! thread that wants it to use up its time slice, which Ruby warns about
//! for short calls (`thread.c:1721-1723` at Ruby v4.0.1). So the callers in
//! `lib.rs` release it only for the calls above, and every other call runs
//! with the GVL held.
//!
//! The work runs with no Ruby API in reach: callers convert every argument
//! to Rust values first and build Ruby values after it returns, and the
//! work never sees a `Ruby` handle. It catches its own panics, since a
//! panic cannot unwind out of the `extern "C"` function Ruby calls.
//!
//! There is no unblocking function. arboard offers no way to cancel a call
//! in progress, so `Thread#kill`, `Thread#raise`, and Ctrl-C take effect
//! once the call returns. Ruby documents that a call without one "will not
//! stop for Control+C" (`thread.c:1677-1679`). Process exit waits for it
//! too: Ruby kills the other threads and then waits for each to finish
//! (`rb_thread_terminate_all`, `thread.c:484-493`).
//!
//! magnus 0.9.3 does not wrap `rb_thread_call_without_gvl`, so this module
//! calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;

use magnus::{Error, Ruby};

/// Whether the work runs with the GVL released or, on the fallback path,
/// held. Work that waits on a lock another thread may hold for long must
/// not wait while the GVL is held.
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
pub extern "C" fn run<F: FnOnce(Gvl) -> T, T>(data: *mut c_void) -> *mut c_void {
    // SAFETY: `data` is the `&mut Call<F, T>` that `release_and_run` (or a
    // test) passed in, and it outlives this call: `rb_nogvl` calls `func`
    // synchronously on the calling thread and returns only after it does
    // (`thread.c:1628-1631` at Ruby v4.0.1), so nothing else holds the
    // reference meanwhile.
    #[allow(unsafe_code)]
    let call = unsafe { &mut *data.cast::<Call<F, T>>() };
    call.run(Gvl::Released);
    ptr::null_mut()
}

/// Asks Ruby to run the work with the GVL released. Ruby may skip it when
/// an interrupt is pending; then `call` still holds the work.
fn release_and_run<F: FnOnce(Gvl) -> T, T>(call: &mut Call<F, T>) {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<F, T>;
    // SAFETY: Ruby calls `function` with `data1` at most once, on this
    // thread, with the GVL released, and returns after it does
    // (`thread.c:1594-1643`, `:1731-1735` at Ruby v4.0.1). `run` touches no
    // Ruby object, which the NOTE in `thread.c:1709-1716` requires, and
    // never unwinds. A null unblocking function and argument are allowed:
    // Ruby stores the null pointer and calls the function only when it is
    // non-null (`thread.c:336-338`, `:367-368`). The caller holds the GVL
    // here, as magnus guarantees for any `&Ruby`.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_thread_call_without_gvl2(
            Some(function),
            ptr::from_mut(call).cast::<c_void>(),
            None,
            ptr::null_mut(),
        );
    }
}

/// The retry loop, with Ruby's two calls passed in so tests can drive it.
///
/// Each try asks for the work to run unlocked. When it was skipped for a
/// pending interrupt, `check_ints` runs that interrupt; an `Err` from it
/// (the exception the interrupt raised) is returned and the work never
/// runs. After `TRIES` skips, the work runs with the GVL held. At Ruby
/// v4.0.1 that is rare: running the interrupts clears every pending flag
/// a handler does not mask (`thread.c:2256-2283`, `:2595-2607`, `:2679`),
/// so a try is skipped again only when an interrupt is already being
/// raised (`thread.c:2625`) or a new one arrives each time.
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
/// or the payload of the panic it raised. `work` learns whether the GVL is
/// released or held (the rare fallback in `drive`).
///
/// It uses `rb_thread_call_without_gvl2`, not `rb_thread_call_without_gvl`:
/// the latter checks interrupts after reacquiring the GVL and may raise
/// from there (`thread.c:1636-1638`), a `longjmp` across these Rust frames.
/// The `2` variant instead skips the work when an interrupt is already
/// pending (`thread.c:320-334`, `:1523-1542`, `:1731-1735`), and the
/// interrupt then runs through magnus's protected `thread_check_ints`,
/// which returns any exception it raises as an `Err`.
pub fn without_gvl<F: FnOnce(Gvl) -> T, T>(
    ruby: &Ruby,
    work: F,
) -> Result<std::thread::Result<T>, Error> {
    let mut call = Call::new(work);
    drive(&mut call, release_and_run, || ruby.thread_check_ints())
}

#[cfg(test)]
mod tests {
    use super::{drive, run, Call, Gvl, TRIES};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;

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
}
