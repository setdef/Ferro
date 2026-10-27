// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The native half of ferro-idna: Ruby bindings for idna 1.1.0.
//!
//! Ruby owns the public API (`lib/ferro/idna`). The functions here live on
//! `Ferro::Idna::Native`, a private module, beside `Native::AsciiDenyList`,
//! which holds one of idna's deny lists. Enum values cross as their
//! variant names, and a deprecated `Config` as its four flags.
//!
//! No panic reaches magnus, which would turn it into Ruby's uncatchable
//! `fatal` (magnus 0.9.3 `src/error.rs:292-296`): every call into idna
//! runs under `catch_unwind` and raises `Ferro::Idna::Errors` instead, and
//! the inputs idna is known to panic on are refused first (plan 006,
//! decisions 7, 8, and 15).

mod callback;
mod deprecated;
mod uts46;

use std::any::Any;
use std::panic::{self, AssertUnwindSafe};

use magnus::{function, prelude::*, Error, ExceptionClass, RModule, Ruby, Value};

/// A panic inside idna, with its message.
#[derive(Debug, PartialEq, Eq)]
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

/// The message of the `Errors` a panic raises (plan 006, decision 3).
pub(crate) fn panicked(panic: &Panic) -> String {
    format!("idna panicked: {}", panic.0)
}

/// The class at `path` under `Ferro::Idna`, such as `Errors` or
/// `Uts46::ProcessingError::ValidityError`.
pub(crate) fn class(ruby: &Ruby, path: &str) -> Result<ExceptionClass, Error> {
    let root: Value = ruby
        .class_object()
        .const_get::<_, RModule>("Ferro")?
        .const_get("Idna")?;
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

/// `Errors`, idna's one error, with its `Display` text (`src/lib.rs:80-84`).
pub(crate) fn errors(ruby: &Ruby, error: &idna::Errors) -> Error {
    raise(ruby, "Errors", error.to_string())
}

/// Runs `operation` under `catch_unwind`, raising `Errors` for a panic.
pub(crate) fn guarded<T>(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<T, Error>,
) -> Result<T, Error> {
    capture(operation).unwrap_or_else(|panic| Err(raise(ruby, "Errors", panicked(&panic))))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). idna keeps no
    // mutable state: `Uts46::new` reads ICU4X's compiled data, immutable
    // statics (idna 1.1.0 src/uts46.rs:500-508). The one wrapped type,
    // `Native::AsciiDenyList`, holds a `Copy` value no method changes, so
    // sharing it frozen is sound. Every other value a function touches is
    // an argument, which Ruby guarantees is the calling Ractor's own or
    // shareable (extension.rdoc:2260-2261). `rb_ext_ractor_safe` takes a
    // plain flag, called from `Init_` as extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let idna = ruby.define_module("Ferro")?.define_module("Idna")?;
    let native = idna.define_module("Native")?;

    // Ruby never allocates a deny list: the functions below make one, so
    // idna's panicking assertions are refused first (plan 006, decision 7).
    native
        .define_class("AsciiDenyList", ruby.class_object())?
        .undef_default_alloc_func();
    native.define_singleton_method(
        "ascii_deny_list_new",
        function!(uts46::ascii_deny_list_new, 2),
    )?;
    native.define_singleton_method(
        "ascii_deny_list_constant",
        function!(uts46::ascii_deny_list_constant, 1),
    )?;
    native.define_singleton_method(
        "ascii_deny_list_eq",
        function!(uts46::ascii_deny_list_eq, 2),
    )?;

    native.define_singleton_method(
        "domain_to_ascii_cow",
        function!(uts46::domain_to_ascii_cow, 2),
    )?;
    native.define_singleton_method(
        "domain_to_ascii_from_cow",
        function!(uts46::domain_to_ascii_from_cow, 2),
    )?;
    native.define_singleton_method("domain_to_ascii", function!(uts46::domain_to_ascii, 1))?;
    native.define_singleton_method(
        "domain_to_ascii_strict",
        function!(uts46::domain_to_ascii_strict, 1),
    )?;
    native.define_singleton_method("domain_to_unicode", function!(uts46::domain_to_unicode, 1))?;

    native.define_singleton_method(
        "punycode_decode_to_string",
        function!(uts46::punycode_decode_to_string, 1),
    )?;
    native.define_singleton_method("punycode_decode", function!(uts46::punycode_decode, 1))?;
    native.define_singleton_method(
        "punycode_encode_str",
        function!(uts46::punycode_encode_str, 1),
    )?;
    native.define_singleton_method("punycode_encode", function!(uts46::punycode_encode, 1))?;

    native.define_singleton_method("verify_dns_length", function!(uts46::verify_dns_length, 2))?;
    native.define_singleton_method("uts46_to_ascii", function!(uts46::uts46_to_ascii, 4))?;
    native.define_singleton_method("uts46_to_unicode", function!(uts46::uts46_to_unicode, 3))?;
    native.define_singleton_method(
        "uts46_to_user_interface",
        function!(uts46::uts46_to_user_interface, 4),
    )?;
    native.define_singleton_method("uts46_process", function!(uts46::uts46_process, 6))?;

    native.define_singleton_method(
        "config_use_idna_2008_rules",
        function!(deprecated::config_use_idna_2008_rules, 1),
    )?;
    native.define_singleton_method("config_to_ascii", function!(deprecated::config_to_ascii, 2))?;
    native.define_singleton_method(
        "config_to_unicode",
        function!(deprecated::config_to_unicode, 2),
    )?;
    native.define_singleton_method("idna_to_ascii", function!(deprecated::idna_to_ascii, 3))?;
    native.define_singleton_method("idna_to_unicode", function!(deprecated::idna_to_unicode, 3))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{capture, panicked, Panic};

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
    fn a_panic_reads_as_idnas() {
        assert_eq!(panicked(&Panic("boom".to_owned())), "idna panicked: boom");
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Display text of idna 1.1.0's Errors
    //   (src/lib.rs:63-84), which Ruby's Errors copies

    #[test]
    fn errors_displays_its_debug_text() {
        assert_eq!(idna::Errors::default().to_string(), "Errors");
    }

    // SPDX-SnippetEnd
}
