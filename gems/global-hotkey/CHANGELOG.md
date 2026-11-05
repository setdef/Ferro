<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-global-hotkey are recorded here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
gem follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for
its own API. Releases are tagged `ferro-global-hotkey/vX.Y.Z`.

## [Unreleased]

### Added

- `TryRecvError#is_empty` and `#is_disconnected`; `RecvTimeoutError#is_timeout` and `#is_disconnected`.
- `TryRecvError.from` and `RecvTimeoutError.from`, which convert a `RecvError` to a `Disconnected` with crossbeam's text.
- `Error::OsError#io_error`, the `io::Error` as a `SystemCallError` on Unix and an `IOError` otherwise.
- `Hotkey::Modifiers::FLAGS`, an Array of `Hotkey::Modifiers::Flag` (`name`, `value`, `is_named`, `is_unnamed`); `Modifiers#known_bits`, `#unknown_bits`, `#contains_unknown_bits`, and `Modifiers.all_named`.

### Changed

- `RecvError.new`, `TryRecvError::Empty.new`, `TryRecvError::Disconnected.new`, `RecvTimeoutError::Timeout.new`, and `RecvTimeoutError::Disconnected.new` carry crossbeam's text as their message, not the class name.

### Fixed

- `GlobalHotKeyEventReceiver#dup` returns a frozen, Ractor-shareable receiver, as documented.
- A handler block or an `iter` or `try_iter` consumer block that raises `StopIteration` no longer ends delivery or iteration silently; the exception propagates like any other.

## [0.1.0.pre.1] - 2026-10-26

### Added

- `Ferro::GlobalHotkey::GlobalHotKeyManager` binding global-hotkey 0.9.0: `new`, `register`, `unregister`, `register_all`, and `unregister_all`.
- `Hotkey::HotKey`, a Data with `mods`, `key`, and `id`: `new(mods, key)`, `from_str`, `try_from`, `matches`, `into_string`, and `to_s`; and `Hotkey::CMD_OR_CTRL`.
- `Hotkey::Code` with a constant for each of keyboard-types 0.8.3's codes and `Code.from_str`; `Hotkey::Modifiers` with its flags and bitflags' methods and operators.
- `GlobalHotKeyEvent` (`id`, `state`), `HotKeyState`, `GlobalHotKeyEvent.receiver`, and `GlobalHotKeyEvent.set_event_handler`, whose handler runs on a Ruby thread the gem starts.
- `GlobalHotKeyEventReceiver` with crossbeam's `try_recv`, `recv`, `recv_timeout`, `iter`, `try_iter`, `is_empty`, `is_full`, `len`, `capacity`, and `same_channel`; `recv` and `recv_timeout` release Ruby's global VM lock, and an interrupt ends them.
- `Error` with a subclass per global-hotkey error variant, `Hotkey::HotKeyParseError` with its three, `Hotkey::UnrecognizedCodeError`, and crossbeam's receive errors. A panic inside global-hotkey raises `Error` instead of ending the process.
- Built with global-hotkey's `serde` and `tracing` features.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-global-hotkey/v0.1.0.pre.1...HEAD
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-global-hotkey/v0.1.0.pre.1
