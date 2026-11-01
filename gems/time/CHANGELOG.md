<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-time are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for its
own API. Releases are tagged `ferro-time/vX.Y.Z`.

## [Unreleased]

### Added

- `FormatDescription.parse_borrowed` and `parse_owned` with versions 1 and 2, `parse_strftime_borrowed`, `parse_strftime_owned`, and the deprecated `parse`, returning time's format items.
- `FormatDescription::BorrowedFormatItem` and `OwnedFormatItem` with their variants, `Component` with its 43 variants, and `Modifier` with its modifiers and enums, as frozen values with time's builders, conversions, equality, and `Debug`; time's deprecated items warn.
- `format`, `format_into`, and `parse` take a format item or an Array of them.
- `Parsing::Parsed` with time's getters, setters, builders, `parse_item`, `parse_items`, `parse_literal`, and `parse_component`.
- `try_from(parsed)` and `parse_with_defaults` on `Date`, `Time`, `UtcOffset`, `PlainDateTime`, `UtcDateTime`, and `OffsetDateTime`.

### Fixed

- `UtcDateTime.parse` of a local date and time whose UTC instant leaves the year range raises `RangeError` with time's "local datetime out of valid range" instead of `Error` with "time panicked".

### Changed

- `FormatDescription.parse_borrowed` and `parse_owned` raise `TypeError` with time's "invalid version provided" only for versions other than 1, 2, and 3; versions 1 and 2 no longer raise `ArgumentError`.

## [0.1.0.pre.1] - 2026-10-27

### Added

- `Ferro::Time` binding time 0.3.55, with `large-dates` off: `Date`, `Time`, `PlainDateTime` (also `PrimitiveDateTime`), `UtcDateTime`, `OffsetDateTime`, `UtcOffset`, and `SignedDuration` (also `Duration`), frozen values with time's constructors, readers, `replace_*`, `truncate_*`, checked, saturating, and operator arithmetic, equality, ordering, and hashing.
- `Month` and `Weekday` constants with time's methods, `from_str`, `try_from`, and `to_i`.
- `format`, `format_into`, and `parse` on every type with version 3 `FormatDescription` descriptions, `WellKnown::Rfc2822`, `WellKnown::Rfc3339`, and `WellKnown::Iso8601` with any `Config`.
- `OffsetDateTime.from`, `UtcDateTime.from`, `#to_time`, and comparisons with Ruby's `::Time`, as time's `SystemTime` impls.
- `UtcOffset.current_local_offset`, `.local_offset_at`, `OffsetDateTime.now_local`, and `Util` with `refresh_tz`.
- `Error` with a class for each of time's error types and variants, and time's messages. Inputs time panics on raise `RangeError` with time's message instead of ending the process.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-time/v0.1.0.pre.1...HEAD
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-time/v0.1.0.pre.1
