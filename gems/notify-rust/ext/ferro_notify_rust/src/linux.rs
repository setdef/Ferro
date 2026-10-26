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
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use magnus::{
    function, method, prelude::*, typed_data::Obj, Error, RArray, RClass, RModule, RString, Ruby,
    TypedData, Value,
};
use notify_rust::{CloseReason, ImageError, NotificationResponse};

use crate::notification::{plain_set, try_set, Holds, Notification};
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

    /// `#inspect`: notify-rust's derived `Debug`.
    fn inspect(&self) -> String {
        format!("{:?}", self.0)
    }
}

/// The `ImageError` subclass for `failure`, with notify-rust's text
/// (`src/image.rs:126-165`).
fn image_error(ruby: &Ruby, failure: &ImageError) -> Error {
    let leaf = match failure {
        ImageError::TooBig => "TooBig",
        ImageError::WrongDataSize => "WrongDataSize",
        ImageError::CantOpen(_) => "CantOpen",
        ImageError::CantConvert => "CantConvert",
    };
    error::raise(ruby, &["ImageError", leaf], &[failure.to_string()])
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
    let made = gvl::without_gvl(ruby, |_| notify_rust::Image::open(&path))?;
    image_result(ruby, made.map_err(|payload| panic_of(&payload)))
}

/// The Ruby `Ferro::NotifyRust::NotificationHandle` on Linux
/// (`src/xdg/mod.rs:67-73`).
///
/// It follows Rust's borrow rules at run time, as a `RefCell` does. A
/// wait, `close`, and the readers borrow the handle shared, as
/// notify-rust's `&self` methods do, each through its own `Arc`, so a wait
/// and a `close` run together, as notify-rust's own `close_async` example
/// does (`src/xdg/mod.rs:155-178`). A setter or `update` borrows it
/// mutably, as `&mut self` does: while a wait or close holds a share, it
/// raises `Error` at once rather than wait, since Rust would refuse it at
/// compile time, and while `update` runs, every other call does. The
/// `Mutex` is held only for a moment, with the GVL held, and never across
/// a wait, so no thread waits behind another (plan 003, decision 5).
#[magnus::wrap(
    class = "Ferro::NotifyRust::NotificationHandle",
    free_immediately,
    size
)]
pub struct Handle(Mutex<Option<Arc<notify_rust::NotificationHandle>>>);

/// What a mutable borrow raises while a shared one is out.
const BORROWED: &str =
    "already borrowed: a wait or close in progress is using this NotificationHandle";

/// What any borrow raises while `update` holds the handle.
const MUTABLY_BORROWED: &str =
    "already mutably borrowed: update in progress is using this NotificationHandle";

/// `value`, which the compiler checks is `Send`: a future polled across
/// `gvl::wait`'s tries may be polled on another native thread, as a Ruby
/// thread can move under the M:N scheduler.
const fn sendable<T: Send>(value: T) -> T {
    value
}

impl Handle {
    fn new(handle: notify_rust::NotificationHandle) -> Self {
        Self(Mutex::new(Some(Arc::new(handle))))
    }

    fn slot(&self) -> MutexGuard<'_, Option<Arc<notify_rust::NotificationHandle>>> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// A shared borrow: a clone of the handle's `Arc`.
    fn shared(&self, ruby: &Ruby) -> Result<Arc<notify_rust::NotificationHandle>, Error> {
        self.slot()
            .as_ref()
            .map(Arc::clone)
            .ok_or_else(|| error::base(ruby, MUTABLY_BORROWED))
    }

    /// Runs a short `operation` on the handle, mutably borrowed.
    fn exclusive<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&mut notify_rust::NotificationHandle) -> R,
    ) -> Result<R, Error> {
        let mut slot = self.slot();
        let outcome = slot.as_mut().map_or(Err(MUTABLY_BORROWED), |handle| {
            Arc::get_mut(handle).map(operation).ok_or(BORROWED)
        });
        drop(slot);
        outcome.map_err(|message| error::base(ruby, message))
    }

    /// Takes the handle out of its slot, if no share is out, for `update`.
    fn take_unique(&self) -> Result<notify_rust::NotificationHandle, &'static str> {
        let mut slot = self.slot();
        let taken = slot.take().ok_or(MUTABLY_BORROWED);
        let outcome = taken.and_then(|shared| {
            Arc::try_unwrap(shared).map_err(|shared| {
                *slot = Some(shared);
                BORROWED
            })
        });
        drop(slot);
        outcome
    }

    /// Waits for the server's answer through `wait_for_action_async`
    /// (`src/xdg/mod.rs:146-195`), and returns the response it passed the
    /// closure, if any: the wait also ends when the connection does.
    fn response(&self, ruby: &Ruby) -> Result<Option<NotificationResponse>, Error> {
        let handle = self.shared(ruby)?;
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
    /// closure, or `nil` when it calls none.
    fn wait_for_action(ruby: &Ruby, rb_self: &Self) -> Result<Option<String>, Error> {
        Ok(rb_self.response(ruby)?.as_ref().and_then(action_of))
    }

    /// `#native_wait_for_response`: the response, as its tag, or `nil`.
    fn wait_for_response(ruby: &Ruby, rb_self: &Self) -> Result<Option<RArray>, Error> {
        Ok(rb_self
            .response(ruby)?
            .map(|response| values::response_to_ruby(ruby, &response)))
    }

    /// `#native_on_close`: the reason `on_close` passes its handler, or
    /// `nil` when the wait ended otherwise (`src/xdg/mod.rs:269-288`).
    fn on_close(ruby: &Ruby, rb_self: &Self) -> Result<Option<Value>, Error> {
        Ok(match rb_self.response(ruby)? {
            Some(NotificationResponse::Closed(reason)) => {
                Some(values::close_reason_to_ruby(ruby, reason))
            }
            _ => None,
        })
    }

    /// `#native_close`: `close_async` (`src/xdg/mod.rs:223-238`), which
    /// `close` blocks on, ignoring its error as `close` does.
    fn close(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        let handle = rb_self.shared(ruby)?;
        let outcome = {
            let mut future = pin!(sendable(handle.close_async()));
            gvl::wait(ruby, |context| future.as_mut().poll(context))?
        };
        outcome.map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
    }

    /// `#native_update`: `update` (`src/xdg/mod.rs:290-317`), which
    /// notify-rust runs only through `block_on`, so nothing can cancel it.
    /// The handle leaves the slot while it runs, so every other call
    /// raises rather than wait for it.
    fn update(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        let mut handle = rb_self
            .take_unique()
            .map_err(|message| error::base(ruby, message))?;
        let outcome = gvl::without_gvl(ruby, |_| handle.update());
        *rb_self.slot() = Some(Arc::new(handle));
        outcome?
            .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))?
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
        self.exclusive(ruby, |handle| operation(handle))
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

/// `Notification.native_at_bus` (`src/notification.rs:127-139`).
/// notify-rust unwraps an invalid sub-bus into a panic; that panic raises
/// the error `show_async_at_bus` returns for the same input, `invalid
/// subpath` (`:531`), as plan 003, decision 15 says.
#[allow(deprecated)]
fn at_bus(ruby: &Ruby, sub_bus: String) -> Result<Obj<Notification>, Error> {
    match capture(move || notify_rust::Notification::at_bus(&sub_bus)) {
        Ok(notification) => Ok(ruby.obj_wrap(Notification::new(notification))),
        Err(panic) if panic.0.contains("invalid subpath") => Err(error::notify_error(
            ruby,
            &notify_rust::error::Error::from("invalid subpath"),
        )),
        Err(panic) => Err(error::panicked(ruby, &panic)),
    }
}

/// The class methods only `Notification` has here.
pub fn define_notification(_ruby: &Ruby, class: RClass) -> Result<(), Error> {
    class.define_singleton_method("native_at_bus", function!(at_bus, 1))?;
    Ok(())
}

/// Runs a call notify-rust cannot cancel with the GVL released.
fn blocking<T>(
    ruby: &Ruby,
    work: impl FnOnce() -> notify_rust::error::Result<T>,
) -> Result<T, Error> {
    gvl::without_gvl(ruby, |_| work())?
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
    image.define_private_method("native_inspect", method!(Image::inspect, 0))?;

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
    handle.define_private_method("native_close", method!(Handle::close, 0))?;
    handle.define_private_method("native_update", method!(Handle::update, 0))?;
    handle.define_private_method("native_handle_id", method!(Handle::id, 0))?;

    native.define_singleton_method("get_capabilities", function!(get_capabilities, 0))?;
    native.define_singleton_method(
        "get_server_information",
        function!(get_server_information, 0),
    )?;
    native.define_singleton_method("handle_action", function!(handle_action, 1))?;
    native.define_singleton_method("dbus_stack", function!(dbus_stack, 0))?;
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
