// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Ruby's `::Time` as std's `SystemTime` (plan 007, decision 10), and
//! time's impls with it (time 0.3.55 `src/interop/offsetdatetime_systemtime.rs`,
//! `src/interop/utcdatetime_systemtime.rs`).
//!
//! A `::Time` crosses as its whole seconds since the epoch and its
//! nanoseconds (`Time#to_i`, `Time#nsec`, floor and remainder), the
//! `SystemTime` is built from them as Rust would, and time's own `From`,
//! `PartialEq`, `PartialOrd`, and `Sub` run on it. Each step time or std
//! would panic on is refused first with `RangeError` and its message.

use std::time::{Duration, SystemTime};

use magnus::{function, prelude::*, Error, IntoValue, RModule, Ruby, Symbol, Value};
use time::{OffsetDateTime, UtcDateTime};

use crate::calendar::unknown;
use crate::datetime::OUT_OF_RANGE;
use crate::values::{NDuration, NOffsetDateTime, NUtc};
use crate::{frozen, guarded, Failure};

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: The Rust Project Developers
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic messages of std's SystemTime arithmetic
//   (library/std/src/time.rs, Add and Sub of Duration for SystemTime)

/// std's message for a `SystemTime` past its range, forward.
pub const ADDING: &str = "overflow when adding duration to `SystemTime`";

/// std's message for a `SystemTime` past its range, backward.
pub const SUBTRACTING: &str = "overflow when subtracting duration from `SystemTime`";

// SPDX-SnippetEnd

/// The `SystemTime` `seconds` and `nanoseconds` after the epoch name, as
/// `UNIX_EPOCH + Duration` or `UNIX_EPOCH - Duration` would build it.
pub fn system_time(seconds: i64, nanoseconds: u32) -> Result<SystemTime, Failure> {
    let whole = if seconds >= 0 {
        SystemTime::UNIX_EPOCH
            .checked_add(Duration::from_secs(seconds.unsigned_abs()))
            .ok_or(ADDING)
    } else {
        SystemTime::UNIX_EPOCH
            .checked_sub(Duration::from_secs(seconds.unsigned_abs()))
            .ok_or(SUBTRACTING)
    };
    whole
        .and_then(|time| {
            time.checked_add(Duration::from_nanos(nanoseconds.into()))
                .ok_or(ADDING)
        })
        .map_err(|message| Failure::Range(message.to_owned()))
}

/// The seconds and nanoseconds after the epoch of `time`, as Ruby's
/// `Time.at(seconds, nanoseconds, :nsec)` takes them.
pub fn since_epoch(time: SystemTime) -> (i64, u32) {
    match time.duration_since(SystemTime::UNIX_EPOCH) {
        Ok(after) => (after.as_secs().cast_signed(), after.subsec_nanos()),
        Err(before) => {
            let before = before.duration();
            let seconds = before.as_secs().cast_signed();
            match before.subsec_nanos() {
                0 => (-seconds, 0),
                nanos => (-seconds - 1, 1_000_000_000 - nanos),
            }
        }
    }
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panics of time 0.3.55's From<SystemTime>, which
//   adds or subtracts a std Duration from the epoch
//   (src/interop/offsetdatetime_systemtime.rs:59-67,
//   src/offset_date_time.rs:1686-1770, src/date.rs:1675-1737)

/// What time's `From<SystemTime>` panics with for `time`, if anything. It
/// adds the span since the epoch to the epoch's date, which fails past
/// `Date::MAX`; before the epoch it subtracts, which fails past
/// `Date::MIN`, and a span with a part-day remainder steps back one more
/// day, which fails at `Date::MIN` itself.
pub fn from_system_time_panic(time: SystemTime) -> Option<&'static str> {
    let epoch = OffsetDateTime::UNIX_EPOCH.date();
    match time.duration_since(SystemTime::UNIX_EPOCH) {
        Ok(after) => epoch
            .checked_add_std(after)
            .is_none()
            .then_some("overflow adding duration to date"),
        Err(before) => {
            let before = before.duration();
            match epoch.checked_sub_std(before) {
                None => Some("overflow subtracting duration from date"),
                Some(date)
                    if before.as_nanos() % 86_400_000_000_000 != 0
                        && date.previous_day().is_none() =>
                {
                    Some(OUT_OF_RANGE)
                }
                Some(_) => None,
            }
        }
    }
}

// SPDX-SnippetEnd

/// `Err` with what time's `From<SystemTime>` would panic with.
fn convertible(time: SystemTime) -> Result<(), Failure> {
    from_system_time_panic(time).map_or(Ok(()), |message| Err(Failure::Range(message.to_owned())))
}

/// `From<SystemTime> for OffsetDateTime` (`offsetdatetime_systemtime.rs:59-67`),
/// refusing what it panics on.
pub fn offset_from(time: SystemTime) -> Result<OffsetDateTime, Failure> {
    convertible(time)?;
    Ok(OffsetDateTime::from(time))
}

/// `From<SystemTime> for UtcDateTime` (`utcdatetime_systemtime.rs:61-69`),
/// which takes the same steps on a `PlainDateTime`
/// (`src/utc_date_time.rs:1335-1347`, `src/plain_date_time.rs:1201-1283`).
pub fn utc_from(time: SystemTime) -> Result<UtcDateTime, Failure> {
    convertible(time)?;
    Ok(UtcDateTime::from(time))
}

/// `From<OffsetDateTime> for SystemTime` (`offsetdatetime_systemtime.rs:69-82`),
/// refusing what std panics on where `SystemTime` is narrower (Windows).
pub fn system_from_offset(datetime: OffsetDateTime) -> Result<SystemTime, Failure> {
    let span = datetime - OffsetDateTime::UNIX_EPOCH;
    let fits = if span.is_negative() {
        SystemTime::UNIX_EPOCH
            .checked_sub(span.unsigned_abs())
            .ok_or(SUBTRACTING)
    } else {
        SystemTime::UNIX_EPOCH
            .checked_add(span.unsigned_abs())
            .ok_or(ADDING)
    };
    fits.map_err(|message| Failure::Range(message.to_owned()))?;
    Ok(SystemTime::from(datetime))
}

/// `From<UtcDateTime> for SystemTime` (`utcdatetime_systemtime.rs:71-84`).
pub fn system_from_utc(datetime: UtcDateTime) -> Result<SystemTime, Failure> {
    system_from_offset(OffsetDateTime::from(datetime))?;
    Ok(SystemTime::from(datetime))
}

fn offset_date_time_from_system_time(
    ruby: &Ruby,
    seconds: i64,
    nanoseconds: u32,
) -> Result<Value, Error> {
    let value = guarded(ruby, || offset_from(system_time(seconds, nanoseconds)?))?;
    Ok(frozen(ruby, NOffsetDateTime(value)).as_value())
}

fn utc_from_system_time(ruby: &Ruby, seconds: i64, nanoseconds: u32) -> Result<Value, Error> {
    let value = guarded(ruby, || utc_from(system_time(seconds, nanoseconds)?))?;
    Ok(frozen(ruby, NUtc(value)).as_value())
}

fn offset_date_time_to_system_time(
    ruby: &Ruby,
    value: &NOffsetDateTime,
) -> Result<(i64, u32), Error> {
    let value = value.0;
    guarded(ruby, || Ok(since_epoch(system_from_offset(value)?)))
}

fn utc_to_system_time(ruby: &Ruby, value: &NUtc) -> Result<(i64, u32), Error> {
    let value = value.0;
    guarded(ruby, || Ok(since_epoch(system_from_utc(value)?)))
}

/// `==`, `<=>`, or `-` with a `SystemTime` on the right
/// (`offsetdatetime_systemtime.rs:7-57`, `utcdatetime_systemtime.rs:7-59`):
/// each converts the `SystemTime` with time's `From` first, so each
/// refuses what that `From` panics on.
macro_rules! with_system_time {
    ($name:ident, $wrapper:ident, $from:ident, $owner:literal) => {
        fn $name(
            ruby: &Ruby,
            value: &$wrapper,
            operator: Symbol,
            seconds: i64,
            nanoseconds: u32,
        ) -> Result<Value, Error> {
            let operator = operator.name()?;
            let value = value.0;
            let time = guarded(ruby, || {
                let time = system_time(seconds, nanoseconds)?;
                $from(time)?;
                Ok(time)
            })?;
            match operator.as_ref() {
                "==" => Ok(guarded(ruby, || Ok(value == time))?.into_value_with(ruby)),
                "<=>" => Ok(
                    guarded(ruby, || Ok(value.partial_cmp(&time).map(|o| o as i8)))?
                        .into_value_with(ruby),
                ),
                "-" => {
                    let difference = guarded(ruby, || Ok(value - time))?;
                    Ok(frozen(ruby, NDuration(difference)).as_value())
                }
                other => Err(unknown($owner, other).into_error(ruby)),
            }
        }
    };
}

with_system_time!(
    offset_date_time_with_system_time,
    NOffsetDateTime,
    offset_from,
    "OffsetDateTime"
);
with_system_time!(utc_with_system_time, NUtc, utc_from, "UtcDateTime");

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method(
        "offset_date_time_from_system_time",
        function!(offset_date_time_from_system_time, 2),
    )?;
    native.define_singleton_method("utc_from_system_time", function!(utc_from_system_time, 2))?;
    native.define_singleton_method(
        "offset_date_time_to_system_time",
        function!(offset_date_time_to_system_time, 1),
    )?;
    native.define_singleton_method("utc_to_system_time", function!(utc_to_system_time, 1))?;
    native.define_singleton_method(
        "offset_date_time_with_system_time",
        function!(offset_date_time_with_system_time, 4),
    )?;
    native.define_singleton_method("utc_with_system_time", function!(utc_with_system_time, 4))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::time::{Duration, SystemTime};

    use super::{offset_from, since_epoch, system_time, utc_from, ADDING, SUBTRACTING};
    use crate::{capture, Failure, Panic};
    use time::{OffsetDateTime, UtcDateTime};

    fn panic_of<T: std::fmt::Debug>(operation: impl FnOnce() -> T) -> String {
        match capture(operation) {
            Err(Panic(message)) => message,
            Ok(value) => panic!("did not panic: {value:?}"),
        }
    }

    fn refusal<T: std::fmt::Debug>(result: Result<T, Failure>) -> String {
        match result {
            Err(Failure::Range(message)) => message,
            other => panic!("not refused: {other:?}"),
        }
    }

    #[test]
    fn std_words_its_overflows_as_the_gem_does() {
        assert_eq!(
            panic_of(|| SystemTime::UNIX_EPOCH + Duration::from_secs(u64::MAX)),
            ADDING
        );
        assert_eq!(
            panic_of(|| SystemTime::UNIX_EPOCH - Duration::from_secs(u64::MAX)),
            SUBTRACTING
        );
    }

    /// What a `SystemTime` keeps of `nanoseconds`: all of them on Unix,
    /// and whole 100 ns intervals on Windows, which counts in them from
    /// 1601 (std `sys/pal/windows/time.rs`, `checked_dur2intervals`).
    const fn kept(nanoseconds: u32) -> u32 {
        if cfg!(windows) {
            nanoseconds - nanoseconds % 100
        } else {
            nanoseconds
        }
    }

    #[test]
    fn a_ruby_time_round_trips_through_system_time() {
        for (seconds, nanoseconds) in [
            (0, 0),
            (1, 5),
            (-1, 0),
            (-1, 999_999_999),
            (-86_401, 1),
            (1_700_000_000, 123),
            (1_700_000_000, 123_456_789),
        ] {
            assert_eq!(
                since_epoch(system_time(seconds, nanoseconds).unwrap()),
                (seconds, kept(nanoseconds))
            );
        }
    }

    #[test]
    fn from_system_time_refuses_what_time_panics_on() {
        let far = system_time(400_000_000_000, 0).unwrap();
        assert_eq!(
            refusal(offset_from(far)),
            panic_of(|| OffsetDateTime::from(far))
        );
        assert_eq!(refusal(utc_from(far)), panic_of(|| UtcDateTime::from(far)));
        let near = system_time(-1, 999_999_900).unwrap();
        assert_eq!(offset_from(near).unwrap(), OffsetDateTime::from(near));
        assert_eq!(offset_from(near).unwrap().unix_timestamp_nanos(), -100);
    }

    /// Before 1601 a Windows `SystemTime` does not exist, so std refuses it
    /// before time could.
    #[cfg(windows)]
    #[test]
    fn std_refuses_a_time_before_1601_on_windows() {
        assert_eq!(refusal(system_time(-400_000_000_000, 0)), SUBTRACTING);
        assert_eq!(refusal(system_time(-11_644_473_601, 0)), SUBTRACTING);
        assert!(system_time(-11_644_473_600, 0).is_ok());
        let year_one = OffsetDateTime::from_unix_timestamp(-62_135_596_800).unwrap();
        assert_eq!(refusal(super::system_from_offset(year_one)), SUBTRACTING);
    }

    /// Near `Date::MIN`, which only Unix's `SystemTime` reaches, time
    /// panics in one of two ways, and the gem refuses each with its text.
    #[cfg(not(windows))]
    #[test]
    fn from_system_time_refuses_what_time_panics_on_before_the_minimum() {
        let early = system_time(-400_000_000_000, 0).unwrap();
        assert_eq!(
            refusal(offset_from(early)),
            panic_of(|| OffsetDateTime::from(early))
        );
        for seconds in [-377_705_116_800, -377_705_116_801, -377_705_203_200] {
            let time = system_time(seconds, 0).unwrap();
            match capture(|| OffsetDateTime::from(time)) {
                Ok(value) => assert_eq!(offset_from(time).unwrap(), value),
                Err(Panic(message)) => assert_eq!(refusal(offset_from(time)), message),
            }
            match capture(|| UtcDateTime::from(time)) {
                Ok(value) => assert_eq!(utc_from(time).unwrap(), value),
                Err(Panic(message)) => assert_eq!(refusal(utc_from(time)), message),
            }
        }
        let near = system_time(-1, 999_999_999).unwrap();
        assert_eq!(offset_from(near).unwrap().unix_timestamp_nanos(), -1);
    }
}
