// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! The native half of ferro-global-hotkey: Ruby bindings for
//! global-hotkey 0.9.0.
//!
//! Ruby owns the public API (`lib/ferro/global_hotkey`). The functions here
//! live on `Ferro::GlobalHotkey::Native`, a private module, beside
//! `Native::Manager`, which owns global-hotkey's manager. A hotkey crosses
//! as its three public fields (`hotkey.rs`), and a call that can fail
//! returns `[:ok, value]` or `[:error, path, message, hotkey]` for the Ruby
//! side to raise (`error.rs`).
//!
//! Two rules hold for every function:
//!
//! - A panic never reaches magnus, which would turn it into Ruby's
//!   uncatchable `fatal` (magnus 0.9.3 `src/error.rs:292-296`). Every call
//!   into global-hotkey runs under `catch_unwind` and fails with
//!   `Ferro::GlobalHotkey::Error` instead (plan 004, decision 14).
//! - A wait for an event runs with the GVL released and can be
//!   interrupted (`gvl.rs`).

mod error;
mod events;
mod gvl;
mod hotkey;
mod manager;
mod owned;

use std::any::Any;
use std::panic::{self, AssertUnwindSafe};

use magnus::{function, prelude::*, Error, Ruby};

/// A panic inside global-hotkey, with its message.
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

/// The platform global-hotkey's `platform_impl` was built for
/// (`src/platform_impl/mod.rs:5-33`).
#[cfg(target_os = "macos")]
const PLATFORM: &str = "macos";
#[cfg(windows)]
const PLATFORM: &str = "windows";
#[cfg(not(any(target_os = "macos", windows)))]
const PLATFORM: &str = "linux";

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). Its statics are
    // global-hotkey's and its own crossbeam channels and an atomic flag,
    // all `Sync`. Its one wrapped type, `Native::Manager`, is never made
    // shareable, and global-hotkey's manager takes `&self` with its own
    // locks (macOS), a channel (Linux), or Win32 calls that fail off the
    // window's thread (Windows; see `manager.rs`). Every other value a
    // function touches is an argument, which Ruby guarantees is the calling
    // Ractor's own or shareable (extension.rdoc:2260-2261).
    // `rb_ext_ractor_safe` takes a plain flag, called from `Init_` as
    // extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let global_hotkey = ruby.define_module("Ferro")?.define_module("GlobalHotkey")?;
    global_hotkey.const_set("PLATFORM", ruby.to_symbol(PLATFORM))?;

    let native = global_hotkey.define_module("Native")?;
    // Ruby never allocates a manager: `manager_new` makes one, so a panic
    // in global-hotkey's `new` is caught (plan 004, decision 3).
    native
        .define_class("Manager", ruby.class_object())?
        .undef_default_alloc_func();
    native.define_singleton_method("manager_new", function!(manager::manager_new, 0))?;
    native.define_singleton_method("manager_register", function!(manager::manager_register, 2))?;
    native.define_singleton_method(
        "manager_unregister",
        function!(manager::manager_unregister, 2),
    )?;
    native.define_singleton_method(
        "manager_register_all",
        function!(manager::manager_register_all, 2),
    )?;
    native.define_singleton_method(
        "manager_unregister_all",
        function!(manager::manager_unregister_all, 2),
    )?;

    native.define_singleton_method("hotkey_new", function!(hotkey::hotkey_new, 2))?;
    native.define_singleton_method("hotkey_parse", function!(hotkey::hotkey_parse, 1))?;
    native.define_singleton_method("hotkey_matches", function!(hotkey::hotkey_matches, 3))?;
    native.define_singleton_method(
        "hotkey_into_string",
        function!(hotkey::hotkey_into_string, 1),
    )?;
    native.define_singleton_method("cmd_or_ctrl", function!(hotkey::cmd_or_ctrl, 0))?;
    native.define_singleton_method("code_from_str", function!(hotkey::code_from_str, 1))?;
    native.define_singleton_method("code_count", function!(hotkey::code_count, 0))?;
    native.define_singleton_method("modifier_flags", function!(hotkey::modifier_flags, 0))?;
    native.define_singleton_method("u32", function!(hotkey::u32, 1))?;
    native.define_singleton_method("modifiers_debug", function!(hotkey::modifiers_debug, 1))?;
    native.define_singleton_method(
        "modifiers_from_name",
        function!(hotkey::modifiers_from_name, 1),
    )?;

    native.define_singleton_method("receiver_try_recv", function!(events::receiver_try_recv, 0))?;
    native.define_singleton_method("receiver_recv", function!(events::receiver_recv, 1))?;
    native.define_singleton_method("receiver_len", function!(events::receiver_len, 0))?;
    native.define_singleton_method("receiver_is_empty", function!(events::receiver_is_empty, 0))?;
    native.define_singleton_method("receiver_is_full", function!(events::receiver_is_full, 0))?;
    native.define_singleton_method("receiver_capacity", function!(events::receiver_capacity, 0))?;
    native.define_singleton_method("set_event_handler", function!(events::set_event_handler, 1))?;
    native.define_singleton_method("handler_recv", function!(events::handler_recv, 0))?;
    native.define_singleton_method("handler_close", function!(events::handler_close, 0))?;
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
}
