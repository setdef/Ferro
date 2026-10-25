<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-arboard are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for its
own API. Releases are tagged `ferro-arboard/vX.Y.Z`.

## [Unreleased]

## [0.1.0.pre.2] - 2026-10-25

### Added

- `Ferro::Arboard::Clipboard` binding arboard 3.7.0: `new`, `get_text`, `set_text`, `set_html`, `get_image`, `set_image`, `clear`, `clear_with`, `get`, and `set`.
- `Get` (`text`, `image`, `html`, `file_list`), `Set` (`text`, `html`, `image`, `file_list`), and `Clear` (`default`) builders.
- `ImageData`, a `Data` of `width`, `height`, and RGBA `bytes`.
- `Error` with `ContentNotAvailable`, `ClipboardNotSupported`, `ClipboardOccupied`, `ConversionFailure`, and `Unknown` (with `description`), each carrying arboard's message.
- Linux only: `LinuxClipboardKind`, `GetExtLinux#clipboard`, `SetExtLinux` (`wait`, `wait_until`, `wait_once`, `clipboard`, `exclude_from_history`), and `ClearExtLinux#clipboard`.
- macOS only: `SetExtApple#exclude_from_history`. Windows only: `SetExtWindows` (`exclude_from_monitoring`, `exclude_from_cloud`, `exclude_from_history`).
- Images arboard would panic on (a zero width or height, or a byte count other than `width * height * 4`) raise `Error::ConversionFailure` instead; any panic inside arboard raises `Error` instead of ending the process.
- Calls that can block (Linux reads and waiting writes) release Ruby's global VM lock, so other threads run meanwhile; the extension is Ractor-safe, and a frozen `Clipboard` is shareable.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-arboard/v0.1.0.pre.2...HEAD
[0.1.0.pre.2]: https://github.com/setdef/Ferro/releases/tag/ferro-arboard/v0.1.0.pre.2
