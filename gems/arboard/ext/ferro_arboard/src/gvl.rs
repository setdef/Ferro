// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Runs an arboard call with Ruby's global VM lock released, for the calls
//! that can block and for a call that waits its turn at the clipboard
//! (plan 001, decision 14).
//!
//! Only some calls block for long: on Linux, a `Set` with `wait`,
//! `wait_until`, or `wait_once` serves the clipboard until another program
//! takes it (arboard `src/platform/linux/x11.rs:281-296`; on Wayland,
//! `wayland.rs:63-68` runs wl-clipboard-rs in the foreground), and a read
//! polls the owning program for up to four seconds (`x11.rs:101`,
//! `:371-378`). Holding the GVL through those would stop every other Ruby
//! thread. Releasing it has a cost too: getting it back waits for each
//! thread that wants it to use up its time slice, which Ruby warns about
//! for short calls (`thread.c:1721-1723` at Ruby v4.0.9). So the callers in
//! `lib.rs` release it only for the calls above, and for any call that
//! finds another thread using the clipboard.
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
//! The work runs with no Ruby API in reach: callers convert every argument
//! to Rust values first and build Ruby values after it returns, and the
//! work never sees a `Ruby` handle. It catches its own panics, since a
//! panic cannot unwind out of the `extern "C"` function Ruby calls.
//!
//! The work has two parts. The wait (for the clipboard's lock) can be cut
//! short: Ruby calls the unblocking function, `Unblock`, when it wants the
//! thread back, the wait gives up, Ruby runs the interrupt, and, unless the
//! interrupt raised, the wait starts again. arboard offers no way to
//! cancel the call itself, so once it starts, `Thread#kill`,
//! `Thread#raise`, and Ctrl-C take effect when it returns, as Ruby warns
//! for a call nothing can stop (`thread.c:1677-1679`). Process exit waits
//! for it too: Ruby kills the other threads and then waits for each to
//! finish (`rb_thread_terminate_all`, `thread.c:484-493`).
//!
//! magnus 0.9.3 does not wrap `rb_thread_call_without_gvl`, so this module
//! calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicUsize, Ordering};

use magnus::rb_sys::{protect, AsRawValue};
use magnus::{Error, Ruby};

/// How many times work has run with the GVL released in this process.
///
/// The tests read it (`Clipboard#native_gvl_releases`) to tell which path a
/// call took. Whether another Ruby thread actually runs meanwhile is up to
/// Ruby's scheduler: from Ruby 4.0.6 on, a thread returning from a short
/// blocking region takes the GVL straight back when the thread it woke has
/// not started yet (`thread_pthread.c:846-867` and `:1055-1066` at
/// v4.0.9), so a fast read can release the lock without anyone using it.
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

/// Asks Ruby to run the call with the GVL released, inside `protect`.
///
/// Returns the exception a pending interrupt raised, before the call ran
/// or after it, which leaves the outcome in `call`.
fn release_and_run<W: FnMut() -> Option<G>, F: FnOnce(G) -> T, G, T, U: Unblock>(
    ruby: &Ruby,
    call: &mut Call<W, F, T>,
    unblock: &U,
) -> Result<(), Error> {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = run::<W, F, G, T>;
    let ubf: unsafe extern "C" fn(*mut c_void) = interrupt::<U>;
    let data = ptr::from_mut(call).cast::<c_void>();
    let ubf_data = ptr::from_ref(unblock).cast_mut().cast::<c_void>();
    let nil = ruby.qnil().as_raw();
    protect(|| {
        // SAFETY: The caller holds the GVL, as magnus guarantees for any
        // `&Ruby`. Ruby runs `function` with `data` exactly once, on this
        // thread, with the GVL released, and returns after it does, unless
        // an interrupt raises first (`thread.c:1594-1643`, `:1737-1742`
        // at Ruby v4.0.9). `run` touches no Ruby object, which the NOTE in
        // `thread.c:1709-1716` requires, and never unwinds; `interrupt` is
        // the unblocking function (see its SAFETY comment). An interrupt
        // that raises jumps out of this call with `longjmp`, either before
        // the GVL is released (`unblock_function_set`, `thread.c:328`) or
        // after it is taken back (`thread.c:1636-1638`). `protect` (magnus
        // `src/error.rs:449-510`) runs this closure under `rb_protect`, so
        // the jump lands there and skips only this closure and magnus's
        // adapter, which hold raw pointers and a `VALUE`, nothing with a
        // destructor; `call` and everything it owns live in the caller's
        // frame and drop normally. magnus's own `thread_check_ints` jumps
        // over its closure the same way (`src/thread.rs:404-410`).
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

/// Waits with the GVL released until `wait` gives what `work` needs, runs
/// `work` on it, and returns its outcome: its value, or the payload of the
/// panic it or `wait` raised. Or returns the exception an interrupt raised.
///
/// `wait` returns `None` to give up after `unblock` ran; Ruby then runs
/// the interrupt, and unless it raised, `wait` runs again. An interrupt
/// raised after `work` returned discards its value, as Ruby's own blocking
/// calls do (`thread.c:1694-1699`); without this release it would fire as
/// the method returned and discard it all the same.
pub fn without_gvl<W, F, G, T, U>(
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
        release_and_run(ruby, call, unblock)
    })
}

#[cfg(test)]
mod tests {
    use super::{drive, interrupt, run, Call, Unblock, RELEASES};
    use std::cell::Cell;
    use std::ffi::c_void;
    use std::ptr;
    use std::sync::atomic::{AtomicBool, Ordering};

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
}
