// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! The parent window rfd's `set_parent` reads (plan 002, decision 6).
//!
//! Ruby passes each handle as a tagged Array built from the gem's handle
//! values: `[:Win32, hwnd, hinstance]`, `[:Xlib, window, visual_id]`, or
//! `[:Xcb, window, visual_id]` for the window, and `[:Windows]`,
//! `[:Xlib, display, screen]`, or `[:Xcb, connection, screen]` for the
//! display. Only kinds rfd never dereferences are accepted, so a handle
//! made from a wrong Integer cannot corrupt memory: an `HWND` is a handle
//! Windows validates, and the portal backend formats an X11 window ID as
//! text without reading the display (rfd
//! `src/backend/xdg_desktop_portal/window_identifier/mod.rs:33-43`).

use std::ffi::{c_int, c_ulong, c_void};
use std::num::{NonZeroIsize, NonZeroU32};
use std::ptr::NonNull;

use magnus::{prelude::*, Error, RArray, Ruby, Symbol, Value};
use raw_window_handle::{
    DisplayHandle, HandleError, HasDisplayHandle, HasWindowHandle, RawDisplayHandle,
    RawWindowHandle, Win32WindowHandle, WindowHandle, WindowsDisplayHandle, XcbDisplayHandle,
    XcbWindowHandle, XlibDisplayHandle, XlibWindowHandle,
};

use crate::platform;

/// A parent window for rfd: the two handles `set_parent` reads, each
/// absent when the Ruby parent answered `nil` (rfd keeps a handle only if
/// reading it succeeds, `src/file_dialog.rs:100-101`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Parent {
    window: Option<RawWindowHandle>,
    display: Option<RawDisplayHandle>,
}

impl HasWindowHandle for Parent {
    fn window_handle(&self) -> Result<WindowHandle<'_>, HandleError> {
        let raw = self.window.ok_or(HandleError::Unavailable)?;
        // SAFETY: `borrow_raw` asks that the handle stay valid while the
        // borrow lives. rfd only copies the raw handle out
        // (`src/file_dialog.rs:100`), and the kinds `window` accepts are
        // never dereferenced (module docs): Windows checks an `HWND` it is
        // given, and an X11 ID becomes text. A handle to a window that is
        // gone makes the dialog fail or ignore it, which rfd reports as
        // `None`.
        #[allow(unsafe_code)]
        let handle = unsafe { WindowHandle::borrow_raw(raw) };
        Ok(handle)
    }
}

impl HasDisplayHandle for Parent {
    fn display_handle(&self) -> Result<DisplayHandle<'_>, HandleError> {
        let raw = self.display.ok_or(HandleError::Unavailable)?;
        // SAFETY: as for the window above; rfd reads no display handle of
        // the kinds `display` accepts (rfd
        // `window_identifier/mod.rs:33-43` reads one only for Wayland).
        #[allow(unsafe_code)]
        let handle = unsafe { DisplayHandle::borrow_raw(raw) };
        Ok(handle)
    }
}

/// The `RangeError` for a zero where raw-window-handle holds a `NonZero`
/// integer, with the text Rust gives when it converts one
/// (`TryFromIntError`).
fn out_of_range(ruby: &Ruby) -> Error {
    let message = NonZeroU32::try_from(0_u32)
        .err()
        .map_or_else(String::new, |error| error.to_string());
    Error::new(ruby.exception_range_error(), message)
}

fn non_zero_isize(ruby: &Ruby, value: Value) -> Result<NonZeroIsize, Error> {
    NonZeroIsize::new(isize::try_convert(value)?).ok_or_else(|| out_of_range(ruby))
}

fn non_zero_u32(ruby: &Ruby, value: Value) -> Result<NonZeroU32, Error> {
    NonZeroU32::new(u32::try_convert(value)?).ok_or_else(|| out_of_range(ruby))
}

fn optional<T>(
    value: Value,
    convert: impl FnOnce(Value) -> Result<T, Error>,
) -> Result<Option<T>, Error> {
    if value.is_nil() {
        Ok(None)
    } else {
        convert(value).map(Some)
    }
}

/// A pointer-sized address from Ruby, or `None` for `nil`. rfd never
/// dereferences the display pointers this carries (module docs).
fn address(ruby: &Ruby, value: Value) -> Result<Option<NonNull<c_void>>, Error> {
    optional(value, |value| {
        let address = usize::try_convert(value)?;
        NonNull::new(std::ptr::with_exposed_provenance_mut::<c_void>(address))
            .ok_or_else(|| out_of_range(ruby))
    })
}

fn tag(tuple: RArray) -> Result<String, Error> {
    let tag: Symbol = tuple.entry(0)?;
    Ok(tag.name()?.into_owned())
}

fn unknown(ruby: &Ruby, what: &str, name: &str) -> Error {
    Error::new(
        ruby.exception_arg_error(),
        format!("unknown {what} handle {name}"),
    )
}

/// The raw window handle a tagged Array describes.
fn window(ruby: &Ruby, tuple: RArray) -> Result<RawWindowHandle, Error> {
    let name = tag(tuple)?;
    match name.as_str() {
        "Win32" => {
            let mut handle = Win32WindowHandle::new(non_zero_isize(ruby, tuple.entry(1)?)?);
            handle.hinstance = optional(tuple.entry(2)?, |value| non_zero_isize(ruby, value))?;
            Ok(RawWindowHandle::Win32(handle))
        }
        "Xlib" => {
            let mut handle = XlibWindowHandle::new(c_ulong::try_convert(tuple.entry(1)?)?);
            handle.visual_id = c_ulong::try_convert(tuple.entry(2)?)?;
            Ok(RawWindowHandle::Xlib(handle))
        }
        "Xcb" => {
            let mut handle = XcbWindowHandle::new(non_zero_u32(ruby, tuple.entry(1)?)?);
            handle.visual_id = optional(tuple.entry(2)?, |value| non_zero_u32(ruby, value))?;
            Ok(RawWindowHandle::Xcb(handle))
        }
        other => Err(unknown(ruby, "window", other)),
    }
}

/// The raw display handle a tagged Array describes.
fn display(ruby: &Ruby, tuple: RArray) -> Result<RawDisplayHandle, Error> {
    let name = tag(tuple)?;
    match name.as_str() {
        "Windows" => Ok(RawDisplayHandle::Windows(WindowsDisplayHandle::new())),
        "Xlib" => Ok(RawDisplayHandle::Xlib(XlibDisplayHandle::new(
            address(ruby, tuple.entry(1)?)?,
            c_int::try_convert(tuple.entry(2)?)?,
        ))),
        "Xcb" => Ok(RawDisplayHandle::Xcb(XcbDisplayHandle::new(
            address(ruby, tuple.entry(1)?)?,
            c_int::try_convert(tuple.entry(2)?)?,
        ))),
        other => Err(unknown(ruby, "display", other)),
    }
}

/// The parent a `[window, display]` pair describes, refusing a window
/// kind rfd would panic on here with rfd's own message (plan 002,
/// decision 6).
pub fn parent(ruby: &Ruby, pair: (Option<RArray>, Option<RArray>)) -> Result<Parent, Error> {
    let window = pair.0.map(|tuple| window(ruby, tuple)).transpose()?;
    if let Some(message) = window.as_ref().and_then(platform::refused_handle) {
        return Err(Error::new(ruby.exception_arg_error(), message));
    }
    let display = pair.1.map(|tuple| display(ruby, tuple)).transpose()?;
    Ok(Parent { window, display })
}

/// `Native.check_parent`: refuses a parent `set_parent` cannot take, when
/// it is set rather than when the dialog runs.
pub fn check_parent(ruby: &Ruby, pair: (Option<RArray>, Option<RArray>)) -> Result<(), Error> {
    parent(ruby, pair).map(|_| ())
}

#[cfg(test)]
mod tests {
    use super::Parent;
    use raw_window_handle::{
        HandleError, HasDisplayHandle, HasWindowHandle, RawDisplayHandle, RawWindowHandle,
        WindowsDisplayHandle, XlibWindowHandle,
    };
    use std::num::NonZeroU32;

    #[test]
    fn a_parent_lends_rfd_the_handles_it_holds() {
        let window = RawWindowHandle::Xlib(XlibWindowHandle::new(42));
        let display = RawDisplayHandle::Windows(WindowsDisplayHandle::new());
        let parent = Parent {
            window: Some(window),
            display: Some(display),
        };
        assert_eq!(
            parent.window_handle().map(|h| h.as_raw()).ok(),
            Some(window)
        );
        assert_eq!(
            parent.display_handle().map(|h| h.as_raw()).ok(),
            Some(display)
        );
    }

    #[test]
    fn a_missing_handle_is_unavailable_which_rfd_keeps_as_none() {
        let parent = Parent {
            window: None,
            display: None,
        };
        assert!(matches!(
            parent.window_handle(),
            Err(HandleError::Unavailable)
        ));
        assert!(matches!(
            parent.display_handle(),
            Err(HandleError::Unavailable)
        ));
        let dialog = rfd::FileDialog::new().set_parent(&parent);
        assert!(format!("{dialog:?}").contains("parent: None, parent_display: None"));
    }

    /// The Ruby side refuses a zero with this text (`out_of_range`).
    #[test]
    fn a_zero_reads_as_rusts_out_of_range_error() {
        assert_eq!(
            NonZeroU32::try_from(0_u32).map_err(|error| error.to_string()),
            Err("number would be zero for non-zero type".to_owned())
        );
    }
}
