// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! What notify-rust compiles for Windows: the toast handle and the
//! `app_id` and `urgency` setters (plan 003, decision 5).
//!
//! `show` builds and shows a toast, and the handle's waits block on a
//! channel the toast's callbacks feed (notify-rust 4.18.2
//! `src/windows.rs:14-48`, `:109-144`). Nothing outside notify-rust can
//! close that channel, so they run with the GVL released and no unblocking
//! function.

use std::sync::{Mutex, MutexGuard, PoisonError, TryLockError};

use magnus::{method, prelude::*, typed_data::Obj, Error, RArray, RModule, Ruby, TypedData, Value};
use notify_rust::NotificationResponse;

use crate::notification::{plain_set, Holds};
use crate::slot::Slot;
use crate::{error, gvl, panic_of, values};

/// The platform's name, as `Ferro::NotifyRust::PLATFORM` reports it.
pub const NAME: &str = "windows";

/// The Ruby `Ferro::NotifyRust::NotificationHandle` on Windows
/// (`src/windows.rs:99-107`). A wait takes notify-rust's handle out, as
/// notify-rust's waits take `self` (`:111`, `:123`, `:136`), and so does
/// the end of `show`'s block, where Rust drops it; afterwards every call
/// raises `IOError` naming the call that took it (plan 003, decision 5;
/// ADR 001, 2026-11-05).
#[magnus::wrap(
    class = "Ferro::NotifyRust::NotificationHandle",
    free_immediately,
    size
)]
pub struct Handle(Mutex<Slot<notify_rust::NotificationHandle>>);

impl Handle {
    const fn new(handle: notify_rust::NotificationHandle) -> Self {
        Self(Mutex::new(Slot::Live(handle)))
    }

    fn lock(&self) -> MutexGuard<'_, Slot<notify_rust::NotificationHandle>> {
        match self.0.try_lock() {
            Ok(guard) => guard,
            Err(TryLockError::Poisoned(poisoned)) => poisoned.into_inner(),
            Err(TryLockError::WouldBlock) => self.0.lock().unwrap_or_else(PoisonError::into_inner),
        }
    }

    /// Takes notify-rust's handle out for the consuming call `by` and runs
    /// `work` on it with the GVL released; raises `IOError` if a consuming
    /// call already took it.
    fn consume<T>(
        ruby: &Ruby,
        rb_self: &Self,
        by: &'static str,
        work: impl FnOnce(notify_rust::NotificationHandle) -> T,
    ) -> Result<T, Error> {
        let taken = rb_self.lock().take(by);
        let handle = taken.map_err(|earlier| error::consumed(ruby, earlier))?;
        gvl::without_gvl(ruby, || work(handle))?
            .map_err(|payload| error::panicked(ruby, &panic_of(&payload)))
    }

    /// `#native_release`: the end of `show`'s block drops notify-rust's
    /// handle, unless a wait has taken it.
    fn release(rb_self: &Self) {
        let handle = rb_self.lock().release("Builder#show");
        drop(handle);
    }

    /// `#native_debug`: notify-rust's derived `Debug` (`src/windows.rs:103`).
    fn debug(ruby: &Ruby, rb_self: &Self) -> Result<String, Error> {
        let text = rb_self.lock().get_mut().map(|handle| format!("{handle:?}"));
        text.map_err(|by| error::consumed(ruby, by))
    }

    /// `#native_wait_for_action` (`src/windows.rs:110-120`).
    fn wait_for_action(ruby: &Ruby, rb_self: &Self) -> Result<Option<String>, Error> {
        Self::consume(
            ruby,
            rb_self,
            "NotificationHandle#wait_for_action",
            |handle| {
                let mut seen = None;
                handle.wait_for_action(|action| seen = Some(action.to_owned()));
                seen
            },
        )
    }

    /// `#native_wait_for_response` (`src/windows.rs:122-133`).
    fn wait_for_response(ruby: &Ruby, rb_self: &Self) -> Result<Option<RArray>, Error> {
        let outcome = Self::consume(
            ruby,
            rb_self,
            "NotificationHandle#wait_for_response",
            |handle| {
                let mut seen = None;
                handle
                    .wait_for_response(|response: &NotificationResponse| {
                        seen = Some(response.clone());
                    })
                    .map(|()| seen)
            },
        )?;
        match outcome {
            Ok(seen) => Ok(seen.map(|response| values::response_to_ruby(ruby, &response))),
            Err(failure) => Err(error::notify_error(ruby, &failure)),
        }
    }

    /// `#native_on_close` (`src/windows.rs:135-143`).
    fn on_close(ruby: &Ruby, rb_self: &Self) -> Result<Option<Value>, Error> {
        Ok(
            Self::consume(ruby, rb_self, "NotificationHandle#on_close", |handle| {
                // A close handler is `Fn` (`src/response.rs:145-166`), so
                // it records the reason through a `Cell`.
                let seen = std::cell::Cell::new(None);
                handle.on_close(|reason: notify_rust::CloseReason| seen.set(Some(reason)));
                seen.get()
            })?
            .map(|reason| values::close_reason_to_ruby(ruby, reason)),
        )
    }
}

impl Holds for Handle {
    fn with<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&mut notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        let mut guard = self.lock();
        // The handle dereferences to its notification, as notify-rust's
        // Windows NotificationHandle does; the call coerces it.
        let outcome = guard.get_mut().map(|handle| operation(handle));
        drop(guard);
        outcome.map_err(|by| error::consumed(ruby, by))
    }

    fn with_ref<R>(
        &self,
        ruby: &Ruby,
        operation: impl FnOnce(&notify_rust::Notification) -> R,
    ) -> Result<R, Error> {
        self.with(ruby, |notification| operation(&*notification))
    }
}

/// `#native_show` (`src/notification.rs:550-554`): shows a copy.
pub fn show<T: Holds + TypedData>(ruby: &Ruby, rb_self: Obj<T>) -> Result<Obj<Handle>, Error> {
    let copy = rb_self.with_ref(ruby, notify_rust::Notification::finalize)?;
    match gvl::without_gvl(ruby, || copy.show())? {
        Ok(Ok(handle)) => Ok(ruby.obj_wrap(Handle::new(handle))),
        Ok(Err(failure)) => Err(error::notify_error(ruby, &failure)),
        Err(payload) => Err(error::panicked(ruby, &panic_of(&payload))),
    }
}

pub fn app_id<T: Holds + TypedData>(
    ruby: &Ruby,
    rb_self: Obj<T>,
    app_id: String,
) -> Result<(), Error> {
    plain_set(ruby, rb_self, move |notification| {
        notification.app_id(&app_id);
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

/// The Windows setters and `show`, on a holder's class.
macro_rules! define_builder {
    ($class:expr, $holder:ty) => {{
        let class: magnus::RClass = $class;
        class.define_private_method(
            "native_app_id",
            magnus::method!($crate::platform::app_id::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_urgency",
            magnus::method!($crate::platform::urgency::<$holder>, 1),
        )?;
        class.define_private_method(
            "native_show",
            magnus::method!($crate::platform::show::<$holder>, 0),
        )?;
    }};
}
pub(crate) use define_builder;

/// Defines the Windows handle.
pub fn define(ruby: &Ruby, notify_rust: RModule, _native: RModule) -> Result<(), Error> {
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
    handle.define_private_method("native_release", method!(Handle::release, 0))?;
    handle.define_private_method("native_debug", method!(Handle::debug, 0))?;
    Ok(())
}
