// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! The parent window rfd's `set_parent` reads (plan 002, decision 6;
//! plan 008).
//!
//! Ruby passes each handle as a tagged Array built from a handle value:
//! `[:Win32, hwnd, hinstance]`, `[:Xlib, window, visual_id]`,
//! `[:Xcb, window, visual_id]`, or `[:AppKit, window_number]` for the
//! window, and `[:Windows]`, `[:Xlib, display, screen]`,
//! `[:Xcb, connection, screen]`, or `[:AppKit]` for the display. They
//! become a `ParentSpec`, numbers only, under the GVL; the raw handles rfd
//! takes are built from it in `with_parent`, on the thread that calls rfd.
//!
//! Only kinds rfd never dereferences, or that the gem resolves itself,
//! are accepted, so a handle made from a wrong Integer cannot corrupt
//! memory: an `HWND` is a handle Windows validates, the portal backend
//! formats an X11 window ID as text without reading the display (rfd
//! `src/backend/xdg_desktop_portal/window_identifier/mod.rs:33-43`), and
//! an `AppKit` window number is looked up by `AppKit`, on the main thread,
//! which answers nothing for a number that names no window (plan 008,
//! decision 3).

use std::ffi::{c_int, c_ulong, c_void};
use std::num::{NonZeroIsize, NonZeroU32, NonZeroUsize};
use std::ptr::NonNull;

use magnus::{prelude::*, Error, RArray, Ruby, Symbol, Value};
use raw_window_handle::{
    AppKitDisplayHandle, DisplayHandle, HandleError, HasDisplayHandle, HasWindowHandle,
    RawDisplayHandle, RawWindowHandle, Win32WindowHandle, WindowHandle, WindowsDisplayHandle,
    XcbDisplayHandle, XcbWindowHandle, XlibDisplayHandle, XlibWindowHandle,
};

use crate::{capture, platform, Panic};

/// A window as Ruby named it, holding numbers only, so it can cross to
/// the main thread.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WindowSpec {
    /// raw-window-handle's `Win32WindowHandle` (`src/windows.rs:52-57`).
    Win32 {
        hwnd: NonZeroIsize,
        hinstance: Option<NonZeroIsize>,
    },
    /// raw-window-handle's `XlibWindowHandle` (`src/unix.rs:48-53`).
    Xlib { window: c_ulong, visual_id: c_ulong },
    /// raw-window-handle's `XcbWindowHandle` (`src/unix.rs:122-127`).
    Xcb {
        window: NonZeroU32,
        visual_id: Option<NonZeroU32>,
    },
    /// An `AppKit` window by its `windowNumber`, which stands in for
    /// raw-window-handle's `AppKitWindowHandle` (plan 008, decision 1).
    AppKit { window_number: isize },
}

/// A display as Ruby named it; addresses are kept as numbers, never
/// followed (module docs).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum DisplaySpec {
    Windows,
    Xlib {
        display: Option<NonZeroUsize>,
        screen: c_int,
    },
    Xcb {
        connection: Option<NonZeroUsize>,
        screen: c_int,
    },
    AppKit,
}

/// A parent as Ruby described it: the window and display, each absent
/// where the Ruby parent answered `nil` (rfd keeps a handle only if
/// reading it succeeds, `src/file_dialog.rs:100-101`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ParentSpec {
    window: Option<WindowSpec>,
    display: Option<DisplaySpec>,
}

impl ParentSpec {
    /// Whether building the parent looks a window up, which happens on the
    /// main thread (plan 008, decision 3). Only macOS looks one up; the
    /// portal ignores an `AppKit` window (decision 6).
    pub const fn needs_main_thread(&self) -> bool {
        cfg!(target_os = "macos") && matches!(self.window, Some(WindowSpec::AppKit { .. }))
    }
}

/// A parent window for rfd: the two raw handles `set_parent` reads, and
/// on macOS the window and content view an `AppKit` handle names, held
/// retained while the parent lives so the view rfd retains is alive.
pub struct Parent {
    window: Option<RawWindowHandle>,
    display: Option<RawDisplayHandle>,
    #[cfg(target_os = "macos")]
    _looked_up: Option<platform::LookedUp>,
}

impl std::fmt::Debug for Parent {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("Parent")
            .field("window", &self.window)
            .field("display", &self.display)
            .finish_non_exhaustive()
    }
}

impl HasWindowHandle for Parent {
    fn window_handle(&self) -> Result<WindowHandle<'_>, HandleError> {
        let raw = self.window.ok_or(HandleError::Unavailable)?;
        // SAFETY: `borrow_raw` asks that the handle stay valid while the
        // borrow lives. rfd only copies the raw handle out
        // (`src/file_dialog.rs:100`), and every kind `window` holds is
        // either never dereferenced (module docs: Windows checks an
        // `HWND` it is given, and an X11 ID becomes text) or, for
        // `AppKit`, the content view of a window `AppKit` looked up, which
        // `_looked_up` keeps retained for as long as this parent lives,
        // and the parent outlives rfd's call (`with_parent`).
        #[allow(unsafe_code)]
        let handle = unsafe { WindowHandle::borrow_raw(raw) };
        Ok(handle)
    }
}

impl HasDisplayHandle for Parent {
    fn display_handle(&self) -> Result<DisplayHandle<'_>, HandleError> {
        let raw = self.display.ok_or(HandleError::Unavailable)?;
        // SAFETY: as for the window above; rfd reads no display handle of
        // the kinds `display` holds (rfd `window_identifier/mod.rs:33-43`
        // reads one only for Wayland, and the macOS backend none).
        #[allow(unsafe_code)]
        let handle = unsafe { DisplayHandle::borrow_raw(raw) };
        Ok(handle)
    }
}

/// A pointer from an address rfd never follows (module docs).
fn pointer(address: NonZeroUsize) -> NonNull<c_void> {
    NonNull::with_exposed_provenance(address)
}

impl WindowSpec {
    /// The raw handle for every kind but `AppKit`, which `Parent::build`
    /// looks up.
    fn raw(self) -> Option<RawWindowHandle> {
        match self {
            Self::Win32 { hwnd, hinstance } => {
                let mut handle = Win32WindowHandle::new(hwnd);
                handle.hinstance = hinstance;
                Some(RawWindowHandle::Win32(handle))
            }
            Self::Xlib { window, visual_id } => {
                let mut handle = XlibWindowHandle::new(window);
                handle.visual_id = visual_id;
                Some(RawWindowHandle::Xlib(handle))
            }
            Self::Xcb { window, visual_id } => {
                let mut handle = XcbWindowHandle::new(window);
                handle.visual_id = visual_id;
                Some(RawWindowHandle::Xcb(handle))
            }
            Self::AppKit { .. } => None,
        }
    }
}

impl DisplaySpec {
    fn raw(self) -> RawDisplayHandle {
        match self {
            Self::Windows => RawDisplayHandle::Windows(WindowsDisplayHandle::new()),
            Self::Xlib { display, screen } => {
                RawDisplayHandle::Xlib(XlibDisplayHandle::new(display.map(pointer), screen))
            }
            Self::Xcb { connection, screen } => {
                RawDisplayHandle::Xcb(XcbDisplayHandle::new(connection.map(pointer), screen))
            }
            Self::AppKit => RawDisplayHandle::AppKit(AppKitDisplayHandle::new()),
        }
    }
}

impl Parent {
    /// The parent `spec` describes. On macOS an `AppKit` window is looked
    /// up here, which only the main thread may do; off macOS it is no
    /// parent, as the portal ignores it (plan 008, decision 6). The error
    /// is the message `Ferro::Rfd::Error` carries.
    fn build(spec: ParentSpec) -> Result<Self, String> {
        let display = spec.display.map(DisplaySpec::raw);
        #[cfg(target_os = "macos")]
        if let Some(WindowSpec::AppKit { window_number }) = spec.window {
            let looked_up = platform::look_up(window_number)?;
            return Ok(Self {
                window: Some(looked_up.raw()),
                display,
                _looked_up: Some(looked_up),
            });
        }
        Ok(Self {
            window: spec.window.and_then(WindowSpec::raw),
            display,
            #[cfg(target_os = "macos")]
            _looked_up: None,
        })
    }
}

/// Runs `job` with the parent `spec` describes, and returns its value,
/// or the message of the `Ferro::Rfd::Error` to raise, or the panic it
/// caught. A parent that looks a window up runs, with `job`, on the main
/// thread: here when this is it, else through the running app's main
/// thread, as rfd hops there for a sync dialog (rfd
/// `src/backend/macos/utils.rs:20-27`); with no running app it is
/// refused (plan 008, decision 3). The parent lives until `job` returns,
/// and both run before any Ruby value is made. Run it with the GVL
/// released where it may wait for the main thread.
pub fn with_parent<T: Send>(
    spec: Option<ParentSpec>,
    job: impl FnOnce(Option<&Parent>) -> T + Send,
) -> Result<Result<T, String>, Panic> {
    let work = move || {
        capture(move || {
            let parent = spec.map(Parent::build).transpose()?;
            Ok(job(parent.as_ref()))
        })
    };
    if spec.is_some_and(|spec| spec.needs_main_thread()) {
        platform::on_main(work).unwrap_or_else(|refusal| Ok(Err(refusal.to_owned())))
    } else {
        work()
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
fn address(ruby: &Ruby, value: Value) -> Result<Option<NonZeroUsize>, Error> {
    optional(value, |value| {
        NonZeroUsize::new(usize::try_convert(value)?).ok_or_else(|| out_of_range(ruby))
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

/// The window a tagged Array describes.
fn window(ruby: &Ruby, tuple: RArray) -> Result<WindowSpec, Error> {
    let name = tag(tuple)?;
    match name.as_str() {
        "Win32" => Ok(WindowSpec::Win32 {
            hwnd: non_zero_isize(ruby, tuple.entry(1)?)?,
            hinstance: optional(tuple.entry(2)?, |value| non_zero_isize(ruby, value))?,
        }),
        "Xlib" => Ok(WindowSpec::Xlib {
            window: c_ulong::try_convert(tuple.entry(1)?)?,
            visual_id: c_ulong::try_convert(tuple.entry(2)?)?,
        }),
        "Xcb" => Ok(WindowSpec::Xcb {
            window: non_zero_u32(ruby, tuple.entry(1)?)?,
            visual_id: optional(tuple.entry(2)?, |value| non_zero_u32(ruby, value))?,
        }),
        "AppKit" => Ok(WindowSpec::AppKit {
            window_number: isize::try_convert(tuple.entry(1)?)?,
        }),
        other => Err(unknown(ruby, "window", other)),
    }
}

/// The display a tagged Array describes.
fn display(ruby: &Ruby, tuple: RArray) -> Result<DisplaySpec, Error> {
    let name = tag(tuple)?;
    match name.as_str() {
        "Windows" => Ok(DisplaySpec::Windows),
        "Xlib" => Ok(DisplaySpec::Xlib {
            display: address(ruby, tuple.entry(1)?)?,
            screen: c_int::try_convert(tuple.entry(2)?)?,
        }),
        "Xcb" => Ok(DisplaySpec::Xcb {
            connection: address(ruby, tuple.entry(1)?)?,
            screen: c_int::try_convert(tuple.entry(2)?)?,
        }),
        "AppKit" => Ok(DisplaySpec::AppKit),
        other => Err(unknown(ruby, "display", other)),
    }
}

/// The parent a `[window, display]` pair describes, refusing a window
/// kind rfd would panic on here with rfd's own message (plan 002,
/// decision 6).
pub fn parent(ruby: &Ruby, pair: (Option<RArray>, Option<RArray>)) -> Result<ParentSpec, Error> {
    let window = pair.0.map(|tuple| window(ruby, tuple)).transpose()?;
    if let Some(message) = window.as_ref().and_then(platform::refused_handle) {
        return Err(Error::new(ruby.exception_arg_error(), message));
    }
    let display = pair.1.map(|tuple| display(ruby, tuple)).transpose()?;
    Ok(ParentSpec { window, display })
}

/// `Native.check_parent`: refuses a parent `set_parent` cannot take, when
/// it is set rather than when the dialog runs.
pub fn check_parent(ruby: &Ruby, pair: (Option<RArray>, Option<RArray>)) -> Result<(), Error> {
    parent(ruby, pair).map(|_| ())
}

#[cfg(test)]
mod tests {
    use super::{with_parent, Parent, ParentSpec, WindowSpec};
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
            #[cfg(target_os = "macos")]
            _looked_up: None,
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
            #[cfg(target_os = "macos")]
            _looked_up: None,
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

    fn appkit(window_number: isize) -> ParentSpec {
        ParentSpec {
            window: Some(WindowSpec::AppKit { window_number }),
            display: None,
        }
    }

    /// A parent that needs no lookup is built where the job runs.
    #[test]
    fn a_parent_without_a_lookup_runs_its_job_here() {
        let spec = ParentSpec {
            window: Some(WindowSpec::Xlib {
                window: 42,
                visual_id: 0,
            }),
            display: None,
        };
        let here = std::thread::current().id();
        let outcome = with_parent(Some(spec), |parent| {
            (
                std::thread::current().id(),
                parent.and_then(|parent| parent.window_handle().ok().map(|h| h.as_raw()))
                    == Some(RawWindowHandle::Xlib(XlibWindowHandle::new(42))),
            )
        });
        assert_eq!(outcome, Ok(Ok((here, true))));
    }

    /// The test harness runs tests off the main thread, with no app, so
    /// macOS cannot reach the main thread to look the window up; the
    /// portal ignores an `AppKit` window (plan 008, decisions 3 and 6).
    #[test]
    fn an_appkit_window_is_looked_up_only_on_macos() {
        let outcome = with_parent(Some(appkit(7)), |parent| {
            parent.map(|parent| parent.window_handle().is_ok())
        });
        let expected = if !cfg!(target_os = "macos") {
            Ok(Ok(Some(false)))
        } else if crate::platform::is_main_thread() {
            // One test thread runs tests on the main thread, where the
            // lookup runs, and with no app finds no window.
            Ok(Err("no window of this app has window number 7".to_owned()))
        } else {
            Ok(Err(
                "an AppKitWindowHandle is looked up on the main thread, and no NSApplication runs to reach it from this one"
                    .to_owned(),
            ))
        };
        assert_eq!(outcome, expected);
        assert_eq!(appkit(7).needs_main_thread(), cfg!(target_os = "macos"));
    }
}
