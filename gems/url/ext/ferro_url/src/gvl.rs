// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Runs url's `socket_addrs` on a thread of its own and waits for it with
//! Ruby's global VM lock released, so an interrupt ends the wait (plan
//! 005, decision 11).
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
//! (`ext/socket/raddrinfo.c:489-498`, `:554-618` at Ruby v4.0.9).
//!
//! The work runs with no Ruby API in reach: callers convert every argument
//! to Rust values first and build Ruby values after it returns. Every other
//! url call is short and keeps the GVL: getting it back after a release
//! waits for each thread that wants it to use up its time slice, which Ruby
//! warns about for short calls (`thread.c:1721-1723` at Ruby v4.0.1).
//!
//! magnus 0.9.3 does not wrap `rb_thread_call_without_gvl2`, so this module
//! calls rb-sys directly.

use std::ffi::c_void;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;

use magnus::{Error, Ruby};

/// How many waits have run with the GVL released in this process, for the
/// tests (`Native.gvl_releases`).
pub static RELEASES: AtomicUsize = AtomicUsize::new(0);

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
    // SAFETY: `data` is the `&mut Wait<T>` that `release_and_wait` passed,
    // and it outlives this call: `rb_nogvl` calls `func` synchronously on
    // the calling thread and returns only after it does (`thread.c:1594-1643`
    // at Ruby v4.0.9), so nothing else holds the reference meanwhile.
    #[allow(unsafe_code)]
    let state = unsafe { &mut *data.cast::<Wait<T>>() };
    RELEASES.fetch_add(1, Ordering::Relaxed);
    state.wait();
    ptr::null_mut()
}

/// The unblocking function: tells the waiting thread to return.
extern "C" fn interrupt<T>(data: *mut c_void) {
    // SAFETY: `data` is the `&Sender<Message<T>>` that `release_and_wait`
    // passed. Ruby calls this only while the blocking region it was given
    // for is active and clears it before `rb_nogvl` returns
    // (`blocking_region_end`, `thread.c:1546-1551`; `unblock_function_clear`
    // takes the interrupt lock Ruby holds while calling it, `thread.c:346-351`,
    // `:375-383`), and the sender outlives that call. `Sender` is `Sync`, so
    // a shared reference from Ruby's interrupting thread is sound, and
    // sending on an unbounded channel never blocks.
    #[allow(unsafe_code)]
    let sender = unsafe { &*data.cast::<Sender<Message<T>>>() };
    let _ = sender.send(Message::Interrupted);
}

/// Asks Ruby to run one wait with the GVL released, interruptible through
/// `sender`. Ruby skips the wait when an interrupt is already pending; then
/// `state.seen` stays empty.
fn release_and_wait<T>(state: &mut Wait<T>, sender: &Sender<Message<T>>) {
    let function: unsafe extern "C" fn(*mut c_void) -> *mut c_void = wait::<T>;
    let unblock: unsafe extern "C" fn(*mut c_void) = interrupt::<T>;
    // SAFETY: Ruby calls `function` with `state` at most once, on this
    // thread, with the GVL released, and returns after it does
    // (`thread.c:1594-1643`, `:1730-1735` at Ruby v4.0.9). `wait` touches no
    // Ruby object, which the NOTE in `thread.c:1709-1716` requires, and never
    // unwinds. `interrupt` and its argument are sound as its own SAFETY
    // comment says. The caller holds the GVL here, as magnus guarantees for
    // any `&Ruby`. The `2` variant never raises from inside the call
    // (`thread.c:1636-1638`), which would `longjmp` across these frames.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_thread_call_without_gvl2(
            Some(function),
            ptr::from_mut(state).cast::<c_void>(),
            Some(unblock),
            ptr::from_ref(sender).cast_mut().cast::<c_void>(),
        );
    }
}

/// The wait loop, with Ruby's two calls passed in so tests can drive it.
///
/// Each round waits unlocked. The work's outcome ends the loop. An
/// interrupt, or a round Ruby skipped for a pending one, runs `check_ints`;
/// an `Err` from it (the exception the interrupt raised) ends the loop and
/// abandons the work, and an `Ok` (a trap handler that raised nothing)
/// waits again.
pub fn drive<T, E>(
    state: &mut Wait<T>,
    mut try_unlocked: impl FnMut(&mut Wait<T>),
    mut check_ints: impl FnMut() -> Result<(), E>,
) -> Result<thread::Result<T>, E> {
    loop {
        state.seen = None;
        try_unlocked(state);
        match state.seen.take() {
            Some(Message::Done(outcome)) => return Ok(outcome),
            Some(Message::Interrupted) | None => check_ints()?,
        }
    }
}

/// A new wait, and the work started on its own thread, which sends its
/// outcome, a panic included, to the wait's channel.
pub fn start<T: Send + 'static>(
    work: impl FnOnce() -> T + Send + 'static,
) -> std::io::Result<(Wait<T>, Sender<Message<T>>)> {
    let (sender, receiver) = mpsc::channel();
    let worker = sender.clone();
    thread::Builder::new()
        .name("ferro-url lookup".to_owned())
        .spawn(move || {
            let outcome = panic::catch_unwind(AssertUnwindSafe(work));
            let _ = worker.send(Message::Done(outcome));
        })?;
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
/// finish alone. The work never sees a `Ruby` handle.
pub fn in_background<T: Send + 'static>(
    ruby: &Ruby,
    work: impl FnOnce() -> T + Send + 'static,
) -> Result<thread::Result<T>, Error> {
    let (mut state, sender) = start(work).map_err(|failure| {
        crate::error(ruby, format!("could not start a lookup thread: {failure}"))
    })?;
    drive(
        &mut state,
        |state| release_and_wait(state, &sender),
        || ruby.thread_check_ints(),
    )
}

#[cfg(test)]
mod tests {
    use super::{drive, start, Message, Wait};
    use std::sync::mpsc::Sender;
    use std::time::{Duration, Instant};

    /// Waits as Ruby would, with `interrupt` standing in for the unblocking
    /// function, run from another thread after `after`.
    fn wait_with_interrupt<T: Send + 'static>(
        state: &mut Wait<T>,
        sender: &Sender<Message<T>>,
        after: Duration,
    ) {
        let interrupter = sender.clone();
        std::thread::spawn(move || {
            std::thread::sleep(after);
            let _ = interrupter.send(Message::Interrupted);
        });
        state.wait();
    }

    #[test]
    fn a_finished_lookup_ends_the_wait_with_its_value() {
        let (mut state, sender) = start(|| 7).expect("a thread");
        let outcome = drive(&mut state, Wait::wait, || -> Result<(), ()> { Ok(()) });
        drop(sender);
        assert!(matches!(outcome, Ok(Ok(7))));
    }

    #[test]
    fn a_panicking_lookup_ends_the_wait_with_its_payload() {
        let (mut state, _sender) = start(|| -> u8 { panic!("inside") }).expect("a thread");
        let outcome = drive(&mut state, Wait::wait, || -> Result<(), ()> { Ok(()) });
        let payload = outcome.expect("no interrupt").expect_err("it panicked");
        assert_eq!(payload.downcast_ref::<&str>(), Some(&"inside"));
    }

    #[test]
    fn an_interrupt_that_raises_abandons_a_slow_lookup() {
        let (mut state, sender) = start(|| {
            std::thread::sleep(Duration::from_secs(10));
            7
        })
        .expect("a thread");
        let started = Instant::now();
        let outcome = drive(
            &mut state,
            |state| wait_with_interrupt(state, &sender, Duration::from_millis(50)),
            || Err("Interrupt"),
        );
        assert_eq!(outcome.err(), Some("Interrupt"));
        assert!(started.elapsed() < Duration::from_secs(5));
    }

    #[test]
    fn an_interrupt_that_raises_nothing_waits_on_for_the_lookup() {
        let (mut state, sender) = start(|| {
            std::thread::sleep(Duration::from_millis(200));
            7
        })
        .expect("a thread");
        let mut checks = 0;
        let outcome = drive(
            &mut state,
            |state| wait_with_interrupt(state, &sender, Duration::from_millis(10)),
            || -> Result<(), ()> {
                checks += 1;
                Ok(())
            },
        );
        assert!(matches!(outcome, Ok(Ok(7))));
        assert!(checks >= 1);
    }

    #[test]
    fn a_skipped_wait_checks_interrupts_first() {
        let (mut state, _sender) = start(|| 7).expect("a thread");
        let mut tries = 0;
        let outcome = drive(
            &mut state,
            |state| {
                tries += 1;
                if tries > 1 {
                    state.wait();
                }
            },
            || -> Result<(), ()> { Ok(()) },
        );
        assert!(matches!(outcome, Ok(Ok(7))));
        assert_eq!(tries, 2);
    }
}
