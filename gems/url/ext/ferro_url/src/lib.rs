// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The native half of ferro-url: Ruby bindings for url 2.5.8 and the
//! `form_urlencoded` 1.2.2 it re-exports.
//!
//! Ruby owns the public API (`lib/ferro/url`). The functions here live on
//! `Ferro::Url::Native`, a private module, beside `Native::Url`, which owns
//! a `url::Url`, and `Native::OpaqueOrigin`. A host crosses as
//! `[variant, value]` and an origin as `[variant, ...]` (`values.rs`).
//!
//! Three rules hold for every function:
//!
//! - A panic never reaches magnus, which would turn it into Ruby's
//!   uncatchable `fatal` (magnus 0.9.3 `src/error.rs:292-296`). Every call
//!   into url runs under `catch_unwind` and raises `Ferro::Url::Error`
//!   instead (plan 005, decision 17).
//! - Nothing of Ruby's is touched while a `Url`'s lock is held: no method
//!   call, no allocation, no class lookup. Work under the lock returns
//!   Rust values and a Rust `Failure`, and Ruby values and exceptions are
//!   built only once the lock is released (plan 005, decision 20). A Ruby
//!   call can switch threads or start a garbage collection, and another
//!   thread or Ractor waiting for the same lock would then hold up the
//!   whole VM.
//! - Only `socket_addrs` releases the GVL (`gvl.rs`).

mod form;
mod gvl;
mod native_url;
mod quirks;
mod values;

use std::any::Any;
use std::panic::{self, AssertUnwindSafe};

use magnus::{prelude::*, Error, ExceptionClass, RModule, Ruby, Value};

/// A panic inside url, with its message.
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

/// The message of the `Error` a panic raises (plan 005, decision 6).
pub(crate) fn panicked(panic: &Panic) -> String {
    format!("url panicked: {}", panic.0)
}

/// The message of the `Error` a `Result<_, ()>` raises (plan 005,
/// decision 6): `url::Url::set_port returned Err(())`.
pub(crate) fn unit_error(function: &str) -> String {
    format!("{function} returned Err(())")
}

/// The class at `path` under `Ferro::Url`, such as `Error` or
/// `ParseError::EmptyHost`.
pub(crate) fn class(ruby: &Ruby, path: &str) -> Result<ExceptionClass, Error> {
    let root: Value = ruby
        .class_object()
        .const_get::<_, RModule>("Ferro")?
        .const_get("Url")?;
    let found = path.split("::").try_fold(root, |namespace, name| {
        namespace.funcall::<_, _, Value>("const_get", (name, false))
    })?;
    ExceptionClass::try_convert(found)
}

/// A Ruby exception of the class at `path` with `message`.
pub(crate) fn raise(ruby: &Ruby, path: &str, message: impl Into<String>) -> Error {
    match class(ruby, path) {
        Ok(class) => Error::new(class, message.into()),
        Err(error) => error,
    }
}

/// `Ferro::Url::Error` with `message`.
pub(crate) fn error(ruby: &Ruby, message: impl Into<String>) -> Error {
    raise(ruby, "Error", message)
}

/// A failure from work done under a `Url`'s lock, in Rust values only, so
/// the Ruby exception is built after the lock is released.
#[derive(Debug, PartialEq, Eq)]
pub(crate) enum Failure {
    /// url's `ParseError`.
    Parse(url::ParseError),
    /// url's `Err(())`, from the function named.
    Unit(&'static str),
    /// `Ferro::Url::Error` with this message.
    Message(String),
    /// A panic inside url.
    Panic(Panic),
}

impl Failure {
    /// The Ruby exception, which may look up classes and allocate.
    pub(crate) fn into_error(self, ruby: &Ruby) -> Error {
        match self {
            Self::Parse(failure) => values::parse_error(ruby, failure),
            Self::Unit(function) => error(ruby, unit_error(function)),
            Self::Message(message) => error(ruby, message),
            Self::Panic(panic) => error(ruby, panicked(&panic)),
        }
    }
}

/// Runs `operation` under `catch_unwind`, raising `Error` for a panic.
pub(crate) fn guarded<T>(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<T, Error>,
) -> Result<T, Error> {
    capture(operation).unwrap_or_else(|panic| Err(error(ruby, panicked(&panic))))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). url's one static is
    // the atomic counter behind `Origin::new_opaque` (url 2.5.8
    // src/origin.rs:65-69). The wrapped types are a `Mutex` over a `Url`,
    // which is `Send` and `Sync`, and an `OpaqueOrigin`, a number no method
    // changes, so sharing either frozen is sound. Every other value a
    // function touches is an argument, which Ruby guarantees is the calling
    // Ractor's own or shareable (extension.rdoc:2260-2261).
    // `rb_ext_ractor_safe` takes a plain flag, called from `Init_` as
    // extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let url = ruby.define_module("Ferro")?.define_module("Url")?;
    let native = url.define_module("Native")?;
    // Ruby never allocates either: the functions below make them, so a
    // panic while building one is caught (plan 005, decision 3).
    native
        .define_class("Url", ruby.class_object())?
        .undef_default_alloc_func();
    native
        .define_class("OpaqueOrigin", ruby.class_object())?
        .undef_default_alloc_func();

    native_url::define(native)?;
    values::define(native)?;
    form::define(native)?;
    quirks::define(native)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{capture, panicked, unit_error, Panic};

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
    fn messages_read_as_urls() {
        assert_eq!(panicked(&Panic("boom".to_owned())), "url panicked: boom");
        assert_eq!(
            unit_error("url::Url::set_port"),
            "url::Url::set_port returned Err(())"
        );
    }
}
