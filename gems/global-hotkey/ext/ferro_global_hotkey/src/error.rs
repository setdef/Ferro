// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! The failures the native layer hands Ruby (plan 004, decision 7).
//!
//! A function that can fail returns `[:ok, value]` or
//! `[:error, path, message, hotkey]`, and the Ruby side raises the class at
//! `path` under `Ferro::GlobalHotkey`. Building the exception in Ruby keeps
//! its constructor, its `hotkey`, and its docs in one place. The message is
//! always the source crate's own `Display` text.

use global_hotkey::hotkey::HotKeyParseError;
use magnus::{IntoValue, RArray, Ruby, Value};

use crate::hotkey::{parts, Parts};
use crate::Panic;

/// Where a failure goes in Ruby: the class path under
/// `Ferro::GlobalHotkey`, the message, and the hotkey the error carries.
#[derive(Debug, PartialEq, Eq)]
pub struct Failure {
    pub path: String,
    pub message: String,
    pub hotkey: Option<Parts>,
}

impl Failure {
    pub fn new(path: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            message: message.into(),
            hotkey: None,
        }
    }
}

/// The base `Error` for a panic inside global-hotkey.
pub fn panicked(panic: &Panic) -> Failure {
    Failure::new("Error", format!("global-hotkey panicked: {}", panic.0))
}

/// Where one of global-hotkey's errors goes (`src/error.rs:9-31`). A
/// variant a later global-hotkey adds goes to the base class, since the
/// enum is `#[non_exhaustive]`.
pub fn classify(error: &global_hotkey::Error) -> Failure {
    use global_hotkey::Error as E;
    let (variant, hotkey) = match error {
        E::OsError(_) => ("OsError", None),
        E::HotKeyParseError(_) => ("HotKeyParseError", None),
        E::UnrecognizedHotKeyCode(_) => ("UnrecognizedHotKeyCode", None),
        E::EmptyHotKeyToken(_) => ("EmptyHotKeyToken", None),
        E::UnexpectedHotKeyFormat(_) => ("UnexpectedHotKeyFormat", None),
        E::FailedToRegister(_) => ("FailedToRegister", None),
        E::FailedToUnRegister(hotkey) => ("FailedToUnRegister", Some(parts(hotkey))),
        E::AlreadyRegistered(hotkey) => ("AlreadyRegistered", Some(parts(hotkey))),
        E::FailedToWatchMediaKeyEvent => ("FailedToWatchMediaKeyEvent", None),
        _ => ("", None),
    };
    Failure {
        path: if variant.is_empty() {
            "Error".to_owned()
        } else {
            format!("Error::{variant}")
        },
        message: error.to_string(),
        hotkey,
    }
}

/// Where one of `hotkey::HotKeyParseError`'s variants goes
/// (`src/hotkey.rs:38-46`).
pub fn classify_parse(error: &HotKeyParseError) -> Failure {
    let variant = match error {
        HotKeyParseError::UnsupportedKey(_) => "UnsupportedKey",
        HotKeyParseError::EmptyToken(_) => "EmptyToken",
        HotKeyParseError::InvalidFormat(_) => "InvalidFormat",
    };
    Failure::new(
        format!("Hotkey::HotKeyParseError::{variant}"),
        error.to_string(),
    )
}

/// `[:ok, value]`.
pub fn ok(ruby: &Ruby, value: impl IntoValue) -> RArray {
    let tag: Value = ruby.to_symbol("ok").into_value_with(ruby);
    ruby.ary_new_from_values(&[tag, value.into_value_with(ruby)])
}

/// `[:error, path, message, hotkey]`, `hotkey` being `nil` or the parts
/// of the hotkey the error carries.
pub fn error(ruby: &Ruby, failure: Failure) -> RArray {
    let values: [Value; 4] = [
        ruby.to_symbol("error").into_value_with(ruby),
        failure.path.into_value_with(ruby),
        failure.message.into_value_with(ruby),
        failure.hotkey.into_value_with(ruby),
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

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
// SPDX-License-Identifier: Apache-2.0 OR MIT
// SPDX-SnippetComment: the Display texts of global-hotkey 0.9.0's errors
//   (src/error.rs:12-31, src/hotkey.rs:38-46), which these tests pin

#[cfg(test)]
mod tests {
    use super::{classify, classify_parse, panicked, Failure};
    use crate::Panic;
    use global_hotkey::hotkey::{Code, HotKey, HotKeyParseError, Modifiers};
    use global_hotkey::Error;

    fn failure(path: &str, message: &str) -> Failure {
        Failure::new(path, message)
    }

    #[test]
    fn each_variant_goes_to_its_class_with_global_hotkeys_text() {
        let os = std::io::Error::from_raw_os_error(1);
        let os_text = os.to_string();
        assert_eq!(
            classify(&Error::OsError(os)),
            failure("Error::OsError", &os_text)
        );
        assert_eq!(
            classify(&Error::HotKeyParseError("bad".to_owned())),
            failure("Error::HotKeyParseError", "bad")
        );
        assert_eq!(
            classify(&Error::UnrecognizedHotKeyCode("Nope".to_owned())),
            failure(
                "Error::UnrecognizedHotKeyCode",
                "Couldn't recognize \"Nope\" as a valid HotKey Code, if you feel like it should be, please report this to https://github.com/tauri-apps/global-hotkey"
            )
        );
        assert_eq!(
            classify(&Error::EmptyHotKeyToken("a++b".to_owned())),
            failure(
                "Error::EmptyHotKeyToken",
                "Unexpected empty token while parsing hotkey: \"a++b\""
            )
        );
        assert_eq!(
            classify(&Error::UnexpectedHotKeyFormat("a+b+c".to_owned())),
            failure(
                "Error::UnexpectedHotKeyFormat",
                "Unexpected hotkey string format: \"a+b+c\", a hotkey should have the modifiers first and only contain one main key"
            )
        );
        assert_eq!(
            classify(&Error::FailedToRegister(
                "Unknown scancode for F24".to_owned()
            )),
            failure(
                "Error::FailedToRegister",
                "Unable to register hotkey: Unknown scancode for F24"
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
            unregister.hotkey,
            Some((0x200, "KeyD".to_owned(), 33_554_454))
        );

        let already = classify(&Error::AlreadyRegistered(hotkey));
        assert_eq!(already.path, "Error::AlreadyRegistered");
        assert_eq!(
            already.message,
            "HotKey already registered: HotKey { mods: Modifiers(SHIFT), key: KeyD, id: 33554454 }"
        );
        assert_eq!(already.hotkey, unregister.hotkey);
    }

    #[test]
    fn each_parse_error_goes_to_its_class_with_global_hotkeys_text() {
        assert_eq!(
            classify_parse(&HotKeyParseError::UnsupportedKey("Nope".to_owned())),
            failure(
                "Hotkey::HotKeyParseError::UnsupportedKey",
                "Couldn't recognize \"Nope\" as a valid key for hotkey, if you feel like it should be, please report this to https://github.com/tauri-apps/muda"
            )
        );
        assert_eq!(
            classify_parse(&HotKeyParseError::EmptyToken("a++b".to_owned())),
            failure(
                "Hotkey::HotKeyParseError::EmptyToken",
                "Found empty token while parsing hotkey: a++b"
            )
        );
        assert_eq!(
            classify_parse(&HotKeyParseError::InvalidFormat("a+b+c".to_owned())),
            failure(
                "Hotkey::HotKeyParseError::InvalidFormat",
                "Invalid hotkey format: \"a+b+c\", an hotkey should have the modifiers first and only one main key, for example: \"Shift + Alt + K\""
            )
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
