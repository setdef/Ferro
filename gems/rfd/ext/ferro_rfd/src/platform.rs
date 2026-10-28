// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! What differs by platform: its name, which window handles rfd takes
//! there, and on macOS, the thread checks rfd would otherwise fail with a
//! panic (plan 002, decisions 5 and 6) and the lookup of a window by its
//! number (plan 008, decision 3).

use crate::handles::WindowSpec;

/// The platform rfd was built for, as Ruby reads it: Linux and the BSDs
/// rfd serves through the XDG desktop portal (rfd `src/backend.rs:8-18`),
/// Windows (`:35-36`), or macOS (`:31-32`).
pub const NAME: &str = if cfg!(target_os = "macos") {
    "macos"
} else if cfg!(windows) {
    "windows"
} else {
    "linux"
};

/// Whether making a future can block. On macOS it can run a whole modal,
/// or wait for the main thread (rfd `src/backend/macos/modal_future.rs:79-119`).
/// Elsewhere it starts nothing: the backends run the dialog on a thread
/// when the future is first polled (`src/backend/win_cid/file_dialog.rs:14-29`,
/// `src/backend/xdg_desktop_portal.rs:19-34`).
pub const CREATION_BLOCKS: bool = cfg!(target_os = "macos");

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
// SPDX-License-Identifier: MIT
// SPDX-SnippetComment: rfd 0.17.2's panic messages, verbatim, from
//   src/backend/macos/utils.rs:29, modal_future.rs:117

/// The message rfd panics with when a dialog starts on another thread
/// while no `NSApplication` runs (rfd `src/backend/macos/utils.rs:29`).
pub const NON_WINDOWED: &str = "You are running RFD in NonWindowed environment, it is impossible to spawn dialog from thread different than main in this env.";

/// The message rfd panics with when an async dialog cannot attach to a
/// running app and is not on the main thread to fall back to a modal
/// (rfd `src/backend/macos/modal_future.rs:117`), typo and missing
/// parenthesis included.
pub const FALLBACK_OFF_MAIN: &str = "Fallback Sync Dialog Must Be Spawned On Main Thread (Why? If async dialog is unsupported in this env, it also means that spawning dialogs outside of main thread is also inpossible";

// SPDX-SnippetEnd

/// What `Future#value` raises on the main thread when the dialog it waits
/// for finishes on the main thread's run loop. rfd has no such message:
/// it would deadlock.
pub const WAIT_ON_MAIN: &str = "waiting on the main thread would deadlock: this dialog finishes on the main thread's run loop, so start it on the main thread and wait for it on another (rfd src/lib.rs:79-86)";

/// What rfd panics with for a window handle it cannot use here: on
/// Windows, any but Win32 (`src/backend/win_cid/file_dialog/dialog_ffi.rs:157`,
/// `:169`, `win_cid/message_dialog.rs:56`); on macOS, any but `AppKit`
/// (`src/backend/macos/utils.rs:43`). The portal backend ignores a handle
/// it cannot use (`window_identifier/mod.rs:41`), so Linux refuses none.
pub const fn refused_handle(window: &WindowSpec) -> Option<&'static str> {
    if cfg!(target_os = "macos") && !matches!(window, WindowSpec::AppKit { .. }) {
        Some(UNSUPPORTED_MACOS)
    } else if cfg!(windows) && !matches!(window, WindowSpec::Win32 { .. }) {
        Some(UNSUPPORTED_WINDOWS)
    } else {
        None
    }
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
// SPDX-License-Identifier: MIT
// SPDX-SnippetComment: rfd 0.17.2's unreachable! messages, verbatim, from
//   src/backend/macos/utils.rs:43, win_cid/file_dialog/dialog_ffi.rs:157

/// rfd's panic for a handle other than `AppKit` on macOS.
const UNSUPPORTED_MACOS: &str = "unsupported window handle, expected: MacOS";

/// rfd's panic for a handle other than Win32 on Windows.
const UNSUPPORTED_WINDOWS: &str = "unsupported window handle, expected: Windows";

// SPDX-SnippetEnd

#[cfg(target_os = "macos")]
mod apple {
    use std::ptr::NonNull;
    use std::sync::atomic::{AtomicPtr, Ordering};

    use objc2::rc::{autoreleasepool, Retained};
    use objc2::runtime::AnyObject;
    use objc2::{msg_send, MainThreadMarker};
    use raw_window_handle::{AppKitWindowHandle, RawWindowHandle};

    #[link(name = "AppKit", kind = "framework")]
    extern "C" {
        /// `AppKit`'s global application object: null until
        /// `+[NSApplication sharedApplication]` first runs, which any
        /// thread may call at any time (rfd does, `utils.rs:24-26`). It is
        /// `mut` because `AppKit` writes it after Rust code runs, and an
        /// immutable extern static mutated then is undefined behavior
        /// (the Rust Reference, `items.extern.static.read-only`).
        static mut NSApp: *mut AnyObject;
    }

    /// Whether this is the main thread.
    pub fn is_main_thread() -> bool {
        MainThreadMarker::new().is_some()
    }

    /// The application, if one exists, read without creating one. rfd
    /// asks `sharedApplication`, which creates the application from
    /// whatever thread calls it (rfd `src/backend/macos/utils.rs:24-26`).
    fn application() -> Option<NonNull<AnyObject>> {
        // SAFETY: `&raw const` takes the static's address without reading
        // or referencing it (the Reference, `items.extern.static.safety`
        // makes the access unsafe because C owns the bit pattern). The
        // global is a pointer, the size and alignment of `AtomicPtr`
        // (std documents `AtomicPtr<T>` as having the same in-memory
        // representation as `*mut T`), and the read is an atomic acquire
        // load. `AppKit`'s own store is a plain aligned pointer store, which
        // no 64-bit Apple CPU tears, so a load racing the creation of the
        // application sees null or the application, never a mix.
        #[allow(unsafe_code)]
        let app =
            unsafe { (*(&raw const NSApp).cast::<AtomicPtr<AnyObject>>()).load(Ordering::Acquire) };
        NonNull::new(app)
    }

    /// Whether an `NSApplication` exists and runs its event loop, read
    /// without creating one.
    pub fn app_running() -> bool {
        let Some(app) = application() else {
            return false;
        };
        // SAFETY: a non-null `NSApp` is the application, which lives for
        // the rest of the process. `isRunning` takes no arguments and
        // returns a BOOL; rfd sends it from any thread too
        // (`src/backend/macos/utils.rs:26`, `modal_future.rs:79`).
        #[allow(unsafe_code)]
        let running: bool = unsafe { msg_send![app.as_ref(), isRunning] };
        running
    }

    /// What `inspect` or a lookup raises from another thread when no app
    /// runs to reach the main thread through (plan 008, decision 5).
    pub const LOOKUP_OFF_MAIN: &str = "an AppKitWindowHandle is looked up on the main thread, and no NSApplication runs to reach it from this one";

    fn no_window(window_number: isize) -> String {
        format!("no window of this app has window number {window_number}")
    }

    fn no_content_view(window_number: isize) -> String {
        format!("window number {window_number} has no content view")
    }

    /// A window `AppKit` found by its number, and its content view, both
    /// retained, so the view stays alive while rfd uses it.
    pub struct LookedUp {
        _window: Retained<AnyObject>,
        view: Retained<AnyObject>,
    }

    impl LookedUp {
        /// raw-window-handle's handle for the window, as tao and winit
        /// make it: the content view (raw-window-handle
        /// `src/appkit.rs:46-110`).
        pub fn raw(&self) -> RawWindowHandle {
            RawWindowHandle::AppKit(AppKitWindowHandle::new(NonNull::from(&*self.view).cast()))
        }
    }

    /// The window of this app numbered `window_number`, looked up by
    /// `-[NSApplication windowWithWindowNumber:]`, which answers `nil` for
    /// a number that names none of the app's windows. Only the main
    /// thread may ask (objc2-app-kit marks `NSApplication` and `NSWindow`
    /// `MainThreadOnly`). With no application, no number names a window,
    /// and none is created.
    pub fn look_up(window_number: isize) -> Result<LookedUp, String> {
        if MainThreadMarker::new().is_none() {
            return Err(LOOKUP_OFF_MAIN.to_owned());
        }
        let app = application().ok_or_else(|| no_window(window_number))?;
        autoreleasepool(|_| {
            // SAFETY: `app` is the application (`application`), and this
            // is the main thread. `windowWithWindowNumber:` takes an
            // `NSInteger` (`isize`) and returns an `NSWindow` or `nil`;
            // `msg_send!` retains the autoreleased result.
            #[allow(unsafe_code)]
            let window: Option<Retained<AnyObject>> =
                unsafe { msg_send![app.as_ref(), windowWithWindowNumber: window_number] };
            let window = window.ok_or_else(|| no_window(window_number))?;
            // SAFETY: `window` is a live `NSWindow`, retained, on the main
            // thread; `contentView` takes no arguments and returns an
            // `NSView` or `nil`, retained by `msg_send!`.
            #[allow(unsafe_code)]
            let view: Option<Retained<AnyObject>> = unsafe { msg_send![&*window, contentView] };
            let view = view.ok_or_else(|| no_content_view(window_number))?;
            Ok(LookedUp {
                _window: window,
                view,
            })
        })
    }

    /// Runs `work` on the main thread: here if this is it, else through a
    /// running app's main queue, which waits for its run loop, as rfd's own
    /// hop does (rfd `src/backend/macos/utils.rs:20-27`); with no running
    /// app, nothing reaches the main thread, and `work` does not run.
    ///
    /// The check and the hop race: an app that stops running between
    /// `app_running` and `exec_sync` leaves this thread waiting for a main
    /// queue nobody drains. rfd's own hop has the same window
    /// (`utils.rs:26-27`), and `AppKit` offers no atomic "run on main if
    /// running". The wait cannot be interrupted, since the GVL is released
    /// with no unblocking function (`gvl.rs`, `without_gvl`).
    pub fn on_main<R: Send>(work: impl FnOnce() -> R + Send) -> Result<R, &'static str> {
        if is_main_thread() {
            Ok(work())
        } else if app_running() {
            Ok(dispatch2::run_on_main(|_| work()))
        } else {
            Err(LOOKUP_OFF_MAIN)
        }
    }
}

#[cfg(target_os = "macos")]
pub use apple::{look_up, on_main, LookedUp};

/// Off macOS, rfd has no thread rules, and these answers refuse nothing.
#[cfg(not(target_os = "macos"))]
mod apple {
    pub const fn is_main_thread() -> bool {
        false
    }

    pub const fn app_running() -> bool {
        true
    }
}

#[cfg(test)]
pub use apple::is_main_thread;

/// rfd's sync dialogs on macOS leave the main thread only for a running
/// app, and panic otherwise (rfd `src/backend/macos/utils.rs:20-31`).
pub fn refuse_sync() -> Option<&'static str> {
    (!apple::is_main_thread() && !apple::app_running()).then_some(NON_WINDOWED)
}

/// rfd's async dialogs on macOS, except a message without a parent,
/// start a sheet on a running app or fall back to a modal on the main
/// thread, and panic otherwise (`modal_future.rs:79-119`); a message
/// without a parent runs on a thread of its own
/// (`src/backend/macos/utils/user_alert.rs:177-196`).
pub fn refuse_async(attaches_to_window: bool) -> Option<&'static str> {
    (attaches_to_window && !apple::is_main_thread() && !apple::app_running())
        .then_some(FALLBACK_OFF_MAIN)
}

/// Whether an async dialog finishes on the main thread's run loop: on
/// macOS, every file dialog and a message with a parent.
pub const fn needs_main_loop(attaches_to_window: bool) -> bool {
    cfg!(target_os = "macos") && attaches_to_window
}

/// A pending macOS sheet finishes in a completion handler on the main
/// thread's run loop (`modal_future.rs:87-103`), which cannot run while
/// the main thread waits for it.
pub fn refuse_wait(needs_main_loop: bool) -> Option<&'static str> {
    (needs_main_loop && apple::is_main_thread()).then_some(WAIT_ON_MAIN)
}

#[cfg(test)]
mod tests {
    use super::{needs_main_loop, refuse_async, refuse_sync, refuse_wait, refused_handle, NAME};
    use crate::handles::WindowSpec;
    use std::num::NonZeroIsize;

    fn win32() -> WindowSpec {
        WindowSpec::Win32 {
            hwnd: NonZeroIsize::new(1).expect("non-zero"),
            hinstance: None,
        }
    }

    const fn xlib() -> WindowSpec {
        WindowSpec::Xlib {
            window: 1,
            visual_id: 0,
        }
    }

    const fn appkit() -> WindowSpec {
        WindowSpec::AppKit { window_number: 1 }
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    // SPDX-License-Identifier: MIT
    // SPDX-SnippetComment: rfd 0.17.2's unreachable! messages, pinned
    #[test]
    fn each_platform_refuses_what_rfd_panics_on() {
        let windows = Some("unsupported window handle, expected: Windows");
        let macos = Some("unsupported window handle, expected: MacOS");
        let expected = match NAME {
            "windows" => [None, windows, windows],
            "macos" => [macos, macos, None],
            _ => [None, None, None],
        };
        assert_eq!(
            [
                refused_handle(&win32()),
                refused_handle(&xlib()),
                refused_handle(&appkit())
            ],
            expected
        );
    }

    // SPDX-SnippetEnd

    #[test]
    fn only_macos_dialogs_need_the_main_loop() {
        assert_eq!(needs_main_loop(true), NAME == "macos");
        assert!(!needs_main_loop(false));
    }

    /// The test harness runs tests off the main thread (unless it runs one
    /// at a time), with no app.
    #[test]
    fn off_the_main_thread_without_an_app_only_macos_refuses() {
        let refuses = NAME == "macos" && !super::apple::is_main_thread();
        assert_eq!(refuse_sync().is_some(), refuses);
        assert_eq!(refuse_async(true).is_some(), refuses);
        assert_eq!(refuse_async(false), None);
        assert_eq!(
            refuse_wait(true).is_some(),
            super::apple::is_main_thread() && NAME == "macos"
        );
    }
}
