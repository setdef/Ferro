// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! rfd's `FileHandle`, rebuilt from its path for each call (plan 002,
//! decision 10). On native platforms it wraps only a path (rfd
//! `src/file_handle/native.rs:112-114`), so the Ruby `FileHandle` keeps the
//! path and these functions run rfd's code on it.

use magnus::{Error, RString, Ruby, Value};
use rfd::FileHandle;

use crate::future::{Future, Output};
use crate::{capture, path_from_ruby, settle};

fn handle(path: Value) -> Result<FileHandle, Error> {
    path_from_ruby(path).map(FileHandle::from)
}

/// `Native.file_name`: rfd's `FileHandle::file_name`, empty when the last
/// component is missing or not UTF-8 (`native.rs:124-131`).
pub fn file_name(ruby: &Ruby, path: Value) -> Result<String, Error> {
    let handle = handle(path)?;
    settle(ruby, capture(|| handle.file_name()))
}

/// `Native.file_handle_debug`: rfd's `Debug`, the path's (`native.rs:173-177`).
pub fn debug(ruby: &Ruby, path: Value) -> Result<String, Error> {
    let handle = handle(path)?;
    settle(ruby, capture(|| format!("{handle:?}")))
}

/// `Native.read`: rfd's `FileHandle::read`, as a `Future` of the bytes
/// (`native.rs:140-147`). It reads on a thread rfd starts when the future
/// is first polled, and panics there if the file cannot be read
/// (`native.rs:51`); `Future#value` raises that as `Ferro::Rfd::Error`.
pub fn read(path: Value) -> Result<Future, Error> {
    let handle = handle(path)?;
    Ok(Future::new(
        Box::pin(async move { Output::Bytes(handle.read().await) }),
        false,
    ))
}

/// `Native.write`: rfd's `FileHandle::write`, as a `Future` that finishes
/// once the bytes are written (`native.rs:149-156`).
pub fn write(path: Value, data: RString) -> Result<Future, Error> {
    let handle = handle(path)?;
    let bytes = data.to_bytes().to_vec();
    Ok(Future::new(
        Box::pin(async move {
            let written = handle.write(&bytes).await;
            Output::Written(handle.path().to_owned(), written)
        }),
        false,
    ))
}
