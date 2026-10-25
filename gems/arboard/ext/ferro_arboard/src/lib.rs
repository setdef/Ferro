// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The native half of ferro-arboard: Ruby bindings for arboard 3.7.0.
//!
//! Ruby owns the public API (`lib/ferro/arboard`). This crate defines
//! `Ferro::Arboard::Clipboard`, its constructor, and one private method per
//! terminal operation of arboard's `Get`, `Set`, and `Clear` builders. Each
//! private method takes the settings the Ruby builder collected, rebuilds
//! arboard's builder, and completes it (plan 001, decision 1).
//!
//! Two rules hold for every method:
//!
//! - An `arboard::Error` raises the matching `Ferro::Arboard::Error`
//!   subclass with the crate's `Display` text.
//! - A panic never reaches magnus, which would turn it into Ruby's
//!   uncatchable `fatal` (magnus 0.9.3 `src/error.rs:292-296`). Every call
//!   into arboard runs under `catch_unwind` and raises
//!   `Ferro::Arboard::Error` instead (plan 001, decision 5).

mod gvl;

use std::any::Any;
use std::borrow::Cow;
use std::panic::{self, AssertUnwindSafe};
use std::path::PathBuf;
use std::sync::{Mutex, MutexGuard, PoisonError, TryLockError};

use magnus::{
    function, method, prelude::*, Error, ExceptionClass, RArray, RModule, RString, Ruby, Symbol,
    Value,
};

/// The Ruby `Ferro::Arboard::Clipboard`: one arboard clipboard.
///
/// arboard's methods take `&mut self`, and a Ruby object may be reached
/// from several threads, so the clipboard sits behind a `Mutex`.
/// `arboard::Clipboard` is `Send` and `Sync` (arboard `src/lib.rs:510-516`),
/// so a frozen instance may be shared between Ractors (plan 001,
/// decision 13).
///
/// Ruby frees it during a GC sweep, which drops arboard's clipboard there.
/// On X11, dropping the last one hands the contents to the clipboard
/// manager, waiting up to 100 ms (arboard `src/platform/linux/x11.rs:790`),
/// and joins the server thread (`x11.rs:1105-1135`), all with the GVL held,
/// since a free function cannot release it.
#[magnus::wrap(
    class = "Ferro::Arboard::Clipboard",
    free_immediately,
    size,
    frozen_shareable
)]
struct Clipboard(Mutex<arboard::Clipboard>);

/// Why a call into arboard failed.
#[derive(Debug)]
enum Failure {
    /// arboard returned an error.
    Arboard(arboard::Error),
    /// arboard panicked, with this message.
    Panic(String),
}

/// Runs `operation`, catching a panic as `Failure::Panic`.
fn capture<T>(operation: impl FnOnce() -> Result<T, arboard::Error>) -> Result<T, Failure> {
    match panic::catch_unwind(AssertUnwindSafe(operation)) {
        Ok(result) => result.map_err(Failure::Arboard),
        Err(payload) => Err(Failure::Panic(panic_message(payload.as_ref()))),
    }
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

/// The Ruby exception for `failure`.
fn raise(ruby: &Ruby, failure: &Failure) -> Error {
    exception(ruby, failure).unwrap_or_else(|lookup| lookup)
}

/// The Ruby class a failure raises, as a name under `Ferro::Arboard::Error`
/// (`None` for the base class), and the argument its constructor takes.
///
/// Unit variants get the crate's `Display` text as their message.
/// `Unknown` gets its description, and its Ruby class formats the message
/// as arboard does (`src/common.rs:62`). `Error` is `#[non_exhaustive]`
/// (`src/common.rs:19`), so a variant a later arboard adds raises the base
/// class with its `Display` text; arboard 3.7.0 has no such variant, so the
/// fallback arm cannot be reached or tested until one exists. A panic
/// raises the base class too, since arboard never returned it.
fn class_and_message(failure: &Failure) -> (Option<&'static str>, String) {
    let error = match failure {
        Failure::Panic(message) => return (None, format!("arboard panicked: {message}")),
        Failure::Arboard(error) => error,
    };
    let variant = match error {
        arboard::Error::ContentNotAvailable => "ContentNotAvailable",
        arboard::Error::ClipboardNotSupported => "ClipboardNotSupported",
        arboard::Error::ClipboardOccupied => "ClipboardOccupied",
        arboard::Error::ConversionFailure => "ConversionFailure",
        arboard::Error::Unknown { description } => return (Some("Unknown"), description.clone()),
        _ => return (None, error.to_string()),
    };
    (Some(variant), error.to_string())
}

/// Builds the exception for `failure`, or returns the error that looking
/// up its class raised.
fn exception(ruby: &Ruby, failure: &Failure) -> Result<Error, Error> {
    let base: ExceptionClass = ruby
        .class_object()
        .const_get::<_, RModule>("Ferro")?
        .const_get::<_, RModule>("Arboard")?
        .const_get("Error")?;
    let (variant, message) = class_and_message(failure);
    let class = match variant {
        Some(name) => base.const_get(name)?,
        None => base,
    };
    Ok(Error::new(class, message))
}

/// The value of work that ran without the GVL, or the Ruby exception for
/// its failure. A panic outside `capture` (none is expected) still raises
/// `Ferro::Arboard::Error` rather than reaching magnus.
fn settle<T>(ruby: &Ruby, outcome: std::thread::Result<Result<T, Failure>>) -> Result<T, Error> {
    outcome
        .unwrap_or_else(|payload| Err(Failure::Panic(panic_message(payload.as_ref()))))
        .map_err(|failure| raise(ruby, &failure))
}

/// The clipboard's lock if it is free, recovering a poisoned one.
fn try_lock<C>(mutex: &Mutex<C>) -> Option<MutexGuard<'_, C>> {
    match mutex.try_lock() {
        Ok(guard) => Some(guard),
        Err(TryLockError::Poisoned(poisoned)) => Some(poisoned.into_inner()),
        Err(TryLockError::WouldBlock) => None,
    }
}

/// The clipboard's lock, for work running under `gvl::without_gvl`. With
/// the GVL released it waits for the lock. On the rare fallback that runs
/// the work with the GVL held, waiting could stall every Ruby thread for
/// as long as another thread's `wait` lasts, so a lock in use reports
/// arboard's `ClipboardOccupied` instead: the clipboard "is held by
/// another party", here another thread of this program, as arboard
/// describes it (`src/common.rs:33-42`).
fn lock_for<C>(mutex: &Mutex<C>, gvl: gvl::Gvl) -> Result<MutexGuard<'_, C>, Failure> {
    match gvl {
        gvl::Gvl::Released => Ok(mutex.lock().unwrap_or_else(PoisonError::into_inner)),
        gvl::Gvl::Held => {
            try_lock(mutex).ok_or(Failure::Arboard(arboard::Error::ClipboardOccupied))
        }
    }
}

/// Whether arboard can draw an RGBA buffer of `len` bytes as a `width` by
/// `height` image: both dimensions non-zero and exactly four bytes per
/// pixel (plan 001, decision 4).
///
/// This function and its three tests come from Tokra's `tokra_clipboard`
/// binding (AGPL-3.0-or-later). Their author, Kerrick Long, relicensed them
/// to MIT OR Apache-2.0 for Ferro.
const fn is_drawable_rgba(len: usize, width: usize, height: usize) -> bool {
    width != 0 && height != 0 && len == width.saturating_mul(height).saturating_mul(4)
}

/// The settings of a Ruby `Set`, as `Set#options` lists them: the Linux
/// selection, the Linux wait (`nil`, `:forever`, `:once`, or the seconds
/// left until a deadline), and the three history exclusions.
type SetArgs = (Option<Symbol>, Value, bool, bool, bool);

/// The `ArgumentError` for a setting this platform's arboard lacks. The
/// Ruby builders define such settings only where they exist, so this is
/// reachable only by calling the private methods directly.
fn unavailable(ruby: &Ruby, setting: &str) -> Error {
    Error::new(
        ruby.exception_arg_error(),
        format!("{setting} is not available on this platform"),
    )
}

/// The point `remaining` seconds after `now`, as `SetExtLinux::wait_until`
/// takes it (plan 001, decision 6). A negative count is a deadline already
/// past. A NaN or infinite count, or one past the clock's range, fails with
/// the message Rust gives for it (core `Duration::try_from_secs_f64`, std
/// `Instant + Duration`).
#[cfg(any(
    test,
    all(
        unix,
        not(any(target_os = "macos", target_os = "android", target_os = "emscripten"))
    )
))]
fn deadline(now: std::time::Instant, remaining: f64) -> Result<std::time::Instant, String> {
    let remaining = if remaining < 0.0 { 0.0 } else { remaining };
    let duration =
        std::time::Duration::try_from_secs_f64(remaining).map_err(|error| error.to_string())?;
    now.checked_add(duration)
        .ok_or_else(|| "overflow when adding duration to instant".to_owned())
}

/// Linux and the other Unixes arboard serves with X11 or Wayland
/// (arboard `src/lib.rs:24-28`): selections, waiting, and the KDE history
/// hint.
#[cfg(all(
    unix,
    not(any(target_os = "macos", target_os = "android", target_os = "emscripten"))
))]
mod platform {
    use super::{deadline, unavailable, Error, Ruby, SetArgs, Symbol, Value};
    use arboard::{ClearExtLinux, GetExtLinux, LinuxClipboardKind, SetExtLinux};
    use magnus::value::ReprValue;
    use magnus::TryConvert;

    pub const NAME: &str = "linux";

    /// Reading asks the owning program for the data and polls for up to four
    /// seconds (arboard `src/platform/linux/x11.rs:101`, `:371-378`); on
    /// Wayland, wl-clipboard-rs reads it from a pipe the owner writes.
    pub const BLOCKS_ON_READS: bool = true;

    pub struct GetOptions(Option<LinuxClipboardKind>);

    pub struct SetOptions {
        selection: Option<LinuxClipboardKind>,
        wait: Wait,
        exclude_from_history: bool,
    }

    enum Wait {
        None,
        Forever,
        Once,
        Until(std::time::Instant),
    }

    fn kind(ruby: &Ruby, selection: Symbol) -> Result<LinuxClipboardKind, Error> {
        match selection.name()?.as_ref() {
            "Clipboard" => Ok(LinuxClipboardKind::Clipboard),
            "Primary" => Ok(LinuxClipboardKind::Primary),
            "Secondary" => Ok(LinuxClipboardKind::Secondary),
            other => Err(Error::new(
                ruby.exception_arg_error(),
                format!("unknown LinuxClipboardKind {other}"),
            )),
        }
    }

    pub fn get_options(ruby: &Ruby, selection: Option<Symbol>) -> Result<GetOptions, Error> {
        Ok(GetOptions(
            selection.map(|name| kind(ruby, name)).transpose()?,
        ))
    }

    fn wait(ruby: &Ruby, value: Value) -> Result<Wait, Error> {
        if value.is_nil() {
            return Ok(Wait::None);
        }
        if let Some(symbol) = Symbol::from_value(value) {
            return match symbol.name()?.as_ref() {
                "forever" => Ok(Wait::Forever),
                "once" => Ok(Wait::Once),
                other => Err(Error::new(
                    ruby.exception_arg_error(),
                    format!("unknown wait {other}"),
                )),
            };
        }
        let remaining = f64::try_convert(value)?;
        deadline(std::time::Instant::now(), remaining)
            .map(Wait::Until)
            .map_err(|message| Error::new(ruby.exception_range_error(), message))
    }

    pub fn set_options(ruby: &Ruby, args: SetArgs) -> Result<SetOptions, Error> {
        let (selection, wait_value, exclude_from_history, monitoring, cloud) = args;
        if monitoring {
            return Err(unavailable(ruby, "exclude_from_monitoring"));
        }
        if cloud {
            return Err(unavailable(ruby, "exclude_from_cloud"));
        }
        Ok(SetOptions {
            selection: selection.map(|name| kind(ruby, name)).transpose()?,
            wait: wait(ruby, wait_value)?,
            exclude_from_history,
        })
    }

    impl GetOptions {
        pub fn get(self, clipboard: &mut arboard::Clipboard) -> arboard::Get<'_> {
            let get = clipboard.get();
            match self.0 {
                Some(selection) => get.clipboard(selection),
                None => get,
            }
        }

        pub fn clear(self, clipboard: &mut arboard::Clipboard) -> Result<(), arboard::Error> {
            match self.0 {
                Some(selection) => clipboard.clear_with().clipboard(selection),
                None => clipboard.clear_with().default(),
            }
        }
    }

    impl SetOptions {
        /// Whether the write waits for another program: `wait`, `wait_until`,
        /// and `wait_once` (arboard `src/platform/linux/x11.rs:281-296`;
        /// `wayland.rs:63-68`).
        pub const fn waits(&self) -> bool {
            !matches!(self.wait, Wait::None)
        }

        pub fn set(self, clipboard: &mut arboard::Clipboard) -> arboard::Set<'_> {
            let mut set = clipboard.set();
            if let Some(selection) = self.selection {
                set = set.clipboard(selection);
            }
            set = match self.wait {
                Wait::None => set,
                Wait::Forever => set.wait(),
                Wait::Once => set.wait_once(),
                Wait::Until(deadline) => set.wait_until(deadline),
            };
            if self.exclude_from_history {
                set = set.exclude_from_history();
            }
            set
        }
    }
}

/// macOS (arboard `src/lib.rs:33-34`): the history exclusion only.
#[cfg(target_os = "macos")]
mod platform {
    use super::{unavailable, Error, Ruby, SetArgs, Symbol};
    use arboard::SetExtApple;
    use magnus::value::ReprValue;

    pub const NAME: &str = "macos";

    /// arboard's `NSPasteboard` reads have no wait or timeout of their own
    /// (arboard `src/platform/osx.rs:135-153`, `:224-249`). An app that
    /// promises its data lazily can still make one wait; that case is
    /// unmeasured and keeps the GVL.
    pub const BLOCKS_ON_READS: bool = false;

    pub struct GetOptions;

    pub struct SetOptions {
        exclude_from_history: bool,
    }

    pub fn get_options(ruby: &Ruby, selection: Option<Symbol>) -> Result<GetOptions, Error> {
        if selection.is_some() {
            return Err(unavailable(ruby, "clipboard"));
        }
        Ok(GetOptions)
    }

    pub fn set_options(ruby: &Ruby, args: SetArgs) -> Result<SetOptions, Error> {
        let (selection, wait, exclude_from_history, monitoring, cloud) = args;
        if selection.is_some() {
            return Err(unavailable(ruby, "clipboard"));
        }
        if !wait.is_nil() {
            return Err(unavailable(ruby, "wait"));
        }
        if monitoring {
            return Err(unavailable(ruby, "exclude_from_monitoring"));
        }
        if cloud {
            return Err(unavailable(ruby, "exclude_from_cloud"));
        }
        Ok(SetOptions {
            exclude_from_history,
        })
    }

    impl GetOptions {
        // A Get here carries no settings, so it builds arboard's default.
        pub fn get(self, clipboard: &mut arboard::Clipboard) -> arboard::Get<'_> {
            let Self = self;
            clipboard.get()
        }

        pub fn clear(self, clipboard: &mut arboard::Clipboard) -> Result<(), arboard::Error> {
            let Self = self;
            clipboard.clear_with().default()
        }
    }

    impl SetOptions {
        /// Writes here never wait for another program.
        pub const fn waits(&self) -> bool {
            let _ = self;
            false
        }

        pub fn set(self, clipboard: &mut arboard::Clipboard) -> arboard::Set<'_> {
            let set = clipboard.set();
            if self.exclude_from_history {
                set.exclude_from_history()
            } else {
                set
            }
        }
    }
}

/// Windows (arboard `src/lib.rs:30-31`): the three history exclusions.
#[cfg(windows)]
mod platform {
    use super::{unavailable, Error, Ruby, SetArgs, Symbol};
    use arboard::SetExtWindows;
    use magnus::value::ReprValue;

    pub const NAME: &str = "windows";

    /// Opening the clipboard retries five times, five milliseconds apart
    /// (arboard `src/platform/windows.rs:533-560`), too short to be worth
    /// releasing the GVL.
    pub const BLOCKS_ON_READS: bool = false;

    pub struct GetOptions;

    pub struct SetOptions {
        exclude_from_history: bool,
        exclude_from_monitoring: bool,
        exclude_from_cloud: bool,
    }

    pub fn get_options(ruby: &Ruby, selection: Option<Symbol>) -> Result<GetOptions, Error> {
        if selection.is_some() {
            return Err(unavailable(ruby, "clipboard"));
        }
        Ok(GetOptions)
    }

    pub fn set_options(ruby: &Ruby, args: SetArgs) -> Result<SetOptions, Error> {
        let (selection, wait, exclude_from_history, exclude_from_monitoring, exclude_from_cloud) =
            args;
        if selection.is_some() {
            return Err(unavailable(ruby, "clipboard"));
        }
        if !wait.is_nil() {
            return Err(unavailable(ruby, "wait"));
        }
        Ok(SetOptions {
            exclude_from_history,
            exclude_from_monitoring,
            exclude_from_cloud,
        })
    }

    impl GetOptions {
        // A Get here carries no settings, so it builds arboard's default.
        pub fn get(self, clipboard: &mut arboard::Clipboard) -> arboard::Get<'_> {
            let Self = self;
            clipboard.get()
        }

        pub fn clear(self, clipboard: &mut arboard::Clipboard) -> Result<(), arboard::Error> {
            let Self = self;
            clipboard.clear_with().default()
        }
    }

    impl SetOptions {
        /// Writes here never wait for another program.
        pub const fn waits(&self) -> bool {
            let _ = self;
            false
        }

        pub fn set(self, clipboard: &mut arboard::Clipboard) -> arboard::Set<'_> {
            let mut set = clipboard.set();
            if self.exclude_from_monitoring {
                set = set.exclude_from_monitoring();
            }
            if self.exclude_from_cloud {
                set = set.exclude_from_cloud();
            }
            if self.exclude_from_history {
                set = set.exclude_from_history();
            }
            set
        }
    }
}

/// A path from Ruby, byte for byte, as Unix allows.
#[cfg(unix)]
fn path_from_ruby(path: Value) -> Result<PathBuf, Error> {
    use std::os::unix::ffi::OsStringExt;
    let bytes = RString::try_convert(path)?.to_bytes().to_vec();
    Ok(PathBuf::from(std::ffi::OsString::from_vec(bytes)))
}

/// A path from Ruby, which Windows takes as UTF-8.
#[cfg(not(unix))]
fn path_from_ruby(path: Value) -> Result<PathBuf, Error> {
    String::try_convert(path).map(PathBuf::from)
}

impl Clipboard {
    /// `Clipboard.new`: arboard's `Clipboard::new` (`src/lib.rs:75-83`).
    fn new(ruby: &Ruby) -> Result<Self, Error> {
        settle(ruby, Ok(capture(arboard::Clipboard::new)))
            .map(|clipboard| Self(Mutex::new(clipboard)))
    }

    /// Runs `operation` on the clipboard, under its lock and `capture`.
    ///
    /// A `blocking` operation (`blocks_on_reads`, `SetOptions::waits`) runs
    /// with the GVL released (`gvl::without_gvl`), and takes the lock only
    /// once the GVL is released, so a thread waiting for it never holds up
    /// the rest of Ruby. Any other operation keeps the GVL, since releasing
    /// and retaking it costs a time slice per competing thread (gvl.rs), but
    /// only if the lock is free: when another thread holds it, perhaps
    /// through a long wait, this one waits for it with the GVL released.
    ///
    /// The panic is caught inside the lock, so it never poisons it. A lock
    /// poisoned anyway is still used: arboard's clipboard holds no
    /// invariant a panic could break. `operation` sees only Rust values;
    /// callers convert Ruby arguments before and results after.
    fn with<T>(
        &self,
        ruby: &Ruby,
        blocking: bool,
        operation: impl FnOnce(&mut arboard::Clipboard) -> Result<T, arboard::Error>,
    ) -> Result<T, Error> {
        if !blocking {
            if let Some(mut clipboard) = try_lock(&self.0) {
                return settle(ruby, Ok(capture(|| operation(&mut clipboard))));
            }
        }
        let outcome = gvl::without_gvl(ruby, |gvl| {
            let mut clipboard = lock_for(&self.0, gvl)?;
            capture(|| operation(&mut clipboard))
        })?;
        settle(ruby, outcome)
    }

    /// `Get#text`: arboard's `Get::text` (`src/lib.rs:188-191`).
    fn native_get_text(
        ruby: &Ruby,
        rb_self: &Self,
        selection: Option<Symbol>,
    ) -> Result<String, Error> {
        let options = platform::get_options(ruby, selection)?;
        rb_self.with(ruby, platform::BLOCKS_ON_READS, |clipboard| {
            options.get(clipboard).text()
        })
    }

    /// `Get#html`: arboard's `Get::html` (`src/lib.rs:204-207`).
    fn native_get_html(
        ruby: &Ruby,
        rb_self: &Self,
        selection: Option<Symbol>,
    ) -> Result<String, Error> {
        let options = platform::get_options(ruby, selection)?;
        rb_self.with(ruby, platform::BLOCKS_ON_READS, |clipboard| {
            options.get(clipboard).html()
        })
    }

    /// `Get#image`: arboard's `Get::image` (`src/lib.rs:193-202`), as
    /// `[width, height, bytes]` for Ruby to wrap in `ImageData`.
    fn native_get_image(
        ruby: &Ruby,
        rb_self: &Self,
        selection: Option<Symbol>,
    ) -> Result<(usize, usize, RString), Error> {
        let options = platform::get_options(ruby, selection)?;
        let image = rb_self.with(ruby, platform::BLOCKS_ON_READS, |clipboard| {
            options.get(clipboard).image()
        })?;
        Ok((image.width, image.height, ruby.str_from_slice(&image.bytes)))
    }

    /// `Get#file_list`: arboard's `Get::file_list` (`src/lib.rs:209-212`).
    /// The paths arboard returns come from UTF-8 on macOS and Linux, so
    /// the conversion is exact there.
    fn native_get_file_list(
        ruby: &Ruby,
        rb_self: &Self,
        selection: Option<Symbol>,
    ) -> Result<Vec<String>, Error> {
        let options = platform::get_options(ruby, selection)?;
        let paths = rb_self.with(ruby, platform::BLOCKS_ON_READS, |clipboard| {
            options.get(clipboard).file_list()
        })?;
        Ok(paths
            .iter()
            .map(|path| path.to_string_lossy().into_owned())
            .collect())
    }

    /// `Clear#default`, or `ClearExtLinux#clipboard` with a selection
    /// (`src/lib.rs:272-277`, `src/platform/linux/mod.rs:432-459`).
    fn native_clear(ruby: &Ruby, rb_self: &Self, selection: Option<Symbol>) -> Result<(), Error> {
        let options = platform::get_options(ruby, selection)?;
        rb_self.with(ruby, false, |clipboard| options.clear(clipboard))
    }

    /// `Set#text`: arboard's `Set::text` (`src/lib.rs:227-232`).
    fn native_set_text(
        ruby: &Ruby,
        rb_self: &Self,
        text: String,
        args: SetArgs,
    ) -> Result<(), Error> {
        let options = platform::set_options(ruby, args)?;
        rb_self.with(ruby, options.waits(), |clipboard| {
            options.set(clipboard).text(text)
        })
    }

    /// `Set#html`: arboard's `Set::html` (`src/lib.rs:234-246`).
    fn native_set_html(
        ruby: &Ruby,
        rb_self: &Self,
        html: String,
        alt_text: Option<String>,
        args: SetArgs,
    ) -> Result<(), Error> {
        let options = platform::set_options(ruby, args)?;
        rb_self.with(ruby, options.waits(), |clipboard| {
            options.set(clipboard).html(html, alt_text)
        })
    }

    /// `Set#image`: arboard's `Set::image` (`src/lib.rs:248-258`), after
    /// refusing a shape arboard would panic on (plan 001, decision 4).
    fn native_set_image(
        ruby: &Ruby,
        rb_self: &Self,
        width: usize,
        height: usize,
        bytes: RString,
        args: SetArgs,
    ) -> Result<(), Error> {
        let options = platform::set_options(ruby, args)?;
        let bytes = bytes.to_bytes();
        if !is_drawable_rgba(bytes.len(), width, height) {
            return Err(raise(
                ruby,
                &Failure::Arboard(arboard::Error::ConversionFailure),
            ));
        }
        rb_self.with(ruby, options.waits(), |clipboard| {
            options.set(clipboard).image(arboard::ImageData {
                width,
                height,
                bytes: Cow::Borrowed(&bytes),
            })
        })
    }

    /// `Set#file_list`: arboard's `Set::file_list` (`src/lib.rs:260-263`).
    fn native_set_file_list(
        ruby: &Ruby,
        rb_self: &Self,
        paths: RArray,
        args: SetArgs,
    ) -> Result<(), Error> {
        let options = platform::set_options(ruby, args)?;
        let paths = paths
            .into_iter()
            .map(path_from_ruby)
            .collect::<Result<Vec<_>, _>>()?;
        rb_self.with(ruby, options.waits(), |clipboard| {
            options.set(clipboard).file_list(&paths)
        })
    }
}

/// How many calls have run with the GVL released (`gvl::RELEASES`), for
/// the tests that check which calls release it.
fn native_gvl_releases(_clipboard: &Clipboard) -> usize {
    gvl::RELEASES.load(std::sync::atomic::Ordering::Relaxed)
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // SAFETY: Ruby asks a Ractor-safe extension to share no unshareable
    // object between Ractors and to be thread-safe, along with the libraries
    // it calls (doc/extension.rdoc:2207-2286 at Ruby v4.0.1). This crate
    // keeps no Ruby value in a static except magnus's class lookups, and
    // classes are shareable (extension.rdoc:2239-2240). Its one wrapped
    // type is `Mutex<arboard::Clipboard>`, and arboard asserts its
    // `Clipboard` is `Send + Sync` (arboard src/lib.rs:510-516).
    // extension.rdoc:2278-2280 says a frozen-shareable object's wrapped data
    // must not be mutated. This crate reads that rule as a guard against
    // unsynchronized mutation and deliberately mutates a frozen clipboard
    // under its Mutex, which `Send + Sync` makes sound; that is a reading of
    // the rule, not what it literally says. Every other value a method
    // touches is an argument or the
    // receiver, which Ruby guarantees are the calling Ractor's own or
    // shareable (extension.rdoc:2260-2261). `rb_ext_ractor_safe` takes a
    // plain flag, called from `Init_` as extension.rdoc:2218-2220 asks.
    #[allow(unsafe_code)]
    unsafe {
        rb_sys::rb_ext_ractor_safe(true);
    }

    let arboard = ruby.define_module("Ferro")?.define_module("Arboard")?;
    arboard.const_set("PLATFORM", ruby.to_symbol(platform::NAME))?;

    let class = arboard.define_class("Clipboard", ruby.class_object())?;
    class.undef_default_alloc_func();
    // Resolve magnus's lazy class lookup now, on the main Ractor. It is a
    // OnceLock: two Ractors wrapping their first clipboard at once would
    // race to fill it, and the loser would block in the lock, holding its
    // Ractor's GVL, while the winner allocates and may wait at a GC barrier
    // for that same Ractor. Filled here, it never blocks again.
    let _ = <Clipboard as magnus::TypedData>::class(ruby);
    class.define_singleton_method("new", function!(Clipboard::new, 0))?;
    class.define_private_method("native_get_text", method!(Clipboard::native_get_text, 1))?;
    class.define_private_method("native_get_html", method!(Clipboard::native_get_html, 1))?;
    class.define_private_method("native_get_image", method!(Clipboard::native_get_image, 1))?;
    class.define_private_method(
        "native_get_file_list",
        method!(Clipboard::native_get_file_list, 1),
    )?;
    class.define_private_method("native_clear", method!(Clipboard::native_clear, 1))?;
    class.define_private_method("native_set_text", method!(Clipboard::native_set_text, 2))?;
    class.define_private_method("native_set_html", method!(Clipboard::native_set_html, 3))?;
    class.define_private_method("native_set_image", method!(Clipboard::native_set_image, 4))?;
    class.define_private_method(
        "native_set_file_list",
        method!(Clipboard::native_set_file_list, 2),
    )?;
    class.define_private_method("native_gvl_releases", method!(native_gvl_releases, 0))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        capture, class_and_message, deadline, gvl::Gvl, is_drawable_rgba, lock_for, try_lock,
        Failure,
    };
    use std::sync::Mutex;
    use std::time::{Duration, Instant};

    // The three is_drawable_rgba tests come from Tokra, relicensed with the
    // function they test.
    #[test]
    fn accepts_four_bytes_per_pixel() {
        assert!(is_drawable_rgba(8, 2, 1));
        assert!(is_drawable_rgba(8, 1, 2));
        assert!(is_drawable_rgba(24, 3, 2));
    }

    #[test]
    fn rejects_zero_dimensions_and_empty_bytes() {
        assert!(!is_drawable_rgba(0, 0, 0));
        assert!(!is_drawable_rgba(0, 0, 5));
        assert!(!is_drawable_rgba(0, 5, 0));
        assert!(!is_drawable_rgba(4, 0, 1));
        assert!(!is_drawable_rgba(4, 1, 0));
        assert!(!is_drawable_rgba(0, 1, 1));
    }

    #[test]
    fn rejects_mismatched_byte_counts() {
        assert!(!is_drawable_rgba(7, 2, 1));
        assert!(!is_drawable_rgba(9, 2, 1));
        assert!(!is_drawable_rgba(4, usize::MAX, 2));
    }

    #[test]
    fn capture_passes_values_and_errors_through() {
        assert!(matches!(capture(|| Ok(7)), Ok(7)));
        assert!(matches!(
            capture::<()>(|| Err(arboard::Error::ClipboardOccupied)),
            Err(Failure::Arboard(arboard::Error::ClipboardOccupied))
        ));
    }

    #[test]
    fn capture_turns_panics_into_failures() {
        let literal = capture::<()>(|| panic!("boom"));
        assert!(matches!(literal, Err(Failure::Panic(message)) if message == "boom"));

        // A message built at run time is a String payload; literal arguments
        // would be folded into a &'static str.
        let built = capture::<()>(|| {
            panic!(
                "{} {}",
                std::hint::black_box("bad"),
                std::hint::black_box(7)
            )
        });
        assert!(matches!(built, Err(Failure::Panic(message)) if message == "bad 7"));

        let other = capture::<()>(|| std::panic::panic_any(7_u8));
        assert!(matches!(other, Err(Failure::Panic(message)) if message == "Box<dyn Any>"));
    }

    #[test]
    fn each_variant_raises_its_own_class_with_the_display_text() {
        for (error, name) in [
            (arboard::Error::ContentNotAvailable, "ContentNotAvailable"),
            (
                arboard::Error::ClipboardNotSupported,
                "ClipboardNotSupported",
            ),
            (arboard::Error::ClipboardOccupied, "ClipboardOccupied"),
            (arboard::Error::ConversionFailure, "ConversionFailure"),
        ] {
            let message = error.to_string();
            assert_eq!(
                class_and_message(&Failure::Arboard(error)),
                (Some(name), message)
            );
        }
    }

    #[test]
    fn unknown_raises_its_class_with_the_description() {
        let failure = Failure::Arboard(arboard::Error::Unknown {
            description: "pasteboard unavailable".to_owned(),
        });
        assert_eq!(
            class_and_message(&failure),
            (Some("Unknown"), "pasteboard unavailable".to_owned())
        );
    }

    #[test]
    fn a_panic_raises_the_base_class_with_its_message() {
        assert_eq!(
            class_and_message(&Failure::Panic("boom".to_owned())),
            (None, "arboard panicked: boom".to_owned())
        );
    }

    #[test]
    fn a_lock_in_use_reports_clipboard_occupied_only_with_the_gvl_held() {
        let mutex = Mutex::new(5);
        let held = mutex.lock().expect("free");
        assert!(try_lock(&mutex).is_none());
        assert!(matches!(
            lock_for(&mutex, Gvl::Held),
            Err(Failure::Arboard(arboard::Error::ClipboardOccupied))
        ));
        drop(held);
        assert_eq!(
            lock_for(&mutex, Gvl::Held).map(|guard| *guard).ok(),
            Some(5)
        );
        assert_eq!(
            lock_for(&mutex, Gvl::Released).map(|guard| *guard).ok(),
            Some(5)
        );
    }

    #[test]
    fn a_poisoned_lock_is_recovered() {
        let mutex = Mutex::new(5);
        let _ = std::panic::catch_unwind(|| {
            let _guard = mutex.lock().expect("free");
            panic!("poison it");
        });
        assert!(mutex.is_poisoned());
        assert_eq!(try_lock(&mutex).map(|guard| *guard), Some(5));
        assert_eq!(
            lock_for(&mutex, Gvl::Released).map(|guard| *guard).ok(),
            Some(5)
        );
    }

    #[test]
    fn deadline_adds_the_remaining_seconds() {
        let now = Instant::now();
        assert_eq!(deadline(now, 1.5), Ok(now + Duration::from_millis(1500)));
        assert_eq!(deadline(now, 0.0), Ok(now));
    }

    #[test]
    fn deadline_in_the_past_is_now() {
        let now = Instant::now();
        assert_eq!(deadline(now, -3.0), Ok(now));
    }

    #[test]
    fn deadline_refuses_what_an_instant_cannot_hold() {
        let now = Instant::now();
        let too_big = "cannot convert float seconds to Duration: value is either too big or NaN";
        assert_eq!(deadline(now, f64::NAN), Err(too_big.to_owned()));
        assert_eq!(deadline(now, f64::INFINITY), Err(too_big.to_owned()));
        // How far an Instant reaches is the platform's: Unix keeps signed
        // seconds, so 1e19 overflows there, while Windows keeps a Duration,
        // which holds it. Either way the deadline is what Instant itself
        // gives, with std's own overflow message.
        let huge = 1.0e19;
        let expected = now
            .checked_add(Duration::from_secs_f64(huge))
            .ok_or_else(|| "overflow when adding duration to instant".to_owned());
        assert_eq!(deadline(now, huge), expected);
        #[cfg(unix)]
        assert_eq!(
            deadline(now, huge),
            Err("overflow when adding duration to instant".to_owned())
        );
    }

    /// The Ruby error classes copy these messages (`lib/ferro/arboard/error.rb`);
    /// this pins them to the crate, so an arboard upgrade that rewords one
    /// fails here.
    #[test]
    fn display_text_matches_the_ruby_defaults() {
        assert_eq!(
            arboard::Error::ContentNotAvailable.to_string(),
            "The clipboard contents were not available in the requested format or the clipboard is empty."
        );
        assert_eq!(
            arboard::Error::ClipboardNotSupported.to_string(),
            "The selected clipboard is not supported with the current system configuration."
        );
        assert_eq!(
            arboard::Error::ClipboardOccupied.to_string(),
            "The native clipboard is not accessible due to being held by another party."
        );
        assert_eq!(
            arboard::Error::ConversionFailure.to_string(),
            "The image or the text that was about the be transferred to/from the clipboard could not be converted to the appropriate format."
        );
        assert_eq!(
            arboard::Error::Unknown {
                description: "x".to_owned()
            }
            .to_string(),
            "Unknown error while interacting with the clipboard: x"
        );
    }
}
