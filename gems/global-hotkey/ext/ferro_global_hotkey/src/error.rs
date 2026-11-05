// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! The failures the native layer hands Ruby (plan 004, decision 7), and
//! the `Debug` text of each error type, rebuilt from its field.
//!
//! A function that can fail returns `[:ok, value]` or
//! `[:error, path, message, field]`, and the Ruby side raises the class at
//! `path` under `Ferro::GlobalHotkey`. Building the exception in Ruby keeps
//! its constructor, its field, and its docs in one place. The message is
//! always the source crate's own `Display` text, and the field is the
//! value a tuple variant carries, tagged by its kind.

use std::io;
use std::str::FromStr;

use crossbeam_channel::{RecvError, RecvTimeoutError, TryRecvError};
use global_hotkey::hotkey::{Code, HotKeyParseError};
use magnus::{Error, IntoValue, RArray, RString, Ruby, TryConvert, Value};

use crate::hotkey::{hotkey, parts, Parts};
use crate::Panic;

/// What an `io::Error` carries into Ruby: its OS error code, if it has
/// one, and its text.
pub type OsError = (Option<i32>, String);

/// The value a tuple variant carries (`Error::FailedToRegister(String)`),
/// as it crosses into Ruby.
#[derive(Debug, PartialEq, Eq)]
pub enum Field {
    /// A unit variant, or no variant of the crate's.
    None,
    /// A `String`.
    Text(String),
    /// A `HotKey`, by its parts.
    HotKey(Parts),
    /// An `io::Error`.
    Os(OsError),
}

/// Where a failure goes in Ruby: the class path under
/// `Ferro::GlobalHotkey`, the message, and the field its variant carries.
#[derive(Debug, PartialEq, Eq)]
pub struct Failure {
    pub path: String,
    pub message: String,
    pub field: Field,
}

impl Failure {
    pub fn new(path: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            message: message.into(),
            field: Field::None,
        }
    }
}

/// The base `Error` for a panic inside global-hotkey.
pub fn panicked(panic: &Panic) -> Failure {
    Failure::new("Error", format!("global-hotkey panicked: {}", panic.0))
}

/// Where one of global-hotkey's errors goes (`src/error.rs:9-31`), with
/// the field its variant carries. A variant a later global-hotkey adds
/// goes to the base class, since the enum is `#[non_exhaustive]`.
pub fn classify(error: &global_hotkey::Error) -> Failure {
    use global_hotkey::Error as E;
    let text = |text: &String| Field::Text(text.clone());
    let (variant, field) = match error {
        E::OsError(io) => ("OsError", Field::Os((io.raw_os_error(), io.to_string()))),
        E::HotKeyParseError(found) => ("HotKeyParseError", text(found)),
        E::UnrecognizedHotKeyCode(found) => ("UnrecognizedHotKeyCode", text(found)),
        E::EmptyHotKeyToken(found) => ("EmptyHotKeyToken", text(found)),
        E::UnexpectedHotKeyFormat(found) => ("UnexpectedHotKeyFormat", text(found)),
        E::FailedToRegister(found) => ("FailedToRegister", text(found)),
        E::FailedToUnRegister(hotkey) => ("FailedToUnRegister", Field::HotKey(parts(hotkey))),
        E::AlreadyRegistered(hotkey) => ("AlreadyRegistered", Field::HotKey(parts(hotkey))),
        E::FailedToWatchMediaKeyEvent => ("FailedToWatchMediaKeyEvent", Field::None),
        _ => ("", Field::None),
    };
    Failure {
        path: if variant.is_empty() {
            "Error".to_owned()
        } else {
            format!("Error::{variant}")
        },
        message: error.to_string(),
        field,
    }
}

/// Where one of `hotkey::HotKeyParseError`'s variants goes
/// (`src/hotkey.rs:38-46`), with the `String` each carries.
pub fn classify_parse(error: &HotKeyParseError) -> Failure {
    let (variant, text) = match error {
        HotKeyParseError::UnsupportedKey(text) => ("UnsupportedKey", text),
        HotKeyParseError::EmptyToken(text) => ("EmptyToken", text),
        HotKeyParseError::InvalidFormat(text) => ("InvalidFormat", text),
    };
    Failure {
        path: format!("Hotkey::HotKeyParseError::{variant}"),
        message: error.to_string(),
        field: Field::Text(text.clone()),
    }
}

/// `[:ok, value]`.
pub fn ok(ruby: &Ruby, value: impl IntoValue) -> RArray {
    let tag: Value = ruby.to_symbol("ok").into_value_with(ruby);
    ruby.ary_new_from_values(&[tag, value.into_value_with(ruby)])
}

/// The field as Ruby reads it: `nil`, `[:text, string]`,
/// `[:hotkey, parts]`, or `[:os, code, text]`.
fn field_value(ruby: &Ruby, field: Field) -> Value {
    let tag = |name: &str| ruby.to_symbol(name).into_value_with(ruby);
    let tagged = |values: &[Value]| ruby.ary_new_from_values(values).into_value_with(ruby);
    match field {
        Field::None => ruby.qnil().into_value_with(ruby),
        Field::Text(text) => tagged(&[tag("text"), text.into_value_with(ruby)]),
        Field::HotKey(parts) => tagged(&[tag("hotkey"), parts.into_value_with(ruby)]),
        Field::Os((code, text)) => tagged(&[
            tag("os"),
            code.into_value_with(ruby),
            text.into_value_with(ruby),
        ]),
    }
}

/// `[:error, path, message, field]`, `field` being what `field_value`
/// makes of the value the variant carries.
pub fn error(ruby: &Ruby, failure: Failure) -> RArray {
    let values: [Value; 4] = [
        ruby.to_symbol("error").into_value_with(ruby),
        failure.path.into_value_with(ruby),
        failure.message.into_value_with(ruby),
        field_value(ruby, failure.field),
    ];
    ruby.ary_new_from_values(&values)
}

/// `[:ok, value]` or `[:error, ...]` for `result`.
pub fn settle<T: IntoValue>(ruby: &Ruby, result: Result<T, Failure>) -> RArray {
    match result {
        Ok(value) => ok(ruby, value),
        Err(failure) => error(ruby, failure),
    }
}

/// The `io::Error` an `OsError` carries, rebuilt from its code, or, for
/// one without a code, from its text.
fn io_error((code, text): OsError) -> io::Error {
    code.map_or_else(|| io::Error::other(text), io::Error::from_raw_os_error)
}

/// The `Debug` text of the error class at `path` under
/// `Ferro::GlobalHotkey`, rebuilt from `value`, the field its variant
/// carries (`nil` for a unit variant): global-hotkey's derived `Debug`
/// (`src/error.rs:11`, `src/hotkey.rs:38`), keyboard-types'
/// (`src/code.rs:947`), and crossbeam's (`src/err.rs:53-74`). magnus
/// raises `TypeError` for a field of the wrong type, `nil` included, and
/// so does a path that names no error type with a `Debug`.
pub fn error_debug(ruby: &Ruby, path: RString, value: Option<Value>) -> Result<String, Error> {
    use global_hotkey::Error as E;
    use HotKeyParseError as P;
    let value = value.unwrap_or_else(|| ruby.qnil().into_value_with(ruby));
    let text = || String::try_convert(value);
    let rebuilt = || {
        hotkey(Parts::try_convert(value)?)
            .map_err(|failure| Error::new(ruby.exception_type_error(), failure.message))
    };
    let debug = match path.to_string()?.as_str() {
        "Error::OsError" => format!("{:?}", E::OsError(io_error(OsError::try_convert(value)?))),
        "Error::HotKeyParseError" => format!("{:?}", E::HotKeyParseError(text()?)),
        "Error::UnrecognizedHotKeyCode" => format!("{:?}", E::UnrecognizedHotKeyCode(text()?)),
        "Error::EmptyHotKeyToken" => format!("{:?}", E::EmptyHotKeyToken(text()?)),
        "Error::UnexpectedHotKeyFormat" => format!("{:?}", E::UnexpectedHotKeyFormat(text()?)),
        "Error::FailedToRegister" => format!("{:?}", E::FailedToRegister(text()?)),
        "Error::FailedToUnRegister" => format!("{:?}", E::FailedToUnRegister(rebuilt()?)),
        "Error::AlreadyRegistered" => format!("{:?}", E::AlreadyRegistered(rebuilt()?)),
        "Error::FailedToWatchMediaKeyEvent" => format!("{:?}", E::FailedToWatchMediaKeyEvent),
        "Hotkey::HotKeyParseError::UnsupportedKey" => format!("{:?}", P::UnsupportedKey(text()?)),
        "Hotkey::HotKeyParseError::EmptyToken" => format!("{:?}", P::EmptyToken(text()?)),
        "Hotkey::HotKeyParseError::InvalidFormat" => format!("{:?}", P::InvalidFormat(text()?)),
        other => unit_debug(other).ok_or_else(|| {
            Error::new(
                ruby.exception_type_error(),
                format!("{other} is no error type with a Debug"),
            )
        })?,
    };
    Ok(debug)
}

/// The `Debug` text of a fieldless error type at `path`: keyboard-types'
/// `UnrecognizedCodeError`, which global-hotkey does not re-export, so it
/// comes from a failed `Code::from_str`, and crossbeam's receive errors.
fn unit_debug(path: &str) -> Option<String> {
    Some(match path {
        "Hotkey::UnrecognizedCodeError" => format!("{:?}", Code::from_str("").err()?),
        "GlobalHotKeyEventReceiver::RecvError" => format!("{RecvError:?}"),
        "GlobalHotKeyEventReceiver::TryRecvError::Empty" => format!("{:?}", TryRecvError::Empty),
        "GlobalHotKeyEventReceiver::TryRecvError::Disconnected" => {
            format!("{:?}", TryRecvError::Disconnected)
        }
        "GlobalHotKeyEventReceiver::RecvTimeoutError::Timeout" => {
            format!("{:?}", RecvTimeoutError::Timeout)
        }
        "GlobalHotKeyEventReceiver::RecvTimeoutError::Disconnected" => {
            format!("{:?}", RecvTimeoutError::Disconnected)
        }
        _ => return None,
    })
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
// SPDX-License-Identifier: Apache-2.0 OR MIT
// SPDX-SnippetComment: the Display and Debug texts of global-hotkey 0.9.0's
//   errors (src/error.rs:11-31, src/hotkey.rs:37-46), which these tests pin

#[cfg(test)]
mod tests {
    use super::{classify, classify_parse, io_error, panicked, unit_debug, Failure, Field};
    use crate::Panic;
    use global_hotkey::hotkey::{Code, HotKey, HotKeyParseError, Modifiers};
    use global_hotkey::Error;

    fn failure(path: &str, message: &str) -> Failure {
        Failure::new(path, message)
    }

    fn carrying(path: &str, message: &str, text: &str) -> Failure {
        Failure {
            field: Field::Text(text.to_owned()),
            ..failure(path, message)
        }
    }

    #[test]
    fn each_variant_goes_to_its_class_with_global_hotkeys_text_and_field() {
        let os = std::io::Error::from_raw_os_error(1);
        let os_text = os.to_string();
        let expected = Failure {
            field: Field::Os((Some(1), os_text.clone())),
            ..failure("Error::OsError", &os_text)
        };
        assert_eq!(classify(&Error::OsError(os)), expected);
        let coded = classify(&Error::OsError(std::io::Error::other("no code")));
        assert_eq!(coded.field, Field::Os((None, "no code".to_owned())));
        assert_eq!(
            classify(&Error::HotKeyParseError("bad".to_owned())),
            carrying("Error::HotKeyParseError", "bad", "bad")
        );
        assert_eq!(
            classify(&Error::UnrecognizedHotKeyCode("Nope".to_owned())),
            carrying(
                "Error::UnrecognizedHotKeyCode",
                "Couldn't recognize \"Nope\" as a valid HotKey Code, if you feel like it should be, please report this to https://github.com/tauri-apps/global-hotkey",
                "Nope"
            )
        );
        assert_eq!(
            classify(&Error::EmptyHotKeyToken("a++b".to_owned())),
            carrying(
                "Error::EmptyHotKeyToken",
                "Unexpected empty token while parsing hotkey: \"a++b\"",
                "a++b"
            )
        );
        assert_eq!(
            classify(&Error::UnexpectedHotKeyFormat("a+b+c".to_owned())),
            carrying(
                "Error::UnexpectedHotKeyFormat",
                "Unexpected hotkey string format: \"a+b+c\", a hotkey should have the modifiers first and only contain one main key",
                "a+b+c"
            )
        );
        assert_eq!(
            classify(&Error::FailedToRegister(
                "Unknown scancode for F24".to_owned()
            )),
            carrying(
                "Error::FailedToRegister",
                "Unable to register hotkey: Unknown scancode for F24",
                "Unknown scancode for F24"
            )
        );
        assert_eq!(
            classify(&Error::FailedToWatchMediaKeyEvent),
            failure(
                "Error::FailedToWatchMediaKeyEvent",
                "Failed to watch media key event"
            )
        );
    }

    #[test]
    fn the_variants_with_a_hotkey_carry_it_and_its_debug_text() {
        let hotkey = HotKey::new(Some(Modifiers::SHIFT), Code::KeyD);
        let unregister = classify(&Error::FailedToUnRegister(hotkey));
        assert_eq!(unregister.path, "Error::FailedToUnRegister");
        assert_eq!(
            unregister.message,
            "Failed to unregister hotkey: HotKey { mods: Modifiers(SHIFT), key: KeyD, id: 33554454 }"
        );
        assert_eq!(
            unregister.field,
            Field::HotKey((0x200, "KeyD".to_owned(), 33_554_454))
        );

        let already = classify(&Error::AlreadyRegistered(hotkey));
        assert_eq!(already.path, "Error::AlreadyRegistered");
        assert_eq!(
            already.message,
            "HotKey already registered: HotKey { mods: Modifiers(SHIFT), key: KeyD, id: 33554454 }"
        );
        assert_eq!(already.field, unregister.field);
    }

    #[test]
    fn each_parse_error_goes_to_its_class_with_global_hotkeys_text_and_field() {
        assert_eq!(
            classify_parse(&HotKeyParseError::UnsupportedKey("Nope".to_owned())),
            carrying(
                "Hotkey::HotKeyParseError::UnsupportedKey",
                "Couldn't recognize \"Nope\" as a valid key for hotkey, if you feel like it should be, please report this to https://github.com/tauri-apps/muda",
                "Nope"
            )
        );
        assert_eq!(
            classify_parse(&HotKeyParseError::EmptyToken("a++b".to_owned())),
            carrying(
                "Hotkey::HotKeyParseError::EmptyToken",
                "Found empty token while parsing hotkey: a++b",
                "a++b"
            )
        );
        assert_eq!(
            classify_parse(&HotKeyParseError::InvalidFormat("a+b+c".to_owned())),
            carrying(
                "Hotkey::HotKeyParseError::InvalidFormat",
                "Invalid hotkey format: \"a+b+c\", an hotkey should have the modifiers first and only one main key, for example: \"Shift + Alt + K\"",
                "a+b+c"
            )
        );
    }

    /// An `io::Error` rebuilt from its code is the one the crate made
    /// from `last_os_error` (`macos/mod.rs:68`, `windows/mod.rs:70`),
    /// `Debug` text included; one without a code is rebuilt from its text.
    #[test]
    fn an_os_error_rebuilds_from_its_code_or_its_text() {
        let original = std::io::Error::from_raw_os_error(13);
        let rebuilt = io_error((original.raw_os_error(), original.to_string()));
        assert_eq!(format!("{rebuilt:?}"), format!("{original:?}"));
        assert_eq!(rebuilt.to_string(), original.to_string());
        let other = io_error((None, "no code".to_owned()));
        assert_eq!(
            format!("{:?}", Error::OsError(other)),
            "OsError(Custom { kind: Other, error: \"no code\" })"
        );
    }

    #[test]
    fn the_fieldless_error_types_have_their_crates_debug_text() {
        let texts = [
            ("Hotkey::UnrecognizedCodeError", "UnrecognizedCodeError"),
            ("GlobalHotKeyEventReceiver::RecvError", "RecvError"),
            ("GlobalHotKeyEventReceiver::TryRecvError::Empty", "Empty"),
            (
                "GlobalHotKeyEventReceiver::TryRecvError::Disconnected",
                "Disconnected",
            ),
            (
                "GlobalHotKeyEventReceiver::RecvTimeoutError::Timeout",
                "Timeout",
            ),
            (
                "GlobalHotKeyEventReceiver::RecvTimeoutError::Disconnected",
                "Disconnected",
            ),
        ];
        for (path, text) in texts {
            assert_eq!(unit_debug(path).as_deref(), Some(text));
        }
        assert_eq!(unit_debug("Error"), None);
    }

    #[test]
    fn a_variants_debug_text_shows_its_field() {
        assert_eq!(
            format!("{:?}", Error::FailedToRegister("F24".to_owned())),
            "FailedToRegister(\"F24\")"
        );
        let hotkey = HotKey::new(Some(Modifiers::SHIFT), Code::KeyD);
        assert_eq!(
            format!("{:?}", Error::AlreadyRegistered(hotkey)),
            "AlreadyRegistered(HotKey { mods: Modifiers(SHIFT), key: KeyD, id: 33554454 })"
        );
        assert_eq!(
            format!("{:?}", HotKeyParseError::EmptyToken("a++b".to_owned())),
            "EmptyToken(\"a++b\")"
        );
    }

    #[test]
    fn a_panic_reads_as_global_hotkeys() {
        assert_eq!(
            panicked(&Panic("boom".to_owned())),
            failure("Error", "global-hotkey panicked: boom")
        );
    }
}

// SPDX-SnippetEnd
