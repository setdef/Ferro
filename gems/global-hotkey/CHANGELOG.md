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

- `Ferro::GlobalHotkey::GlobalHotKeyManager` binding global-hotkey 0.9.0: `new`, `register`, `unregister`, `register_all`, and `unregister_all`.
- `Hotkey::HotKey`, a Data with `mods`, `key`, and `id`: `new(mods, key)`, `from_str`, `try_from`, `matches`, `into_string`, and `to_s`; and `Hotkey::CMD_OR_CTRL`.
- `Hotkey::Code` with a constant for each of keyboard-types 0.8.3's codes and `Code.from_str`; `Hotkey::Modifiers` with its flags and bitflags' methods and operators.
- `GlobalHotKeyEvent` (`id`, `state`), `HotKeyState`, `GlobalHotKeyEvent.receiver`, and `GlobalHotKeyEvent.set_event_handler`, whose handler runs on a Ruby thread the gem starts.
- `GlobalHotKeyEventReceiver` with crossbeam's `try_recv`, `recv`, `recv_timeout`, `iter`, `try_iter`, `is_empty`, `is_full`, `len`, `capacity`, and `same_channel`; `recv` and `recv_timeout` release Ruby's global VM lock, and an interrupt ends them.
- `Error` with a subclass per global-hotkey error variant, `Hotkey::HotKeyParseError` with its three, `Hotkey::UnrecognizedCodeError`, and crossbeam's receive errors. A panic inside global-hotkey raises `Error` instead of ending the process.
- Built with global-hotkey's `serde` and `tracing` features.
