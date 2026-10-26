// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! `Ferro::Rfd::Native::Future`: one of rfd's futures, waited on from Ruby
//! through `Ferro::Rfd::Future` (plan 002, decision 3).
//!
//! rfd's async methods return `impl Future`. Ruby has no futures to poll,
//! so this type keeps rfd's future as it is and polls it when Ruby asks
//! for its value: once with the GVL held, in case it is ready, then with
//! the GVL released until rfd's waker wakes the thread (`gvl::wait`).
//! Ruby's `Future#value` keeps the outcome, so this polls each future to
//! completion at most once.

use std::io;
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::{Mutex, MutexGuard, TryLockError};
use std::task::{Context, Poll, Waker};

use magnus::{method, prelude::*, Error, Exception, RArray, RModule, Ruby, Value};
use rfd::{FileHandle, MessageDialogResult};

use crate::{
    capture, error_class, gvl, panic_of, panic_text, path_to_ruby, platform, rfd_error, Panic,
};

/// What one of rfd's futures finishes with.
pub enum Output {
    /// A file dialog's `pick_file`, `pick_folder`, or `save_file`.
    Handle(Option<FileHandle>),
    /// A file dialog's `pick_files` or `pick_folders`.
    Handles(Option<Vec<FileHandle>>),
    /// A message dialog's `show`.
    Result(MessageDialogResult),
    /// `FileHandle::read`.
    Bytes(Vec<u8>),
    /// `FileHandle::write`, with the path it wrote to.
    Written(PathBuf, io::Result<()>),
}

/// A future of rfd's, mapped to an `Output`.
pub type Pending = Pin<Box<dyn std::future::Future<Output = Output> + Send>>;

impl Output {
    /// `future`, already started, as a `Pending` that finishes with a
    /// `Handle`. The caller has made rfd's call, so on macOS the dialog is
    /// open before this returns.
    pub fn handle(
        future: impl std::future::Future<Output = Option<FileHandle>> + Send + 'static,
    ) -> Pending {
        Box::pin(async move { Self::Handle(future.await) })
    }

    /// `future` as a `Pending` that finishes with `Handles`.
    pub fn handles(
        future: impl std::future::Future<Output = Option<Vec<FileHandle>>> + Send + 'static,
    ) -> Pending {
        Box::pin(async move { Self::Handles(future.await) })
    }

    /// `future` as a `Pending` that finishes with a `Result`.
    pub fn result(
        future: impl std::future::Future<Output = MessageDialogResult> + Send + 'static,
    ) -> Pending {
        Box::pin(async move { Self::Result(future.await) })
    }

    /// The tagged Array Ruby's `Future#value` turns into its value:
    /// `[:handle, path]`, `[:handles, paths]`, `[:result, result]`,
    /// `[:bytes, bytes]`, `[:written, nil]`, or, for a failed write,
    /// `[:raise, exception]` (plan 002, decision 10).
    fn into_ruby(self, ruby: &Ruby) -> Result<RArray, Error> {
        let path = |handle: &FileHandle| path_to_ruby(ruby, handle.path()).as_value();
        Ok(match self {
            Self::Handle(handle) => tagged(
                ruby,
                "handle",
                handle.as_ref().map_or_else(|| ruby.qnil().as_value(), path),
            ),
            Self::Handles(handles) => tagged(
                ruby,
                "handles",
                handles.map_or_else(
                    || ruby.qnil().as_value(),
                    |handles| ruby.ary_from_iter(handles.iter().map(path)).as_value(),
                ),
            ),
            Self::Result(result) => tagged(
                ruby,
                "result",
                crate::dialogs::result_to_ruby(ruby, result).as_value(),
            ),
            Self::Bytes(bytes) => tagged(ruby, "bytes", ruby.str_from_slice(&bytes).as_value()),
            Self::Written(_, Ok(())) => tagged(ruby, "written", ruby.qnil().as_value()),
            Self::Written(target, Err(error)) => {
                tagged(ruby, "raise", io_error(ruby, &target, &error)?.as_value())
            }
        })
    }
}

/// `[tag, value]`, for Ruby's `Future#value`.
fn tagged(ruby: &Ruby, tag: &str, value: Value) -> RArray {
    ruby.ary_new_from_values(&[ruby.to_symbol(tag).as_value(), value])
}

/// The Ruby exception for a failed write: the `Errno` class for its OS
/// error on Unix, naming the path as Ruby's own file methods do, or
/// `IOError` with Rust's message where there is no errno (Windows' codes
/// are not errno values).
fn io_error(ruby: &Ruby, path: &std::path::Path, error: &io::Error) -> Result<Exception, Error> {
    #[cfg(unix)]
    if let Some(errno) = error.raw_os_error() {
        return ruby
            .exception_system_call_error()
            .new_instance((path_to_ruby(ruby, path), errno));
    }
    let _ = path;
    ruby.exception_io_error().new_instance((error.to_string(),))
}

/// What a `Future` holds: rfd's future until it finishes, and whether it
/// finishes on the main thread's run loop.
struct Slot {
    pending: Option<Pending>,
    needs_main_loop: bool,
}

/// The Ruby `Ferro::Rfd::Native::Future`, which `Ferro::Rfd::Future` holds.
///
/// rfd's futures are `Send` (rfd `src/backend.rs:89-90`), and a Ruby
/// object may be reached from several threads, so the future sits behind
/// a `Mutex`. Ruby's `Future#value` lets one thread wait at a time.
#[magnus::wrap(class = "Ferro::Rfd::Native::Future", free_immediately, size)]
pub struct Future(Mutex<Slot>);

impl Future {
    pub const fn new(pending: Pending, needs_main_loop: bool) -> Self {
        Self(Mutex::new(Slot {
            pending: Some(pending),
            needs_main_loop,
        }))
    }

    /// The slot, recovering a lock a panic poisoned: the slot holds no
    /// invariant a panic could break, and a panicked future is dropped
    /// below before the lock is released.
    fn lock(&self, ruby: &Ruby) -> Result<MutexGuard<'_, Slot>, Error> {
        match self.0.try_lock() {
            Ok(slot) => Ok(slot),
            Err(TryLockError::Poisoned(poisoned)) => Ok(poisoned.into_inner()),
            Err(TryLockError::WouldBlock) => {
                Err(rfd_error(ruby, "another thread is waiting on this future"))
            }
        }
    }

    /// `Native::Future#native_value` (private): waits for rfd's future and
    /// returns its tagged output. A panic drops the future and comes back
    /// as `[:raise, Ferro::Rfd::Error]`, so Ruby keeps it as the outcome;
    /// an exception raised here is an interrupt's, or a refusal, and leaves
    /// the future pending.
    fn native_value(ruby: &Ruby, rb_self: &Self) -> Result<RArray, Error> {
        let mut slot = rb_self.lock(ruby)?;
        let needs_main_loop = slot.needs_main_loop;
        let Some(pending) = slot.pending.as_mut() else {
            return Err(rfd_error(ruby, "this future has already finished"));
        };
        let first = capture(|| {
            pending
                .as_mut()
                .poll(&mut Context::from_waker(Waker::noop()))
        });
        let outcome: Result<Output, Panic> = match first {
            Ok(Poll::Ready(output)) => Ok(output),
            Err(panic) => Err(panic),
            Ok(Poll::Pending) => {
                if let Some(message) = platform::refuse_wait(needs_main_loop) {
                    return Err(rfd_error(ruby, message));
                }
                gvl::wait(ruby, |context| pending.as_mut().poll(context))?
                    .map_err(|payload| panic_of(&payload))
            }
        };
        slot.pending = None;
        drop(slot);
        match outcome {
            Ok(output) => output.into_ruby(ruby),
            Err(panic) => {
                let error = error_class(ruby)?.new_instance((panic_text(&panic),))?;
                Ok(tagged(ruby, "raise", error.as_value()))
            }
        }
    }
}

/// Defines `Ferro::Rfd::Native::Future` under `native`.
pub fn define(ruby: &Ruby, native: RModule) -> Result<(), Error> {
    let class = native.define_class("Future", ruby.class_object())?;
    class.undef_default_alloc_func();
    // Resolve magnus's lazy class lookup now, on the main Ractor, as
    // ferro-arboard does: two Ractors making their first future at once
    // would otherwise race to fill it.
    let _ = <Future as magnus::TypedData>::class(ruby);
    class.define_private_method("native_value", method!(Future::native_value, 0))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{Output, Pending};
    use std::task::{Context, Poll, Waker};

    fn poll(pending: &mut Pending) -> Poll<Output> {
        pending
            .as_mut()
            .poll(&mut Context::from_waker(Waker::noop()))
    }

    #[test]
    fn a_handle_future_finishes_with_rfds_value() {
        let path = std::path::PathBuf::from("/tmp/x.txt");
        let handle = rfd::FileHandle::from(path.clone());
        let mut pending = Output::handle(std::future::ready(Some(handle)));
        match poll(&mut pending) {
            Poll::Ready(Output::Handle(Some(handle))) => assert_eq!(handle.path(), path),
            _ => panic!("expected a handle"),
        }
    }

    #[test]
    fn mapping_a_future_starts_nothing_before_it_is_polled() {
        let started = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let flag = std::sync::Arc::clone(&started);
        let mut pending = Output::result(async move {
            flag.store(true, std::sync::atomic::Ordering::SeqCst);
            rfd::MessageDialogResult::Ok
        });
        assert!(!started.load(std::sync::atomic::Ordering::SeqCst));
        assert!(matches!(
            poll(&mut pending),
            Poll::Ready(Output::Result(rfd::MessageDialogResult::Ok))
        ));
        assert!(started.load(std::sync::atomic::Ordering::SeqCst));
    }
}
