// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! What notify-rust compiles for macOS without `preview-macos-un`: the
//! `NSUserNotificationCenter` handle, scheduling, and mac-notification-sys's
//! two application functions (plan 003, decisions 4 and 13).
//!
//! Every call that sends runs with the GVL released and no unblocking
//! function: mac-notification-sys waits on the main thread's run loop or a
//! condition variable that nothing outside it can signal
//! (mac-notification-sys 0.6.15 `objc/notify.m:161-238`).

use std::sync::{Mutex, PoisonError};

use magnus::{
    function, method, prelude::*, typed_data::Obj, Error, RArray, RClass, RModule, Ruby, TypedData,
    Value,
};
use notify_rust::NotificationResponse;

use crate::notification::{Holds, Notification};
use crate::{error, gvl, panic_of, values};

/// The platform's name, as `Ferro::NotifyRust::PLATFORM` reports it.
pub const NAME: &str = "macos";

/// The Ruby `Ferro::NotifyRust::NotificationHandle` on macOS
/// (`src/macos/nsusernotifications.rs:5-12`). It holds notify-rust's handle
/// until a wait or the end of `show`'s block takes it; then it holds
/// nothing, and its waits return without calling the block, as notify-rust's
/// do for a handle with no notification (plan 003, decision 4).
#[magnus::wrap(
    class = "Ferro::NotifyRust::NotificationHandle",
    free_immediately,
    size
)]
pub struct Handle(Mutex<Option<notify_rust::NotificationHandle>>);

impl Handle {
    const fn new(handle: notify_rust::NotificationHandle) -> Self {
        Self(Mutex::new(Some(handle)))
    }

    /// Takes notify-rust's handle out, leaving nothing.
    fn take(&self) -> Option<notify_rust::NotificationHandle> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner).take()
    }

    /// Runs `work` on the handle, taken out, with the GVL released.
    fn consume<T>(
        ruby: &Ruby,
        rb_self: &Self,
        work: impl FnOnce(notify_rust::NotificationHandle) -> T,
    ) -> Result<Option<T>, Error> {
        let Some(handle) = rb_self.take() else {
            return Ok(None);
        };
        gvl::without_gvl(ruby, |_| work(handle))?
            .map(Some)
            .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
    }

    /// `#native_drop`: drops notify-rust's handle, which sends the
    /// notification if no wait has (`nsusernotifications.rs:142-162`).
    fn drop_handle(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        Self::consume(ruby, rb_self, drop).map(|_| ())
    }

    /// `#native_wait_for_action` (`nsusernotifications.rs:23-62`).
    fn wait_for_action(ruby: &Ruby, rb_self: &Self) -> Result<Option<String>, Error> {
        Ok(Self::consume(ruby, rb_self, |handle| {
            let mut seen = None;
            handle.wait_for_action(|action| seen = Some(action.to_owned()));
            seen
        })?
        .flatten())
    }

    /// `#native_wait_for_response` (`nsusernotifications.rs:64-106`).
    fn wait_for_response(ruby: &Ruby, rb_self: &Self) -> Result<Option<RArray>, Error> {
        let outcome = Self::consume(ruby, rb_self, |handle| {
            let mut seen = None;
            handle
                .wait_for_response(|response: &NotificationResponse| {
                    seen = Some(response.clone());
                })
                .map(|()| seen)
        })?;
        match outcome {
            None => Ok(None),
            Some(Ok(seen)) => Ok(seen.map(|response| values::response_to_ruby(ruby, &response))),
            Some(Err(failure)) => Err(error::notify_error(ruby, &failure)),
        }
    }

    /// `#native_on_close` (`nsusernotifications.rs:108-139`).
    fn on_close(ruby: &Ruby, rb_self: &Self) -> Result<Option<Value>, Error> {
        Ok(Self::consume(ruby, rb_self, |handle| {
            // A close handler is `Fn` (`src/response.rs:145-166`), so it
            // records the reason through a `Cell`.
            let seen = std::cell::Cell::new(None);
            handle.on_close(|reason: notify_rust::CloseReason| seen.set(Some(reason)));
            seen.get()
        })?
        .flatten()
        .map(|reason| values::close_reason_to_ruby(ruby, reason)))
    }
}

/// A handle the garbage collector frees while it still holds a
/// notification (an interrupt between `show` and its block's `ensure` can
/// leave one) drops notify-rust's handle on a thread of its own: the drop
/// sends the notification (`nsusernotifications.rs:142-162`) and waits up
/// to about two seconds, which must not happen inside the collector with
/// the GVL held. A process that exits first may never send it.
impl Drop for Handle {
    fn drop(&mut self) {
        let held = self
            .0
            .get_mut()
            .unwrap_or_else(PoisonError::into_inner)
            .take();
        if let Some(handle) = held {
            std::thread::spawn(move || drop(handle));
        }
    }
}

/// Sends `operation`'s handle-returning call with the GVL released.
fn shown(
    ruby: &Ruby,
    operation: impl FnOnce() -> notify_rust::error::Result<notify_rust::NotificationHandle>,
) -> Result<Obj<Handle>, Error> {
    match gvl::without_gvl(ruby, |_| operation())? {
        Ok(Ok(handle)) => Ok(ruby.obj_wrap(Handle::new(handle))),
        Ok(Err(failure)) => Err(error::notify_error(ruby, &failure)),
        Err(payload) => Err(error::panicked(ruby, &panic_of(&payload))),
    }
}

/// `#native_show` (`src/notification.rs:535-540`): a handle holding a copy;
/// nothing is sent yet.
pub fn show<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>) -> Result<Obj<Handle>, Error> {
    let copy = rb_self.with_ref(ruby, notify_rust::Notification::finalize)?;
    shown(ruby, || copy.show())
}

/// `#native_schedule_raw` (`src/notification.rs:498-505`).
fn schedule_raw(
    ruby: &Ruby,
    rb_self: Obj<Notification>,
    timestamp: f64,
) -> Result<Obj<Handle>, Error> {
    let copy = rb_self.copy(ruby)?;
    shown(ruby, || copy.schedule_raw(timestamp))
}

/// `#native_schedule` (`src/notification.rs:489-496`), given the time's
/// seconds since the epoch, which is what notify-rust reads of a chrono
/// `DateTime` (plan 003, decision 9).
fn schedule(ruby: &Ruby, rb_self: Obj<Notification>, seconds: i64) -> Result<Obj<Handle>, Error> {
    let copy = rb_self.copy(ruby)?;
    let Some(time) = chrono::DateTime::from_timestamp(seconds, 0) else {
        return Err(Error::new(
            ruby.exception_range_error(),
            "time out of range for a chrono DateTime",
        ));
    };
    shown(ruby, || copy.schedule(time))
}

/// The macOS builder methods: only `show`; macOS has no `hint` or
/// `urgency` without `preview-macos-un` (`src/notification.rs:302`, `:386`,
/// `:426`).
macro_rules! define_builder {
    ($class:expr, $holder:ty) => {{
        let class: magnus::RClass = $class;
        class.define_private_method(
            "native_show",
            magnus::method!($crate::platform::show::<$holder>, 0),
        )?;
    }};
}
pub(crate) use define_builder;

/// `schedule` and `schedule_raw`, which only `Notification` has: the macOS
/// handle does not dereference to it.
pub fn define_notification(_ruby: &Ruby, class: RClass) -> Result<(), Error> {
    class.define_private_method("native_schedule_raw", method!(schedule_raw, 1))?;
    class.define_private_method("native_schedule", method!(schedule, 1))?;
    Ok(())
}

/// `Native.set_application` (mac-notification-sys `src/lib.rs:146-158`).
fn set_application(ruby: &Ruby, bundle_ident: String) -> Result<(), Error> {
    let outcome = crate::capture(move || notify_rust::set_application(&bundle_ident));
    match crate::settle(ruby, outcome)? {
        Ok(()) => Ok(()),
        Err(failure) => {
            let target = typed_raise(&failure);
            Err(error::raise(ruby, &target.path, &target.arguments))
        }
    }
}

/// The class for mac-notification-sys's error, read from its typed
/// variant, which `set_application` returns as it is (plan 003,
/// decision 10).
fn typed_raise(failure: &notify_rust::error::MacOsError) -> error::Raise {
    use notify_rust::error::{ApplicationError, MacOsError, NotificationError};

    let application = |leaf: &'static str, name: &str| error::Raise {
        path: vec!["Error", "MacNotificationSys", "Application", leaf],
        arguments: vec![name.to_owned()],
    };
    let notification = |leaf: &'static str| error::Raise {
        path: vec!["Error", "MacNotificationSys", "Notification", leaf],
        arguments: vec![],
    };
    match failure {
        MacOsError::Application(ApplicationError::AlreadySet(name)) => {
            application("AlreadySet", name)
        }
        MacOsError::Application(ApplicationError::CouldNotSet(name)) => {
            application("CouldNotSet", name)
        }
        MacOsError::Notification(NotificationError::ScheduleInThePast) => {
            notification("ScheduleInThePast")
        }
        MacOsError::Notification(NotificationError::UnableToSchedule) => {
            notification("UnableToSchedule")
        }
        MacOsError::Notification(NotificationError::UnableToDeliver) => {
            notification("UnableToDeliver")
        }
    }
}

/// `Native.get_bundle_identifier_or_default` (mac-notification-sys
/// `src/lib.rs:119-123`). It runs `AppleScript`, so the GVL is released.
fn get_bundle_identifier_or_default(ruby: &Ruby, app_name: String) -> Result<String, Error> {
    gvl::without_gvl(ruby, move |_| {
        notify_rust::get_bundle_identifier_or_default(&app_name)
    })?
    .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
}

/// Defines the macOS classes and functions.
pub fn define(ruby: &Ruby, notify_rust: RModule, native: RModule) -> Result<(), Error> {
    let handle = notify_rust.define_class("NotificationHandle", ruby.class_object())?;
    handle.undef_default_alloc_func();
    let _ = <Handle as TypedData>::class(ruby);
    handle.define_private_method("native_drop", method!(Handle::drop_handle, 0))?;
    handle.define_private_method(
        "native_wait_for_action",
        method!(Handle::wait_for_action, 0),
    )?;
    handle.define_private_method(
        "native_wait_for_response",
        method!(Handle::wait_for_response, 0),
    )?;
    handle.define_private_method("native_on_close", method!(Handle::on_close, 0))?;

    native.define_singleton_method("set_application", function!(set_application, 1))?;
    native.define_singleton_method(
        "get_bundle_identifier_or_default",
        function!(get_bundle_identifier_or_default, 1),
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::typed_raise;
    use notify_rust::error::{ApplicationError, MacOsError, NotificationError};

    #[test]
    fn set_applications_errors_keep_their_name_as_it_is() {
        let raise = typed_raise(&MacOsError::from(ApplicationError::CouldNotSet(
            "it's".into(),
        )));
        assert_eq!(
            raise.path,
            ["Error", "MacNotificationSys", "Application", "CouldNotSet"]
        );
        assert_eq!(raise.arguments, ["it's"]);
        let raise = typed_raise(&MacOsError::from(NotificationError::UnableToDeliver));
        assert_eq!(raise.path.last(), Some(&"UnableToDeliver"));
        assert_eq!(raise.arguments, Vec::<String>::new());
    }
}
