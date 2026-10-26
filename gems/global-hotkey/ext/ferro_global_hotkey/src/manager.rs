// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! `GlobalHotKeyManager` (global-hotkey 0.9.0 `src/lib.rs:135-163`),
//! wrapped for the Ruby class of the same name (plan 004, decision 3).

use global_hotkey::GlobalHotKeyManager;
use magnus::{RArray, Ruby};

use crate::capture;
use crate::error::{classify, panicked, settle, Failure};
use crate::hotkey::{hotkey, Parts};
use crate::owned::{exhume, Owned};

/// Whether this platform's manager must drop on the thread that made it:
/// Carbon on macOS and the window's thread on Windows. Linux's drop only
/// sends its X11 thread a message, which any thread may (`x11/mod.rs:95-99`).
const BOUND: bool = cfg!(any(target_os = "macos", windows));

/// global-hotkey's manager, `Send` so it can move to the graveyard of
/// `owned.rs` and live in a magnus object.
pub struct Platform(GlobalHotKeyManager);

// SAFETY: magnus requires every wrapped type to be `Send`, and Windows'
// manager holds an `HWND` (global-hotkey `windows/mod.rs:22-24`), a raw
// pointer, so it is not. What another thread can do with it is limited to
// two things. It can call `register`, `unregister`, and their `_all`
// forms, which pass the handle to Win32: Microsoft's `RegisterHotKey`
// documentation says it "cannot associate a hot key with a window created
// by another thread", so the call fails and global-hotkey returns
// `Error::OsError`; `UnregisterHotKey` from another thread fails too, as
// `Error::FailedToUnRegister` (UNVERIFIED here: Windows never ran on this
// machine). Neither touches the window. And it can drop it: `Owned` never
// runs the destructor, `DestroyWindow`, off the window's thread, since
// that call cannot destroy another thread's window (Microsoft's
// `DestroyWindow` documentation) and would leave the window and its
// hotkeys registered; it defers the drop to the owner. The window
// procedure runs only on the owner, from its message loop. Removing this
// impl fails to compile on Windows. Clippy's `non_send_fields_in_send_ty`
// names the same `HWND` field; the exception is in clippy_exceptions.rb.
#[cfg(windows)]
#[allow(unsafe_code)]
#[allow(clippy::non_send_fields_in_send_ty)]
unsafe impl Send for Platform {}

/// global-hotkey's manager, owned by a Ruby object.
///
/// Dropping it unregisters every macOS hotkey and removes the Carbon
/// handler, destroys the Windows window, or ends the Linux thread
/// (`macos/mod.rs:291-302`, `windows/mod.rs:26-30`, `x11/mod.rs:95-99`).
/// On macOS and Windows that runs on the thread that made it, deferred
/// when the garbage collector frees it elsewhere (`owned.rs`), and always
/// under `catch_unwind`, since a panic in a sweep would abort the process.
#[magnus::wrap(class = "Ferro::GlobalHotkey::Native::Manager", free_immediately, size)]
pub struct Manager {
    inner: Owned<Platform>,
}

impl Manager {
    fn with<T>(
        &self,
        operation: impl FnOnce(&GlobalHotKeyManager) -> Result<T, Failure>,
    ) -> Result<T, Failure> {
        exhume();
        let manager = self
            .inner
            .get()
            .ok_or_else(|| Failure::new("Error", "the manager was dropped"))?;
        capture(|| operation(&manager.0)).unwrap_or_else(|panic| Err(panicked(&panic)))
    }
}

/// `GlobalHotKeyManager::new` (`src/lib.rs:140-144`).
pub fn manager_new(ruby: &Ruby) -> RArray {
    exhume();
    let made = capture(|| {
        GlobalHotKeyManager::new()
            .map(|manager| Manager {
                inner: Owned::new(Platform(manager), BOUND),
            })
            .map_err(|error| classify(&error))
    })
    .unwrap_or_else(|panic| Err(panicked(&panic)));
    settle(ruby, made)
}

/// `GlobalHotKeyManager::register` (`src/lib.rs:146-148`).
pub fn manager_register(ruby: &Ruby, manager: &Manager, parts: Parts) -> RArray {
    settle(
        ruby,
        manager.with(move |inner| inner.register(hotkey(parts)?).map_err(|e| classify(&e))),
    )
}

/// `GlobalHotKeyManager::unregister` (`src/lib.rs:150-152`).
pub fn manager_unregister(ruby: &Ruby, manager: &Manager, parts: Parts) -> RArray {
    settle(
        ruby,
        manager.with(move |inner| inner.unregister(hotkey(parts)?).map_err(|e| classify(&e))),
    )
}

/// The Rust slice `register_all` and `unregister_all` take.
fn hotkeys(list: Vec<Parts>) -> Result<Vec<global_hotkey::hotkey::HotKey>, Failure> {
    list.into_iter().map(hotkey).collect()
}

/// `GlobalHotKeyManager::register_all` (`src/lib.rs:154-157`).
pub fn manager_register_all(ruby: &Ruby, manager: &Manager, list: Vec<Parts>) -> RArray {
    settle(
        ruby,
        manager.with(move |inner| {
            inner
                .register_all(&hotkeys(list)?)
                .map_err(|e| classify(&e))
        }),
    )
}

/// `GlobalHotKeyManager::unregister_all` (`src/lib.rs:159-162`).
pub fn manager_unregister_all(ruby: &Ruby, manager: &Manager, list: Vec<Parts>) -> RArray {
    settle(
        ruby,
        manager.with(move |inner| {
            inner
                .unregister_all(&hotkeys(list)?)
                .map_err(|e| classify(&e))
        }),
    )
}
