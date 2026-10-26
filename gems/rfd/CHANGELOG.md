<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-rfd are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for its
own API. Releases are tagged `ferro-rfd/vX.Y.Z`.

## [Unreleased]

## [0.1.0.pre.2] - 2026-10-26

### Added

- `Ferro::Rfd::FileDialog` binding rfd 0.17.2: `new`, `add_filter`, `set_directory`, `set_file_name`, `set_title`, `set_parent`, `set_can_create_directories`, `pick_file`, `pick_files`, `pick_folder`, `pick_folders`, and `save_file`; on macOS also `pick_file_or_folder` and `pick_files_or_folders`.
- `AsyncFileDialog` and `AsyncMessageDialog`, whose terminal methods return a `Future`; `Future#value` waits for it, interruptibly.
- `MessageDialog` (`set_level`, `set_title`, `set_description`, `set_buttons`, `set_parent`, `show`), `MessageLevel`, `MessageButtons` (with `OkCustom`, `OkCancelCustom`, `YesNoCancelCustom`), and `MessageDialogResult` (with `Custom`).
- `FileHandle` (`new`, `file_name`, `path`, `inner`, `read`, `write`, `to_path`).
- Parent windows for `set_parent`: `Win32WindowHandle`, `XlibWindowHandle`, `XcbWindowHandle`, `WindowsDisplayHandle`, `XlibDisplayHandle`, and `XcbDisplayHandle`. AppKit and Wayland handles are not bound.
- `#inspect` on every builder shows rfd's `Debug` text.
- Dialogs release Ruby's global VM lock while open. Calls rfd would panic on raise `ArgumentError` or `Ferro::Rfd::Error` instead: a NUL byte in a filter, a window handle the platform cannot use, and on macOS a dialog off the main thread without a running app; any other panic inside rfd raises `Ferro::Rfd::Error`.
- On Linux, rfd's XDG desktop portal backend (rfd's default); its GTK backend and Windows' `common-controls-v6` are not built.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-rfd/v0.1.0.pre.2...HEAD
[0.1.0.pre.2]: https://github.com/setdef/Ferro/releases/tag/ferro-rfd/v0.1.0.pre.2
