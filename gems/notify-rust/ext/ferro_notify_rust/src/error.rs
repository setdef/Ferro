// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! notify-rust's errors as Ruby exceptions (plan 003, decision 10).
//!
//! notify-rust's `Error` keeps its `ErrorKind` in a private field and has no
//! accessor (notify-rust 4.18.2 `src/error.rs:16-19`), so the variant is
//! read from the derived `Debug` text, `Error { kind: Zbus(...) }`. The
//! tests below build every variant through the public `From<ErrorKind>`
//! and pin both that text and the `Display` text the Ruby classes copy.
//!
//! Each exception raised for a value notify-rust returned keeps that
//! value's `Debug` text, formatted here, as `@debug`, which its Ruby
//! `debug` answers (ADR 001, 2026-11-05).

use magnus::{
    prelude::*, Error, ExceptionClass, RClass, RModule, RObject, Ruby, Symbol, TryConvert, Value,
};

use crate::Panic;

/// The class at `path` under `Ferro::NotifyRust`. Each step may be a
/// class, as `Error` is, so the lookup goes through `const_get`.
pub fn class_at(ruby: &Ruby, path: &[&str]) -> Result<RClass, Error> {
    let mut current: Value = ruby
        .class_object()
        .const_get::<_, RModule>("Ferro")?
        .const_get("NotifyRust")?;
    for name in path {
        current = current.funcall("const_get", (*name, false))?;
    }
    RClass::try_convert(current)
}

/// An instance of the exception class at `path`, made with `arguments`,
/// keeping `debug`, the `Debug` text of the Rust value it stands for, if
/// there is one; or the error looking it up raised.
pub fn raise(ruby: &Ruby, path: &[&str], arguments: &[String], debug: Option<String>) -> Error {
    let made = class_at(ruby, path).and_then(|class| {
        let class = ExceptionClass::from_value(class.as_value()).ok_or_else(|| {
            Error::new(
                ruby.exception_type_error(),
                format!("{} is not an exception class", path.join("::")),
            )
        })?;
        match arguments {
            [] => class.new_instance(()),
            [only] => class.new_instance((only.as_str(),)),
            _ => Err(Error::new(
                ruby.exception_arg_error(),
                "an exception takes at most one argument",
            )),
        }
    });
    let kept = made.and_then(|exception| {
        if let Some(text) = debug {
            // An exception is a plain object, which holds instance
            // variables as any object does.
            RObject::try_convert(exception.as_value())?.ivar_set("@debug", text)?;
        }
        Ok(exception)
    });
    match kept {
        Ok(exception) => Error::from(exception),
        Err(error) => error,
    }
}

/// `Ferro::NotifyRust::Error` with `message`, for a panic, which is no
/// value of notify-rust's, so it keeps no `Debug` text.
pub fn base(ruby: &Ruby, message: impl Into<String>) -> Error {
    raise(ruby, &["Error"], &[message.into()], None)
}

/// The `IOError` a handle that a consuming call used up raises, as a
/// closed IO does (ADR 001, 2026-11-05); `by` names that call.
pub fn consumed(ruby: &Ruby, by: &str) -> Error {
    Error::new(
        ruby.exception_io_error(),
        format!("Ferro::NotifyRust::NotificationHandle consumed by {by}"),
    )
}

/// The base `Error` for a panic inside notify-rust.
pub fn panicked(ruby: &Ruby, panic: &Panic) -> Error {
    base(ruby, panic_text(panic))
}

/// The message `Ferro::NotifyRust::Error` carries for a panic.
pub fn panic_text(panic: &Panic) -> String {
    format!("notify-rust panicked: {}", panic.0)
}

/// Where a notify-rust error goes in Ruby: the class path under
/// `Ferro::NotifyRust`, and the arguments its constructor takes.
#[derive(Debug, PartialEq, Eq)]
pub struct Raise {
    pub path: Vec<&'static str>,
    pub arguments: Vec<String>,
}

/// The `ErrorKind` variants this build of notify-rust has, each a class
/// under `Error` (`src/error.rs:24-50`). `Dbus` and `MacUserNotifications`
/// need features ferro does not build (plan 003, decision 2).
const KINDS: &[&str] = &[
    "Msg",
    #[cfg(all(unix, not(target_os = "macos")))]
    "Zbus",
    #[cfg(target_os = "macos")]
    "MacNotificationSys",
    "Parse",
    "SpecVersion",
    "Conversion",
    #[cfg(all(unix, not(target_os = "macos")))]
    "Image",
    "ImplementationMissing",
];

/// The variant name that follows `prefix` in a derived `Debug` text: the
/// identifier up to the next `(`, ` `, or `}`.
fn variant_after<'a>(debug: &'a str, prefix: &str) -> Option<&'a str> {
    let rest = debug.strip_prefix(prefix)?;
    let end = rest
        .find(|character: char| !(character.is_alphanumeric() || character == '_'))
        .unwrap_or(rest.len());
    Some(&rest[..end])
}

/// Where `error` goes, read from its `Debug` and `Display` texts.
pub fn classify(debug: &str, display: &str) -> Raise {
    let message = vec![display.to_owned()];
    let Some(kind) = variant_after(debug, "Error { kind: ") else {
        return Raise {
            path: vec!["Error"],
            arguments: message,
        };
    };
    if kind == "MacNotificationSys" {
        return mac_raise(debug, display);
    }
    let path = KINDS
        .iter()
        .find(|known| **known == kind)
        .map_or_else(|| vec!["Error"], |known| vec!["Error", known]);
    if path == ["Error", "Conversion"] {
        // `Conversion`'s Ruby class adds the prefix its `Display` writes
        // (`src/error.rs:68`), so it takes the reason alone. At the locked
        // 4.18.2 that `Display` always writes the prefix, so the fallback
        // below never runs.
        let reason = display.strip_prefix(CONVERSION_PREFIX).unwrap_or(display);
        return Raise {
            path,
            arguments: vec![reason.to_owned()],
        };
    }
    Raise {
        path,
        arguments: message,
    }
}

/// What `ErrorKind::Conversion`'s `Display` writes before its reason
/// (`src/error.rs:68`).
const CONVERSION_PREFIX: &str = "Conversion Error: ";

/// mac-notification-sys's error, inside notify-rust's: a class per leaf
/// under the variant it sits in (plan 003, decision 10).
fn mac_raise(debug: &str, display: &str) -> Raise {
    let outer = variant_after(debug, "Error { kind: MacNotificationSys(").unwrap_or_default();
    let prefix = format!("Error {{ kind: MacNotificationSys({outer}(");
    let leaf = variant_after(debug, &prefix).unwrap_or_default();
    mac_leaf(outer, leaf, display)
}

/// The class for one of mac-notification-sys's errors, named by its outer
/// variant (`Application`, `Notification`) and leaf. An application
/// error's name is read back from its `Display` text, which quotes it
/// (mac-notification-sys 0.6.15 `src/error.rs:21-33`).
pub fn mac_leaf(outer: &str, leaf: &str, display: &str) -> Raise {
    const APPLICATION: &[&str] = &["AlreadySet", "CouldNotSet"];
    const NOTIFICATION: &[&str] = &["ScheduleInThePast", "UnableToSchedule", "UnableToDeliver"];
    let known = match outer {
        "Application" => APPLICATION.iter().find(|name| **name == leaf),
        "Notification" => NOTIFICATION.iter().find(|name| **name == leaf),
        _ => None,
    };
    let outer_path = match outer {
        "Application" => Some("Application"),
        "Notification" => Some("Notification"),
        _ => None,
    };
    match (outer_path, known) {
        (Some("Application"), Some(leaf)) => Raise {
            path: vec!["Error", "MacNotificationSys", "Application", leaf],
            arguments: vec![quoted_name(display)],
        },
        (Some(outer), Some(leaf)) => Raise {
            path: vec!["Error", "MacNotificationSys", outer, leaf],
            arguments: vec![],
        },
        _ => Raise {
            path: vec!["Error", "MacNotificationSys"],
            arguments: vec![display.to_owned()],
        },
    }
}

/// The text between the first pair of single quotes in `display`.
fn quoted_name(display: &str) -> String {
    display
        .split_once('\'')
        .and_then(|(_, rest)| rest.rsplit_once('\''))
        .map(|(name, _)| name.to_owned())
        .unwrap_or_default()
}

/// The Ruby exception for one of notify-rust's errors, keeping its
/// `Debug` text.
pub fn notify_error(ruby: &Ruby, error: &notify_rust::error::Error) -> Error {
    let debug = format!("{error:?}");
    let target = classify(&debug, &error.to_string());
    raise(ruby, &target.path, &target.arguments, Some(debug))
}

/// The notify-rust error that an exception Ruby code made stands for,
/// where its variant holds nothing but text (`src/error.rs:22-50`): `Msg`,
/// `SpecVersion`, and `Conversion` with `text`, and
/// `ImplementationMissing`. Every other variant holds another crate's
/// value, which no Ruby value is, so there is none to build.
fn rebuilt(kind: &str, text: Option<String>) -> Option<notify_rust::error::Error> {
    use notify_rust::error::ErrorKind;

    Some(notify_rust::error::Error::from(match (kind, text) {
        ("Msg", Some(text)) => ErrorKind::Msg(text),
        ("SpecVersion", Some(text)) => ErrorKind::SpecVersion(text),
        ("Conversion", Some(text)) => ErrorKind::Conversion(text),
        ("ImplementationMissing", _) => ErrorKind::ImplementationMissing,
        _ => return None,
    }))
}

/// `Native.error_debug`: notify-rust's `Debug` text (`src/error.rs:16`,
/// `:22`) for the error of variant `kind` holding `text`, which an
/// exception Ruby code made stands for, or `nil` for a variant that holds
/// another crate's value.
pub fn error_debug(kind: Symbol, text: Option<String>) -> Result<Option<String>, Error> {
    Ok(rebuilt(&kind.name()?, text).map(|error| format!("{error:?}")))
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
// SPDX-SnippetCopyrightText: Felix Döring <development@felixdoering.com>, Hendrik Sollich <hendrik@hoodie.de>
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the Display texts of notify-rust 4.18.2's errors
//   (src/error.rs:52-78, src/image.rs:149-165) and mac-notification-sys
//   0.6.15's (src/error.rs:21-63), which these tests pin

#[cfg(test)]
mod tests {
    use super::{classify, mac_leaf, rebuilt, variant_after, Raise};
    use notify_rust::error::{Error, ErrorKind};

    fn target(error: &Error) -> Raise {
        classify(&format!("{error:?}"), &error.to_string())
    }

    fn message(path: &[&'static str], text: &str) -> Raise {
        Raise {
            path: path.to_vec(),
            arguments: vec![text.to_owned()],
        }
    }

    #[test]
    fn a_variant_name_ends_at_its_payload() {
        assert_eq!(
            variant_after("Error { kind: Msg(\"x\") }", "Error { kind: "),
            Some("Msg")
        );
        assert_eq!(
            variant_after("Error { kind: ImplementationMissing }", "Error { kind: "),
            Some("ImplementationMissing")
        );
        assert_eq!(variant_after("Other", "Error { kind: "), None);
    }

    #[test]
    fn each_kind_raises_its_class_with_notify_rusts_text() {
        assert_eq!(
            target(&Error::from("invalid subpath")),
            message(&["Error", "Msg"], "invalid subpath")
        );
        let parse = "x".parse::<u32>().expect_err("not a number");
        assert_eq!(
            target(&Error::from(parse)),
            message(
                &["Error", "Parse"],
                "Parsing Error: invalid digit found in string"
            )
        );
        assert_eq!(
            target(&Error::from(ErrorKind::SpecVersion("1".into()))),
            message(&["Error", "SpecVersion"], "1")
        );
        // Conversion's Ruby class builds the prefix around its reason, as
        // AlreadySet builds its text around the name.
        let conversion = Error::from(ErrorKind::Conversion("invalid input \"x\"".into()));
        assert_eq!(
            conversion.to_string(),
            "Conversion Error: invalid input \"x\""
        );
        assert_eq!(
            target(&conversion),
            message(&["Error", "Conversion"], "invalid input \"x\"")
        );
        assert_eq!(
            target(&Error::from(ErrorKind::ImplementationMissing)),
            message(
                &["Error", "ImplementationMissing"],
                r#"No Dbus implementation available, please compile with either feature ="z" or feature="d""#
            )
        );
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    #[test]
    fn linux_kinds_raise_their_classes() {
        let zbus = zbus::Error::Failure("no".into());
        let text = zbus.to_string();
        assert_eq!(
            target(&Error::from(zbus)),
            message(&["Error", "Zbus"], &text)
        );
        let image = notify_rust::Image::from_rgb(1, 1, vec![]).expect_err("too few bytes");
        assert_eq!(
            target(&Error::from(ErrorKind::Image(image))),
            message(
                &["Error", "Image"],
                "The given bytes don't match the width, height and channel count\n"
            )
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn mac_notification_sys_errors_raise_their_leaf_classes() {
        use notify_rust::error::{ApplicationError, MacOsError, NotificationError};

        let already = MacOsError::from(ApplicationError::AlreadySet("com.apple.Safari".into()));
        assert_eq!(
            target(&Error::from(ErrorKind::MacNotificationSys(already))),
            Raise {
                path: vec!["Error", "MacNotificationSys", "Application", "AlreadySet"],
                arguments: vec!["com.apple.Safari".into()],
            }
        );
        let past = MacOsError::from(NotificationError::ScheduleInThePast);
        let past = Error::from(ErrorKind::MacNotificationSys(past));
        assert_eq!(
            past.to_string(),
            "Can not schedule notification in the past"
        );
        assert_eq!(
            target(&past),
            Raise {
                path: vec![
                    "Error",
                    "MacNotificationSys",
                    "Notification",
                    "ScheduleInThePast"
                ],
                arguments: vec![],
            }
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn mac_notification_sys_texts_are_the_ones_ruby_copies() {
        use notify_rust::error::{ApplicationError, NotificationError};

        assert_eq!(
            ApplicationError::AlreadySet("a.b".into()).to_string(),
            "Application 'a.b' can only be set once."
        );
        assert_eq!(
            ApplicationError::CouldNotSet("a.b".into()).to_string(),
            "Could not set application 'a.b', using default \"com.apple.Terminal\""
        );
        assert_eq!(
            NotificationError::UnableToSchedule.to_string(),
            "Could not schedule notification"
        );
        assert_eq!(
            NotificationError::UnableToDeliver.to_string(),
            "Could not deliver notification"
        );
    }

    #[test]
    fn an_application_error_keeps_a_name_with_quotes_in_it() {
        assert_eq!(
            mac_leaf(
                "Application",
                "CouldNotSet",
                "Could not set application 'it's', using default \"com.apple.Terminal\""
            ),
            Raise {
                path: vec!["Error", "MacNotificationSys", "Application", "CouldNotSet"],
                arguments: vec!["it's".into()],
            }
        );
    }

    #[test]
    fn a_variant_of_text_alone_is_rebuilt_as_notify_rust_debugs_it() {
        let debug = |kind: &str, text: Option<&str>| {
            rebuilt(kind, text.map(str::to_owned)).map(|error| format!("{error:?}"))
        };
        assert_eq!(
            debug("Msg", Some("invalid subpath")).as_deref(),
            Some(r#"Error { kind: Msg("invalid subpath") }"#)
        );
        assert_eq!(
            debug("SpecVersion", Some("1")).as_deref(),
            Some(r#"Error { kind: SpecVersion("1") }"#)
        );
        assert_eq!(
            debug("Conversion", Some("x")).as_deref(),
            Some(r#"Error { kind: Conversion("x") }"#)
        );
        assert_eq!(
            debug("ImplementationMissing", None).as_deref(),
            Some("Error { kind: ImplementationMissing }")
        );
        assert_eq!(debug("Parse", Some("x")), None);
        assert_eq!(debug("Zbus", Some("x")), None);
        assert_eq!(debug("Msg", None), None);
    }

    #[test]
    fn an_unknown_variant_raises_the_base_class() {
        assert_eq!(
            classify("Error { kind: Future(1) }", "later"),
            message(&["Error"], "later")
        );
        assert_eq!(
            classify("Error { kind: Conversion(\"x\") }", "unexpected"),
            message(&["Error", "Conversion"], "unexpected")
        );
        assert_eq!(
            mac_leaf("Other", "Thing", "text"),
            message(&["Error", "MacNotificationSys"], "text")
        );
    }
}

// SPDX-SnippetEnd
