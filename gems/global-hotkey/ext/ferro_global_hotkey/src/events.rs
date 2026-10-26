// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: Apache-2.0 OR MIT

//! global-hotkey's event channel and handler (global-hotkey 0.9.0
//! `src/lib.rs:83-133`, plan 004, decisions 4 to 6).
//!
//! global-hotkey keeps its channel in a static whose sender never drops,
//! so every function here reads that one channel. Its handler runs on the
//! thread that saw the key, where no Ruby may run, so the handler this
//! module installs only forwards each event to a second static channel,
//! which a Ruby thread drains.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::LazyLock;
use std::time::{Duration, Instant};

use crossbeam_channel::{unbounded, Receiver, RecvError, RecvTimeoutError, Sender, TryRecvError};
use global_hotkey::GlobalHotKeyEvent;
use magnus::{Error, RArray, Ruby, Symbol};

use crate::error::{error, ok, panicked, Failure};
use crate::gvl::{self, Received};
use crate::panic_of;

/// The channel the forwarding handler sends to, and the Ruby handler
/// thread reads.
static HANDLER: LazyLock<(Sender<GlobalHotKeyEvent>, Receiver<GlobalHotKeyEvent>)> =
    LazyLock::new(unbounded);

/// Whether a Ruby handler thread still reads `HANDLER`. Once it ends,
/// events are dropped instead of kept where nobody reads them.
static HANDLER_OPEN: AtomicBool = AtomicBool::new(true);

/// An event as Ruby builds it: its id and its state's variant name.
type Event = (u32, Symbol);

fn event(ruby: &Ruby, event: GlobalHotKeyEvent) -> Event {
    (event.id(), ruby.to_symbol(format!("{:?}", event.state())))
}

/// The class under `GlobalHotKeyEventReceiver` for one of crossbeam's
/// receive errors, with crossbeam's `Display` text.
fn receive_failure(class: &str, message: &impl ToString) -> Failure {
    Failure::new(
        format!("GlobalHotKeyEventReceiver::{class}"),
        message.to_string(),
    )
}

/// crossbeam's `Receiver::try_recv` (crossbeam-channel 0.5.17
/// `src/channel.rs:765`) on global-hotkey's channel.
pub fn receiver_try_recv(ruby: &Ruby) -> RArray {
    match GlobalHotKeyEvent::receiver().try_recv() {
        Ok(found) => ok(ruby, event(ruby, found)),
        Err(TryRecvError::Empty) => error(
            ruby,
            receive_failure("TryRecvError::Empty", &TryRecvError::Empty),
        ),
        Err(TryRecvError::Disconnected) => error(
            ruby,
            receive_failure("TryRecvError::Disconnected", &TryRecvError::Disconnected),
        ),
    }
}

/// The deadline for a timeout of `seconds`, `None` for one too long for an
/// `Instant` to hold, as crossbeam's `recv_timeout` waits forever then
/// (`src/channel.rs:884-889`). A negative or NaN timeout raises
/// `ArgumentError` with Rust's text, where `Duration::from_secs_f64`
/// would panic.
fn deadline(ruby: &Ruby, seconds: f64) -> Result<Option<Instant>, Error> {
    let timeout = Duration::try_from_secs_f64(seconds)
        .map_err(|reason| Error::new(ruby.exception_arg_error(), reason.to_string()))?;
    Ok(Instant::now().checked_add(timeout))
}

/// The tagged result of a wait on `receiver`.
fn waited(
    ruby: &Ruby,
    outcome: std::thread::Result<Received<GlobalHotKeyEvent>>,
    timed: bool,
) -> RArray {
    match outcome.map_err(|payload| panic_of(&payload)) {
        Ok(Received::Message(found)) => ok(ruby, event(ruby, found)),
        Ok(Received::Timeout) => error(
            ruby,
            receive_failure("RecvTimeoutError::Timeout", &RecvTimeoutError::Timeout),
        ),
        Ok(Received::Disconnected) if timed => error(
            ruby,
            receive_failure(
                "RecvTimeoutError::Disconnected",
                &RecvTimeoutError::Disconnected,
            ),
        ),
        Ok(Received::Disconnected) => error(ruby, receive_failure("RecvError", &RecvError)),
        Err(panic) => error(ruby, panicked(&panic)),
    }
}

/// crossbeam's `recv` (`src/channel.rs:818`), or `recv_timeout`
/// (`:884`) when `seconds` is given, with the GVL released.
pub fn receiver_recv(ruby: &Ruby, seconds: Option<f64>) -> Result<RArray, Error> {
    let deadline = match seconds {
        Some(seconds) => deadline(ruby, seconds)?,
        None => None,
    };
    let outcome = gvl::recv(ruby, GlobalHotKeyEvent::receiver(), deadline)?;
    Ok(waited(ruby, outcome, seconds.is_some()))
}

/// crossbeam's `len` (`src/channel.rs:1025`).
pub fn receiver_len() -> usize {
    GlobalHotKeyEvent::receiver().len()
}

/// crossbeam's `is_empty` (`src/channel.rs:974`).
pub fn receiver_is_empty() -> bool {
    GlobalHotKeyEvent::receiver().is_empty()
}

/// crossbeam's `is_full` (`src/channel.rs:1000`).
pub fn receiver_is_full() -> bool {
    GlobalHotKeyEvent::receiver().is_full()
}

/// crossbeam's `capacity` (`src/channel.rs:1052`): `None`, as the channel
/// is unbounded.
pub fn receiver_capacity() -> Option<usize> {
    GlobalHotKeyEvent::receiver().capacity()
}

/// `GlobalHotKeyEvent::set_event_handler` (`src/lib.rs:112-124`): with
/// `forward`, a handler that sends each event to `HANDLER` while a Ruby
/// thread reads it; without, `None`.
pub fn set_event_handler(forward: bool) {
    if forward {
        GlobalHotKeyEvent::set_event_handler(Some(|found: GlobalHotKeyEvent| {
            if HANDLER_OPEN.load(Ordering::Acquire) {
                let _ = HANDLER.0.send(found);
            }
        }));
    } else {
        GlobalHotKeyEvent::set_event_handler(None::<fn(GlobalHotKeyEvent)>);
    }
}

/// The next event the handler forwarded, waiting with the GVL released.
pub fn handler_recv(ruby: &Ruby) -> Result<RArray, Error> {
    let outcome = gvl::recv(ruby, &HANDLER.1, None)?;
    Ok(waited(ruby, outcome, false))
}

/// Stops forwarding, and drops what was forwarded, once the Ruby handler
/// thread ends.
pub fn handler_close() {
    HANDLER_OPEN.store(false, Ordering::Release);
    HANDLER.1.try_iter().for_each(drop);
}
