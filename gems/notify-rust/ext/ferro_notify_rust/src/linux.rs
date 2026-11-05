// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! What notify-rust compiles for its XDG platforms, `all(unix,
//! not(target_os = "macos"))`, with the `z` (zbus) and `images` features:
//! the D-Bus handle, the image type, the hint and urgency setters, and the
//! module functions (plan 003, decisions 5 and 6).
//!
//! Showing and waiting poll notify-rust's own futures with the GVL
//! released and an unblocking function (`gvl::wait`), so an interrupt ends
//! the wait. The sync methods notify-rust offers do the same work through
//! `zbus::block_on` (notify-rust 4.18.2 `src/xdg/mod.rs:118-127`,
//! `:139-142`, `:219`, `:280-286`, `:414-416`), which nothing could
//! interrupt.

use std::future::Future;
use std::hash::{Hash, Hasher};
use std::pin::pin;
use std::sync::{Mutex, PoisonError};

use magnus::rb_sys::{AsRawValue, FromRawValue};
use magnus::{
    function, method, prelude::*, typed_data::Obj, Error, RArray, RModule, RString, Ruby, Symbol,
    TypedData, Value,
};
use notify_rust::{CloseReason, ImageError, NotificationResponse};

use crate::lock::{Lock, Owner, ReadGuard, Retired};
use crate::notification::{plain_set, try_set, Holds};
use crate::slot::Slot;
use crate::{capture, error, gvl, panic_of, path_from_ruby, settle, values};

/// The platform's name, as `Ferro::NotifyRust::PLATFORM` reports it.
pub const NAME: &str = "linux";

/// The Ruby `Ferro::NotifyRust::Image`: notify-rust's `Image`
/// (`src/image.rs:19-29`), frozen and shareable, since it is `Send`, `Sync`,
/// and never changes.
#[magnus::wrap(
    class = "Ferro::NotifyRust::Image",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct Image(notify_rust::Image);

impl Image {
    pub const fn new(image: notify_rust::Image) -> Self {
        Self(image)
    }

    pub const fn inner(&self) -> &notify_rust::Image {
        &self.0
    }

    /// `#==`: notify-rust's derived `PartialEq` (`src/image.rs:20`).
    fn equal(&self, other: Value) -> bool {
        <&Self>::try_convert(other).is_ok_and(|other| self.0 == other.0)
    }

    /// `#hash`: notify-rust's derived `Hash`, so equal images hash alike.
    fn hash(&self) -> i64 {
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        self.0.hash(&mut hasher);
        i64::from_ne_bytes(hasher.finish().to_ne_bytes())
    }

    /// `#debug`: notify-rust's derived `Debug` (`src/image.rs:20`).
    fn debug(&self) -> String {
        format!("{:?}", self.0)
    }
}

/// The `ImageError` subclass for `failure`, with notify-rust's text
/// (`src/image.rs:126-165`), keeping its `Debug` text.
fn image_error(ruby: &Ruby, failure: &ImageError) -> Error {
    let leaf = match failure {
        ImageError::TooBig => "TooBig",
        ImageError::WrongDataSize => "WrongDataSize",
        ImageError::CantOpen(_) => "CantOpen",
        ImageError::CantConvert => "CantConvert",
    };
    error::raise(
        ruby,
        &["ImageError", leaf],
        &[failure.to_string()],
        Some(format!("{failure:?}")),
    )
}

/// `Native.image_error_debug`: notify-rust's derived `Debug` text
/// (`src/image.rs:127`) for the variant `name` of an `ImageError` Ruby
/// code made. Only the variants that hold nothing can be built; `CantOpen`
/// holds the image crate's error, a value no Ruby value is.
fn image_error_debug(ruby: &Ruby, name: Symbol) -> Result<String, Error> {
    let failure = match name.name()?.as_ref() {
        "TooBig" => ImageError::TooBig,
        "WrongDataSize" => ImageError::WrongDataSize,
        "CantConvert" => ImageError::CantConvert,
        other => {
            return Err(Error::new(
                ruby.exception_type_error(),
                format!("{other} is not an ImageError that holds nothing"),
            ))
        }
    };
    Ok(format!("{failure:?}"))
}

/// An `Image` for Ruby, or `ImageError`.
fn image_result(
    ruby: &Ruby,
    made: Result<Result<notify_rust::Image, ImageError>, crate::Panic>,
) -> Result<Obj<Image>, Error> {
    match settle(ruby, made)? {
        Ok(image) => Ok(ruby.obj_wrap(Image::new(image))),
        Err(failure) => Err(image_error(ruby, &failure)),
    }
}

/// `Image.from_rgb` (`src/image.rs:60-65`).
fn from_rgb(ruby: &Ruby, width: i32, height: i32, data: RString) -> Result<Obj<Image>, Error> {
    let bytes = data.to_bytes().to_vec();
    image_result(
        ruby,
        capture(|| notify_rust::Image::from_rgb(width, height, bytes)),
    )
}

/// `Image.from_rgba` (`src/image.rs:67-72`).
fn from_rgba(ruby: &Ruby, width: i32, height: i32, data: RString) -> Result<Obj<Image>, Error> {
    let bytes = data.to_bytes().to_vec();
    image_result(
        ruby,
        capture(|| notify_rust::Image::from_rgba(width, height, bytes)),
    )
}

/// `Image.open` (`src/image.rs:74-78`). Decoding a file can take a while,
/// so it runs with the GVL released.
fn open(ruby: &Ruby, path: Value) -> Result<Obj<Image>, Error> {
    let path = path_from_ruby(path)?;
    let made = gvl::without_gvl(ruby, || notify_rust::Image::open(&path))?;
    image_result(ruby, made.map_err(|payload| panic_of(&payload)))
}

/// The Ruby `Ferro::NotifyRust::NotificationHandle` on Linux
/// (`src/xdg/mod.rs:67-73`).
///
/// It takes the turns Rust's borrow checker hands out, at run time, as a
/// reader-writer lock does (`lock.rs`, plan 003, decision 5). A wait,
/// `close`, their async forms, `id`, and the field readers take a shared
/// turn, as notify-rust's `&self` methods borrow the handle, so
/// `wait_for_action_async` and `close_async` run together, as
/// notify-rust's own `close_async` example does
/// (`src/xdg/mod.rs:155-178`). A setter or `update` takes the exclusive
/// turn, as `&mut self` does, and waits for the shared ones to end, with
/// the GVL released, as Ruby's `Mutex` makes a second thread wait; while
/// `update` runs, every other call waits for it. `Thread#raise`,
/// `Thread#kill`, and Ctrl-C end such a wait. A thread that asks for the
/// exclusive turn while its own wait holds a shared one (from a signal
/// trap that runs during the wait) would wait for itself forever, so it
/// raises `ThreadError` instead, as Ruby's `Mutex#lock` does.
///
/// notify-rust's `wait_for_action`, `wait_for_response`, `on_close`, and
/// `close` take `self` (`src/xdg/mod.rs:101`, `:134`, `:214`, `:269`), and
/// Rust drops the handle at the end of its scope, so each of those, and
/// the end of `show`'s block, uses the handle up (`spent`): every later
/// call raises `IOError` (ADR 001, 2026-11-05). `wait_for_action_async`
/// and `close_async` borrow it (`:183`, `:229`), so they do not. A call
/// already under way on another thread when the handle is used up
/// finishes.
///
/// A consuming call frees notify-rust's handle, and the D-Bus connection
/// it keeps (a socket, and zbus's executor thread, `src/xdg/zbus_rs.rs:61`;
/// zbus 5.19.0 `src/connection/builder.rs:785-797`), when it returns, as
/// Rust drops a moved handle at the end of the call, and the end of
/// `show`'s block frees it there: each retires the lock (`lock.rs`). A
/// borrowing call already under way on another thread keeps it until that
/// call ends, as no Rust borrow outlives a move, and a setter or `update`
/// waiting for its turn raises `IOError`. The drop runs where the last
/// turn ends, with the GVL held when that is a Ruby method's end. It never
/// waits: zbus's `ConnectionInner` drop only notifies its listeners
/// (`src/connection/mod.rs:86-93`), and the socket and the reader task
/// close without blocking; the executor thread ends on its own once its
/// tasks are gone (`builder.rs:792-797`).
#[magnus::wrap(
    class = "Ferro::NotifyRust::NotificationHandle",
    free_immediately,
    size
)]
pub struct Handle {
    lock: Lock<notify_rust::NotificationHandle>,
    spent: Mutex<Slot<()>>,
}

/// What a setter or `update` raises on the thread whose own wait or close
/// holds the handle.
const BORROWED: &str =
    "already borrowed: this thread's own wait or close is using this NotificationHandle";

/// `value`, which the compiler checks is `Send`: a future polled across
/// `gvl::wait`'s tries may be polled on another native thread, as a Ruby
/// thread can move under the M:N scheduler.
const fn sendable<T: Send>(value: T) -> T {
    value
}

/// The current Ruby thread, as the lock records who holds a turn.
fn owner(ruby: &Ruby) -> Result<Owner, Error> {
    let thread = ruby.thread_current();
    // SAFETY: `rb_obj_id` (`gc.c:2233-2240` at Ruby v4.0.9) takes any
    // object's `VALUE` and returns an Integer `VALUE`; `thread` is a live
    // Thread, and this runs with the GVL held. Unlike `funcall("__id__")`,
    // no Ruby method that code could redefine is dispatched.
    #[allow(unsafe_code)]
    let id = unsafe { Value::from_raw(rb_sys::rb_obj_id(thread.as_raw())) };
    Owner::try_convert(id)
}

impl Handle {
    fn new(handle: notify_rust::NotificationHandle) -> Self {
        Self {
            lock: Lock::new(handle),
            spent: Mutex::new(Slot::Live(())),
        }
    }

    fn slot(&self) -> std::sync::MutexGuard<'_, Slot<()>> {
        self.spent.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Raises `IOError` once a consuming call has used the handle up.
    fn live(&self, ruby: &Ruby) -> Result<(), Error> {
        let spent = self.slot().get_mut().err();
        spent.map_or(Ok(()), |by| Err(error::consumed(ruby, by)))
    }

    /// Uses the handle up for the consuming call `by`, or raises `IOError`
    /// if one already did.
    fn consume(&self, ruby: &Ruby, by: &'static str) -> Result<(), Error> {
        let taken = self.slot().take(by);
        taken.map_err(|earlier| error::consumed(ruby, earlier))
    }

    /// A shared turn, for a call that borrows the handle: at once if no
    /// setter or `update` has the handle, else waited for with the GVL
    /// released. Raises `IOError` for a handle used up.
    fn shared(&self, ruby: &Ruby) -> Result<ReadGuard<'_, notify_rust::NotificationHandle>, Error> {
        self.live(ruby)?;
        self.turn(ruby)
    }

    /// A shared turn, for a consuming call that has already used the
    /// handle up, or a borrowing one that checked it is live. Raises
    /// `IOError` once a consuming call has retired the lock.
    fn turn(&self, ruby: &Ruby) -> Result<ReadGuard<'_, notify_rust::NotificationHandle>, Error> {
        let owner = owner(ruby)?;
        if let Some(turn) = self.lock.try_read(owner) {
            return turn.map_err(|Retired(by)| error::consumed(ruby, by));
        }
        let waiter = self.lock.waiter(owner);
        gvl::wait_until(ruby, &waiter, || waiter.read(), |turn| turn)?
            .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))?
            .map_err(|Retired(by)| error::consumed(ruby, by))
    }

    /// The shared turn of the consuming call `by`: uses the handle up, as
    /// Rust moves it into the call, takes a turn, and retires the lock, so
    /// notify-rust's handle drops when the turn ends, as Rust drops it when
    /// the call returns. An interrupted wait for the turn retires it too.
    fn consuming_turn(
        &self,
        ruby: &Ruby,
        by: &'static str,
    ) -> Result<ReadGuard<'_, notify_rust::NotificationHandle>, Error> {
        self.consume(ruby, by)?;
        let turn = self.turn(ruby);
        self.lock.retire(by);
        turn
    }

    /// Waits for the exclusive turn with the GVL released and runs
    /// `operation` in it, there, or raises `ThreadError` when this thread
    /// holds a shared turn. The first try for the turn is `try_write`'s,
    /// when `operation` is short enough to run with the GVL held.
    fn exclusive<R>(
        &self,
        ruby: &Ruby,
        short: bool,
        operation: impl FnOnce(&mut notify_rust::NotificationHandle) -> R,
    ) -> Result<R, Error> {
        self.live(ruby)?;
        if short {
            if let Some(turn) = self.lock.try_write() {
                let mut turn = turn.map_err(|Retired(by)| error::consumed(ruby, by))?;
                return Ok(operation(&mut turn));
            }
        }
        let owner = owner(ruby)?;
        if self.lock.holds(owner) {
            return Err(Error::new(ruby.exception_thread_error(), BORROWED));
        }
        let waiter = self.lock.waiter(owner);
        gvl::wait_until(
            ruby,
            &waiter,
            || waiter.write(),
            |turn| turn.map(|mut turn| operation(&mut turn)),
        )?
        .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))?
        .map_err(|Retired(by)| error::consumed(ruby, by))
    }

    /// Waits for the server's answer through `wait_for_action_async`
    /// (`src/xdg/mod.rs:146-195`), and returns the response it passed the
    /// closure, if any: the wait also ends when the connection does. An
    /// interrupt that raises just as the response arrives discards it
    /// (`gvl.rs`). `by` names the consuming wait that uses the handle up,
    /// or is `None` for `wait_for_action_async`, which borrows it.
    fn response(
        &self,
        ruby: &Ruby,
        by: Option<&'static str>,
    ) -> Result<Option<NotificationResponse>, Error> {
        let handle = by.map_or_else(|| self.shared(ruby), |by| self.consuming_turn(ruby, by))?;
        let mut seen = None;
        let outcome = {
            let mut future = pin!(sendable(handle.wait_for_action_async(
                |response: &NotificationResponse| {
                    seen = Some(response.clone());
                }
            )));
            gvl::wait(ruby, |context| future.as_mut().poll(context))?
        };
        outcome.map_err(|payload| error::panicked(ruby, &panic_of(&payload)))?;
        Ok(seen)
    }

    /// `#native_wait_for_action`: the string `wait_for_action` passes its
    /// closure, or `nil` when it calls none. It uses the handle up.
    fn wait_for_action(ruby: &Ruby, rb_self: &Self) -> Result<Option<String>, Error> {
        Ok(rb_self
            .response(ruby, Some("NotificationHandle#wait_for_action"))?
            .as_ref()
            .and_then(action_of))
    }

    /// `#native_wait_for_response`: the response, as its tag, or `nil`. It
    /// uses the handle up.
    fn wait_for_response(ruby: &Ruby, rb_self: &Self) -> Result<Option<RArray>, Error> {
        Ok(rb_self
            .response(ruby, Some("NotificationHandle#wait_for_response"))?
            .map(|response| values::response_to_ruby(ruby, &response)))
    }

    /// `#native_wait_for_action_async`: the response, as its tag, or `nil`,
    /// waited for through a borrow of the handle, as
    /// `wait_for_action_async` borrows it (`src/xdg/mod.rs:183`).
    fn wait_for_action_async(ruby: &Ruby, rb_self: &Self) -> Result<Option<RArray>, Error> {
        Ok(rb_self
            .response(ruby, None)?
            .map(|response| values::response_to_ruby(ruby, &response)))
    }

    /// `#native_on_close`: the reason `on_close` passes its handler, or
    /// `nil` when the wait ended otherwise (`src/xdg/mod.rs:269-288`). It
    /// uses the handle up.
    fn on_close(ruby: &Ruby, rb_self: &Self) -> Result<Option<Value>, Error> {
        Ok(
            match rb_self.response(ruby, Some("NotificationHandle#on_close"))? {
                Some(NotificationResponse::Closed(reason)) => {
                    Some(values::close_reason_to_ruby(ruby, reason))
                }
                _ => None,
            },
        )
    }

    /// `#native_close`: `close` (`src/xdg/mod.rs:214-221`), which uses the
    /// handle up and blocks on `close_async`.
    fn close(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        let handle = rb_self.consuming_turn(ruby, "NotificationHandle#close")?;
        Self::closed(ruby, &handle)
    }

    /// `#native_close_async`: `close_async` (`src/xdg/mod.rs:223-238`),
    /// which borrows the handle.
    fn close_async(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        let handle = rb_self.shared(ruby)?;
        Self::closed(ruby, &handle)
    }

    /// `#native_release`: the end of `show`'s block, where Rust drops a
    /// handle no consuming call has moved away, uses it up and retires the
    /// lock, so notify-rust's handle drops now, or when a borrowing call
    /// on another thread ends.
    fn release(rb_self: &Self) {
        let released = rb_self.slot().release("Builder#show");
        if released.is_some() {
            rb_self.lock.retire("Builder#show");
        }
    }

    /// `#native_debug`: notify-rust's derived `Debug` (`src/xdg/mod.rs:70`),
    /// which shows the zbus connection the handle keeps.
    fn debug(ruby: &Ruby, rb_self: &Self) -> Result<String, Error> {
        Ok(format!("{:?}", *rb_self.shared(ruby)?))
    }

    /// Polls `close_async` on `handle`, which a shared turn holds, until
    /// the server has the call, ignoring its error as `close` does.
    fn closed(ruby: &Ruby, handle: &notify_rust::NotificationHandle) -> Result<(), Error> {
        let outcome = {
            let mut future = pin!(sendable(handle.close_async()));
            gvl::wait(ruby, |context| future.as_mut().poll(context))?
        };
        outcome.map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
    }

    /// `#native_update`: `update` (`src/xdg/mod.rs:290-317`), which
    /// notify-rust runs only through `block_on`, so nothing can cancel it
    /// once it starts; the wait for its turn can be. Its turn is taken and
    /// given back with the GVL released, so no Ruby code runs while it
    /// holds the handle. It takes `&mut self`, as the setters do, so a
    /// frozen handle refuses it.
    fn update(ruby: &Ruby, rb_self: Obj<Self>) -> Result<(), Error> {
        rb_self.check_frozen()?;
        rb_self
            .exclusive(ruby, false, notify_rust::NotificationHandle::update)?
            .map_err(|failure| error::notify_error(ruby, &failure))
    }

    /// `#native_handle_id`: `id` (`src/xdg/mod.rs:319-327`).
    fn id(ruby: &Ruby, rb_self: &Self) -> Result<u32, Error> {
        Ok(rb_self.shared(ruby)?.id())
    }
}

impl Holds for Handle {
    fn with<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&mut notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        self.exclusive(ruby, true, |handle| operation(handle))
    }

    fn with_released<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&mut notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        self.exclusive(ruby, false, |handle| operation(handle))
    }

    fn with_ref<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        let handle = self.shared(ruby)?;
        Ok(operation(&handle))
    }
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the response-to-string mapping of
//   notify-rust 4.18.2 src/xdg/mod.rs:119-124

/// The string `wait_for_action` passes its closure for `response`, or
/// `None` for a reply, which XDG never sends (`src/xdg/mod.rs:119-124`).
fn action_of(response: &NotificationResponse) -> Option<String> {
    match response {
        NotificationResponse::Default => Some("default".to_owned()),
        NotificationResponse::Action(action) => Some(action.clone()),
        NotificationResponse::Reply(_) => None,
        NotificationResponse::Closed(_) => Some("__closed".to_owned()),
    }
}

// SPDX-SnippetEnd

/// Polls a future that shows a notification and wraps its handle.
fn shown(
    ruby: &Ruby,
    future: impl Future<Output = notify_rust::error::Result<notify_rust::NotificationHandle>> + Send,
) -> Result<Obj<Handle>, Error> {
    let mut future = pin!(sendable(future));
    let outcome = gvl::wait(ruby, |context| future.as_mut().poll(context))?;
    match outcome {
        Ok(Ok(handle)) => Ok(ruby.obj_wrap(Handle::new(handle))),
        Ok(Err(failure)) => Err(error::notify_error(ruby, &failure)),
        Err(payload) => Err(error::panicked(ruby, &panic_of(&payload))),
    }
}

/// `#native_show`: shows a copy of the notification through `show_async`
/// (`src/notification.rs:515-522`), which `show` blocks on.
pub fn show<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>) -> Result<Obj<Handle>, Error> {
    let copy = rb_self.with_ref(ruby, notify_rust::Notification::finalize)?;
    shown(ruby, copy.show_async())
}

/// `#native_show_async_at_bus` (`src/notification.rs:524-533`).
pub fn show_async_at_bus<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    sub_bus: RString,
) -> Result<Obj<Handle>, Error> {
    let sub_bus = sub_bus.to_string()?;
    let copy = rb_self.with_ref(ruby, notify_rust::Notification::finalize)?;
    shown(ruby, copy.show_async_at_bus(&sub_bus))
}

pub fn hint<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>, tag: RArray) -> Result<(), Error> {
    let hint = values::hint_from_ruby(ruby, tag)?;
    plain_set(ruby, rb_self, |notification| {
        notification.hint(hint);
    })
}

pub fn urgency<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    tag: Value,
) -> Result<(), Error> {
    let urgency = values::urgency_from_ruby(ruby, tag)?;
    plain_set(ruby, rb_self, |notification| {
        notification.urgency(urgency);
    })
}

pub fn image_data<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    image: &Image,
) -> Result<(), Error> {
    let image = image.0.clone();
    plain_set(ruby, rb_self, |notification| {
        notification.image_data(image);
    })
}

pub fn image<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>, path: Value) -> Result<(), Error> {
    let path = path_from_ruby(path)?;
    try_set(ruby, rb_self, |notification| {
        notification.image(&path).map(|_| ())
    })
}

/// The Linux setters and `show`, on a holder's class.
macro_rules! define_builder {
    ($class:expr, $holder:ty) => {{
        let class: magnus::RClass = $class;
        class.define_private_method(
            "native_hint",
            magnus::method!($crate::platform::hint::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_urgency",
            magnus::method!($crate::platform::urgency::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_image_data",
            magnus::method!($crate::platform::image_data::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_image",
            magnus::method!($crate::platform::image::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_show",
            magnus::method!($crate::platform::show::<$holder>, 0),
        )?;
        class.define_private_method(
            "native_show_async_at_bus",
            magnus::method!($crate::platform::show_async_at_bus::<$holder>, 1),
        )?;
    }};
}
pub(crate) use define_builder;

/// Runs a call notify-rust cannot cancel with the GVL released.
fn blocking<T>(
    ruby: &Ruby,
    work: impl FnOnce() -> notify_rust::error::Result<T>,
) -> Result<T, Error> {
    gvl::without_gvl(ruby, work)?
        .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))?
        .map_err(|failure| error::notify_error(ruby, &failure))
}

/// `Native.get_capabilities` (`src/xdg/mod.rs:487-493`).
fn get_capabilities(ruby: &Ruby) -> Result<Vec<String>, Error> {
    blocking(ruby, notify_rust::get_capabilities)
}

/// `Native.get_server_information` (`src/xdg/mod.rs:515-523`), as
/// `[name, vendor, version, spec_version]`.
fn get_server_information(ruby: &Ruby) -> Result<(String, String, String, String), Error> {
    let information = blocking(ruby, notify_rust::get_server_information)?;
    Ok((
        information.name,
        information.vendor,
        information.version,
        information.spec_version,
    ))
}

/// `Native.spec_version`: notify-rust's `SPEC_VERSION`
/// (`src/lib.rs:226-233`), as `[major, minor]`. The first read asks the
/// server through `get_server_information`, which notify-rust blocks on,
/// so it runs with the GVL released; notify-rust falls back to 1.1 when
/// that fails.
fn spec_version(ruby: &Ruby) -> Result<(u64, u64), Error> {
    gvl::without_gvl(ruby, || {
        let version = *notify_rust::SPEC_VERSION;
        (version.major, version.minor)
    })?
    .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
}

/// What `handle_action`'s closure saw, owned, since `ActionResponse`
/// borrows its key.
enum Seen {
    Custom(String),
    Closed(CloseReason),
}

/// `Native.handle_action` (`src/xdg/mod.rs:574-586`): the response its
/// closure saw, as an `ActionResponse` tag, or `nil`.
fn handle_action(ruby: &Ruby, id: u32) -> Result<Option<RArray>, Error> {
    let seen = blocking(ruby, || {
        let mut seen = None;
        notify_rust::handle_action(id, |response| {
            seen = Some(match response {
                notify_rust::ActionResponse::Custom(key) => Seen::Custom((*key).to_owned()),
                notify_rust::ActionResponse::Closed(reason) => Seen::Closed(*reason),
            });
        })?;
        Ok(seen)
    })?;
    Ok(seen.map(|seen| {
        let response = match &seen {
            Seen::Custom(key) => notify_rust::ActionResponse::Custom(key),
            Seen::Closed(reason) => notify_rust::ActionResponse::Closed(*reason),
        };
        values::action_response_to_ruby(ruby, &response)
    }))
}

/// `Native.dbus_stack` (`src/xdg/mod.rs:451-457`): the stack's name.
fn dbus_stack(ruby: &Ruby) -> Option<Value> {
    notify_rust::dbus_stack().map(|stack| ruby.to_symbol(format!("{stack:?}")).as_value())
}

/// `Native.dbus_stack_debug`: notify-rust's derived `Debug` for the
/// variant `name` (`src/xdg/mod.rs:402-408`), whose `Dbus` variant exists
/// without the `d` feature.
fn dbus_stack_debug(ruby: &Ruby, name: Symbol) -> Result<String, Error> {
    let stack = match name.name()?.as_ref() {
        "Dbus" => notify_rust::DbusStack::Dbus,
        "Zbus" => notify_rust::DbusStack::Zbus,
        other => {
            return Err(Error::new(
                ruby.exception_type_error(),
                format!("{other} is not a DbusStack"),
            ))
        }
    };
    Ok(format!("{stack:?}"))
}

/// `Native.version_debug`: the derived `Debug` of `miniver::Version`
/// (`src/miniver.rs:4`) with `major` and `minor`. The type sits in a
/// private module, so the only way to one is a copy of `SPEC_VERSION`
/// (`src/lib.rs:226-233`), whose public fields the copy then takes. A
/// `Version` exists in Ruby only once `SPEC_VERSION` is read, but reading
/// it the first time asks the server, so it runs with the GVL released.
fn version_debug(ruby: &Ruby, major: u64, minor: u64) -> Result<String, Error> {
    gvl::without_gvl(ruby, move || {
        let mut version = *notify_rust::SPEC_VERSION;
        version.major = major;
        version.minor = minor;
        format!("{version:?}")
    })?
    .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
}

/// Defines the Linux classes and functions.
pub fn define(ruby: &Ruby, notify_rust: RModule, native: RModule) -> Result<(), Error> {
    let image = notify_rust.define_class("Image", ruby.class_object())?;
    image.undef_default_alloc_func();
    let _ = <Image as TypedData>::class(ruby);
    image.define_singleton_method("native_from_rgb", function!(from_rgb, 3))?;
    image.define_singleton_method("native_from_rgba", function!(from_rgba, 3))?;
    image.define_singleton_method("native_open", function!(open, 1))?;
    image.define_private_method("native_equal", method!(Image::equal, 1))?;
    image.define_private_method("native_hash", method!(Image::hash, 0))?;
    image.define_private_method("native_debug", method!(Image::debug, 0))?;

    let handle = notify_rust.define_class("NotificationHandle", ruby.class_object())?;
    handle.undef_default_alloc_func();
    let _ = <Handle as TypedData>::class(ruby);
    crate::notification::define_builder!(handle, Handle);
    handle.define_private_method(
        "native_wait_for_action",
        method!(Handle::wait_for_action, 0),
    )?;
    handle.define_private_method(
        "native_wait_for_response",
        method!(Handle::wait_for_response, 0),
    )?;
    handle.define_private_method("native_on_close", method!(Handle::on_close, 0))?;
    handle.define_private_method(
        "native_wait_for_action_async",
        method!(Handle::wait_for_action_async, 0),
    )?;
    handle.define_private_method("native_close", method!(Handle::close, 0))?;
    handle.define_private_method("native_close_async", method!(Handle::close_async, 0))?;
    handle.define_private_method("native_release", method!(Handle::release, 0))?;
    handle.define_private_method("native_debug", method!(Handle::debug, 0))?;
    handle.define_private_method("native_update", method!(Handle::update, 0))?;
    handle.define_private_method("native_handle_id", method!(Handle::id, 0))?;

    native.define_singleton_method("get_capabilities", function!(get_capabilities, 0))?;
    native.define_singleton_method(
        "get_server_information",
        function!(get_server_information, 0),
    )?;
    native.define_singleton_method("handle_action", function!(handle_action, 1))?;
    native.define_singleton_method("dbus_stack", function!(dbus_stack, 0))?;
    native.define_singleton_method("spec_version", function!(spec_version, 0))?;
    native.define_singleton_method("version_debug", function!(version_debug, 2))?;
    native.define_singleton_method("dbus_stack_debug", function!(dbus_stack_debug, 1))?;
    native.define_singleton_method("image_error_debug", function!(image_error_debug, 1))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::action_of;
    use notify_rust::{CloseReason, NotificationResponse};

    #[test]
    fn wait_for_action_passes_the_strings_notify_rust_does() {
        assert_eq!(
            action_of(&NotificationResponse::Default).as_deref(),
            Some("default")
        );
        assert_eq!(
            action_of(&NotificationResponse::Action("ok".into())).as_deref(),
            Some("ok")
        );
        assert_eq!(action_of(&NotificationResponse::Reply("hi".into())), None);
        assert_eq!(
            action_of(&NotificationResponse::Closed(CloseReason::Expired)).as_deref(),
            Some("__closed")
        );
    }
}
