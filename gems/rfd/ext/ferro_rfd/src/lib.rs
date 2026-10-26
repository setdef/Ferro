// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! The native half of ferro-rfd: Ruby bindings for rfd 0.17.2.
//!
//! Ruby owns the public API (`lib/ferro/rfd`). The Ruby builders keep the
//! arguments their setters received, and each terminal method hands them
//! to a function here, which builds rfd's builder with rfd's own setters
//! and runs the terminal call (plan 002, decision 1). The functions live
//! on `Ferro::Rfd::Native`, a private module, and `Native::Future` wraps
//! rfd's futures for the Ruby `Ferro::Rfd::Future`.
//!
//! Two rules hold for every function:
//!
//! - A panic never reaches magnus, which would turn it into Ruby's
//!   uncatchable `fatal` (magnus 0.9.3 `src/error.rs:292-296`). Every call
//!   into rfd runs under `catch_unwind` and raises `Ferro::Rfd::Error`
//!   instead (plan 002, decision 11).
//! - A call that shows a dialog runs with the GVL released (`gvl.rs`).

mod dialogs;
mod file_handle;
mod future;
mod gvl;
mod handles;
mod platform;

use std::any::Any;
use std::panic::{self, AssertUnwindSafe};
use std::path::PathBuf;

use magnus::{function, prelude::*, Error, ExceptionClass, RModule, RString, Ruby, Value};

/// A panic inside rfd, with its message.
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

/// The message `Ferro::Rfd::Error` carries for a panic.
pub(crate) fn panic_text(panic: &Panic) -> String {
    format!("rfd panicked: {}", panic.0)
}

/// `Ferro::Rfd::Error`, the class for rfd's panics and for the calls the
/// gem refuses because rfd would panic or deadlock on them.
pub(crate) fn error_class(ruby: &Ruby) -> Result<ExceptionClass, Error> {
    ruby.class_object()
        .const_get::<_, RModule>("Ferro")?
        .const_get::<_, RModule>("Rfd")?
        .const_get("Error")
}

/// A `Ferro::Rfd::Error` with `message`, or the error looking up the
/// class raised.
pub(crate) fn rfd_error(ruby: &Ruby, message: impl Into<String>) -> Error {
    match error_class(ruby) {
        Ok(class) => Error::new(class, message.into()),
        Err(lookup) => lookup,
    }
}

/// The value of `outcome`, or `Ferro::Rfd::Error` for the panic it caught.
pub(crate) fn settle<T>(ruby: &Ruby, outcome: Result<T, Panic>) -> Result<T, Error> {
    outcome.map_err(|panic| rfd_error(ruby, panic_text(&panic)))
}

/// A path from Ruby, byte for byte, as Unix allows. Ruby passes it through
/// `File.path`, which has refused a NUL byte already.
#[cfg(unix)]
pub(crate) fn path_from_ruby(path: Value) -> Result<PathBuf, Error> {
    use std::os::unix::ffi::OsStringExt;
    let bytes = RString::try_convert(path)?.to_bytes().to_vec();
    Ok(PathBuf::from(std::ffi::OsString::from_vec(bytes)))
}

/// A path from Ruby, which Windows takes as UTF-8.
#[cfg(not(unix))]
pub(crate) fn path_from_ruby(path: Value) -> Result<PathBuf, Error> {
    String::try_convert(path).map(PathBuf::from)
}

/// A path for Ruby: its bytes in the filesystem encoding on Unix.
#[cfg(unix)]
pub(crate) fn path_to_ruby(ruby: &Ruby, path: &std::path::Path) -> RString {
    use std::os::unix::ffi::OsStrExt;
    ruby.enc_str_new(path.as_os_str().as_bytes(), ruby.filesystem_encoding())
}

/// A path for Ruby: UTF-8 on Windows, which stores paths as UTF-16; an
/// unpaired surrogate becomes U+FFFD.
#[cfg(not(unix))]
pub(crate) fn path_to_ruby(ruby: &Ruby, path: &std::path::Path) -> RString {
    ruby.str_new(&path.to_string_lossy())
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). Its one wrapped
    // type, `Future`, holds a `Mutex` over a `Send` future and is never
    // made shareable. rfd's builders are `Send` (rfd src/file_dialog.rs:30-33,
    // src/message_dialog.rs:24-26) and each call builds its own, so a call
    // from any thread touches only its own values; the macOS thread rules
    // are checked in `platform`. Every other value a function touches is
    // an argument, which Ruby guarantees is the calling Ractor's own or
    // shareable (extension.rdoc:2260-2261). `rb_ext_ractor_safe` takes a
    // plain flag, called from `Init_` as extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let rfd = ruby.define_module("Ferro")?.define_module("Rfd")?;
    rfd.const_set("PLATFORM", ruby.to_symbol(platform::NAME))?;

    let native = rfd.define_module("Native")?;
    future::define(ruby, native)?;
    native.define_singleton_method(
        "file_dialog_debug",
        function!(dialogs::file_dialog_debug, 1),
    )?;
    native.define_singleton_method(
        "async_file_dialog_debug",
        function!(dialogs::async_file_dialog_debug, 1),
    )?;
    native.define_singleton_method("file_dialog", function!(dialogs::file_dialog, 2))?;
    native.define_singleton_method(
        "async_file_dialog",
        function!(dialogs::async_file_dialog, 2),
    )?;
    native.define_singleton_method(
        "message_dialog_debug",
        function!(dialogs::message_dialog_debug, 1),
    )?;
    native.define_singleton_method(
        "async_message_dialog_debug",
        function!(dialogs::async_message_dialog_debug, 1),
    )?;
    native.define_singleton_method("message_dialog", function!(dialogs::message_dialog, 1))?;
    native.define_singleton_method(
        "async_message_dialog",
        function!(dialogs::async_message_dialog, 1),
    )?;
    native.define_singleton_method("check_parent", function!(handles::check_parent, 1))?;
    native.define_singleton_method("file_name", function!(file_handle::file_name, 1))?;
    native.define_singleton_method("file_handle_debug", function!(file_handle::debug, 1))?;
    native.define_singleton_method("read", function!(file_handle::read, 1))?;
    native.define_singleton_method("write", function!(file_handle::write, 2))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{capture, panic_text, Panic};

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
    fn a_panic_reads_as_rfds() {
        assert_eq!(panic_text(&Panic("boom".to_owned())), "rfd panicked: boom");
    }
}
