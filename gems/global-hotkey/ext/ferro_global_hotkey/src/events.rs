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
use global_hotkey::{GlobalHotKeyEvent, HotKeyState};
use magnus::{Error, RArray, RString, Ruby, Symbol};

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

/// crossbeam's `Display` text for the error class at `path` under
/// `GlobalHotKeyEventReceiver` (crossbeam-channel 0.5.17
/// `src/err.rs:282-333`), or `None` for any other path.
pub fn receive_error_text(path: RString) -> Result<Option<String>, Error> {
    Ok(error_text(&path.to_string()?))
}

/// `receive_error_text` for a Rust string.
fn error_text(path: &str) -> Option<String> {
    Some(match path {
        "RecvError" => RecvError.to_string(),
        "TryRecvError::Empty" => TryRecvError::Empty.to_string(),
        "TryRecvError::Disconnected" => TryRecvError::Disconnected.to_string(),
        "RecvTimeoutError::Timeout" => RecvTimeoutError::Timeout.to_string(),
        "RecvTimeoutError::Disconnected" => RecvTimeoutError::Disconnected.to_string(),
        _ => return None,
    })
}

/// The `Display` text of `TryRecvError::from(RecvError)` for `"try_recv"`
/// (`src/err.rs:301-307`), or of `RecvTimeoutError::from(RecvError)` for
/// `"recv_timeout"` (`src/err.rs:338-344`); `None` for anything else.
pub fn recv_error_into(target: RString) -> Result<Option<String>, Error> {
    Ok(converted_text(&target.to_string()?))
}

/// `recv_error_into` for a Rust string.
fn converted_text(target: &str) -> Option<String> {
    match target {
        "try_recv" => Some(TryRecvError::from(RecvError).to_string()),
        "recv_timeout" => Some(RecvTimeoutError::from(RecvError).to_string()),
        _ => None,
    }
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
    let timeout =
        timeout(seconds).map_err(|reason| Error::new(ruby.exception_arg_error(), reason))?;
    Ok(Instant::now().checked_add(timeout))
}

/// The `Duration` of `seconds`, or the text `Duration::from_secs_f64`
/// panics with for it (`a_bad_timeout_has_the_panics_text` pins it).
fn timeout(seconds: f64) -> Result<Duration, String> {
    Duration::try_from_secs_f64(seconds).map_err(|reason| reason.to_string())
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
        GlobalHotKeyEvent::set_event_handler(Some(forward_event));
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

/// The handler `set_event_handler` installs: sends `found` to `HANDLER`
/// while a Ruby thread reads it, and drops it after.
fn forward_event(found: GlobalHotKeyEvent) {
    if HANDLER_OPEN.load(Ordering::Acquire) {
        let _ = HANDLER.0.send(found);
    }
}

/// The `HotKeyState` named `name` (`src/lib.rs:63-71`); `TypeError` for
/// any other name.
fn state(ruby: &Ruby, name: Symbol) -> Result<HotKeyState, Error> {
    match &*name.name()? {
        "Pressed" => Ok(HotKeyState::Pressed),
        "Released" => Ok(HotKeyState::Released),
        other => Err(Error::new(
            ruby.exception_type_error(),
            format!("no HotKeyState named {other}"),
        )),
    }
}

/// The `Debug` global-hotkey derives for the `HotKeyState` named `name`
/// (`src/lib.rs:63`): the variant's name.
pub fn state_debug(ruby: &Ruby, name: Symbol) -> Result<String, Error> {
    Ok(format!("{:?}", state(ruby, name)?))
}

/// The `Debug` global-hotkey derives for the event literal
/// `GlobalHotKeyEvent { id, state }` (`src/lib.rs:74-81`).
pub fn event_debug(ruby: &Ruby, id: u32, name: Symbol) -> Result<String, Error> {
    let state = state(ruby, name)?;
    Ok(format!("{:?}", GlobalHotKeyEvent { id, state }))
}

/// crossbeam's `Debug` for the receiver (`src/channel.rs:1189-1193`).
pub fn receiver_debug() -> String {
    format!("{:?}", GlobalHotKeyEvent::receiver())
}

/// Test hooks, built only with the `test-hooks` feature (`Cargo.toml`).
#[cfg(feature = "test-hooks")]
pub mod hooks {
    use global_hotkey::GlobalHotKeyEvent;
    use magnus::{Error, Ruby, Symbol};

    /// Hands the event `{ id, state }` to the handler `set_event_handler`
    /// installs, as global-hotkey does when a key is pressed
    /// (`src/lib.rs:126-132`), so a test drives the handler thread with no
    /// key press.
    pub fn handler_forward(ruby: &Ruby, id: u32, name: Symbol) -> Result<(), Error> {
        let state = super::state(ruby, name)?;
        super::forward_event(GlobalHotKeyEvent { id, state });
        Ok(())
    }

    /// How many forwarded events wait for the Ruby handler thread: none
    /// once it has ended, since `handler_close` stops forwarding.
    pub fn handler_pending() -> usize {
        super::HANDLER.1.len()
    }
}

#[cfg(test)]
mod tests {
    use super::{converted_text, error_text, timeout};
    use std::time::Duration;

    /// A timeout `Duration::from_secs_f64` would panic on is refused with
    /// the text of that panic, which the real panic gives here.
    #[test]
    fn a_bad_timeout_has_the_panics_text() {
        for seconds in [-1.0, f64::NAN, 1e20] {
            let panic = std::panic::catch_unwind(|| Duration::from_secs_f64(seconds))
                .expect_err("from_secs_f64 panics");
            let text = panic
                .downcast_ref::<String>()
                .cloned()
                .or_else(|| panic.downcast_ref::<&str>().map(|text| (*text).to_owned()));
            assert_eq!(timeout(seconds).err(), text);
        }
        assert_eq!(
            timeout(-1.0).err().as_deref(),
            Some("cannot convert float seconds to Duration: value is negative")
        );
        assert_eq!(timeout(1.5), Ok(Duration::from_millis(1500)));
    }

    #[test]
    fn a_states_and_an_events_debug_are_global_hotkeys() {
        use global_hotkey::{GlobalHotKeyEvent, HotKeyState};
        assert_eq!(format!("{:?}", HotKeyState::Released), "Released");
        let event = GlobalHotKeyEvent {
            id: 7,
            state: HotKeyState::Pressed,
        };
        assert_eq!(
            format!("{event:?}"),
            "GlobalHotKeyEvent { id: 7, state: Pressed }"
        );
        assert_eq!(
            format!("{:?}", GlobalHotKeyEvent::receiver()),
            "Receiver { .. }"
        );
    }

    #[test]
    fn each_receive_error_has_crossbeams_display_text() {
        let texts = [
            (
                "RecvError",
                "receiving on an empty and disconnected channel",
            ),
            ("TryRecvError::Empty", "receiving on an empty channel"),
            (
                "TryRecvError::Disconnected",
                "receiving on an empty and disconnected channel",
            ),
            (
                "RecvTimeoutError::Timeout",
                "timed out waiting on receive operation",
            ),
            (
                "RecvTimeoutError::Disconnected",
                "channel is empty and disconnected",
            ),
        ];
        for (path, text) in texts {
            assert_eq!(error_text(path).as_deref(), Some(text));
        }
        assert_eq!(error_text("Nope"), None);
    }

    #[test]
    fn a_recv_error_converts_to_a_disconnected_with_crossbeams_text() {
        assert_eq!(
            converted_text("try_recv").as_deref(),
            Some("receiving on an empty and disconnected channel")
        );
        assert_eq!(
            converted_text("recv_timeout").as_deref(),
            Some("channel is empty and disconnected")
        );
        assert_eq!(converted_text("recv"), None);
    }
}
