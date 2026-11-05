// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The clipboard's lock: a mutex whose wait Ruby can cut short (plan 001,
//! decision 14).
//!
//! arboard's methods take `&mut self`, and any Ruby thread, or any Ractor
//! given a frozen clipboard, may call them, so one call at a time holds
//! the clipboard. On Linux a call can hold it for long: a write that waits
//! serves the clipboard until another program takes it. A thread waiting
//! its turn waits with Ruby's global VM lock released, and Ruby asks for it
//! back when the thread is interrupted (`Thread#raise`, `Thread#kill`, a
//! signal, process exit). `std::sync::Mutex::lock` cannot be cut short, so
//! the turn is a flag under a mutex and a condition variable, and a
//! [`Waiter`] is woken either when the flag clears or when Ruby's
//! unblocking function asks. Contended waiters wake together and are not
//! served in FIFO order, as with std's `Mutex`.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Condvar, Mutex, MutexGuard, PoisonError};

use crate::gvl::Unblock;

/// A value one caller at a time may use.
///
/// `busy` marks a turn in progress; `value` is locked only by the caller
/// whose turn it is, so it is never contended. Neither mutex is held while
/// a caller waits for anything else, and a panic is caught before it could
/// poison them (`capture` in `lib.rs`); a poisoned one is still used.
pub struct Lock<T> {
    value: Mutex<T>,
    busy: Mutex<bool>,
    freed: Condvar,
}

/// One caller's turn with the value, ended when dropped.
pub struct Guard<'a, T> {
    // Fields drop in order: the value's lock is released before the turn
    // ends, so the next caller finds it free.
    value: MutexGuard<'a, T>,
    _turn: Turn<'a>,
}

/// Ends a turn: clears the flag and wakes every waiter.
struct Turn<'a> {
    busy: &'a Mutex<bool>,
    freed: &'a Condvar,
}

/// One caller waiting for its turn, which Ruby's unblocking function can
/// wake ([`Unblock`]).
pub struct Waiter<'a, T> {
    lock: &'a Lock<T>,
    unblocked: AtomicBool,
}

fn recover<G>(result: Result<G, PoisonError<G>>) -> G {
    result.unwrap_or_else(PoisonError::into_inner)
}

impl<T> Lock<T> {
    pub const fn new(value: T) -> Self {
        Self {
            value: Mutex::new(value),
            busy: Mutex::new(false),
            freed: Condvar::new(),
        }
    }

    /// A turn, if no other caller has one.
    pub fn try_lock(&self) -> Option<Guard<'_, T>> {
        let mut busy = recover(self.busy.lock());
        if *busy {
            return None;
        }
        *busy = true;
        drop(busy);
        Some(self.turn())
    }

    /// A waiter for a turn, to pass to [`crate::gvl::without_gvl`].
    pub const fn waiter(&self) -> Waiter<'_, T> {
        Waiter {
            lock: self,
            unblocked: AtomicBool::new(false),
        }
    }

    /// The guard for a turn this caller has just marked busy.
    fn turn(&self) -> Guard<'_, T> {
        let turn = Turn {
            busy: &self.busy,
            freed: &self.freed,
        };
        Guard {
            value: recover(self.value.lock()),
            _turn: turn,
        }
    }
}

impl<T> std::ops::Deref for Guard<'_, T> {
    type Target = T;

    fn deref(&self) -> &T {
        &self.value
    }
}

impl<T> std::ops::DerefMut for Guard<'_, T> {
    fn deref_mut(&mut self) -> &mut T {
        &mut self.value
    }
}

impl Drop for Turn<'_> {
    fn drop(&mut self) {
        *recover(self.busy.lock()) = false;
        self.freed.notify_all();
    }
}

impl<T> Waiter<'_, T> {
    /// Waits for a turn. Returns `None`, without one, once the unblocking
    /// function has run since the last time this returned `None`: Ruby
    /// then handles the interrupt and, unless it raises, waits again. An
    /// interrupt wins over a free lock, so an interrupted call does not
    /// start its work, as the (a) case of `thread.c:1685-1699` at Ruby
    /// v4.0.9 describes: an interrupt before the work cancels it.
    pub fn lock(&self) -> Option<Guard<'_, T>> {
        let mut busy = recover(self.lock.busy.lock());
        loop {
            if self.unblocked.swap(false, Ordering::Relaxed) {
                return None;
            }
            if !*busy {
                *busy = true;
                drop(busy);
                return Some(self.lock.turn());
            }
            busy = recover(self.lock.freed.wait(busy));
        }
    }
}

impl<T: Send> Unblock for Waiter<'_, T> {
    /// Wakes the waiter. It sets the flag under the turn's mutex, so the
    /// waiter either sees it before it waits or is waiting and wakes.
    /// Every waiter wakes; the others find the flag unchanged and wait on.
    fn unblock(&self) {
        let _busy = recover(self.lock.busy.lock());
        self.unblocked.store(true, Ordering::Relaxed);
        self.lock.freed.notify_all();
    }
}

#[cfg(test)]
mod tests {
    use super::Lock;
    use crate::gvl::Unblock;
    use std::sync::mpsc;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn a_free_lock_gives_a_turn_and_a_busy_one_does_not() {
        let lock = Lock::new(5);
        let mut turn = lock.try_lock().expect("free");
        *turn += 1;
        assert!(lock.try_lock().is_none());
        drop(turn);
        assert_eq!(lock.try_lock().map(|turn| *turn), Some(6));
    }

    #[test]
    fn a_waiter_takes_its_turn_when_the_holder_ends_its_own() {
        let lock = Lock::new(Vec::new());
        let mut holding = lock.try_lock().expect("free");
        let (waiting, waits) = mpsc::channel();
        thread::scope(|scope| {
            let waiter = scope.spawn(|| {
                let waiter = lock.waiter();
                waiting.send(()).expect("the test listens");
                let mut turn = waiter.lock().expect("not unblocked");
                turn.push("waiter");
            });
            waits.recv().expect("the waiter starts");
            holding.push("holder");
            drop(holding);
            waiter.join().expect("no panic");
        });
        assert_eq!(*lock.try_lock().expect("free"), ["holder", "waiter"]);
    }

    #[test]
    fn unblocking_ends_a_wait_without_a_turn() {
        let lock = Lock::new(5);
        let holding = lock.try_lock().expect("free");
        let waiter = lock.waiter();
        let (waiting, waits) = mpsc::channel();
        let (ended, ends) = mpsc::channel();
        thread::scope(|scope| {
            scope.spawn(|| {
                waiting.send(()).expect("the test listens");
                ended
                    .send(waiter.lock().is_none())
                    .expect("the test listens");
            });
            waits.recv().expect("the waiter starts");
            waiter.unblock();
            // The timeout only turns a lost wake into a failure rather than
            // a hang: no run passes by it.
            let outcome = ends.recv_timeout(Duration::from_secs(30));
            let kept = lock.try_lock().is_none();
            // Frees a waiter whose wake was lost, so the scope can end.
            drop(holding);
            assert_eq!(outcome, Ok(true), "the unblock woke the waiter");
            assert!(kept, "the holder keeps its turn");
        });
        assert!(lock.try_lock().is_some());
    }

    #[test]
    fn an_unblock_wins_over_a_free_lock_once() {
        let lock = Lock::new(5);
        let waiter = lock.waiter();
        waiter.unblock();
        assert!(waiter.lock().is_none());
        assert_eq!(waiter.lock().map(|turn| *turn), Some(5));
    }

    #[test]
    fn a_poisoned_lock_is_recovered() {
        let lock = Lock::new(5);
        let _ = std::panic::catch_unwind(|| {
            let _turn = lock.try_lock().expect("free");
            panic!("poison it");
        });
        assert_eq!(lock.try_lock().map(|turn| *turn), Some(5));
        assert_eq!(lock.waiter().lock().map(|turn| *turn), Some(5));
    }
}
