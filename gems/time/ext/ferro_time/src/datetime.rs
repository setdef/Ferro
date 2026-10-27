// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `PlainDateTime`, `UtcDateTime`, and `OffsetDateTime` (time 0.3.55
//! `src/plain_date_time.rs`, `src/utc_date_time.rs`,
//! `src/offset_date_time.rs`, and `src/interop/offsetdatetime_utcdatetime.rs`).
//!
//! The three share their readers, `replace_*`, `truncate_to_*`, and
//! arithmetic by name, so one macro defines those natives for each.

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, Value};
use time::{OffsetDateTime, PlainDateTime, SignedDuration, UtcDateTime};

use crate::calendar::unknown;
use crate::values::{
    month, weekday_number, NDate, NDuration, NOffsetDateTime, NPlain, NTime, NUtc, NUtcOffset,
};
use crate::{frozen, frozen_option, guarded, Failure};

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic messages of time 0.3.55's date-time
//   operators and conversions (src/plain_date_time.rs:1187-1276,
//   src/utc_date_time.rs:284-296, :1322-1380, src/offset_date_time.rs:195-270,
//   :1672-1762)

/// The message of every date-time `+` and `-` that leaves the range.
pub const OUT_OF_RANGE: &str = "resulting value is out of range";

/// The message of `to_offset` and `to_utc` leaving the range.
pub const LOCAL_OUT_OF_RANGE: &str = "local datetime out of valid range";

// SPDX-SnippetEnd

/// `value`, or `RangeError` with `message` (plan 007, decision 7).
pub fn or_range<T>(value: Option<T>, message: &str) -> Result<T, Failure> {
    value.ok_or_else(|| Failure::Range(message.to_owned()))
}

macro_rules! datetime {
    (
        $owner:literal, $wrapper:ident, $inner:ty, hms: [$h0:ident, $h1:ident, $h2:ident, $h3:ident],
        int: $int:ident, ints: $ints:ident, truncate: $truncate:ident,
        replace: $replace:ident, arith: $arith:ident, date: $date:ident, time: $time:ident,
        extra: { $($extra:literal => |$v:ident| $extra_value:expr),* $(,)? }
    ) => {
        /// The readers that answer one number; a month is its number, a
        /// weekday its days from Monday.
        fn $int(ruby: &Ruby, value: &$wrapper, name: Symbol) -> Result<i128, Error> {
            let name = name.name()?;
            let value = value.0;
            guarded(ruby, || {
                Ok(match name.as_ref() {
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
                    $($extra => { let $v = value; $extra_value })*
                    other => return Err(unknown($owner, other)),
                })
            })
        }

        /// The readers that answer a tuple.
        fn $ints(ruby: &Ruby, value: &$wrapper, name: Symbol) -> Result<Vec<i64>, Error> {
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
                    stringify!($h0) => {
                        let (h, m, s) = value.$h0();
                        vec![h.into(), m.into(), s.into()]
                    }
                    stringify!($h1) => {
                        let (h, m, s, ms) = value.$h1();
                        vec![h.into(), m.into(), s.into(), ms.into()]
                    }
                    stringify!($h2) => {
                        let (h, m, s, us) = value.$h2();
                        vec![h.into(), m.into(), s.into(), us.into()]
                    }
                    stringify!($h3) => {
                        let (h, m, s, ns) = value.$h3();
                        vec![h.into(), m.into(), s.into(), ns.into()]
                    }
                    other => return Err(unknown($owner, other)),
                })
            })
        }

        /// `truncate_to_day` to `truncate_to_microsecond`.
        fn $truncate(ruby: &Ruby, value: &$wrapper, name: Symbol) -> Result<Value, Error> {
            let name = name.name()?;
            let value = value.0;
            let result: $inner = guarded(ruby, || match name.as_ref() {
                "truncate_to_day" => Ok(value.truncate_to_day()),
                "truncate_to_hour" => Ok(value.truncate_to_hour()),
                "truncate_to_minute" => Ok(value.truncate_to_minute()),
                "truncate_to_second" => Ok(value.truncate_to_second()),
                "truncate_to_millisecond" => Ok(value.truncate_to_millisecond()),
                "truncate_to_microsecond" => Ok(value.truncate_to_microsecond()),
                other => Err(unknown($owner, other)),
            })?;
            Ok(frozen(ruby, $wrapper(result)).as_value())
        }

        /// `replace_year` to `replace_nanosecond`; magnus converts `number`
        /// to each method's type.
        fn $replace(ruby: &Ruby, value: &$wrapper, name: Symbol, number: Value) -> Result<Value, Error> {
            let name = name.name()?;
            let value = value.0;
            let result: $inner = match name.as_ref() {
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
                other => return Err(unknown($owner, other).into_error(ruby)),
            };
            Ok(frozen(ruby, $wrapper(result)).as_value())
        }

        /// `checked_add`, `checked_sub`, `saturating_add`, `saturating_sub`,
        /// `+`, or `-` with a duration; `+` and `-` refuse what time
        /// would panic on.
        fn $arith(ruby: &Ruby, value: &$wrapper, name: Symbol, duration: &NDuration) -> Result<Value, Error> {
            let name = name.name()?;
            let (value, duration): ($inner, SignedDuration) = (value.0, duration.0);
            let result = guarded(ruby, || match name.as_ref() {
                "checked_add" => Ok(value.checked_add(duration)),
                "checked_sub" => Ok(value.checked_sub(duration)),
                "saturating_add" => Ok(Some(value.saturating_add(duration))),
                "saturating_sub" => Ok(Some(value.saturating_sub(duration))),
                "+" => or_range(value.checked_add(duration), OUT_OF_RANGE).map(Some),
                "-" => or_range(value.checked_sub(duration), OUT_OF_RANGE).map(Some),
                other => Err(unknown($owner, other)),
            })?;
            Ok(frozen_option(ruby, result.map($wrapper)))
        }

        /// `date`.
        fn $date(ruby: &Ruby, value: &$wrapper) -> Result<Value, Error> {
            let value = value.0;
            let date = guarded(ruby, || Ok(value.date()))?;
            Ok(frozen(ruby, NDate(date)).as_value())
        }

        /// `time`.
        fn $time(ruby: &Ruby, value: &$wrapper) -> Result<Value, Error> {
            let value = value.0;
            let time = guarded(ruby, || Ok(value.time()))?;
            Ok(frozen(ruby, NTime(time)).as_value())
        }
    };
}

datetime!(
    "PlainDateTime", NPlain, PlainDateTime, hms: [as_hms, as_hms_milli, as_hms_micro, as_hms_nano],
    int: plain_int, ints: plain_ints, truncate: plain_truncate, replace: plain_replace,
    arith: plain_arith, date: plain_date, time: plain_time,
    extra: {}
);

datetime!(
    "UtcDateTime", NUtc, UtcDateTime, hms: [as_hms, as_hms_milli, as_hms_micro, as_hms_nano],
    int: utc_int, ints: utc_ints, truncate: utc_truncate, replace: utc_replace,
    arith: utc_arith, date: utc_date, time: utc_time,
    extra: {
        "unix_timestamp" => |v| v.unix_timestamp().into(),
        "unix_timestamp_nanos" => |v| v.unix_timestamp_nanos(),
    }
);

datetime!(
    "OffsetDateTime", NOffsetDateTime, OffsetDateTime, hms: [to_hms, to_hms_milli, to_hms_micro, to_hms_nano],
    int: offset_date_time_int, ints: offset_date_time_ints, truncate: offset_date_time_truncate,
    replace: offset_date_time_replace, arith: offset_date_time_arith,
    date: offset_date_time_date, time: offset_date_time_time,
    extra: {
        "unix_timestamp" => |v| v.unix_timestamp().into(),
        "unix_timestamp_nanos" => |v| v.unix_timestamp_nanos(),
    }
);

fn plain(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<PlainDateTime, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NPlain(value)).as_value())
}

fn utc(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<UtcDateTime, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NUtc(value)).as_value())
}

fn odt(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<OffsetDateTime, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NOffsetDateTime(value)).as_value())
}

fn duration(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<SignedDuration, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NDuration(value)).as_value())
}

/// `PlainDateTime::MIN` or `MAX` (`plain_date_time.rs:80-165`).
fn plain_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    plain(ruby, || match name.as_ref() {
        "MIN" => Ok(PlainDateTime::MIN),
        "MAX" => Ok(PlainDateTime::MAX),
        other => Err(unknown("PlainDateTime", other)),
    })
}

/// `PlainDateTime::new` (`plain_date_time.rs:167-176`).
fn plain_new(ruby: &Ruby, date: &NDate, time: &NTime) -> Result<Value, Error> {
    let (date, time) = (date.0, time.0);
    plain(ruby, || Ok(PlainDateTime::new(date, time)))
}

/// `replace_time` or `replace_date` (`plain_date_time.rs:719-760`).
fn plain_replace_time(ruby: &Ruby, value: &NPlain, time: &NTime) -> Result<Value, Error> {
    let (value, time) = (value.0, time.0);
    plain(ruby, || Ok(value.replace_time(time)))
}

fn plain_replace_date(ruby: &Ruby, value: &NPlain, date: &NDate) -> Result<Value, Error> {
    let (value, date) = (value.0, date.0);
    plain(ruby, || Ok(value.replace_date(date)))
}

/// `assume_offset` (`plain_date_time.rs:545-558`).
fn plain_assume_offset(ruby: &Ruby, value: &NPlain, offset: &NUtcOffset) -> Result<Value, Error> {
    let (value, offset) = (value.0, offset.0);
    odt(ruby, || Ok(value.assume_offset(offset)))
}

/// `assume_utc` (`plain_date_time.rs:560-576`).
fn plain_assume_utc(ruby: &Ruby, value: &NPlain) -> Result<Value, Error> {
    let value = value.0;
    odt(ruby, || Ok(value.assume_utc()))
}

/// `as_utc` (`plain_date_time.rs:578-591`).
fn plain_as_utc(ruby: &Ruby, value: &NPlain) -> Result<Value, Error> {
    let value = value.0;
    utc(ruby, || Ok(value.as_utc()))
}

/// `Sub for PlainDateTime` (`plain_date_time.rs:1307-1314`).
fn plain_difference(ruby: &Ruby, value: &NPlain, other: &NPlain) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    duration(ruby, || Ok(value - other))
}

/// `UtcDateTime::UNIX_EPOCH`, `MIN`, or `MAX` (`utc_date_time.rs:43-110`).
fn utc_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    utc(ruby, || match name.as_ref() {
        "UNIX_EPOCH" => Ok(UtcDateTime::UNIX_EPOCH),
        "MIN" => Ok(UtcDateTime::MIN),
        "MAX" => Ok(UtcDateTime::MAX),
        other => Err(unknown("UtcDateTime", other)),
    })
}

/// `UtcDateTime::now` (`utc_date_time.rs:112-135`).
fn utc_now(ruby: &Ruby) -> Result<Value, Error> {
    utc(ruby, || Ok(UtcDateTime::now()))
}

/// `UtcDateTime::new` (`utc_date_time.rs:137-156`).
fn utc_new(ruby: &Ruby, date: &NDate, time: &NTime) -> Result<Value, Error> {
    let (date, time) = (date.0, time.0);
    utc(ruby, || Ok(UtcDateTime::new(date, time)))
}

/// `from_unix_timestamp` (`utc_date_time.rs:158-202`).
fn utc_from_unix_timestamp(ruby: &Ruby, timestamp: i64) -> Result<Value, Error> {
    utc(ruby, || Ok(UtcDateTime::from_unix_timestamp(timestamp)?))
}

/// `from_unix_timestamp_nanos` (`utc_date_time.rs:204-252`).
fn utc_from_unix_timestamp_nanos(ruby: &Ruby, timestamp: i128) -> Result<Value, Error> {
    utc(ruby, || {
        Ok(UtcDateTime::from_unix_timestamp_nanos(timestamp)?)
    })
}

/// `to_offset`, refusing what time panics on, or `checked_to_offset`
/// (`utc_date_time.rs:254-380`).
fn utc_to_offset(
    ruby: &Ruby,
    value: &NUtc,
    name: Symbol,
    offset: &NUtcOffset,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, offset) = (value.0, offset.0);
    let result = guarded(ruby, || match name.as_ref() {
        "to_offset" => or_range(value.checked_to_offset(offset), LOCAL_OUT_OF_RANGE).map(Some),
        "checked_to_offset" => Ok(value.checked_to_offset(offset)),
        other => Err(unknown("UtcDateTime", other)),
    })?;
    Ok(frozen_option(ruby, result.map(NOffsetDateTime)))
}

/// `replace_time` or `replace_date` (`utc_date_time.rs:859-900`).
fn utc_replace_time(ruby: &Ruby, value: &NUtc, time: &NTime) -> Result<Value, Error> {
    let (value, time) = (value.0, time.0);
    utc(ruby, || Ok(value.replace_time(time)))
}

fn utc_replace_date(ruby: &Ruby, value: &NUtc, date: &NDate) -> Result<Value, Error> {
    let (value, date) = (value.0, date.0);
    utc(ruby, || Ok(value.replace_date(date)))
}

/// `Sub for UtcDateTime` (`utc_date_time.rs:1419-1426`) and
/// `Sub<OffsetDateTime> for UtcDateTime` (`interop/offsetdatetime_utcdatetime.rs:6-17`).
fn utc_difference(ruby: &Ruby, value: &NUtc, other: &NUtc) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    duration(ruby, || Ok(value - other))
}

fn utc_difference_offset(
    ruby: &Ruby,
    value: &NUtc,
    other: &NOffsetDateTime,
) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    duration(ruby, || Ok(value - other))
}

/// `PartialEq` and `PartialOrd` with an `OffsetDateTime`
/// (`interop/offsetdatetime_utcdatetime.rs:32-58`).
fn utc_eq_offset(ruby: &Ruby, value: &NUtc, other: &NOffsetDateTime) -> Result<bool, Error> {
    let (value, other) = (value.0, other.0);
    guarded(ruby, || Ok(value == other))
}

fn utc_cmp_offset(ruby: &Ruby, value: &NUtc, other: &NOffsetDateTime) -> Result<Option<i8>, Error> {
    let (value, other) = (value.0, other.0);
    guarded(ruby, || {
        Ok(value.partial_cmp(&other).map(|ordering| ordering as i8))
    })
}

/// `From<OffsetDateTime> for UtcDateTime`
/// (`interop/offsetdatetime_utcdatetime.rs:60-69`), refusing what its
/// `to_utc` panics on.
fn utc_from_offset(ruby: &Ruby, value: &NOffsetDateTime) -> Result<Value, Error> {
    let value = value.0;
    utc(ruby, || {
        or_range(value.checked_to_utc(), LOCAL_OUT_OF_RANGE).map(|_| UtcDateTime::from(value))
    })
}

/// `OffsetDateTime::UNIX_EPOCH` (`offset_date_time.rs:84-97`).
fn offset_date_time_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    odt(ruby, || match name.as_ref() {
        "UNIX_EPOCH" => Ok(OffsetDateTime::UNIX_EPOCH),
        other => Err(unknown("OffsetDateTime", other)),
    })
}

/// `now_utc` (`offset_date_time.rs:99-121`).
fn offset_date_time_now_utc(ruby: &Ruby) -> Result<Value, Error> {
    odt(ruby, || Ok(OffsetDateTime::now_utc()))
}

/// `now_local` (`offset_date_time.rs:123-151`).
fn offset_date_time_now_local(ruby: &Ruby) -> Result<Value, Error> {
    odt(ruby, || Ok(OffsetDateTime::now_local()?))
}

/// `new_in_offset` (`offset_date_time.rs:153-171`).
fn offset_date_time_new_in_offset(
    ruby: &Ruby,
    date: &NDate,
    time: &NTime,
    offset: &NUtcOffset,
) -> Result<Value, Error> {
    let (date, time, offset) = (date.0, time.0, offset.0);
    odt(ruby, || {
        Ok(OffsetDateTime::new_in_offset(date, time, offset))
    })
}

/// `new_utc` (`offset_date_time.rs:173-185`).
fn offset_date_time_new_utc(ruby: &Ruby, date: &NDate, time: &NTime) -> Result<Value, Error> {
    let (date, time) = (date.0, time.0);
    odt(ruby, || Ok(OffsetDateTime::new_utc(date, time)))
}

/// `to_offset`, refusing what time panics on, or `checked_to_offset`
/// (`offset_date_time.rs:187-252`).
fn offset_date_time_to_offset(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    name: Symbol,
    offset: &NUtcOffset,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, offset) = (value.0, offset.0);
    let result = guarded(ruby, || match name.as_ref() {
        "to_offset" => or_range(value.checked_to_offset(offset), LOCAL_OUT_OF_RANGE).map(Some),
        "checked_to_offset" => Ok(value.checked_to_offset(offset)),
        other => Err(unknown("OffsetDateTime", other)),
    })?;
    Ok(frozen_option(ruby, result.map(NOffsetDateTime)))
}

/// `to_utc`, refusing what time panics on, or `checked_to_utc`
/// (`offset_date_time.rs:254-310`).
fn offset_date_time_to_utc(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    name: Symbol,
) -> Result<Value, Error> {
    let name = name.name()?;
    let value = value.0;
    let result = guarded(ruby, || match name.as_ref() {
        "to_utc" => or_range(value.checked_to_utc(), LOCAL_OUT_OF_RANGE).map(Some),
        "checked_to_utc" => Ok(value.checked_to_utc()),
        other => Err(unknown("OffsetDateTime", other)),
    })?;
    Ok(frozen_option(ruby, result.map(NUtc)))
}

/// `from_unix_timestamp` (`offset_date_time.rs:410-460`).
fn offset_date_time_from_unix_timestamp(ruby: &Ruby, timestamp: i64) -> Result<Value, Error> {
    odt(ruby, || Ok(OffsetDateTime::from_unix_timestamp(timestamp)?))
}

/// `from_unix_timestamp_nanos` (`offset_date_time.rs:462-515`).
fn offset_date_time_from_unix_timestamp_nanos(
    ruby: &Ruby,
    timestamp: i128,
) -> Result<Value, Error> {
    odt(ruby, || {
        Ok(OffsetDateTime::from_unix_timestamp_nanos(timestamp)?)
    })
}

/// `offset` (`offset_date_time.rs:517-527`).
fn offset_date_time_offset(ruby: &Ruby, value: &NOffsetDateTime) -> Result<Value, Error> {
    let value = value.0;
    let offset = guarded(ruby, || Ok(value.offset()))?;
    Ok(frozen(ruby, NUtcOffset(offset)).as_value())
}

/// `replace_time`, `replace_date`, `replace_date_time`, `replace_offset`
/// (`offset_date_time.rs:1143-1221`).
fn offset_date_time_replace_time(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    time: &NTime,
) -> Result<Value, Error> {
    let (value, time) = (value.0, time.0);
    odt(ruby, || Ok(value.replace_time(time)))
}

fn offset_date_time_replace_date(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    date: &NDate,
) -> Result<Value, Error> {
    let (value, date) = (value.0, date.0);
    odt(ruby, || Ok(value.replace_date(date)))
}

fn offset_date_time_replace_date_time(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    date_time: &NPlain,
) -> Result<Value, Error> {
    let (value, date_time) = (value.0, date_time.0);
    odt(ruby, || Ok(value.replace_date_time(date_time)))
}

fn offset_date_time_replace_offset(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    offset: &NUtcOffset,
) -> Result<Value, Error> {
    let (value, offset) = (value.0, offset.0);
    odt(ruby, || Ok(value.replace_offset(offset)))
}

/// `Sub for OffsetDateTime` (`offset_date_time.rs:1794-1805`) and
/// `Sub<UtcDateTime> for OffsetDateTime` (`interop/offsetdatetime_utcdatetime.rs:19-30`).
fn offset_date_time_difference(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    other: &NOffsetDateTime,
) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    duration(ruby, || Ok(value - other))
}

fn offset_date_time_difference_utc(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    other: &NUtc,
) -> Result<Value, Error> {
    let (value, other) = (value.0, other.0);
    duration(ruby, || Ok(value - other))
}

/// `PartialEq` and `PartialOrd` with a `UtcDateTime`
/// (`interop/offsetdatetime_utcdatetime.rs:39-58`).
fn offset_date_time_eq_utc(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    other: &NUtc,
) -> Result<bool, Error> {
    let (value, other) = (value.0, other.0);
    guarded(ruby, || Ok(value == other))
}

fn offset_date_time_cmp_utc(
    ruby: &Ruby,
    value: &NOffsetDateTime,
    other: &NUtc,
) -> Result<Option<i8>, Error> {
    let (value, other) = (value.0, other.0);
    guarded(ruby, || {
        Ok(value.partial_cmp(&other).map(|ordering| ordering as i8))
    })
}

/// `From<UtcDateTime> for OffsetDateTime`
/// (`interop/offsetdatetime_utcdatetime.rs:71-82`).
fn offset_date_time_from_utc(ruby: &Ruby, value: &NUtc) -> Result<Value, Error> {
    let value = value.0;
    odt(ruby, || Ok(OffsetDateTime::from(value)))
}

macro_rules! define {
    ($native:ident, $($name:ident / $arity:tt),+ $(,)?) => {
        $($native.define_singleton_method(stringify!($name), function!($name, $arity))?;)+
    };
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    define!(
        native,
        plain_int / 2,
        plain_ints / 2,
        plain_truncate / 2,
        plain_replace / 3,
        plain_arith / 3,
        plain_date / 1,
        plain_time / 1,
        plain_constant / 1,
        plain_new / 2,
        plain_replace_time / 2,
        plain_replace_date / 2,
        plain_assume_offset / 2,
        plain_assume_utc / 1,
        plain_as_utc / 1,
        plain_difference / 2,
        utc_int / 2,
        utc_ints / 2,
        utc_truncate / 2,
        utc_replace / 3,
        utc_arith / 3,
        utc_date / 1,
        utc_time / 1,
        utc_constant / 1,
        utc_now / 0,
        utc_new / 2,
        utc_from_unix_timestamp / 1,
        utc_from_unix_timestamp_nanos / 1,
        utc_to_offset / 3,
        utc_replace_time / 2,
        utc_replace_date / 2,
        utc_difference / 2,
        utc_difference_offset / 2,
        utc_eq_offset / 2,
        utc_cmp_offset / 2,
        utc_from_offset / 1,
        offset_date_time_int / 2,
        offset_date_time_ints / 2,
        offset_date_time_truncate / 2,
        offset_date_time_replace / 3,
        offset_date_time_arith / 3,
        offset_date_time_date / 1,
        offset_date_time_time / 1,
        offset_date_time_constant / 1,
        offset_date_time_now_utc / 0,
        offset_date_time_now_local / 0,
        offset_date_time_new_in_offset / 3,
        offset_date_time_new_utc / 2,
        offset_date_time_to_offset / 3,
        offset_date_time_to_utc / 2,
        offset_date_time_from_unix_timestamp / 1,
        offset_date_time_from_unix_timestamp_nanos / 1,
        offset_date_time_offset / 1,
        offset_date_time_replace_time / 2,
        offset_date_time_replace_date / 2,
        offset_date_time_replace_date_time / 2,
        offset_date_time_replace_offset / 2,
        offset_date_time_difference / 2,
        offset_date_time_difference_utc / 2,
        offset_date_time_eq_utc / 2,
        offset_date_time_cmp_utc / 2,
        offset_date_time_from_utc / 1,
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{or_range, LOCAL_OUT_OF_RANGE, OUT_OF_RANGE};
    use crate::{capture, Failure, Panic};
    use time::{OffsetDateTime, PlainDateTime, SignedDuration, UtcDateTime, UtcOffset};

    fn panic_of<T: std::fmt::Debug>(operation: impl FnOnce() -> T) -> String {
        match capture(operation) {
            Err(Panic(message)) => message,
            Ok(value) => panic!("time did not panic: {value:?}"),
        }
    }

    fn refusal<T: std::fmt::Debug>(result: Result<T, Failure>) -> String {
        match result {
            Err(Failure::Range(message)) => message,
            other => panic!("not refused: {other:?}"),
        }
    }

    #[test]
    fn each_refusal_is_times_own_panic() {
        let day = SignedDuration::DAY;
        let plain = PlainDateTime::MAX;
        assert_eq!(
            refusal(or_range(plain.checked_add(day), OUT_OF_RANGE)),
            panic_of(|| plain + day)
        );
        assert_eq!(
            refusal(or_range(PlainDateTime::MIN.checked_sub(day), OUT_OF_RANGE)),
            panic_of(|| PlainDateTime::MIN - day)
        );
        let utc = UtcDateTime::MAX;
        assert_eq!(
            refusal(or_range(utc.checked_add(day), OUT_OF_RANGE)),
            panic_of(|| utc + day)
        );
        assert_eq!(
            refusal(or_range(UtcDateTime::MIN.checked_sub(day), OUT_OF_RANGE)),
            panic_of(|| UtcDateTime::MIN - day)
        );
        let odt = PlainDateTime::MAX.assume_utc();
        assert_eq!(
            refusal(or_range(odt.checked_add(day), OUT_OF_RANGE)),
            panic_of(|| odt + day)
        );
        assert_eq!(
            refusal(or_range(odt.checked_sub(-day), OUT_OF_RANGE)),
            panic_of(|| odt - -day)
        );
        let east = UtcOffset::from_hms(1, 0, 0).unwrap();
        assert_eq!(
            refusal(or_range(odt.checked_to_offset(east), LOCAL_OUT_OF_RANGE)),
            panic_of(|| odt.to_offset(east))
        );
        assert_eq!(
            refusal(or_range(utc.checked_to_offset(east), LOCAL_OUT_OF_RANGE)),
            panic_of(|| utc.to_offset(east))
        );
        let west = PlainDateTime::MAX.assume_offset(UtcOffset::from_hms(-1, 0, 0).unwrap());
        assert_eq!(
            refusal(or_range(west.checked_to_utc(), LOCAL_OUT_OF_RANGE)),
            panic_of(|| west.to_utc())
        );
        assert_eq!(
            refusal(or_range(west.checked_to_utc(), LOCAL_OUT_OF_RANGE)),
            panic_of(|| UtcDateTime::from(west))
        );
        assert!(capture(|| OffsetDateTime::from(UtcDateTime::MAX)).is_ok());
    }
}
