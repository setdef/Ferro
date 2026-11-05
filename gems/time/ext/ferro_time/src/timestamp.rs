// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `Timestamp` and its interop with `UtcDateTime`, `OffsetDateTime`, and
//! Ruby's `::Time` as `SystemTime` (time 0.3.55 `src/timestamp.rs`,
//! `src/interop/timestamp_utcdatetime.rs`,
//! `src/interop/offsetdatetime_timestamp.rs`,
//! `src/interop/systemdatetime_timestamp.rs`; plan 009, "Timestamp").
//!
//! A `Timestamp` holds a Unix time in seconds and nanoseconds, over the
//! range of a `UtcDateTime`. Its readers, `replace_*`, and arithmetic
//! mirror the date-time types', so the natives take the same shape as
//! `datetime.rs`; `Timestamp` has no `truncate_to_*`, so it has its own
//! module. Each conversion time panics on is refused first with
//! `RangeError` and time's own message (plan 007, decision 7).

use std::time::SystemTime;

use magnus::{function, prelude::*, Error, IntoValue, RModule, Ruby, Symbol, Value};
use time::ext::SystemTimeExt;
use time::{OffsetDateTime, SignedDuration, Timestamp};

use crate::calendar::unknown;
use crate::datetime::{or_range, LOCAL_OUT_OF_RANGE, OUT_OF_RANGE};
use crate::duration;
use crate::system_time::{since_epoch, system_after_epoch, system_time};
use crate::values::{
    month, weekday_number, NDate, NDuration, NOffsetDateTime, NTime, NTimestamp, NUtc, NUtcOffset,
};
use crate::{frozen, frozen_option, guarded, Failure};

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic messages of time 0.3.55's Timestamp
//   conversions (src/interop/offsetdatetime_timestamp.rs:63-78,
//   src/interop/systemdatetime_timestamp.rs:67-86) and of the
//   SignedDuration operators its SystemTime subtraction uses
//   (src/signed_duration.rs:1471-1483, :1561-1573,
//   src/interop/systemdatetime_timestamp.rs:12-37)

/// What `Result::expect` panics with in `From<OffsetDateTime> for
/// Timestamp`, before the error's `Debug` text.
const FROM_OFFSET: &str = "local datetime out of valid range for `Timestamp`";

/// What `Result::expect` panics with in `From<SystemTime> for Timestamp`,
/// before the error's `Debug` text.
const FROM_SYSTEM_TIME: &str = "SystemTime value is out of valid range";

/// What `Result::expect` panics with when `SignedDuration`'s
/// `TryFrom<std::time::Duration>` fails inside its `Add` and `Sub` with a
/// std `Duration`: the message, then the error's `Debug` text.
pub const CONVERTING: &str =
    "overflow converting `std::time::Duration` to `time::SignedDuration`: ConversionRange";

// SPDX-SnippetEnd

/// `Timestamp::UNIX_EPOCH`, `MIN`, or `MAX` (`timestamp.rs:103-126`).
fn constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    let value = guarded(ruby, || match name.as_ref() {
        "UNIX_EPOCH" => Ok(Timestamp::UNIX_EPOCH),
        "MIN" => Ok(Timestamp::MIN),
        "MAX" => Ok(Timestamp::MAX),
        other => Err(unknown("Timestamp", other)),
    })?;
    Ok(frozen(ruby, NTimestamp(value)).as_value())
}

fn timestamp(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<Timestamp, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NTimestamp(value)).as_value())
}

/// `From<SystemTime> for Timestamp`, refusing what it panics on
/// (`systemdatetime_timestamp.rs:67-86`). It takes the span since the
/// epoch, steps back a second for a negative fraction, and builds the
/// timestamp with `Timestamp::new`, whose failure its `expect` turns into
/// a panic. The step back overflows only at the span `i64::MIN`, which
/// time's `signed_duration_since` saturates to, and which no timestamp
/// holds; Rust's arithmetic would panic in a debug build and wrap into
/// the same failure in a release build, so the gem names the failure.
pub fn timestamp_from_system(time: SystemTime) -> Result<Timestamp, Failure> {
    let span = time.signed_duration_since(SystemTime::UNIX_EPOCH);
    let seconds = if span.subsec_nanoseconds() < 0 {
        span.whole_seconds().checked_sub(1).unwrap_or(i64::MAX)
    } else {
        span.whole_seconds()
    };
    if let Err(range) = Timestamp::from_seconds(seconds) {
        return Err(Failure::Range(format!("{FROM_SYSTEM_TIME}: {range:?}")));
    }
    Ok(Timestamp::from(time))
}

/// `From<OffsetDateTime> for Timestamp`, refusing what it panics on
/// (`offsetdatetime_timestamp.rs:63-78`).
pub fn timestamp_from_offset(datetime: OffsetDateTime) -> Result<Timestamp, Failure> {
    if let Err(range) = Timestamp::from_seconds(datetime.unix_timestamp()) {
        return Err(Failure::Range(format!("{FROM_OFFSET}: {range:?}")));
    }
    Ok(Timestamp::from(datetime))
}

/// `From<Timestamp> for SystemTime`, which adds the span since the epoch
/// to `UNIX_EPOCH` (`systemdatetime_timestamp.rs:88-97`) and so panics
/// where `SystemTime` is narrower than a timestamp (Windows, before 1601).
pub fn system_from_timestamp(value: Timestamp) -> Result<SystemTime, Failure> {
    system_after_epoch(value - Timestamp::UNIX_EPOCH)?;
    Ok(SystemTime::from(value))
}

/// `Timestamp - SystemTime`, refusing what its `SignedDuration` steps
/// panic on (`systemdatetime_timestamp.rs:12-23`): a `SystemTime` far from
/// the epoch gives a span that, taken from or added to the timestamp's,
/// leaves `SignedDuration`'s range.
pub fn difference_from_system(
    value: Timestamp,
    time: SystemTime,
) -> Result<SignedDuration, Failure> {
    let from_epoch = value - Timestamp::UNIX_EPOCH;
    let convert = |span: std::time::Duration| {
        SignedDuration::try_from(span).map_err(|_| Failure::Range(CONVERTING.to_owned()))
    };
    match time.duration_since(SystemTime::UNIX_EPOCH) {
        Ok(after) => duration::sub(from_epoch, convert(after)?)?,
        Err(before) => duration::add(from_epoch, convert(before.duration())?)?,
    };
    Ok(value - time)
}

/// `Timestamp::now` (`timestamp.rs:128-137`), which converts the system
/// clock with `From<SystemTime>`.
fn now(ruby: &Ruby) -> Result<Value, Error> {
    timestamp(ruby, || timestamp_from_system(SystemTime::now()))
}

/// `Timestamp::new` (`timestamp.rs:171-191`).
fn new(ruby: &Ruby, seconds: i64, nanoseconds: u32) -> Result<Value, Error> {
    timestamp(ruby, || Ok(Timestamp::new(seconds, nanoseconds)?))
}

/// `from_seconds` (`timestamp.rs:193-205`).
fn from_seconds(ruby: &Ruby, seconds: i64) -> Result<Value, Error> {
    timestamp(ruby, || Ok(Timestamp::from_seconds(seconds)?))
}

/// `from_milliseconds` (`timestamp.rs:207-234`).
fn from_milliseconds(ruby: &Ruby, milliseconds: i64) -> Result<Value, Error> {
    timestamp(ruby, || Ok(Timestamp::from_milliseconds(milliseconds)?))
}

/// `from_microseconds` (`timestamp.rs:236-263`).
fn from_microseconds(ruby: &Ruby, microseconds: i128) -> Result<Value, Error> {
    timestamp(ruby, || Ok(Timestamp::from_microseconds(microseconds)?))
}

/// `from_nanoseconds` (`timestamp.rs:265-296`).
fn from_nanoseconds(ruby: &Ruby, nanoseconds: i128) -> Result<Value, Error> {
    timestamp(ruby, || Ok(Timestamp::from_nanoseconds(nanoseconds)?))
}

/// The readers that answer one number (`timestamp.rs:350-775`); a month is
/// its number, a weekday its days from Monday.
fn int(ruby: &Ruby, value: &NTimestamp, name: Symbol) -> Result<i128, Error> {
    let name = name.name()?;
    let value = value.0;
    guarded(ruby, || {
        Ok(match name.as_ref() {
            "as_seconds" => value.as_seconds().into(),
            "as_milliseconds" => value.as_milliseconds().into(),
            "as_microseconds" => value.as_microseconds(),
            "as_nanoseconds" => value.as_nanoseconds(),
            "year" => value.year().into(),
            "month" => u8::from(value.month()).into(),
            "day" => value.day().into(),
            "ordinal" => value.ordinal().into(),
            "iso_week" => value.iso_week().into(),
            "sunday_based_week" => value.sunday_based_week().into(),
            "monday_based_week" => value.monday_based_week().into(),
            "weekday" => weekday_number(value.weekday()).into(),
            "to_julian_day" => value.to_julian_day().into(),
            "hour" => value.hour().into(),
            "minute" => value.minute().into(),
            "second" => value.second().into(),
            "millisecond" => value.millisecond().into(),
            "microsecond" => value.microsecond().into(),
            "nanosecond" => value.nanosecond().into(),
            other => return Err(unknown("Timestamp", other)),
        })
    })
}

/// The readers that answer a tuple.
fn ints(ruby: &Ruby, value: &NTimestamp, name: Symbol) -> Result<Vec<i64>, Error> {
    let name = name.name()?;
    let value = value.0;
    guarded(ruby, || {
        Ok(match name.as_ref() {
            "to_calendar_date" => {
                let (year, month, day) = value.to_calendar_date();
                vec![year.into(), u8::from(month).into(), day.into()]
            }
            "to_ordinal_date" => {
                let (year, ordinal) = value.to_ordinal_date();
                vec![year.into(), ordinal.into()]
            }
            "to_iso_week_date" => {
                let (year, week, weekday) = value.to_iso_week_date();
                vec![year.into(), week.into(), weekday_number(weekday).into()]
            }
            "as_hms" => {
                let (h, m, s) = value.as_hms();
                vec![h.into(), m.into(), s.into()]
            }
            "as_hms_milli" => {
                let (h, m, s, ms) = value.as_hms_milli();
                vec![h.into(), m.into(), s.into(), ms.into()]
            }
            "as_hms_micro" => {
                let (h, m, s, us) = value.as_hms_micro();
                vec![h.into(), m.into(), s.into(), us.into()]
            }
            "as_hms_nano" => {
                let (h, m, s, ns) = value.as_hms_nano();
                vec![h.into(), m.into(), s.into(), ns.into()]
            }
            other => return Err(unknown("Timestamp", other)),
        })
    })
}

/// `replace_year` to `replace_nanosecond` (`timestamp.rs:1009-1296`);
/// magnus converts `number` to each method's type.
fn replace(ruby: &Ruby, value: &NTimestamp, name: Symbol, number: Value) -> Result<Value, Error> {
    let name = name.name()?;
    let value = value.0;
    let result = match name.as_ref() {
        "replace_year" => {
            let year = i32::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_year(year)?))?
        }
        "replace_month" => {
            let number = u8::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_month(month(number)?)?))?
        }
        "replace_day" => {
            let day = u8::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_day(day)?))?
        }
        "replace_ordinal" => {
            let ordinal = u16::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_ordinal(ordinal)?))?
        }
        "replace_hour" => {
            let hour = u8::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_hour(hour)?))?
        }
        "replace_minute" => {
            let minute = u8::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_minute(minute)?))?
        }
        "replace_second" => {
            let second = u8::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_second(second)?))?
        }
        "replace_millisecond" => {
            let millisecond = u16::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_millisecond(millisecond)?))?
        }
        "replace_microsecond" => {
            let microsecond = u32::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_microsecond(microsecond)?))?
        }
        "replace_nanosecond" => {
            let nanosecond = u32::try_convert(number)?;
            guarded(ruby, || Ok(value.replace_nanosecond(nanosecond)?))?
        }
        other => return Err(unknown("Timestamp", other).into_error(ruby)),
    };
    Ok(frozen(ruby, NTimestamp(result)).as_value())
}

/// `replace_time` (`timestamp.rs:1009-1031`).
fn replace_time(ruby: &Ruby, value: &NTimestamp, time: &NTime) -> Result<Value, Error> {
    let (value, time) = (value.0, time.0);
    timestamp(ruby, || Ok(value.replace_time(time)))
}

/// `replace_date` (`timestamp.rs:1033-1056`).
fn replace_date(ruby: &Ruby, value: &NTimestamp, date: &NDate) -> Result<Value, Error> {
    let (value, date) = (value.0, date.0);
    timestamp(ruby, || Ok(value.replace_date(date)))
}

/// `checked_add`, `checked_sub`, `saturating_add`, `saturating_sub`,
/// `+`, or `-` with a duration (`timestamp.rs:900-1004`, `:1450-1546`);
/// `+` and `-` refuse what their `expect` panics on.
fn arith(
    ruby: &Ruby,
    value: &NTimestamp,
    name: Symbol,
    duration: &NDuration,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, duration) = (value.0, duration.0);
    let result = guarded(ruby, || match name.as_ref() {
        "checked_add" => Ok(value.checked_add(duration)),
        "checked_sub" => Ok(value.checked_sub(duration)),
        "saturating_add" => Ok(Some(value.saturating_add(duration))),
        "saturating_sub" => Ok(Some(value.saturating_sub(duration))),
        "+" => or_range(value.checked_add(duration), OUT_OF_RANGE).map(Some),
        "-" => or_range(value.checked_sub(duration), OUT_OF_RANGE).map(Some),
        other => Err(unknown("Timestamp", other)),
    })?;
    Ok(frozen_option(ruby, result.map(NTimestamp)))
}

/// `date` (`timestamp.rs:410-420`).
fn date(ruby: &Ruby, value: &NTimestamp) -> Result<Value, Error> {
    let value = value.0;
    let date = guarded(ruby, || Ok(value.date()))?;
    Ok(frozen(ruby, NDate(date)).as_value())
}

/// `time` (`timestamp.rs:422-445`).
fn time(ruby: &Ruby, value: &NTimestamp) -> Result<Value, Error> {
    let value = value.0;
    let time = guarded(ruby, || Ok(value.time()))?;
    Ok(frozen(ruby, NTime(time)).as_value())
}

/// `to_offset`, refusing what time panics on, or `checked_to_offset`
/// (`timestamp.rs:298-326`).
fn to_offset(
    ruby: &Ruby,
    value: &NTimestamp,
    name: Symbol,
    offset: &NUtcOffset,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, offset) = (value.0, offset.0);
    let result = guarded(ruby, || match name.as_ref() {
        "to_offset" => or_range(value.checked_to_offset(offset), LOCAL_OUT_OF_RANGE).map(Some),
        "checked_to_offset" => Ok(value.checked_to_offset(offset)),
        other => Err(unknown("Timestamp", other)),
    })?;
    Ok(frozen_option(ruby, result.map(NOffsetDateTime)))
}

/// `to_utc` (`timestamp.rs:328-346`).
fn to_utc(ruby: &Ruby, value: &NTimestamp) -> Result<Value, Error> {
    let value = value.0;
    let utc = guarded(ruby, || Ok(value.to_utc()))?;
    Ok(frozen(ruby, NUtc(utc)).as_value())
}

/// `Sub for Timestamp` (`timestamp.rs:1548-1561`).
fn difference(ruby: &Ruby, value: &NTimestamp, other: &NTimestamp) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    let span = guarded(ruby, || Ok(value - other))?;
    Ok(frozen(ruby, NDuration(span)).as_value())
}

/// `==`, `<=>`, or `-` with a `UtcDateTime` or an `OffsetDateTime` on the
/// right (`timestamp_utcdatetime.rs:6-58`, `offsetdatetime_timestamp.rs:9-61`).
macro_rules! with_instant {
    ($name:ident, $wrapper:ty) => {
        fn $name(
            ruby: &Ruby,
            value: &NTimestamp,
            operator: Symbol,
            other: &$wrapper,
        ) -> Result<Value, Error> {
            let operator = operator.name()?;
            let (value, other) = (value.0, other.0);
            match operator.as_ref() {
                "==" => Ok(guarded(ruby, || Ok(value == other))?.into_value_with(ruby)),
                "<=>" => Ok(
                    guarded(ruby, || Ok(value.partial_cmp(&other).map(|o| o as i8)))?
                        .into_value_with(ruby),
                ),
                "-" => {
                    let span = guarded(ruby, || Ok(value - other))?;
                    Ok(frozen(ruby, NDuration(span)).as_value())
                }
                unexpected => Err(unknown("Timestamp", unexpected).into_error(ruby)),
            }
        }
    };
}

with_instant!(with_utc, NUtc);
with_instant!(with_offset_date_time, NOffsetDateTime);

/// `==`, `<=>`, or `-` with a `::Time` on the right, built from its whole
/// seconds and nanoseconds as `SystemTime` (`systemdatetime_timestamp.rs:12-65`).
fn with_system_time(
    ruby: &Ruby,
    value: &NTimestamp,
    operator: Symbol,
    seconds: i64,
    nanoseconds: u32,
) -> Result<Value, Error> {
    let operator = operator.name()?;
    let value = value.0;
    let other = guarded(ruby, || system_time(seconds, nanoseconds))?;
    match operator.as_ref() {
        "==" => Ok(guarded(ruby, || Ok(value == other))?.into_value_with(ruby)),
        "<=>" => Ok(
            guarded(ruby, || Ok(value.partial_cmp(&other).map(|o| o as i8)))?.into_value_with(ruby),
        ),
        "-" => {
            let span = guarded(ruby, || difference_from_system(value, other))?;
            Ok(frozen(ruby, NDuration(span)).as_value())
        }
        other => Err(unknown("Timestamp", other).into_error(ruby)),
    }
}

/// `Sub<Timestamp> for UtcDateTime` (`timestamp_utcdatetime.rs:18-28`).
fn utc_difference(ruby: &Ruby, value: &NUtc, other: &NTimestamp) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    let span = guarded(ruby, || Ok(value - other))?;
    Ok(frozen(ruby, NDuration(span)).as_value())
}

/// `Sub<Timestamp> for OffsetDateTime` (`offsetdatetime_timestamp.rs:21-31`).
fn offset_date_time_difference(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    other: &NTimestamp,
) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    let span = guarded(ruby, || Ok(value - other))?;
    Ok(frozen(ruby, NDuration(span)).as_value())
}

/// `From<UtcDateTime> for Timestamp` (`timestamp_utcdatetime.rs:60-72`).
fn from_utc(ruby: &Ruby, value: &NUtc) -> Result<Value, Error> {
    let value = value.0;
    timestamp(ruby, || Ok(Timestamp::from(value)))
}

/// `From<Timestamp> for UtcDateTime` (`timestamp_utcdatetime.rs:74-86`).
fn utc_from(ruby: &Ruby, value: &NTimestamp) -> Result<Value, Error> {
    let value = value.0;
    let utc = guarded(ruby, || Ok(time::UtcDateTime::from(value)))?;
    Ok(frozen(ruby, NUtc(utc)).as_value())
}

/// `From<OffsetDateTime> for Timestamp`, refusing what it panics on
/// (`offsetdatetime_timestamp.rs:63-78`).
fn from_offset_date_time(ruby: &Ruby, value: &NOffsetDateTime) -> Result<Value, Error> {
    let value = value.0;
    timestamp(ruby, || timestamp_from_offset(value))
}

/// `From<Timestamp> for OffsetDateTime` (`offsetdatetime_timestamp.rs:80-92`).
fn offset_date_time_from(ruby: &Ruby, value: &NTimestamp) -> Result<Value, Error> {
    let value = value.0;
    let odt = guarded(ruby, || Ok(OffsetDateTime::from(value)))?;
    Ok(frozen(ruby, NOffsetDateTime(odt)).as_value())
}

/// `From<SystemTime> for Timestamp` for the instant `seconds` and
/// `nanoseconds` after the epoch name.
fn from_system_time(ruby: &Ruby, seconds: i64, nanoseconds: u32) -> Result<Value, Error> {
    timestamp(ruby, || {
        timestamp_from_system(system_time(seconds, nanoseconds)?)
    })
}

/// `From<Timestamp> for SystemTime`, as the seconds and nanoseconds
/// after the epoch Ruby's `::Time` takes.
fn to_system_time(ruby: &Ruby, value: &NTimestamp) -> Result<(i64, u32), Error> {
    let value = value.0;
    guarded(ruby, || Ok(since_epoch(system_from_timestamp(value)?)))
}

macro_rules! define {
    ($native:ident, $($name:ident / $arity:tt),+ $(,)?) => {
        $($native.define_singleton_method(
            concat!("timestamp_", stringify!($name)),
            function!($name, $arity),
        )?;)+
    };
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    define!(
        native,
        constant / 1,
        now / 0,
        new / 2,
        from_seconds / 1,
        from_milliseconds / 1,
        from_microseconds / 1,
        from_nanoseconds / 1,
        int / 2,
        ints / 2,
        replace / 3,
        replace_time / 2,
        replace_date / 2,
        arith / 3,
        date / 1,
        time / 1,
        to_offset / 3,
        to_utc / 1,
        difference / 2,
        with_utc / 3,
        with_offset_date_time / 3,
        with_system_time / 4,
        from_utc / 1,
        from_offset_date_time / 1,
        from_system_time / 2,
        to_system_time / 1,
    );
    native.define_singleton_method("utc_difference_timestamp", function!(utc_difference, 2))?;
    native.define_singleton_method(
        "offset_date_time_difference_timestamp",
        function!(offset_date_time_difference, 2),
    )?;
    native.define_singleton_method("utc_from_timestamp", function!(utc_from, 1))?;
    native.define_singleton_method(
        "offset_date_time_from_timestamp",
        function!(offset_date_time_from, 1),
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::time::{Duration, SystemTime};

    use time::{OffsetDateTime, SignedDuration, Timestamp, UtcOffset};

    use super::{
        difference_from_system, system_from_timestamp, timestamp_from_offset, timestamp_from_system,
    };
    use crate::system_time::system_time;
    use crate::{capture, Failure, Panic};

    /// What time panics with for `operation`, if it does.
    fn panic_of<T>(operation: impl FnOnce() -> T) -> Option<String> {
        capture(operation).err().map(|Panic(message)| message)
    }

    /// The text of a refusal, or `None` for an answer.
    fn refusal<T>(result: &Result<T, Failure>) -> Option<String> {
        match result {
            Err(Failure::Range(message)) => Some(message.clone()),
            Err(other) => panic!("not a refusal: {other:?}"),
            Ok(_) => None,
        }
    }

    /// A deterministic stream of numbers, so a failure repeats.
    struct Stream(u64);

    impl Stream {
        const fn next(&mut self) -> u64 {
            self.0 ^= self.0 << 13;
            self.0 ^= self.0 >> 7;
            self.0 ^= self.0 << 17;
            self.0
        }

        /// A number from `low` to `high`, both included.
        fn between(&mut self, low: i64, high: i64) -> i64 {
            let span = u64::try_from(i128::from(high) - i128::from(low) + 1).expect("a span");
            low.checked_add(i64::try_from(self.next() % span).expect("below the span"))
                .expect("below high")
        }

        /// A fraction of a second, in nanoseconds.
        fn nanoseconds(&mut self) -> u32 {
            u32::try_from(self.between(0, 999_999_999)).expect("a nanosecond")
        }

        /// Whether the stream's next number is even.
        const fn coin(&mut self) -> bool {
            self.next() & 1 == 0
        }
    }

    #[test]
    fn from_offset_refuses_what_time_panics_on() {
        let mut stream = Stream(0x9E37_79B9_7F4A_7C15);
        for _ in 0..4_000 {
            let seconds = if stream.coin() {
                Timestamp::MAX.as_seconds() + stream.between(-100_000, 100_000)
            } else {
                Timestamp::MIN.as_seconds() + stream.between(-100_000, 100_000)
            };
            let offset = UtcOffset::from_whole_seconds(
                i32::try_from(stream.between(-93_599, 93_599)).expect("an offset"),
            )
            .expect("in range");
            let Ok(utc) = OffsetDateTime::from_unix_timestamp(seconds) else {
                continue;
            };
            let Some(local) = utc.checked_to_offset(offset) else {
                continue;
            };
            let nanos = stream.nanoseconds();
            let datetime = local.replace_nanosecond(nanos).expect("in range");
            let theirs = panic_of(|| Timestamp::from(datetime));
            let ours = timestamp_from_offset(datetime);
            assert_eq!(refusal(&ours), theirs, "{datetime:?}");
            if theirs.is_none() {
                assert_eq!(ours.expect("answers"), Timestamp::from(datetime));
            }
        }
    }

    #[test]
    fn from_offset_names_the_error_as_expect_does() {
        let datetime = OffsetDateTime::new_in_offset(
            time::Date::MAX,
            time::Time::MAX,
            UtcOffset::from_hms(-1, 0, 0).expect("in range"),
        );
        let message = refusal(&timestamp_from_offset(datetime)).expect("refused");
        assert!(message.starts_with("local datetime out of valid range for `Timestamp`: "));
        assert_eq!(panic_of(|| Timestamp::from(datetime)), Some(message));
    }

    /// A `SystemTime` `seconds` and `nanoseconds` from the epoch, or
    /// `None` where std cannot hold it (Windows, before 1601).
    fn instant(seconds: i64, nanoseconds: u32) -> Option<SystemTime> {
        system_time(seconds, nanoseconds).ok()
    }

    #[test]
    fn from_system_time_refuses_what_time_panics_on() {
        let mut stream = Stream(0xD1B5_4A32_D192_ED03);
        let ends = [
            i64::MIN,
            i64::MAX,
            Timestamp::MAX.as_seconds(),
            Timestamp::MIN.as_seconds(),
        ];
        for _ in 0..4_000 {
            let near = ends[(stream.next() % 4) as usize];
            let seconds = if near.unsigned_abs() > 1 << 40 {
                near.saturating_add(stream.between(-1_000_000, 0).saturating_abs())
                    .saturating_add(if near < 0 { 1_000_000 } else { -1_000_000 })
            } else {
                near + stream.between(-100_000, 100_000)
            };
            let nanos = stream.nanoseconds();
            let Some(time) = instant(seconds, nanos) else {
                continue;
            };
            let theirs = panic_of(|| Timestamp::from(time));
            let ours = timestamp_from_system(time);
            // A debug build panics on the one span release builds wrap
            // (`i64::MIN` seconds with a fraction); the gem names the
            // failure a release build gives, so only a release build
            // compares the text.
            if cfg!(debug_assertions) && seconds == i64::MIN && nanos != 0 {
                assert!(refusal(&ours).is_some());
                continue;
            }
            assert_eq!(refusal(&ours), theirs, "{seconds} {nanos}");
            if theirs.is_none() {
                assert_eq!(ours.expect("answers"), Timestamp::from(time));
            }
        }
    }

    #[test]
    fn a_system_time_at_the_ends_of_the_range_converts() {
        let max = instant(Timestamp::MAX.as_seconds(), 999_999_999).expect("held");
        assert_eq!(
            timestamp_from_system(max).expect("in range").as_seconds(),
            253_402_300_799
        );
        let past = instant(Timestamp::MAX.as_seconds() + 1, 0).expect("held");
        assert!(timestamp_from_system(past).is_err());
        if let Some(furthest) = instant(i64::MIN, 5) {
            assert!(matches!(
                timestamp_from_system(furthest),
                Err(Failure::Range(message))
                    if message.starts_with("SystemTime value is out of valid range: ")
            ));
        }
        let min = instant(Timestamp::MIN.as_seconds(), 0);
        if let Some(min) = min {
            assert_eq!(
                timestamp_from_system(min).expect("in range"),
                Timestamp::MIN
            );
        }
    }

    #[test]
    fn subtracting_a_far_system_time_refuses_what_time_panics_on() {
        let mut stream = Stream(0x2545_F491_4F6C_DD1D);
        let stamps = [
            Timestamp::MIN,
            Timestamp::MAX,
            Timestamp::UNIX_EPOCH,
            Timestamp::new(1_546_398_245, 5).expect("in range"),
        ];
        let bounds = [i64::MAX, i64::MIN, i64::MAX / 2, i64::MIN / 2];
        for _ in 0..4_000 {
            let stamp = stamps[(stream.next() % 4) as usize];
            let bound = bounds[(stream.next() % 4) as usize];
            let seconds = bound.saturating_add(stream.between(-400_000_000_000, 400_000_000_000));
            let Some(time) = instant(seconds, stream.nanoseconds()) else {
                continue;
            };
            let theirs = panic_of(|| stamp - time);
            let ours = difference_from_system(stamp, time);
            assert_eq!(refusal(&ours), theirs, "{stamp} {seconds}");
            if theirs.is_none() {
                assert_eq!(ours.expect("answers"), stamp - time);
            }
        }
    }

    #[test]
    fn std_words_the_conversions_the_difference_relies_on() {
        let big = Duration::new(u64::MAX, 0);
        assert_eq!(
            panic_of(|| SignedDuration::MAX + big),
            Some(super::CONVERTING.to_owned())
        );
        let max = SignedDuration::MAX;
        assert_eq!(
            panic_of(|| max + Duration::from_secs(1)),
            Some("overflow when adding durations".to_owned())
        );
        assert_eq!(
            panic_of(|| SignedDuration::MIN - Duration::from_secs(1)),
            Some("overflow when subtracting durations".to_owned())
        );
    }

    #[test]
    fn a_timestamp_converts_to_a_system_time_where_one_exists() {
        for stamp in [
            Timestamp::UNIX_EPOCH,
            Timestamp::MAX,
            Timestamp::MIN,
            Timestamp::new(-1, 1).expect("in range"),
        ] {
            match (
                capture(|| SystemTime::from(stamp)),
                system_from_timestamp(stamp),
            ) {
                (Ok(theirs), Ok(ours)) => assert_eq!(theirs, ours),
                (Err(Panic(message)), Err(Failure::Range(ours))) => assert_eq!(message, ours),
                other => panic!("they differ: {other:?}"),
            }
        }
    }

    /// Windows counts a `SystemTime` from 1601, so std refuses anything
    /// before it, and a timestamp before 1601 has no `SystemTime` there.
    #[cfg(windows)]
    #[test]
    fn a_timestamp_before_1601_has_no_system_time_on_windows() {
        let before = Timestamp::new(-11_644_473_601, 0).expect("in range");
        assert!(matches!(
            system_from_timestamp(before),
            Err(Failure::Range(message)) if message == crate::system_time::SUBTRACTING
        ));
        assert_eq!(
            panic_of(|| SystemTime::from(before)),
            Some(crate::system_time::SUBTRACTING.to_owned())
        );
        let epoch_of_1601 = Timestamp::new(-11_644_473_600, 0).expect("in range");
        assert!(system_from_timestamp(epoch_of_1601).is_ok());
    }

    #[test]
    fn a_timestamp_is_displayed_as_time_displays_it() {
        assert_eq!(
            Timestamp::new(-1, 500_000_000)
                .expect("in range")
                .to_string(),
            "-0.5"
        );
        assert_eq!(format!("{:?}", Timestamp::UNIX_EPOCH), "0");
    }
}
