// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! `HotKey`, `Code`, and `Modifiers` (global-hotkey 0.9.0
//! `src/hotkey.rs`, keyboard-types 0.8.3 `src/code.rs` and
//! `src/modifiers.rs`).
//!
//! The Ruby `HotKey` is a `Data` with the crate's three public fields, so
//! a hotkey crosses as its parts, `(mods bits, key name, id)`, and each
//! function here rebuilds the Rust literal from them (plan 004,
//! decision 9). A `Code` crosses as its name, keyboard-types' `Display`
//! text, and `Modifiers` as its bits.

use std::str::FromStr;

use global_hotkey::hotkey::{Code, HotKey, Modifiers, CMD_OR_CTRL};
use magnus::{Error, RArray, RString, Ruby};

use crate::error::{classify_parse, settle, Failure};
use crate::{capture, error};

/// A hotkey as Ruby holds it: its modifiers' bits, its key's name, and its
/// id.
pub type Parts = (u32, String, u32);

/// The parts of `hotkey`.
pub fn parts(hotkey: &HotKey) -> Parts {
    (hotkey.mods.bits(), hotkey.key.to_string(), hotkey.id)
}

/// The `Code` named `name`, by keyboard-types' `FromStr`, or its
/// `UnrecognizedCodeError` (keyboard-types `src/code.rs:716-954`), which
/// global-hotkey does not re-export.
fn code(name: &str) -> Result<Code, Failure> {
    Code::from_str(name)
        .map_err(|error| Failure::new("Hotkey::UnrecognizedCodeError", error.to_string()))
}

/// The Rust literal `HotKey { mods, key, id }` for `parts`.
pub fn hotkey(parts: Parts) -> Result<HotKey, Failure> {
    let (bits, key, id) = parts;
    Ok(HotKey {
        mods: Modifiers::from_bits_retain(bits),
        key: code(&key)?,
        id,
    })
}

/// Runs `operation` under `catch_unwind`, turning a panic into the base
/// `Error`.
fn guarded<T>(operation: impl FnOnce() -> Result<T, Failure>) -> Result<T, Failure> {
    capture(operation).unwrap_or_else(|panic| Err(error::panicked(&panic)))
}

/// `HotKey::new(mods, key)` (`src/hotkey.rs:87-101`): its parts.
pub fn hotkey_new(ruby: &Ruby, bits: Option<u32>, key: String) -> RArray {
    settle(
        ruby,
        guarded(move || {
            Ok(parts(&HotKey::new(
                bits.map(Modifiers::from_bits_retain),
                code(&key)?,
            )))
        }),
    )
}

/// `HotKey::from_str` (`src/hotkey.rs:147-152`), which both `TryFrom`
/// impls share: the parts, or the `HotKeyParseError` it returned.
pub fn hotkey_parse(ruby: &Ruby, text: String) -> RArray {
    settle(
        ruby,
        guarded(move || {
            HotKey::from_str(&text)
                .map(|hotkey| parts(&hotkey))
                .map_err(|error| classify_parse(&error))
        }),
    )
}

/// `HotKey::matches(modifiers, key)` (`src/hotkey.rs:109-116`).
pub fn hotkey_matches(ruby: &Ruby, parts: Parts, bits: u32, key: String) -> RArray {
    settle(
        ruby,
        guarded(move || {
            let hotkey = hotkey(parts)?;
            Ok(hotkey.matches(Modifiers::from_bits_retain(bits), code(&key)?))
        }),
    )
}

/// `HotKey::into_string` (`src/hotkey.rs:118-135`), which `Display`
/// writes.
pub fn hotkey_into_string(ruby: &Ruby, parts: Parts) -> RArray {
    settle(ruby, guarded(move || Ok(hotkey(parts)?.into_string())))
}

/// `CMD_OR_CTRL`'s bits: `META` on macOS, `CONTROL` elsewhere
/// (`src/hotkey.rs:33-36`).
pub const fn cmd_or_ctrl() -> u32 {
    CMD_OR_CTRL.bits()
}

/// The discriminant of the `Code` named `name`, by keyboard-types'
/// `FromStr`, which is its place in keyboard-types' `Ord`.
pub fn code_from_str(ruby: &Ruby, name: String) -> RArray {
    settle(ruby, guarded(move || Ok(code(&name)? as u32)))
}

/// How many `Code` variants keyboard-types 0.8.3 has: one past the last
/// one's discriminant (`src/code.rs:488`), since a fieldless enum numbers
/// its variants from zero in order.
pub const fn code_count() -> u32 {
    Code::ZoomToggle as u32 + 1
}

/// Every named flag of `Modifiers`, in declaration order, with its bits:
/// bitflags' own table (keyboard-types `src/modifiers.rs:15-32`).
pub fn modifier_flags() -> Vec<(String, u32)> {
    Modifiers::all()
        .iter_names()
        .map(|(name, flag)| (name.to_owned(), flag.bits()))
        .collect()
}

/// `value` as a `u32`, converted by magnus, which raises `RangeError` or
/// `TypeError` for anything else: the bits a `Modifiers` holds, and a
/// `HotKey`'s id.
pub const fn u32(value: u32) -> u32 {
    value
}

/// bitflags' `Debug` text for `bits`: `Modifiers(SHIFT | CONTROL)`,
/// `Modifiers(0x0)`, or with unknown bits in hex.
pub fn modifiers_debug(bits: u32) -> String {
    format!("{:?}", Modifiers::from_bits_retain(bits))
}

/// bitflags' `from_name`: the bits of the flag named exactly `name`.
pub fn modifiers_from_name(name: RString) -> Result<Option<u32>, Error> {
    Ok(Modifiers::from_name(&name.to_string()?).map(|flag| flag.bits()))
}

#[cfg(test)]
mod tests {
    use super::{code, code_count, hotkey, modifier_flags, modifiers_debug, parts};
    use global_hotkey::hotkey::{Code, HotKey, Modifiers};

    #[test]
    fn parts_round_trip_to_the_same_literal() {
        let original = HotKey::new(Some(Modifiers::SHIFT | Modifiers::ALT), Code::F19);
        assert_eq!(hotkey(parts(&original)), Ok(original));
    }

    #[test]
    fn a_literal_keeps_whatever_id_it_was_given() {
        let made = hotkey((0, "KeyA".to_owned(), 7)).expect("KeyA is a code");
        assert_eq!(made.id(), 7);
    }

    #[test]
    fn an_unknown_key_name_is_keyboard_types_error() {
        let failure = code("Nope").expect_err("no such code");
        assert_eq!(failure.path, "Hotkey::UnrecognizedCodeError");
        assert_eq!(failure.message, "Unrecognized code");
    }

    #[test]
    fn codes_number_from_zero_to_the_last_variant() {
        assert_eq!(Code::Backquote as u32, 0);
        assert_eq!(code_count(), 216);
    }

    #[test]
    fn the_flag_table_lists_all_fourteen_flags() {
        let flags = modifier_flags();
        assert_eq!(flags.len(), 14);
        assert_eq!(flags.first(), Some(&("ALT".to_owned(), 0x1)));
        assert_eq!(flags.last(), Some(&("SUPER".to_owned(), 0x2000)));
    }

    #[test]
    fn debug_text_is_bitflags() {
        assert_eq!(modifiers_debug(0), "Modifiers(0x0)");
        assert_eq!(modifiers_debug(0x208), "Modifiers(CONTROL | SHIFT)");
        assert_eq!(modifiers_debug(0x1_0001), "Modifiers(ALT | 0x10000)");
    }
}
