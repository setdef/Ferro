// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's operations with std's `Duration` (ADR 001, 2026-11-05: any
//! Numeric number of seconds in, a Rational number of seconds out).
//!
//! Ruby hands a std `Duration` over as its whole seconds and nanoseconds,
//! `[seconds, nanoseconds]`, which `Std` reads; `lib/ferro/time/arguments.rb`
//! makes the pair from a Numeric. A std `Duration` coming back crosses as
//! its whole nanoseconds, which Ruby divides into a Rational. Every
//! operator time documents as panicking is refused first, with
//! `RangeError` and the panic's text, and the tests drive each real
//! operator into its panic and compare messages.

use std::cmp::Ordering;
use std::time::Duration as StdDuration;

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, TryConvert, Value};
use time::{Date, OffsetDateTime, PlainDateTime, SignedDuration, Time, Timestamp, UtcDateTime};

use crate::calendar::unknown;
use crate::datetime::OUT_OF_RANGE;
use crate::timestamp::CONVERTING;
use crate::values::{NDate, NDuration, NOffsetDateTime, NPlain, NTime, NTimestamp, NUtc};
use crate::{duration, frozen, frozen_option, guarded, Failure};

/// A std `Duration` from Ruby's `[seconds, nanoseconds]`. magnus refuses
/// seconds outside `u64` with `RangeError`, as it refuses every Integer
/// outside a Rust parameter's type (plan 007, decision 8).
#[derive(Clone, Copy)]
pub struct Std(pub StdDuration);

impl TryConvert for Std {
    fn try_convert(value: Value) -> Result<Self, Error> {
        let (seconds, nanoseconds): (u64, u32) = TryConvert::try_convert(value)?;
        if nanoseconds >= 1_000_000_000 {
            let ruby = Ruby::get_with(value);
            return Err(Error::new(
                ruby.exception_arg_error(),
                format!("{nanoseconds} nanoseconds is not under a second"),
            ));
        }
        Ok(Self(StdDuration::new(seconds, nanoseconds)))
    }
}

/// The seconds and nanoseconds of `Duration::try_from_secs_f64(seconds)`,
/// or `ArgumentError` with core's text where `Duration::from_secs_f64`
/// would panic: a negative, NaN, or infinite count, or one past the
/// range. core rounds a Float to the nearest nanosecond, ties to even
/// (`library/core/src/time.rs:1900-1937` at Rust 1.99.1).
fn std_from_secs_f64(ruby: &Ruby, seconds: f64) -> Result<(u64, u32), Error> {
    let value = guarded(ruby, || {
        StdDuration::try_from_secs_f64(seconds)
            .map_err(|failure| Failure::Argument(failure.to_string()))
    })?;
    Ok((value.as_secs(), value.subsec_nanos()))
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic messages and conditions of time 0.3.55's
//   operators with std's Duration (src/signed_duration.rs:1423-1625,
//   src/date.rs:1675-1737, src/plain_date_time.rs:1201-1300,
//   src/utc_date_time.rs:1335-1412, src/offset_date_time.rs:1686-1790,
//   src/timestamp.rs:1464-1540)

/// The message of `Add<StdDuration> for Date`'s overflow.
const DATE_ADD: &str = "overflow adding duration to date";

/// The message of `Sub<StdDuration> for Date`'s overflow.
const DATE_SUB: &str = "overflow subtracting duration from date";

/// `SignedDuration::try_from(std)` as the operators' `expect` takes it.
fn converted(std: StdDuration) -> Result<SignedDuration, Failure> {
    SignedDuration::try_from(std).map_err(|_| Failure::Range(CONVERTING.to_owned()))
}

/// `Add<StdDuration> for SignedDuration` (`:1471-1483`), and
/// `Add<SignedDuration> for StdDuration`, which is `rhs + self`
/// (`:1485-1497`).
pub fn add(value: SignedDuration, std: StdDuration) -> Result<SignedDuration, Failure> {
    duration::add(value, converted(std)?)
}

/// `Sub<StdDuration> for SignedDuration` (`:1561-1573`).
pub fn sub(value: SignedDuration, std: StdDuration) -> Result<SignedDuration, Failure> {
    duration::sub(value, converted(std)?)
}

/// `Sub<SignedDuration> for StdDuration` (`:1575-1589`).
pub fn rsub(std: StdDuration, value: SignedDuration) -> Result<SignedDuration, Failure> {
    duration::sub(converted(std)?, value)
}

/// `Add<StdDuration>` for a date and time whose time wraps into the next
/// day: time adds the whole days to the date with `Date + std`, which
/// panics with Date's message, then steps a day if the time wrapped, which
/// panics with `OUT_OF_RANGE` (`plain_date_time.rs:1201-1220`,
/// `offset_date_time.rs:1686-1706`). The time wraps exactly when the new
/// time is earlier than the old, since the part of a day time adds is
/// under a day.
fn add_date_time(date: Date, time: Time, std: StdDuration) -> Result<(), Failure> {
    let date = date
        .checked_add_std(std)
        .ok_or_else(|| Failure::Range(DATE_ADD.to_owned()))?;
    if time + std < time && date.next_day().is_none() {
        return Err(Failure::Range(OUT_OF_RANGE.to_owned()));
    }
    Ok(())
}

/// `Sub<StdDuration>`, as `add_date_time` (`plain_date_time.rs:1261-1280`,
/// `offset_date_time.rs:1747-1767`).
fn sub_date_time(date: Date, time: Time, std: StdDuration) -> Result<(), Failure> {
    let date = date
        .checked_sub_std(std)
        .ok_or_else(|| Failure::Range(DATE_SUB.to_owned()))?;
    if time - std > time && date.previous_day().is_none() {
        return Err(Failure::Range(OUT_OF_RANGE.to_owned()));
    }
    Ok(())
}

/// `Add<StdDuration>` or `Sub<StdDuration>` for `Date` (`date.rs:1675-1737`).
pub fn date(value: Date, name: &str, std: StdDuration) -> Result<Option<Date>, Failure> {
    Ok(match name {
        "checked_add_std" => value.checked_add_std(std),
        "checked_sub_std" => value.checked_sub_std(std),
        "+" => Some(
            value
                .checked_add_std(std)
                .ok_or_else(|| Failure::Range(DATE_ADD.to_owned()))?,
        ),
        "-" => Some(
            value
                .checked_sub_std(std)
                .ok_or_else(|| Failure::Range(DATE_SUB.to_owned()))?,
        ),
        other => return Err(unknown("Date", other)),
    })
}

/// `Add<StdDuration>` or `Sub<StdDuration>` for `PlainDateTime`.
pub fn plain(value: PlainDateTime, name: &str, std: StdDuration) -> Result<PlainDateTime, Failure> {
    match name {
        "+" => add_date_time(value.date(), value.time(), std).map(|()| value + std),
        "-" => sub_date_time(value.date(), value.time(), std).map(|()| value - std),
        other => Err(unknown("PlainDateTime", other)),
    }
}

/// `Add<StdDuration>` or `Sub<StdDuration>` for `UtcDateTime`, which adds
/// to its `PlainDateTime` in UTC (`utc_date_time.rs:1335-1412`).
pub fn utc(value: UtcDateTime, name: &str, std: StdDuration) -> Result<UtcDateTime, Failure> {
    match name {
        "+" => add_date_time(value.date(), value.time(), std).map(|()| value + std),
        "-" => sub_date_time(value.date(), value.time(), std).map(|()| value - std),
        other => Err(unknown("UtcDateTime", other)),
    }
}

/// `Add<StdDuration>` or `Sub<StdDuration>` for `OffsetDateTime`, which
/// adds to its local date and time and keeps the offset.
pub fn offset(
    value: OffsetDateTime,
    name: &str,
    std: StdDuration,
) -> Result<OffsetDateTime, Failure> {
    match name {
        "+" => add_date_time(value.date(), value.time(), std).map(|()| value + std),
        "-" => sub_date_time(value.date(), value.time(), std).map(|()| value - std),
        other => Err(unknown("OffsetDateTime", other)),
    }
}

/// What `Add<StdDuration> for Timestamp` panics with past its range: its
/// `expect` on the private `add_std`, whose error is always
/// `Overflow::Positive` for a span added, and `Result::expect` appends
/// the error's `Debug` text (`timestamp.rs:862-886`, `:1464-1475`).
const TIMESTAMP_ADD: &str = "resulting value is out of range: Positive";

/// What `Sub<StdDuration> for Timestamp` panics with: `sub_std` fails
/// only with `Overflow::Negative` (`timestamp.rs:890-914`, `:1513-1524`).
const TIMESTAMP_SUB: &str = "resulting value is out of range: Negative";

/// `Add<StdDuration>` or `Sub<StdDuration>` for `Timestamp`, refused past
/// its range. A std `Duration` too long for a `SignedDuration` leaves
/// every timestamp's range, so the checked `SignedDuration` arithmetic
/// finds the same edge.
pub fn timestamp(value: Timestamp, name: &str, std: StdDuration) -> Result<Timestamp, Failure> {
    let span = SignedDuration::try_from(std).ok();
    let (fits, message) = match name {
        "+" => (
            span.and_then(|span| value.checked_add(span)).is_some(),
            TIMESTAMP_ADD,
        ),
        "-" => (
            span.and_then(|span| value.checked_sub(span)).is_some(),
            TIMESTAMP_SUB,
        ),
        other => return Err(unknown("Timestamp", other)),
    };
    if !fits {
        return Err(Failure::Range(message.to_owned()));
    }
    Ok(if name == "+" {
        value + std
    } else {
        value - std
    })
}

// SPDX-SnippetEnd

/// The whole nanoseconds of `std`, which Ruby divides into a Rational.
const fn nanoseconds(std: StdDuration) -> u128 {
    std.as_nanos()
}

/// `SignedDuration::unsigned_abs` (`signed_duration.rs:375-391`).
fn duration_unsigned_abs(ruby: &Ruby, value: &NDuration) -> Result<u128, Error> {
    let value = value.0;
    guarded(ruby, || Ok(nanoseconds(value.unsigned_abs())))
}

/// `TryFrom<SignedDuration> for StdDuration` (`signed_duration.rs:1438-1455`),
/// raising `ConversionRange` for a negative duration.
fn duration_to_std(ruby: &Ruby, value: &NDuration) -> Result<u128, Error> {
    let value = value.0;
    guarded(ruby, || Ok(nanoseconds(StdDuration::try_from(value)?)))
}

/// `TryFrom<StdDuration> for SignedDuration` (`signed_duration.rs:1423-1436`),
/// raising `ConversionRange` past `i64` seconds.
fn duration_try_from_std(ruby: &Ruby, std: Std) -> Result<Value, Error> {
    let value = guarded(ruby, || Ok(SignedDuration::try_from(std.0)?))?;
    Ok(frozen(ruby, NDuration(value)).as_value())
}

/// `+` or `-` with a std `Duration` on the right, or `rsub`, std's `-`
/// with the duration on the right.
fn duration_std(ruby: &Ruby, value: &NDuration, name: Symbol, std: Std) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || match name.as_ref() {
        "+" => add(value, std),
        "-" => sub(value, std),
        "rsub" => rsub(std, value),
        other => Err(unknown("SignedDuration", other)),
    })?;
    Ok(frozen(ruby, NDuration(result)).as_value())
}

/// `PartialEq<StdDuration> for SignedDuration` (`signed_duration.rs:1879-1884`).
fn duration_std_eq(ruby: &Ruby, value: &NDuration, std: Std) -> Result<bool, Error> {
    let (value, std) = (value.0, std.0);
    guarded(ruby, || Ok(value == std))
}

/// `PartialOrd<StdDuration> for SignedDuration` (`signed_duration.rs:1893-1910`),
/// as `<=>` answers it.
fn duration_std_cmp(ruby: &Ruby, value: &NDuration, std: Std) -> Result<Option<i8>, Error> {
    let (value, std) = (value.0, std.0);
    guarded(ruby, || {
        Ok(value.partial_cmp(&std).map(|order| order as i8))
    })
}

/// `PartialOrd<SignedDuration> for StdDuration` (`signed_duration.rs:1912-1917`).
fn std_duration_cmp(ruby: &Ruby, std: Std, value: &NDuration) -> Result<Option<i8>, Error> {
    let (std, value) = (std.0, value.0);
    guarded(ruby, || {
        Ok(std.partial_cmp(&value).map(|order: Ordering| order as i8))
    })
}

/// `Div<SignedDuration> for StdDuration` (`signed_duration.rs:1866-1877`),
/// a Float.
fn std_duration_ratio(ruby: &Ruby, std: Std, value: &NDuration) -> Result<f64, Error> {
    let (std, value) = (std.0, value.0);
    guarded(ruby, || Ok(std / value))
}

/// `checked_add_std`, `checked_sub_std`, `+`, or `-` with a std
/// `Duration` on a `Date` (`date.rs:880-1044`, `:1675-1737`).
fn date_std(ruby: &Ruby, value: &NDate, name: Symbol, std: Std) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || date(value, &name, std))?;
    Ok(frozen_option(ruby, result.map(NDate)))
}

/// `+` or `-` with a std `Duration` on a `Time`, which wraps past
/// midnight and never panics (`time.rs:1110-1180`).
fn time_std(ruby: &Ruby, value: &NTime, name: Symbol, std: Std) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || match name.as_ref() {
        "+" => Ok(value + std),
        "-" => Ok(value - std),
        other => Err(unknown("Time", other)),
    })?;
    Ok(frozen(ruby, NTime(result)).as_value())
}

/// `+` or `-` with a std `Duration` on a `PlainDateTime`.
fn plain_std(ruby: &Ruby, value: &NPlain, name: Symbol, std: Std) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || plain(value, &name, std))?;
    Ok(frozen(ruby, NPlain(result)).as_value())
}

/// `+` or `-` with a std `Duration` on a `UtcDateTime`.
fn utc_std(ruby: &Ruby, value: &NUtc, name: Symbol, std: Std) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || utc(value, &name, std))?;
    Ok(frozen(ruby, NUtc(result)).as_value())
}

/// `+` or `-` with a std `Duration` on an `OffsetDateTime`.
fn offset_date_time_std(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    name: Symbol,
    std: Std,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || offset(value, &name, std))?;
    Ok(frozen(ruby, NOffsetDateTime(result)).as_value())
}

/// `+` or `-` with a std `Duration` on a `Timestamp`.
fn timestamp_std(ruby: &Ruby, value: &NTimestamp, name: Symbol, std: Std) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, std) = (value.0, std.0);
    let result = guarded(ruby, || timestamp(value, &name, std))?;
    Ok(frozen(ruby, NTimestamp(result)).as_value())
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("std_from_secs_f64", function!(std_from_secs_f64, 1))?;
    native.define_singleton_method("duration_unsigned_abs", function!(duration_unsigned_abs, 1))?;
    native.define_singleton_method("duration_to_std", function!(duration_to_std, 1))?;
    native.define_singleton_method("duration_try_from_std", function!(duration_try_from_std, 1))?;
    native.define_singleton_method("duration_std", function!(duration_std, 3))?;
    native.define_singleton_method("duration_std_eq", function!(duration_std_eq, 2))?;
    native.define_singleton_method("duration_std_cmp", function!(duration_std_cmp, 2))?;
    native.define_singleton_method("std_duration_cmp", function!(std_duration_cmp, 2))?;
    native.define_singleton_method("std_duration_ratio", function!(std_duration_ratio, 2))?;
    native.define_singleton_method("date_std", function!(date_std, 3))?;
    native.define_singleton_method("time_std", function!(time_std, 3))?;
    native.define_singleton_method("plain_std", function!(plain_std, 3))?;
    native.define_singleton_method("utc_std", function!(utc_std, 3))?;
    native.define_singleton_method("offset_date_time_std", function!(offset_date_time_std, 3))?;
    native.define_singleton_method("timestamp_std", function!(timestamp_std, 3))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{add, date, offset, plain, rsub, sub, timestamp, utc};
    use crate::{capture, Failure, Panic};
    use std::fmt::Debug;
    use std::time::Duration as StdDuration;
    use time::{
        Date, OffsetDateTime, PlainDateTime, SignedDuration, Time, Timestamp, UtcDateTime,
        UtcOffset,
    };

    /// The message of the panic `operation` raises in time, if any.
    fn panic_of<T: Debug>(operation: impl FnOnce() -> T) -> Option<String> {
        match capture(operation) {
            Err(Panic(message)) => Some(message),
            Ok(_) => None,
        }
    }

    /// The `RangeError` message a refusal carries, if any.
    fn refusal<T: Debug>(result: Result<T, Failure>) -> Option<String> {
        match result {
            Err(Failure::Range(message)) => Some(message),
            Ok(_) => None,
            Err(other) => panic!("refused as something else: {other:?}"),
        }
    }

    /// Spans around the edges of every type's range: a nanosecond, part of
    /// a day, whole days, and spans past `SignedDuration` and `Date`.
    fn spans() -> Vec<StdDuration> {
        vec![
            StdDuration::ZERO,
            StdDuration::from_nanos(1),
            StdDuration::from_secs(1),
            StdDuration::from_hours(23),
            StdDuration::from_hours(24),
            StdDuration::new(86_400, 1),
            StdDuration::from_secs(86_400 * 2 - 1),
            StdDuration::from_hours(24 * 3_652_424),
            StdDuration::from_hours(24 * 7_304_850),
            StdDuration::from_secs(86_400 * 7_304_850 + 1),
            StdDuration::from_secs(u64::from(u32::MAX) * 86_400),
            StdDuration::from_secs(i64::MAX.cast_unsigned()),
            StdDuration::new(i64::MAX.cast_unsigned() + 1, 0),
            StdDuration::new(u64::MAX, 999_999_999),
        ]
    }

    /// Each refusal agrees with time's real operator: refused exactly when
    /// it panics, with its message, and passing its result through
    /// otherwise.
    fn agrees<T: Debug + PartialEq>(
        ours: Result<T, Failure>,
        real: impl FnOnce() -> T,
        case: &str,
    ) {
        assert_eq!(refusal(ours), panic_of(real), "{case}");
    }

    #[test]
    fn duration_refusals_are_times_panics() {
        for value in [
            SignedDuration::MIN,
            -SignedDuration::SECOND,
            SignedDuration::ZERO,
            SignedDuration::MAX,
        ] {
            for std in spans() {
                let case = format!("{value:?} {std:?}");
                agrees(add(value, std), || value + std, &case);
                agrees(add(value, std), || std + value, &case);
                agrees(sub(value, std), || value - std, &case);
                agrees(rsub(std, value), || std - value, &case);
                if let Ok(result) = add(value, std) {
                    assert_eq!(result, value + std, "{case}");
                }
            }
        }
    }

    #[test]
    fn date_time_refusals_are_times_panics_at_both_ends() {
        let near_max = PlainDateTime::MAX - SignedDuration::HOUR;
        let near_min = PlainDateTime::MIN + SignedDuration::HOUR;
        for value in [
            PlainDateTime::MAX,
            near_max,
            PlainDateTime::MIN,
            near_min,
            PlainDateTime::new(Date::MAX, Time::MIDNIGHT),
            PlainDateTime::new(Date::MIN, Time::MAX),
        ] {
            for std in spans() {
                let case = format!("{value:?} {std:?}");
                agrees(plain(value, "+", std), || value + std, &case);
                agrees(plain(value, "-", std), || value - std, &case);
                let utc_value = value.as_utc();
                agrees(utc(utc_value, "+", std), || utc_value + std, &case);
                agrees(utc(utc_value, "-", std), || utc_value - std, &case);
                for hours in [-5, 0, 5] {
                    let odt = value.assume_offset(UtcOffset::from_hms(hours, 0, 0).unwrap());
                    agrees(offset(odt, "+", std), || odt + std, &case);
                    agrees(offset(odt, "-", std), || odt - std, &case);
                }
                let day = value.date();
                agrees(date(day, "+", std), || Some(day + std), &case);
                agrees(date(day, "-", std), || Some(day - std), &case);
            }
        }
    }

    #[test]
    fn timestamp_refusals_are_times_panics_at_both_ends() {
        let one = SignedDuration::NANOSECOND;
        for value in [
            Timestamp::MAX,
            Timestamp::MAX - one,
            Timestamp::MIN,
            Timestamp::MIN + one,
            Timestamp::UNIX_EPOCH,
        ] {
            for std in spans() {
                let case = format!("{value:?} {std:?}");
                agrees(timestamp(value, "+", std), || value + std, &case);
                agrees(timestamp(value, "-", std), || value - std, &case);
            }
        }
    }

    #[test]
    fn what_time_computes_passes_through() {
        let std = StdDuration::new(90_061, 5);
        let at = PlainDateTime::new(
            Date::from_calendar_date(2020, time::Month::February, 28).unwrap(),
            Time::from_hms(23, 0, 0).unwrap(),
        );
        assert_eq!(plain(at, "+", std).unwrap(), at + std);
        assert_eq!(plain(at, "-", std).unwrap(), at - std);
        assert_eq!(utc(at.as_utc(), "+", std).unwrap(), at.as_utc() + std);
        let odt: OffsetDateTime = at.assume_utc();
        assert_eq!(offset(odt, "-", std).unwrap(), odt - std);
        assert_eq!(
            date(at.date(), "checked_add_std", std).unwrap(),
            at.date().checked_add_std(std)
        );
        let _: UtcDateTime = at.as_utc();
    }
}
