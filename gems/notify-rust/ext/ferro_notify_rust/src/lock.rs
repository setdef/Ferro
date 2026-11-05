// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The Linux handle's lock: a reader-writer lock whose waits Ruby can cut
//! short (plan 003, decision 5).
//!
//! notify-rust's `NotificationHandle` waits and closes through `&self` and
//! changes through `&mut self` (`src/xdg/mod.rs:67-354` at 4.18.2), and
//! any Ruby thread may call either, so the handle takes, at run time, the
//! turns Rust's borrow checker hands out at compile time: any number of
//! shared turns, or one exclusive turn. A shared turn can last as long as
//! the user takes to answer the notification, so a thread waiting its turn
//! waits with Ruby's global VM lock released, and Ruby asks for it back
//! when the thread is interrupted (`Thread#raise`, `Thread#kill`, a
//! signal, process exit). std's `RwLock` cannot be cut short, and it
//! queues new readers behind a waiting writer, which would keep a `close`
//! from ending the wait a setter waits behind (plan 003, decision 5). So
//! the turns are counted under a mutex with a condition variable, as
//! ferro-arboard's `lock.rs` counts its one turn, and a [`Waiter`] is woken
//! either when a turn ends or when Ruby's unblocking function asks.
//! Readers go first: a shared turn is granted whenever no exclusive one is
//! out, even with a writer waiting. Waiters wake together and are not
//! served in FIFO order, as with std's `Mutex`.
//!
//! Each shared turn records the Ruby thread that holds it ([`Owner`]), so
//! a thread asking for an exclusive turn while it holds a shared one, which
//! would wait for itself forever, is told so instead ([`Lock::holds`]). A
//! shared turn outlives Ruby code only on its own thread, in a signal trap
//! that runs during the wait. An exclusive turn never does: it is taken and
//! given back either with the GVL held and no Ruby code between, or within
//! one run without the GVL, so no thread ever needs to ask whether it holds
//! one.
//!
//! This module is ferro-arboard's `lock.rs` (plan 001, Follow-up: the GVL
//! is never held), grown from one turn to a reader-writer lock. Its
//! author, Kerrick Long, licenses this copy as MIT OR Apache-2.0 with the
//! rest of ferro-notify-rust.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex, MutexGuard, PoisonError};

use crate::gvl::Unblock;

/// The Ruby thread holding a turn: its `object_id`, which Ruby never gives
/// another object, unlike its address, which compaction can change.
pub type Owner = u64;

/// A value any number of callers may read at once, or one may change.
pub struct Lock<T> {
    state: Mutex<State<T>>,
    freed: Condvar,
}

/// The turns out, under the lock's mutex.
///
/// `value` is `None` while an exclusive turn has it. Each shared turn
/// holds a clone of the `Arc` and drops it before its turn ends, so once
/// `readers` is empty the slot's `Arc` is the only one. The mutex is held
/// only for a moment, never across a wait, and nothing panics under it; a
/// poisoned one is still used.
struct State<T> {
    value: Option<Arc<T>>,
    readers: Vec<Owner>,
}

/// One shared turn with the value, ended when dropped.
pub struct ReadGuard<'a, T> {
    value: Option<Arc<T>>,
    lock: &'a Lock<T>,
    owner: Owner,
}

/// The exclusive turn with the value, ended when dropped.
pub struct WriteGuard<'a, T> {
    value: Option<T>,
    lock: &'a Lock<T>,
}

/// One caller waiting for a turn, which Ruby's unblocking function can
/// wake ([`Unblock`]).
pub struct Waiter<'a, T> {
    lock: &'a Lock<T>,
    owner: Owner,
    unblocked: AtomicBool,
}

fn recover<G>(result: Result<G, PoisonError<G>>) -> G {
    result.unwrap_or_else(PoisonError::into_inner)
}

impl<T> Lock<T> {
    pub fn new(value: T) -> Self {
        Self {
            state: Mutex::new(State {
                value: Some(Arc::new(value)),
                readers: Vec::new(),
            }),
            freed: Condvar::new(),
        }
    }

    fn state(&self) -> MutexGuard<'_, State<T>> {
        recover(self.state.lock())
    }

    /// A shared turn for `owner`, if no exclusive turn is out.
    pub fn try_read(&self, owner: Owner) -> Option<ReadGuard<'_, T>> {
        self.read_from(&mut self.state(), owner)
    }

    /// The exclusive turn, if no other turn is out.
    pub fn try_write(&self) -> Option<WriteGuard<'_, T>> {
        self.write_from(&mut self.state())
    }

    /// Whether `owner` holds a shared turn, so that waiting for the
    /// exclusive one would wait for itself.
    pub fn holds(&self, owner: Owner) -> bool {
        self.state().readers.contains(&owner)
    }

    /// A waiter for a turn for `owner`, to pass to
    /// [`crate::gvl::wait_until`].
    pub const fn waiter(&self, owner: Owner) -> Waiter<'_, T> {
        Waiter {
            lock: self,
            owner,
            unblocked: AtomicBool::new(false),
        }
    }

    fn read_from(&self, state: &mut State<T>, owner: Owner) -> Option<ReadGuard<'_, T>> {
        let value = Arc::clone(state.value.as_ref()?);
        state.readers.push(owner);
        Some(ReadGuard {
            value: Some(value),
            lock: self,
            owner,
        })
    }

    fn write_from(&self, state: &mut State<T>) -> Option<WriteGuard<'_, T>> {
        if !state.readers.is_empty() {
            return None;
        }
        // Every shared turn dropped its clone before it ended (`State`), so
        // the unwrap finds this one alone; were it ever not, the writer
        // would wait as for a shared turn.
        match Arc::try_unwrap(state.value.take()?) {
            Ok(value) => Some(WriteGuard {
                value: Some(value),
                lock: self,
            }),
            Err(shared) => {
                state.value = Some(shared);
                None
            }
        }
    }
}

impl<T> std::ops::Deref for ReadGuard<'_, T> {
    type Target = T;

    fn deref(&self) -> &T {
        // The value is taken out only in `drop`.
        self.value.as_deref().unwrap_or_else(|| unreachable!())
    }
}

impl<T> Drop for ReadGuard<'_, T> {
    /// Drops the clone, then ends the turn and wakes every waiter.
    fn drop(&mut self) {
        drop(self.value.take());
        let mut state = self.lock.state();
        if let Some(index) = state.readers.iter().position(|&owner| owner == self.owner) {
            state.readers.swap_remove(index);
        }
        drop(state);
        self.lock.freed.notify_all();
    }
}

impl<T> std::ops::Deref for WriteGuard<'_, T> {
    type Target = T;

    fn deref(&self) -> &T {
        // The value is taken out only in `drop`.
        self.value.as_ref().unwrap_or_else(|| unreachable!())
    }
}

impl<T> std::ops::DerefMut for WriteGuard<'_, T> {
    fn deref_mut(&mut self) -> &mut T {
        self.value.as_mut().unwrap_or_else(|| unreachable!())
    }
}

impl<T> Drop for WriteGuard<'_, T> {
    /// Puts the value back, then wakes every waiter.
    fn drop(&mut self) {
        if let Some(value) = self.value.take() {
            self.lock.state().value = Some(Arc::new(value));
        }
        self.lock.freed.notify_all();
    }
}

impl<'a, T> Waiter<'a, T> {
    /// Waits for a shared turn. Returns `None`, without one, once the
    /// unblocking function has run since the last time this returned
    /// `None`: Ruby then handles the interrupt and, unless it raises,
    /// waits again. An interrupt wins over a free turn, so an interrupted
    /// call does not start its work, as the (a) case of the passage at
    /// `thread.c:1694-1699` (Ruby v4.0.9) describes.
    pub fn read(&self) -> Option<ReadGuard<'a, T>> {
        self.wait(|lock, state| lock.read_from(state, self.owner))
    }

    /// Waits for the exclusive turn, as [`Waiter::read`] waits for a
    /// shared one.
    pub fn write(&self) -> Option<WriteGuard<'a, T>> {
        self.wait(Lock::write_from)
    }

    fn wait<G>(&self, mut take: impl FnMut(&'a Lock<T>, &mut State<T>) -> Option<G>) -> Option<G> {
        let mut state = self.lock.state();
        loop {
            if self.unblocked.swap(false, Ordering::Relaxed) {
                return None;
            }
            if let Some(turn) = take(self.lock, &mut state) {
                return Some(turn);
            }
            state = recover(self.lock.freed.wait(state));
        }
    }
}

impl<T: Send + Sync> Unblock for Waiter<'_, T> {
    /// Wakes the waiter. It sets the flag under the lock's mutex, so the
    /// waiter either sees it before it waits or is waiting and wakes.
    /// Every waiter wakes; the others find the turns unchanged and wait on.
    fn unblock(&self) {
        let _state = self.lock.state();
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

    // The timeouts below only turn a lost wake into a failure rather than
    // a hang: no run passes by them.
    const LOST: Duration = Duration::from_secs(30);

    #[test]
    fn shared_turns_go_together_and_shut_out_the_exclusive_one() {
        let lock = Lock::new(5);
        let first = lock.try_read(1).expect("free");
        let second = lock.try_read(2).expect("readers share");
        assert_eq!(*first + *second, 10);
        assert!(lock.try_write().is_none());
        drop(first);
        assert!(lock.try_write().is_none());
        drop(second);
        let mut write = lock.try_write().expect("free again");
        *write += 1;
        assert!(lock.try_read(1).is_none());
        assert!(lock.try_write().is_none());
        drop(write);
        assert_eq!(lock.try_read(1).map(|read| *read), Some(6));
    }

    #[test]
    fn a_thread_holding_a_shared_turn_is_known_by_its_owner() {
        let lock = Lock::new(5);
        let first = lock.try_read(1).expect("free");
        let again = lock.try_read(1).expect("readers share");
        let other = lock.try_read(2).expect("readers share");
        assert!(lock.holds(1));
        assert!(lock.holds(2));
        assert!(!lock.holds(3));
        drop(first);
        assert!(lock.holds(1), "one of its two turns is still out");
        drop(again);
        assert!(!lock.holds(1));
        drop(other);
        assert!(!lock.holds(2));
    }

    #[test]
    fn a_writer_waits_for_every_reader_and_then_changes_the_value() {
        let lock = Lock::new(Vec::new());
        let reading = lock.try_read(1).expect("free");
        let (waiting, waits) = mpsc::channel();
        thread::scope(|scope| {
            let writer = scope.spawn(|| {
                let waiter = lock.waiter(2);
                waiting.send(()).expect("the test listens");
                let mut turn = waiter.write().expect("not unblocked");
                turn.push("writer");
            });
            waits.recv().expect("the writer starts");
            assert_eq!(reading.len(), 0, "the reader keeps its turn");
            drop(reading);
            writer.join().expect("no panic");
        });
        assert_eq!(*lock.try_read(1).expect("free"), ["writer"]);
    }

    #[test]
    fn a_reader_waits_for_the_writer() {
        let lock = Lock::new(5);
        let mut exclusive = lock.try_write().expect("free");
        let (waiting, waits) = mpsc::channel();
        thread::scope(|scope| {
            let reader = scope.spawn(|| {
                let waiter = lock.waiter(1);
                waiting.send(()).expect("the test listens");
                waiter.read().map(|turn| *turn)
            });
            waits.recv().expect("the reader starts");
            *exclusive = 6;
            drop(exclusive);
            assert_eq!(reader.join().expect("no panic"), Some(6));
        });
    }

    /// std's `RwLock` would queue the second reader behind the writer, so
    /// a `close` could not end the wait a setter waits behind.
    #[test]
    fn a_waiting_writer_does_not_keep_out_another_reader() {
        let lock = Lock::new(5);
        let reading = lock.try_read(1).expect("free");
        let waiter = lock.waiter(2);
        let (waiting, waits) = mpsc::channel();
        let (ended, ends) = mpsc::channel();
        thread::scope(|scope| {
            scope.spawn(|| {
                waiting.send(()).expect("the test listens");
                ended
                    .send(waiter.write().map(|turn| *turn))
                    .expect("the test listens");
            });
            waits.recv().expect("the writer starts");
            assert_eq!(lock.try_read(3).map(|turn| *turn), Some(5));
            drop(reading);
            assert_eq!(ends.recv_timeout(LOST), Ok(Some(5)));
        });
    }

    #[test]
    fn unblocking_ends_a_wait_without_a_turn() {
        let lock = Lock::new(5);
        let reading = lock.try_read(1).expect("free");
        let waiter = lock.waiter(2);
        let (waiting, waits) = mpsc::channel();
        let (ended, ends) = mpsc::channel();
        thread::scope(|scope| {
            scope.spawn(|| {
                waiting.send(()).expect("the test listens");
                ended
                    .send(waiter.write().is_none())
                    .expect("the test listens");
            });
            waits.recv().expect("the waiter starts");
            waiter.unblock();
            let outcome = ends.recv_timeout(LOST);
            let kept = lock.holds(1);
            // Frees a waiter whose wake was lost, so the scope can end.
            drop(reading);
            assert_eq!(outcome, Ok(true), "the unblock woke the waiter");
            assert!(kept, "the reader keeps its turn");
        });
        assert!(lock.try_write().is_some());
    }

    #[test]
    fn an_unblock_wins_over_a_free_turn_once() {
        let lock = Lock::new(5);
        let waiter = lock.waiter(1);
        waiter.unblock();
        assert!(waiter.read().is_none());
        assert_eq!(waiter.read().map(|turn| *turn), Some(5));
        waiter.unblock();
        assert!(waiter.write().is_none());
        assert_eq!(waiter.write().map(|turn| *turn), Some(5));
    }

    #[test]
    fn a_poisoned_lock_is_recovered() {
        let lock = Lock::new(5);
        let _ = std::panic::catch_unwind(|| {
            let _state = lock.state();
            panic!("poison it");
        });
        assert_eq!(lock.try_read(1).map(|turn| *turn), Some(5));
        assert_eq!(lock.try_write().map(|turn| *turn), Some(5));
        assert_eq!(lock.waiter(1).read().map(|turn| *turn), Some(5));
    }
}
