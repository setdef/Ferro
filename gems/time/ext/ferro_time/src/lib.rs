// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The native half of ferro-time: Ruby bindings for time 0.3.55.
//!
//! Ruby owns the public API (`lib/ferro/time`). Each of time's value types
//! is a wrapped Rust value whose class is the public Ruby class itself
//! (`Ferro::Time::Date` holds a `time::Date`), made only here and always
//! frozen. The functions that reach the crate live on `Ferro::Time::Native`,
//! a private module; the Ruby methods call them.
//!
//! Three rules hold for every function:
//!
//! - A panic never reaches magnus, which would turn it into Ruby's
//!   uncatchable `fatal` (magnus 0.9.3 `src/error.rs:292-296`). The panics
//!   time documents are refused first with `RangeError` and time's own
//!   message, and every call runs under `catch_unwind` as a net, raising
//!   `Ferro::Time::Error` (plan 007, decision 7).
//! - No value is ever changed after it is made, so there is no lock, and
//!   nothing of Ruby's can run while one is held (plan 005, decision 20).
//! - Every call keeps the GVL: each is short CPU work or one system call
//!   (plan 007, decision 17).

mod calendar;
mod clock;
mod date;
mod datetime;
mod duration;
mod failure;
mod format;
mod iso8601;
mod offset;
mod system_time;
mod values;

use std::any::Any;
use std::panic::{self, AssertUnwindSafe};

use magnus::{prelude::*, typed_data::Obj, Error, RModule, Ruby, TypedData, Value};

pub(crate) use failure::Failure;

/// A panic inside time, with its message.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Panic(pub String);

/// Runs `operation`, catching a panic.
pub(crate) fn capture<T>(operation: impl FnOnce() -> T) -> Result<T, Panic> {
    panic::catch_unwind(AssertUnwindSafe(operation)).map_err(|payload| panic_of(&payload))
}

/// The panic a caught payload carries.
fn panic_of(payload: &Box<dyn Any + Send>) -> Panic {
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

/// Runs `operation` under `catch_unwind` and turns its failure, or a
/// panic, into a Ruby exception once it has returned.
pub(crate) fn guarded<T>(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<T, Failure>,
) -> Result<T, Error> {
    capture(operation)
        .unwrap_or_else(|panic| Err(Failure::Panic(panic.0)))
        .map_err(|failure| failure.into_error(ruby))
}

/// `value` wrapped as its Ruby class and frozen: every value this gem
/// makes is immutable and shareable (plan 007, decisions 3 and 17).
pub(crate) fn frozen<T: TypedData>(ruby: &Ruby, value: T) -> Obj<T> {
    let object = ruby.obj_wrap(value);
    object.freeze();
    object
}

/// `value` wrapped and frozen, or `nil`.
pub(crate) fn frozen_option<T: TypedData>(ruby: &Ruby, value: Option<T>) -> Value {
    value.map_or_else(
        || ruby.qnil().as_value(),
        |value| frozen(ruby, value).as_value(),
    )
}

/// The module at `path` under `Ferro::Time`, such as `Native`.
pub(crate) fn namespace(ruby: &Ruby) -> Result<RModule, Error> {
    ruby.class_object()
        .const_get::<_, RModule>("Ferro")?
        .const_get("Time")
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). time keeps no
    // mutable state of its own; its system calls, `localtime_r` and
    // `SystemTimeToTzSpecificLocalTime`, are thread-safe (time 0.3.55
    // src/sys/local_offset_at/unix.rs:18-20, windows.rs:95), and `tzset`
    // runs only where time proves it sound (src/sys/refresh_tz/unix.rs).
    // Every wrapped type holds a `Copy` value no method changes, made
    // frozen, so sharing it is sound. Every other value a function touches
    // is an argument, which Ruby guarantees is the calling Ractor's own or
    // shareable (extension.rdoc:2260-2261). `rb_ext_ractor_safe` takes a
    // plain flag, called from `Init_` as extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let time = ruby.define_module("Ferro")?.define_module("Time")?;
    let native = time.define_module("Native")?;
    values::define(ruby, time)?;
    calendar::define(native)?;
    duration::define(native)?;
    offset::define(native)?;
    date::define(native)?;
    clock::define(native)?;
    datetime::define(native)?;
    format::define(ruby, time, native)?;
    system_time::define(native)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{capture, Panic};

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
}
