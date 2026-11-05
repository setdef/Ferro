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

- `SignedDuration#to_s(precision)`, time's concise `Display` with a precision (Rust's `{:.3}`); a precision from 65,536 up to `usize`'s maximum raises `RangeError` ("Formatting argument out of range"), as Rust's formatter panics, and one from `2**64` up raises Ruby's own `RangeError`.
- The conversions between time's error types: `Error::ComponentRange.try_from`, `Error::TryFromParsed.try_from` and `.from`, `Error::ParseFromDescription.try_from`, `Error::Parse.from`, and `Error::Format.from`, raising `Error::DifferentVariant` for another variant.
- `Error#source`, the error one holds, as time's `Error::source` answers it: a parse error's `Error::TryFromParsed` or `Error::ParseFromDescription` twin, and a nested `ComponentRange`'s `Error::ComponentRange`.
- time's operations with std's `Duration`, which takes any Numeric number of seconds and answers a Rational: `SignedDuration.try_from(seconds)`, `#to_r`, `#unsigned_abs`, `+` and `-` with seconds on either side, `seconds / duration`, and `==` and `<=>` with seconds both ways; `Date#checked_add_std` and `#checked_sub_std`; and `+` and `-` with seconds on `Date`, `Time`, `PlainDateTime`, `UtcDateTime`, `OffsetDateTime`, and `Timestamp`, raising `RangeError` with time's message where Rust panics.
- `Ferro::Time::Ext::NumericalDuration`, `NumericalStdDuration`, and `SystemTimeExt`, time's extension traits as refinements brought in with `using`: `5.seconds`, `1.5.std_minutes`, and `::Time#signed_duration_since`.
- `debug` on every value, iterator, `Parsed`, format item, component, modifier, enum constant, unit, ISO 8601 configuration and enum, and on `Rfc2822` and `Rfc3339`, answering time's `Debug` text as Rust formats it.
- `Weekday#to_i` and `to_i` on the ISO 8601 `FormattedComponents`, `DateKind`, and `OffsetPrecision` variants and on `Modifier::TrailingInput`, Rust's `as` on a fieldless enum.
- `deconstruct` and `to_a` on time's tuple variants, giving the field Rust leaves positional: the name on `Error::Format::InvalidComponent` and `Error::ParseFromDescription::InvalidComponent`, the held `Error::ComponentRange` on `Error::Format::ComponentRange` and `Error::TryFromParsed::ComponentRange`, `nil` on `Error::Format::StdIo`, and the held twin on every error under `Error::Parse::TryFromParsed` and `Error::Parse::ParseFromDescription`, so `in Parse::TryFromParsed[TryFromParsed::ComponentRange[range]]` reads as Rust's pattern does.

### Changed

- **Breaking:** `inspect` is Ruby's own on every class; time's `Debug` text, which `inspect` answered and the constants imitated with their constant paths, moved to `debug`.
- **Breaking:** `SignedDuration#==` and `#<=>` compare with a Numeric as a std `Duration` of that many seconds, as time's `PartialEq` and `PartialOrd` with std's `Duration` do, so `Duration::MINUTE == 60`; and a number on the left of `+`, `-`, `/`, or a comparison now reaches time's std impls instead of raising.
- **Breaking:** integer division of a `SignedDuration` by zero raises `RangeError` ("attempt to divide by zero"), Rust's panic text, instead of `ZeroDivisionError`.
- time's `serde-human-readable` and `serde-well-known` features are no longer built, as ADR 002 drops them; neither reached Ruby.

### Removed

- **Breaking:** `Error::Format::InvalidComponent#component` and `ParseFromDescription::InvalidComponent#name`, readers time never names; use `to_a` or a pattern.
- **Breaking:** `name` and `is_conditional` on `Error::Format::ComponentRange`, `Error::TryFromParsed::ComponentRange`, and `Error::Parse::TryFromParsed::ComponentRange`, readers time gives only the `ComponentRange` they hold; use `source`, `to_a`, or a pattern.

## [0.1.0.pre.4] - 2026-11-02

### Added

- `Iter::DateIter`, `Iter::MonthIter`, `Iter::WeekdayIter`, and `Iter::Rev`, time's iterators, with `Date#iter_to`, `Month.iter_from`, and `Weekday.iter_from`; each includes Enumerable over a copy, and `DateIter#reverse_each` walks back through `next_back`.
- `Unit`, time's units of time, with `per`, `per_t`, ordering, and the `Unit::Unit` enum; the deprecated `Convert` is the same module.

## [0.1.0.pre.3] - 2026-11-01

### Added

- `Timestamp`, time's seconds-and-nanoseconds instant, whole: `new`, `from_seconds` to `from_nanoseconds`, `now`, `MIN`, `MAX`, `UNIX_EPOCH`, every reader and `replace_*`, `checked_` and `saturating_` arithmetic, `+` and `-`, `to_offset`, `to_utc`, `format`, `format_into`, `parse`, `parse_with_defaults`, and `try_from(parsed)`.
- `Timestamp` converts to and from `UtcDateTime`, `OffsetDateTime`, and Ruby's `::Time`, and compares and subtracts with all three.

### Fixed

- An error's arguments could be freed by Ruby's garbage collector before the exception read them, crashing Ruby with a segmentation fault when many errors were raised.

## [0.1.0.pre.2] - 2026-11-01

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

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-time/v0.1.0.pre.4...HEAD
[0.1.0.pre.4]: https://github.com/setdef/Ferro/compare/ferro-time/v0.1.0.pre.3...ferro-time/v0.1.0.pre.4
[0.1.0.pre.3]: https://github.com/setdef/Ferro/compare/ferro-time/v0.1.0.pre.2...ferro-time/v0.1.0.pre.3
[0.1.0.pre.2]: https://github.com/setdef/Ferro/compare/ferro-time/v0.1.0.pre.1...ferro-time/v0.1.0.pre.2
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-time/v0.1.0.pre.1
