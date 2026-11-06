<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-notify-rust are recorded here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
gem follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for
its own API. Releases are tagged `ferro-notify-rust/vX.Y.Z`.

## [Unreleased]

## [0.1.0] - 2026-11-05

### Added

- `to_a` on every variant that carries data (`Timeout::Milliseconds`, `Hint::Category` and the other `Hint` variants, `CloseReason::Other`, `NotificationResponse::Action`, `Reply`, and `Closed`, `ActionResponse::Custom` and `Closed`, `NotificationId::Xdg` and `Mac`), answering what `deconstruct` does.
- `Urgency#to_i`, the integer Rust's `as` gives each variant: Low 0, Normal 1, Critical 2.
- `Notification.default`, notify-rust's `impl Default for Notification`.
- On Linux, `SPEC_VERSION`, notify-rust's own lazily read specification version, loaded the first time it is named, as a `Version` with `major` and `minor` that compares as notify-rust's does.
- `debug` on `Notification`, `NotificationHandle`, every value (`Urgency`, `Timeout`, `CloseReason`, `NotificationResponse`, `ActionResponse`, `Hint`, `NotificationId`, `ServerInformation`; on Linux `Image`, `DbusStack`, `Version`), and every error, answering notify-rust's `Debug` text as Rust formats it; an error notify-rust raised keeps the text of the value it returned.
- `Timeout.from` and `Notification#timeout` take a Rust `Duration` as a non-Integer `Numeric` number of seconds, notify-rust's `From<Duration> for Timeout`; an Integer stays milliseconds.

### Changed

- On Linux, a `NotificationHandle` setter or `update` while another thread's `wait_for_action_async` or `close_async` runs waits for it to end, which Ctrl-C, `Thread#raise`, and `Thread#kill` can cut short, instead of raising `Error` ("already borrowed"); any call while `update` runs waits for it instead of raising ("already mutably borrowed"). From a signal trap on the waiting thread itself it raises `ThreadError`. Breaking: code that rescued `Error` for "already borrowed" or "already mutably borrowed" now waits, or gets `ThreadError`.
- `Error::Conversion.new(reason)` builds notify-rust's message, `Conversion Error: ` and the reason, as `ErrorKind::Conversion` displays it; errors notify-rust raises keep the same message.
- **Breaking:** a `NotificationHandle` works until a call that notify-rust's takes `self` for: `wait_for_action`, `wait_for_response`, `on_close`, and on Linux `close`, and the end of `show`'s block, where Rust drops it. Any later call on it raises `IOError`, instead of waiting again (Linux), returning without calling its block (macOS, Windows), or raising `Error` (Windows setters). On macOS, `show` without a block uses the handle up at once. On Linux, `wait_for_action_async` and `close_async` borrow the handle and leave it usable, and a used-up handle frees its D-Bus connection then, once any borrowing call ends, rather than when garbage-collected; a setter or `update` waiting for its turn then raises `IOError`.
- **Breaking:** a Linux `Future` answers once, as `.await` takes a Rust future: the `value` that returns or raises its outcome uses it up, and a later `value` raises `IOError`; `dup` and `clone` raise `TypeError`.
- **Breaking:** `inspect` is Ruby's own on every class; notify-rust's `Debug` text, which `Notification#inspect` and `Image#inspect` answered and the enum constants imitated, moved to `debug`.
- **Breaking:** a wait without a block (`wait_for_action`, `wait_for_response`, `on_close`, and on Linux `handle_action`) raises `ArgumentError` before it waits, instead of waiting and then losing the answer.
- **Breaking:** `Timeout.from` and `Notification#timeout` read a Float or Rational as seconds, notify-rust's `From<Duration>`, where `Timeout.from` read it as milliseconds and `timeout` raised `TypeError`.
- **Breaking:** an allocated but uninitialized `Notification` raises Ruby's `TypeError` instead of `Error`.

### Removed

- **Breaking:** `Notification.at_bus` (Linux), which notify-rust hides and deprecates as "a test only feature", and the deprecated `actions(list)` setter; the `actions` field still reads and writes through `actions` and `actions=`.

### Fixed

- A blocking call (showing, waiting, `update`, `handle_action`, AppleScript's bundle lookup) no longer stalls every Ruby thread when interrupts keep arriving, or when it is made from an `Exception#backtrace` with one pending: it never runs with the global VM lock held.
- A frozen `Notification`, such as one shared between Ractors, could be reset to a new one by calling `initialize` again through `send`; it now raises `FrozenError`, and so does `update` on a frozen Linux `NotificationHandle`.

## [0.1.0.pre.4] - 2026-11-01

### Fixed

- `Hint.from_key_val` and reading a Linux notification's hints could crash Ruby: the hint's fields were held where the garbage collector does not look while the tag array was allocated.

## [0.1.0.pre.3] - 2026-10-27

### Fixed

- On macOS, `Notification#schedule` accepts a Ruby `Time` again when ferro-time is loaded: it checks for `::Time`, which a bare `Time` inside `Ferro` no longer names once `Ferro::Time` exists.

## [0.1.0.pre.2] - 2026-10-27

### Fixed

- Reading a field of a `Notification` shared between Ractors no longer hangs the process: Ruby values are made after the notification's lock is released, so a garbage collection never waits on a Ractor blocked in that lock.

## [0.1.0.pre.1] - 2026-10-26

### Added

- `Ferro::NotifyRust::Notification` binding notify-rust 4.18.2: `new`, `appname`, `summary`, `subtitle`, `body`, `icon`, `auto_icon`, `image_path`, `sound_name`, `timeout`, `actions` (deprecated), `action`, `id`, `finalize`, `show`, and its public fields as readers and writers; on Linux also `hint`, `hints`, `urgency`, `image_data`, `image`, `show_async`, `show_async_at_bus`, and `Notification.at_bus` (deprecated); on Windows `urgency` and `app_id`; on macOS `schedule` and `schedule_raw`.
- `NotificationHandle` with `wait_for_action`, `wait_for_response`, and `on_close`; on Linux also `close`, `close_async`, `wait_for_action_async`, `update`, and `id`; on Linux and Windows every `Notification` setter and field, as notify-rust's `Deref` gives.
- `show` takes a block: on macOS, where notify-rust sends a notification when its handle drops, the handle drops when the block ends, and `show` without a block sends at once.
- `Urgency`, `Timeout` (with `Milliseconds`), `Hint` and its variants, `CloseReason`, `NotificationResponse`, `ActionResponse`, `NotificationId`, and `ServerInformation`, with notify-rust's conversions (`Urgency.try_from`, `Urgency.from`, `Timeout.from`, `Timeout.from_str`, `Timeout#to_i`, `CloseReason.from`, `Hint.from_key_val`, `Hint#as_bool`, `#as_i32`, `#as_str`).
- On Linux: `get_capabilities`, `get_server_information`, `handle_action`, `dbus_stack`, `DbusStack`, `Image` (`from_rgb`, `from_rgba`, `open`), `ImageError`, and `Future`; on macOS: `set_application` and `get_bundle_identifier_or_default`.
- `Error` with a subclass per notify-rust error kind (`Msg`, `Parse`, `SpecVersion`, `Conversion`, `ImplementationMissing`; `Zbus` and `Image` on Linux; `MacNotificationSys` and mac-notification-sys's kinds under it on macOS). A panic inside notify-rust raises `Error` instead of ending the process.
- Showing and waiting release Ruby's global VM lock; on Linux an interrupt ends a wait.
- Built with notify-rust's `z` (zbus), `images`, and `chrono` features; `d`, `tokio`, `debug_namespace`, and `preview-macos-un` are not built.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-notify-rust/v0.1.0...HEAD
[0.1.0]: https://github.com/setdef/Ferro/compare/ferro-notify-rust/v0.1.0.pre.4...ferro-notify-rust/v0.1.0
[0.1.0.pre.4]: https://github.com/setdef/Ferro/compare/ferro-notify-rust/v0.1.0.pre.3...ferro-notify-rust/v0.1.0.pre.4
[0.1.0.pre.3]: https://github.com/setdef/Ferro/compare/ferro-notify-rust/v0.1.0.pre.2...ferro-notify-rust/v0.1.0.pre.3
[0.1.0.pre.2]: https://github.com/setdef/Ferro/compare/ferro-notify-rust/v0.1.0.pre.1...ferro-notify-rust/v0.1.0.pre.2
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-notify-rust/v0.1.0.pre.1
