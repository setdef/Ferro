// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The native half of ferro-notify-rust: Ruby bindings for notify-rust
//! 4.18.2.
//!
//! Ruby owns the public API (`lib/ferro/notify_rust`). This crate defines
//! the wrapped types, `Notification`, `NotificationHandle`, and on Linux
//! `Image`, with private methods that run notify-rust's own calls, and the
//! conversions on `Ferro::NotifyRust::Native`, a private module (plan 003).
//!
//! Two rules hold for every function:
//!
//! - A panic never reaches magnus, which would turn it into Ruby's
//!   uncatchable `fatal` (magnus 0.9.3 `src/error.rs:292-296`). Every call
//!   into notify-rust runs under `catch_unwind` and raises
//!   `Ferro::NotifyRust::Error` instead (plan 003, decision 15).
//! - A call that talks to the notification server or waits for the user
//!   runs with the GVL released (`gvl.rs`, plan 003, decision 6).

mod error;
mod gvl;
mod notification;
mod values;

#[cfg(all(unix, not(target_os = "macos")))]
#[path = "linux.rs"]
mod platform;

#[cfg(target_os = "macos")]
#[path = "macos.rs"]
mod platform;

#[cfg(windows)]
#[path = "windows.rs"]
mod platform;

use std::any::Any;
use std::panic::{self, AssertUnwindSafe};

use magnus::{function, prelude::*, Error, Ruby};

#[cfg(all(unix, not(target_os = "macos")))]
use magnus::Value;
#[cfg(all(unix, not(target_os = "macos")))]
use std::path::PathBuf;

/// A panic inside notify-rust, with its message.
#[derive(Debug, PartialEq, Eq)]
pub(crate) struct Panic(pub String);

/// Runs `operation`, catching a panic.
pub(crate) fn capture<T>(operation: impl FnOnce() -> T) -> Result<T, Panic> {
    panic::catch_unwind(AssertUnwindSafe(operation)).map_err(|payload| panic_of(&payload))
}

/// The panic a caught payload carries.
pub(crate) fn panic_of(payload: &Box<dyn Any + Send>) -> Panic {
    Panic(panic_message(payload.as_ref()))
}

/// The message a panic carried, worded as Rust's default panic hook words
/// a payload that is not a string.
fn panic_message(payload: &(dyn Any + Send)) -> String {
    payload
        .downcast_ref::<&str>()
        .map(|message| (*message).to_owned())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "Box<dyn Any>".to_owned())
}

/// The value of `outcome`, or `Ferro::NotifyRust::Error` for the panic it
/// caught.
pub(crate) fn settle<T>(ruby: &Ruby, outcome: Result<T, Panic>) -> Result<T, Error> {
    outcome.map_err(|panic| error::panicked(ruby, &panic))
}

/// A path from Ruby, byte for byte, as Unix allows. Ruby passes it through
/// `File.path`, which has refused a NUL byte already.
#[cfg(all(unix, not(target_os = "macos")))]
pub(crate) fn path_from_ruby(path: Value) -> Result<PathBuf, Error> {
    use magnus::{RString, TryConvert};
    use std::os::unix::ffi::OsStringExt;
    let bytes = RString::try_convert(path)?.to_bytes().to_vec();
    Ok(PathBuf::from(std::ffi::OsString::from_vec(bytes)))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). `Notification` and
    // `Image` hold `Send` and `Sync` values behind a `Mutex` or none, and
    // are the only types marked frozen-shareable; a handle stays with its
    // Ractor. notify-rust's calls may come from any thread: zbus connects per
    // call, and mac-notification-sys checks which thread it is on
    // (objc/notify.m:168, :192). Its process-wide state, the bundle hook and
    // the delegate, is set once under a `Once` and `dispatch_once`
    // (src/lib.rs:53, :146-158; objc/notify.m:303-311). Every other value a
    // function touches is an argument, which Ruby guarantees is the calling
    // Ractor's own or shareable (extension.rdoc:2260-2261).
    // `rb_ext_ractor_safe` takes a plain flag, called from `Init_` as
    // extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let notify_rust = ruby.define_module("Ferro")?.define_module("NotifyRust")?;
    notify_rust.const_set("PLATFORM", ruby.to_symbol(platform::NAME))?;

    let native = notify_rust.define_module("Native")?;
    native.define_singleton_method("urgency_try_from", function!(values::urgency_try_from, 1))?;
    native.define_singleton_method("urgency_from", function!(values::urgency_from, 1))?;
    native.define_singleton_method("timeout_from_i32", function!(values::timeout_from_i32, 1))?;
    native.define_singleton_method("timeout_from_str", function!(values::timeout_from_str, 1))?;
    native.define_singleton_method("timeout_to_i32", function!(values::timeout_to_i32, 1))?;
    native.define_singleton_method("close_reason_from", function!(values::close_reason_from, 1))?;
    native.define_singleton_method(
        "notification_response_from",
        function!(values::notification_response_from, 1),
    )?;
    native.define_singleton_method(
        "action_response_from",
        function!(values::action_response_from, 1),
    )?;
    native.define_singleton_method(
        "notification_id_from",
        function!(values::notification_id_from, 1),
    )?;
    native.define_singleton_method("hint_from_key_val", function!(values::hint_from_key_val, 2))?;
    native.define_singleton_method("hint_as_bool", function!(values::hint_as_bool, 1))?;
    native.define_singleton_method("hint_as_i32", function!(values::hint_as_i32, 1))?;
    native.define_singleton_method("hint_as_str", function!(values::hint_as_str, 1))?;

    notification::define(ruby, notify_rust)?;
    platform::define(ruby, notify_rust, native)
}

#[cfg(test)]
mod tests {
    use super::{capture, error::panic_text, Panic};

    #[test]
    fn capture_passes_values_through() {
        assert_eq!(capture(|| 7), Ok(7));
    }

    #[test]
    fn capture_turns_panics_into_their_messages() {
        assert_eq!(
            capture::<()>(|| panic!("boom")),
            Err(Panic("boom".to_owned()))
        );

        // A message built at run time is a String payload; literal
        // arguments would be folded into a &'static str.
        let built = capture::<()>(|| {
            panic!(
                "{} {}",
                std::hint::black_box("bad"),
                std::hint::black_box(7)
            )
        });
        assert_eq!(built, Err(Panic("bad 7".to_owned())));

        let other = capture::<()>(|| std::panic::panic_any(7_u8));
        assert_eq!(other, Err(Panic("Box<dyn Any>".to_owned())));
    }

    #[test]
    fn a_panic_reads_as_notify_rusts() {
        assert_eq!(
            panic_text(&Panic("boom".to_owned())),
            "notify-rust panicked: boom"
        );
    }
}
