// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! A value that a consuming call uses up, and the name of the call that
//! did (ADR 001, 2026-11-05: a consumed value raises on further use).
//!
//! notify-rust's handle waits take `self` on every platform (notify-rust
//! 4.18.2 `src/xdg/mod.rs:101`, `:134`, `:214`, `:269`;
//! `src/macos/nsusernotifications.rs:32`, `:73`, `:113`;
//! `src/windows.rs:111`, `:123`, `:136`), and Rust drops a handle at the
//! end of its scope. Ruby keeps the object, so the native handle keeps a
//! `Slot`: `Live` until a consuming call takes it, then `Spent` with that
//! call's name, which the `IOError` a later call raises names.

/// A value, or the name of the call that used it up.
#[derive(Debug, PartialEq, Eq)]
pub enum Slot<T> {
    Live(T),
    Spent(&'static str),
}

impl<T> Slot<T> {
    /// Takes the value out for the consuming call `by`, or answers the
    /// name of the call that already did.
    pub fn take(&mut self, by: &'static str) -> Result<T, &'static str> {
        match std::mem::replace(self, Self::Spent(by)) {
            Self::Live(value) => Ok(value),
            Self::Spent(earlier) => {
                *self = Self::Spent(earlier);
                Err(earlier)
            }
        }
    }

    /// Takes the value out for `by` if a consuming call has not, as a drop
    /// at the end of a scope does nothing to a value moved away before.
    pub fn release(&mut self, by: &'static str) -> Option<T> {
        self.take(by).ok()
    }

    /// The value, or the name of the call that used it up.
    pub const fn get_mut(&mut self) -> Result<&mut T, &'static str> {
        match self {
            Self::Live(value) => Ok(value),
            Self::Spent(by) => Err(by),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Slot;

    #[test]
    fn a_live_value_is_taken_once_and_names_who_took_it() {
        let mut slot = Slot::Live(7);
        assert_eq!(slot.get_mut(), Ok(&mut 7));
        assert_eq!(slot.take("first"), Ok(7));
        assert_eq!(slot, Slot::Spent("first"));
        assert_eq!(slot.take("second"), Err("first"));
        assert_eq!(slot.get_mut(), Err("first"));
        assert_eq!(slot, Slot::Spent("first"));
    }

    #[test]
    fn a_release_takes_only_a_live_value_and_keeps_the_first_name() {
        let mut slot = Slot::Live("handle");
        assert_eq!(slot.release("end of block"), Some("handle"));
        assert_eq!(slot.release("again"), None);
        assert_eq!(slot.take("wait"), Err("end of block"));
    }
}
