// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `Ferro::NotifyRust::Notification`, notify-rust's builder, and the
//! private methods that run its setters (plan 003, decision 3).
//!
//! The same methods serve every object that holds a notification: the
//! `Notification` itself, and on Linux and Windows a `NotificationHandle`,
//! which dereferences to the notification it showed
//! (notify-rust 4.18.2 `src/xdg/mod.rs:330-354`, `src/windows.rs:146-158`).
//! [`Holds`] is what they share.

use std::sync::{Mutex, PoisonError};

use magnus::{
    method, prelude::*, typed_data::Obj, value::ReprValue, Error, IntoValue, Ruby, Symbol,
    TryConvert, TypedData, Value,
};

use crate::{capture, settle, values, Panic};

/// An object holding one of notify-rust's notifications.
pub trait Holds {
    /// Runs `operation` on the notification. Raises when there is none, as
    /// on a Windows handle a wait has consumed (plan 003, decision 5).
    fn with<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&mut notify_rust::Notification) -> R,
    ) -> Result<R, Error>;

    /// Runs `operation` on the notification, read only, as Rust's `&self`
    /// methods borrow it.
    fn with_ref<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&notify_rust::Notification) -> R,
    ) -> Result<R, Error>;
}

/// The Ruby `Ferro::NotifyRust::Notification`.
///
/// notify-rust's `Notification` is `Send` and `Sync`; the `Mutex` lets a
/// frozen one be shared between Ractors (plan 003, decision 14). Every
/// setter runs with the GVL held and takes the lock only for its own
/// call, so the lock is never held across a wait.
///
/// Ruby's allocator makes it empty. `Notification::new` runs `exe_name`,
/// which unwraps the executable's path, file name, and UTF-8 text
/// (notify-rust 4.18.2 `src/notification.rs:24-33`), and a panic inside
/// magnus's `extern "C"` allocator would abort the process. So
/// `initialize`, a method magnus guards, builds the notification under
/// `capture`, and a panic raises `Error` (plan 003, decision 15).
#[magnus::wrap(
    class = "Ferro::NotifyRust::Notification",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct Notification(Mutex<Option<notify_rust::Notification>>);

/// The empty notification Ruby's allocator makes, for `new` and `dup`.
impl Default for Notification {
    fn default() -> Self {
        Self(Mutex::new(None))
    }
}

/// What a notification not yet initialized raises, as one from
/// `Notification.allocate` would.
const UNINITIALIZED: &str = "uninitialized Ferro::NotifyRust::Notification";

/// Fills `slot` with what `make` builds, catching a panic, which leaves
/// `slot` empty.
fn initialize_with(
    slot: &Mutex<Option<notify_rust::Notification>>,
    make: impl FnOnce() -> notify_rust::Notification,
) -> Result<(), Panic> {
    let notification = capture(make)?;
    *slot.lock().unwrap_or_else(PoisonError::into_inner) = Some(notification);
    Ok(())
}

impl Notification {
    pub const fn new(notification: notify_rust::Notification) -> Self {
        Self(Mutex::new(Some(notification)))
    }

    /// A copy of the notification, as notify-rust's `finalize` makes
    /// (`src/notification.rs:482-487`).
    pub fn copy(&self, ruby: &Ruby) -> Result<notify_rust::Notification, Error> {
        self.with_ref(ruby, notify_rust::Notification::finalize)
    }

    /// `initialize`: `Notification::new` (`src/notification.rs:117-125`).
    fn initialize(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        settle(
            ruby,
            initialize_with(&rb_self.0, notify_rust::Notification::new),
        )
    }

    /// `initialize_copy`: Ruby's `dup` and `clone` copy the notification,
    /// as notify-rust's `Clone` does.
    fn initialize_copy(ruby: &Ruby, rb_self: Obj<Self>, other: &Self) -> Result<(), Error> {
        rb_self.check_frozen()?;
        let copy = other.copy(ruby)?;
        *rb_self.0.lock().unwrap_or_else(PoisonError::into_inner) = Some(copy);
        Ok(())
    }

    /// `#inspect`: notify-rust's `Debug` text (`src/notification.rs:49`).
    fn inspect(ruby: &Ruby, rb_self: &Self) -> Result<String, Error> {
        rb_self.with_ref(ruby, |notification| format!("{notification:?}"))
    }
}

impl Holds for Notification {
    fn with<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&mut notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        // A panic in a setter runs under `capture` before the lock is
        // released, so the notification holds no broken invariant. The
        // error is built once the lock is released: nothing of Ruby's
        // happens under it.
        let outcome = self
            .0
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .as_mut()
            .map(operation);
        outcome.ok_or_else(|| crate::error::base(ruby, UNINITIALIZED))
    }

    fn with_ref<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        let outcome = self
            .0
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .as_ref()
            .map(operation);
        outcome.ok_or_else(|| crate::error::base(ruby, UNINITIALIZED))
    }
}

/// Runs `operation` on the notification `rb_self` holds after checking
/// that `rb_self` is not frozen, catching a panic.
fn set<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    operation: impl FnOnce(&mut notify_rust::Notification),
) -> Result<(), Error> {
    rb_self.check_frozen()?;
    let outcome = rb_self.with(ruby, |notification| capture(|| operation(notification)))?;
    settle(ruby, outcome)
}

pub fn appname<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    appname: String,
) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.appname(&appname);
    })
}

pub fn summary<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    summary: String,
) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.summary(&summary);
    })
}

pub fn subtitle<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    subtitle: String,
) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.subtitle(&subtitle);
    })
}

pub fn body<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>, body: String) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.body(&body);
    })
}

pub fn icon<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>, icon: String) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.icon(&icon);
    })
}

pub fn auto_icon<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>) -> Result<(), Error> {
    set(ruby, rb_self, |notification| {
        notification.auto_icon();
    })
}

pub fn image_path<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    path: String,
) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.image_path(&path);
    })
}

pub fn sound_name<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    name: String,
) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.sound_name(&name);
    })
}

pub fn timeout<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    tag: Value,
) -> Result<(), Error> {
    let timeout = values::timeout_from_ruby(ruby, tag)?;
    set(ruby, rb_self, |notification| {
        notification.timeout(timeout);
    })
}

#[allow(deprecated)]
pub fn actions<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    actions: Vec<String>,
) -> Result<(), Error> {
    set(ruby, rb_self, |notification| {
        notification.actions(actions);
    })
}

pub fn action<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    identifier: String,
    label: String,
) -> Result<(), Error> {
    set(ruby, rb_self, move |notification| {
        notification.action(&identifier, &label);
    })
}

pub fn id<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>, id: u32) -> Result<(), Error> {
    set(ruby, rb_self, |notification| {
        notification.id(id);
    })
}

/// `finalize`: a new `Notification` holding a copy
/// (`src/notification.rs:482-487`).
pub fn finalize<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
) -> Result<Obj<Notification>, Error> {
    let copy = rb_self.with_ref(ruby, notify_rust::Notification::finalize)?;
    Ok(ruby.obj_wrap(Notification::new(copy)))
}

/// The public field `name` (`src/notification.rs:52-101`).
pub fn field<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    name: Symbol,
) -> Result<Value, Error> {
    let name = name.name()?.into_owned();
    // Copy the field out under the lock and make Ruby values after it:
    // an allocation can start a garbage collection, which waits for every
    // Ractor, and another Ractor may be waiting for this lock.
    let copy = rb_self.with_ref(ruby, |notification| {
        Some(match name.as_str() {
            "appname" => Field::Text(notification.appname.clone()),
            "summary" => Field::Text(notification.summary.clone()),
            "subtitle" => Field::Subtitle(notification.subtitle.clone()),
            "body" => Field::Text(notification.body.clone()),
            "icon" => Field::Text(notification.icon.clone()),
            "actions" => Field::Actions(notification.actions.clone()),
            "timeout" => Field::Timeout(notification.timeout),
            #[cfg(all(unix, not(target_os = "macos")))]
            "hints" => Field::Hints(notification.hints.iter().cloned().collect()),
            _ => return None,
        })
    })?;
    Ok(match copy {
        Some(Field::Text(text)) => ruby.str_new(&text).as_value(),
        Some(Field::Subtitle(subtitle)) => subtitle.into_value_with(ruby),
        Some(Field::Actions(actions)) => actions.into_value_with(ruby),
        Some(Field::Timeout(timeout)) => values::timeout_to_ruby(ruby, timeout),
        #[cfg(all(unix, not(target_os = "macos")))]
        Some(Field::Hints(hints)) => ruby
            .ary_from_iter(hints.iter().map(|hint| values::hint_to_ruby(ruby, hint)))
            .as_value(),
        None => {
            return Err(Error::new(
                ruby.exception_name_error(),
                format!("Notification has no field {name}"),
            ))
        }
    })
}

/// A public field's value, copied out of the notification.
enum Field {
    Text(String),
    Subtitle(Option<String>),
    Actions(Vec<String>),
    Timeout(notify_rust::Timeout),
    #[cfg(all(unix, not(target_os = "macos")))]
    Hints(Vec<notify_rust::Hint>),
}

/// Assigns the public field `name`, as Rust code may.
pub fn set_field<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    name: Symbol,
    value: Value,
) -> Result<(), Error> {
    let name = name.name()?.into_owned();
    let text = || <Option<String>>::try_convert(value);
    rb_self.check_frozen()?;
    match name.as_str() {
        "appname" | "summary" | "body" | "icon" => {
            let text = String::try_convert(value)?;
            rb_self.with(ruby, |notification| match name.as_str() {
                "appname" => notification.appname = text,
                "summary" => notification.summary = text,
                "body" => notification.body = text,
                _ => notification.icon = text,
            })
        }
        "subtitle" => {
            let subtitle = text()?;
            rb_self.with(ruby, |notification| notification.subtitle = subtitle)
        }
        "actions" => {
            let actions = Vec::<String>::try_convert(value)?;
            rb_self.with(ruby, |notification| notification.actions = actions)
        }
        "timeout" => {
            let timeout = values::timeout_from_ruby(ruby, value)?;
            rb_self.with(ruby, |notification| notification.timeout = timeout)
        }
        #[cfg(all(unix, not(target_os = "macos")))]
        "hints" => {
            let hints = magnus::RArray::try_convert(value)?
                .into_iter()
                .map(|tag| values::hint_from_ruby(ruby, magnus::RArray::try_convert(tag)?))
                .collect::<Result<std::collections::HashSet<_>, Error>>()?;
            rb_self.with(ruby, |notification| notification.hints = hints)
        }
        other => Err(Error::new(
            ruby.exception_name_error(),
            format!("Notification has no field {other}"),
        )),
    }
}

/// Defines the private methods of a holder's class: one per setter of
/// notify-rust's `Notification` that every platform has, the field
/// accessors, `finalize`, and the platform's own (`platform::define_builder!`).
/// A macro, since magnus's `method!` cannot take a generic parameter.
macro_rules! define_builder {
    ($class:expr, $holder:ty) => {{
        let class: magnus::RClass = $class;
        class.define_private_method(
            "native_appname",
            magnus::method!($crate::notification::appname::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_summary",
            magnus::method!($crate::notification::summary::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_subtitle",
            magnus::method!($crate::notification::subtitle::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_body",
            magnus::method!($crate::notification::body::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_icon",
            magnus::method!($crate::notification::icon::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_auto_icon",
            magnus::method!($crate::notification::auto_icon::<$holder>, 0),
        )?;
        class.define_private_method(
            "native_image_path",
            magnus::method!($crate::notification::image_path::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_sound_name",
            magnus::method!($crate::notification::sound_name::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_timeout",
            magnus::method!($crate::notification::timeout::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_actions",
            magnus::method!($crate::notification::actions::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_action",
            magnus::method!($crate::notification::action::<$holder>, 2),
        )?;
        class.define_private_method(
            "native_id",
            magnus::method!($crate::notification::id::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_finalize",
            magnus::method!($crate::notification::finalize::<$holder>, 0),
        )?;
        class.define_private_method(
            "native_field",
            magnus::method!($crate::notification::field::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_set_field",
            magnus::method!($crate::notification::set_field::<$holder>, 2),
        )?;
        $crate::platform::define_builder!(class, $holder);
    }};
}
#[cfg(not(target_os = "macos"))]
pub(crate) use define_builder;

/// Defines `Ferro::NotifyRust::Notification`.
pub fn define(ruby: &Ruby, notify_rust: magnus::RModule) -> Result<(), Error> {
    let class = notify_rust.define_class("Notification", ruby.class_object())?;
    class.define_alloc_func::<Notification>();
    // Resolve magnus's lazy class lookup now, on the main Ractor, as the
    // other gems do: two Ractors wrapping their first notification at once
    // would otherwise race to fill it.
    let _ = <Notification as TypedData>::class(ruby);
    class.define_private_method("initialize", method!(Notification::initialize, 0))?;
    class.define_private_method("initialize_copy", method!(Notification::initialize_copy, 1))?;
    class.define_private_method("native_inspect", method!(Notification::inspect, 0))?;
    define_builder!(class, Notification);
    // Windows' Notification has nothing of its own beside the builder.
    #[cfg(not(windows))]
    crate::platform::define_notification(ruby, class)?;
    Ok(())
}

#[cfg(all(unix, not(target_os = "macos")))]
/// A setter on `rb_self`'s notification that may fail with notify-rust's
/// own error.
pub fn try_set<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    operation: impl FnOnce(&mut notify_rust::Notification) -> Result<(), notify_rust::error::Error>,
) -> Result<(), Error> {
    rb_self.check_frozen()?;
    let outcome = rb_self.with(ruby, |notification| capture(|| operation(notification)))?;
    settle(ruby, outcome)?.map_err(|failure| crate::error::notify_error(ruby, &failure))
}

#[cfg(not(target_os = "macos"))]
/// A setter on `rb_self`'s notification that cannot fail.
pub fn plain_set<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    operation: impl FnOnce(&mut notify_rust::Notification),
) -> Result<(), Error> {
    set(ruby, rb_self, operation)
}

#[cfg(test)]
mod tests {
    use super::{initialize_with, Panic};
    use std::sync::Mutex;

    /// A constructor that panics, as `exe_name` does without a UTF-8
    /// executable name, raises instead of aborting and leaves the
    /// notification empty.
    #[test]
    fn a_panicking_constructor_leaves_the_notification_empty() {
        let slot = Mutex::new(None);
        let outcome = initialize_with(&slot, || panic!("no executable name"));
        assert_eq!(outcome, Err(Panic("no executable name".to_owned())));
        assert!(slot.lock().expect("unpoisoned").is_none());
        assert_eq!(
            initialize_with(&slot, notify_rust::Notification::new),
            Ok(())
        );
        assert!(slot.lock().expect("unpoisoned").is_some());
    }
}
