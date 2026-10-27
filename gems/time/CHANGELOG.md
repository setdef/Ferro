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

- `Ferro::Time` binding time 0.3.55, with `large-dates` off: `Date`, `Time`, `PlainDateTime` (also `PrimitiveDateTime`), `UtcDateTime`, `OffsetDateTime`, `UtcOffset`, and `SignedDuration` (also `Duration`), frozen values with time's constructors, readers, `replace_*`, `truncate_*`, checked, saturating, and operator arithmetic, equality, ordering, and hashing.
- `Month` and `Weekday` constants with time's methods, `from_str`, `try_from`, and `to_i`.
- `format`, `format_into`, and `parse` on every type with version 3 `FormatDescription` descriptions, `WellKnown::Rfc2822`, `WellKnown::Rfc3339`, and `WellKnown::Iso8601` with any `Config`.
- `OffsetDateTime.from`, `UtcDateTime.from`, `#to_time`, and comparisons with Ruby's `::Time`, as time's `SystemTime` impls.
- `UtcOffset.current_local_offset`, `.local_offset_at`, `OffsetDateTime.now_local`, and `Util` with `refresh_tz`.
- `Error` with a class for each of time's error types and variants, and time's messages. Inputs time panics on raise `RangeError` with time's message instead of ending the process.

[Unreleased]: https://github.com/setdef/Ferro/commits/trunk/gems/time
