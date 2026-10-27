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

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-notify-rust/v0.1.0.pre.1...HEAD
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-notify-rust/v0.1.0.pre.1
