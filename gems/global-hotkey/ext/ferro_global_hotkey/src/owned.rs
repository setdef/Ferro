// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! Values whose destructor must run on the thread that made them (plan
//! 004, decision 3).
//!
//! Ruby's garbage collector frees an unreachable object on whichever thread
//! sweeps it (Ruby v4.0.9 `gc.c`, `gc/default/default.c`), and magnus's
//! `free_immediately` drops the wrapped value right there. global-hotkey's
//! macOS and Windows managers clean up through thread-affine system calls:
//! Carbon's `RemoveEventHandler` and `UnregisterEventHotKey`, which the
//! crate expects on the main thread (`src/lib.rs:15-18`), and Win32's
//! `DestroyWindow`, which "cannot ... destroy a window created by a
//! different thread" (Microsoft's `DestroyWindow` documentation). Dropped
//! elsewhere, the Windows window and every hotkey on it would stay
//! registered for as long as its thread lives.
//!
//! [`Owned`] records the thread that made its value. Dropped on that
//! thread, it drops the value; dropped on any other, it moves the value to
//! a graveyard instead, and the next native call on the owner thread
//! ([`exhume`]) drops it there. Until then the value's hotkeys stay
//! registered, as they would in Rust until the value went out of scope.
//! A value whose owner thread has ended is never dropped: its platform
//! objects ended with the thread, and a `ThreadId` is never reused
//! (std `thread::ThreadId`), so nothing calls into them. This follows
//! Tokra's `ThreadBound` (Tokra `ext/tokra/src/thread_bound.rs`), with a
//! deferred drop where that one forgets.

use std::panic::{self, AssertUnwindSafe};
use std::sync::{Mutex, PoisonError};
use std::thread::{self, ThreadId};

/// Values dropped off their owner thread, waiting for it.
static GRAVEYARD: Mutex<Vec<(ThreadId, Box<dyn Send>)>> = Mutex::new(Vec::new());

/// A value dropped on its owner thread, or deferred to it.
pub struct Owned<T: Send + 'static> {
    owner: ThreadId,
    bound: bool,
    value: Option<T>,
}

impl<T: Send + 'static> Owned<T> {
    /// Binds `value` to the calling thread when `bound`; an unbound value
    /// drops wherever it is dropped.
    pub fn new(value: T, bound: bool) -> Self {
        Self {
            owner: thread::current().id(),
            bound,
            value: Some(value),
        }
    }

    /// The value, on any thread. Calls through it reach the platform from
    /// the calling thread, which global-hotkey's own error paths cover
    /// (plan 004, decision 3).
    pub const fn get(&self) -> Option<&T> {
        self.value.as_ref()
    }
}

impl<T: Send + 'static> Drop for Owned<T> {
    fn drop(&mut self) {
        let Some(value) = self.value.take() else {
            return;
        };
        if self.bound && thread::current().id() != self.owner {
            GRAVEYARD
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .push((self.owner, Box::new(value)));
        } else {
            let _ = panic::catch_unwind(AssertUnwindSafe(|| drop(value)));
        }
    }
}

/// Drops every value the calling thread owns that was dropped elsewhere,
/// each under `catch_unwind`.
pub fn exhume() {
    let current = thread::current().id();
    let mut graveyard = GRAVEYARD.lock().unwrap_or_else(PoisonError::into_inner);
    let (due, rest): (Vec<_>, Vec<_>) = graveyard
        .drain(..)
        .partition(|(owner, _)| *owner == current);
    *graveyard = rest;
    drop(graveyard);
    for (_, value) in due {
        let _ = panic::catch_unwind(AssertUnwindSafe(|| drop(value)));
    }
}

#[cfg(test)]
mod tests {
    use super::{exhume, Owned};
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    /// Counts its drops.
    struct Probe(Arc<AtomicUsize>);

    impl Drop for Probe {
        fn drop(&mut self) {
            self.0.fetch_add(1, Ordering::SeqCst);
        }
    }

    fn probe() -> (Probe, Arc<AtomicUsize>) {
        let drops = Arc::new(AtomicUsize::new(0));
        (Probe(Arc::clone(&drops)), drops)
    }

    #[test]
    fn on_its_owner_thread_a_value_drops_at_once() {
        let (value, drops) = probe();
        drop(Owned::new(value, true));
        assert_eq!(drops.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn off_its_owner_thread_a_value_waits_for_the_owner() {
        let (value, drops) = probe();
        let owned = Owned::new(value, true);
        std::thread::spawn(move || {
            drop(owned);
            exhume();
        })
        .join()
        .expect("the other thread ran");
        assert_eq!(drops.load(Ordering::SeqCst), 0, "dropped off its owner");
        exhume();
        assert_eq!(drops.load(Ordering::SeqCst), 1, "the owner dropped it");
        exhume();
        assert_eq!(drops.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn an_unbound_value_drops_on_any_thread() {
        let (value, drops) = probe();
        let owned = Owned::new(value, false);
        std::thread::spawn(move || drop(owned))
            .join()
            .expect("the other thread ran");
        assert_eq!(drops.load(Ordering::SeqCst), 1);
    }
}
