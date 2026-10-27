// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `Date` (time 0.3.55 `src/date.rs`).

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, Value};
use time::{Date, SignedDuration, Weekday};

use crate::calendar::unknown;
use crate::values::{month, weekday, weekday_number, NDate, NDuration, NPlain, NTime};
use crate::{frozen, frozen_option, guarded, Failure};

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic messages of time 0.3.55's Date operators
//   (src/date.rs:660-750, :1661-1737) and the conditions of its private
//   checked occurrence helpers (src/date.rs:1046-1108)

/// `Add<SignedDuration>` (`:1661-1672`).
pub fn add(date: Date, duration: SignedDuration) -> Result<Date, Failure> {
    date.checked_add(duration)
        .ok_or_else(|| Failure::Range("overflow adding duration to date".to_owned()))
}

/// `Sub<SignedDuration>` (`:1711-1722`).
pub fn sub(date: Date, duration: SignedDuration) -> Result<Date, Failure> {
    date.checked_sub(duration)
        .ok_or_else(|| Failure::Range("overflow subtracting duration from date".to_owned()))
}

/// The day difference of time's private `checked_next_occurrence`
/// (`:1049-1064`).
const fn next_diff(date: Date, weekday: Weekday) -> i64 {
    match weekday as i8 - date.weekday() as i8 {
        1 | -6 => 1,
        2 | -5 => 2,
        3 | -4 => 3,
        4 | -3 => 4,
        5 | -2 => 5,
        6 | -1 => 6,
        _ => 7,
    }
}

/// `next_occurrence`, `prev_occurrence`, `nth_next_occurrence`, or
/// `nth_prev_occurrence` (`:660-750`), refused as time's `expect` would
/// panic: when the date leaves the supported range, or when `n` is zero.
pub fn occurrence(date: Date, name: &str, weekday: Weekday, n: u8) -> Result<Date, Failure> {
    let next = "overflow calculating the next occurrence of a weekday";
    let previous = "overflow calculating the previous occurrence of a weekday";
    let fits = |forward: bool, n: u8| {
        if n == 0 {
            return false;
        }
        // time's private `checked_prev_occurrence` (`:1069-1084`) mirrors
        // the next one: 6 back where the next is 1 ahead, 7 for the same day.
        let first = match (forward, next_diff(date, weekday)) {
            (true, diff) | (false, diff @ 7) => diff,
            (false, diff) => 7 - diff,
        };
        let step = date.checked_add(SignedDuration::days(if forward { first } else { -first }));
        let weeks = SignedDuration::weeks(i64::from(n) - 1);
        step.and_then(|step| {
            if forward {
                step.checked_add(weeks)
            } else {
                step.checked_sub(weeks)
            }
        })
        .is_some()
    };
    let refuse = |message: &str| Err(Failure::Range(message.to_owned()));
    match name {
        "next_occurrence" if fits(true, 1) => Ok(date.next_occurrence(weekday)),
        "prev_occurrence" if fits(false, 1) => Ok(date.prev_occurrence(weekday)),
        "nth_next_occurrence" if fits(true, n) => Ok(date.nth_next_occurrence(weekday, n)),
        "nth_prev_occurrence" if fits(false, n) => Ok(date.nth_prev_occurrence(weekday, n)),
        "next_occurrence" | "nth_next_occurrence" => refuse(next),
        "prev_occurrence" | "nth_prev_occurrence" => refuse(previous),
        other => Err(unknown("Date", other)),
    }
}

// SPDX-SnippetEnd

/// A date made by `operation`, wrapped.
fn made(ruby: &Ruby, operation: impl FnOnce() -> Result<Date, Failure>) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NDate(value)).as_value())
}

/// `MIN` or `MAX` (`:76-98`).
fn date_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    made(ruby, || match name.as_ref() {
        "MIN" => Ok(Date::MIN),
        "MAX" => Ok(Date::MAX),
        other => Err(unknown("Date", other)),
    })
}

/// `from_calendar_date` (`:126-187`).
fn date_from_calendar_date(ruby: &Ruby, year: i32, number: u8, day: u8) -> Result<Value, Error> {
    made(ruby, || {
        Ok(Date::from_calendar_date(year, month(number)?, day)?)
    })
}

/// `from_ordinal_date` (`:189-217`).
fn date_from_ordinal_date(ruby: &Ruby, year: i32, ordinal: u16) -> Result<Value, Error> {
    made(ruby, || Ok(Date::from_ordinal_date(year, ordinal)?))
}

/// `from_iso_week_date` (`:219-286`).
fn date_from_iso_week_date(ruby: &Ruby, year: i32, week: u8, days: u8) -> Result<Value, Error> {
    made(ruby, || {
        Ok(Date::from_iso_week_date(year, week, weekday(days)?)?)
    })
}

/// `from_julian_day` (`:288-351`).
fn date_from_julian_day(ruby: &Ruby, julian_day: i32) -> Result<Value, Error> {
    made(ruby, || Ok(Date::from_julian_day(julian_day)?))
}

/// The readers that answer one number (`:353-779`); a month is its
/// number, a weekday its days from Monday.
fn date_int(ruby: &Ruby, date: &NDate, name: Symbol) -> Result<i64, Error> {
    let name = name.name()?;
    let date = date.0;
    guarded(ruby, || {
        Ok(match name.as_ref() {
            "year" => date.year().into(),
            "month" => u8::from(date.month()).into(),
            "day" => date.day().into(),
            "ordinal" => date.ordinal().into(),
            "iso_week" => date.iso_week().into(),
            "sunday_based_week" => date.sunday_based_week().into(),
            "monday_based_week" => date.monday_based_week().into(),
            "weekday" => weekday_number(date.weekday()).into(),
            "to_julian_day" => date.to_julian_day().into(),
            other => return Err(unknown("Date", other)),
        })
    })
}

/// The readers that answer a tuple (`:502-583`).
fn date_ints(ruby: &Ruby, date: &NDate, name: Symbol) -> Result<Vec<i64>, Error> {
    let name = name.name()?;
    let date = date.0;
    guarded(ruby, || {
        Ok(match name.as_ref() {
            "to_calendar_date" => {
                let (year, month, day) = date.to_calendar_date();
                vec![year.into(), u8::from(month).into(), day.into()]
            }
            "to_ordinal_date" => {
                let (year, ordinal) = date.to_ordinal_date();
                vec![year.into(), ordinal.into()]
            }
            "to_iso_week_date" => {
                let (year, week, weekday) = date.to_iso_week_date();
                vec![year.into(), week.into(), weekday_number(weekday).into()]
            }
            other => return Err(unknown("Date", other)),
        })
    })
}

/// `next_day` or `previous_day` (`:595-650`).
fn date_option(ruby: &Ruby, date: &NDate, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    let date = date.0;
    let value = guarded(ruby, || match name.as_ref() {
        "next_day" => Ok(date.next_day()),
        "previous_day" => Ok(date.previous_day()),
        other => Err(unknown("Date", other)),
    })?;
    Ok(frozen_option(ruby, value.map(NDate)))
}

/// The four occurrence methods (`:652-750`).
fn date_occurrence(
    ruby: &Ruby,
    date: &NDate,
    name: Symbol,
    days: u8,
    n: u8,
) -> Result<Value, Error> {
    let name = name.name()?;
    let date = date.0;
    made(ruby, || occurrence(date, &name, weekday(days)?, n))
}

/// `checked_add`, `checked_sub`, `saturating_add`, `saturating_sub`,
/// `+`, or `-` with a duration (`:781-1191`, `:1661-1737`).
fn date_arith(
    ruby: &Ruby,
    date: &NDate,
    name: Symbol,
    duration: &NDuration,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (date, duration) = (date.0, duration.0);
    let value = guarded(ruby, || match name.as_ref() {
        "checked_add" => Ok(date.checked_add(duration)),
        "checked_sub" => Ok(date.checked_sub(duration)),
        "saturating_add" => Ok(Some(date.saturating_add(duration))),
        "saturating_sub" => Ok(Some(date.saturating_sub(duration))),
        "+" => add(date, duration).map(Some),
        "-" => sub(date, duration).map(Some),
        other => Err(unknown("Date", other)),
    })?;
    Ok(frozen_option(ruby, value.map(NDate)))
}

/// `Sub for Date` (`:1761-1768`).
fn date_difference(ruby: &Ruby, date: &NDate, other: &NDate) -> Result<Value, Error> {
    let (date, other) = (date.0, other.0);
    let value = guarded(ruby, || Ok(date - other))?;
    Ok(frozen(ruby, NDuration(value)).as_value())
}

/// `replace_year`, `replace_month`, `replace_day`, or `replace_ordinal`
/// (`:1193-1351`); magnus converts `value` to each method's type.
fn date_replace(ruby: &Ruby, date: &NDate, name: Symbol, value: Value) -> Result<Value, Error> {
    let name = name.name()?;
    let date = date.0;
    let year = || i32::try_convert(value);
    match name.as_ref() {
        "replace_year" => {
            let year = year()?;
            made(ruby, || Ok(date.replace_year(year)?))
        }
        "replace_month" => {
            let number = u8::try_convert(value)?;
            made(ruby, || Ok(date.replace_month(month(number)?)?))
        }
        "replace_day" => {
            let day = u8::try_convert(value)?;
            made(ruby, || Ok(date.replace_day(day)?))
        }
        "replace_ordinal" => {
            let ordinal = u16::try_convert(value)?;
            made(ruby, || Ok(date.replace_ordinal(ordinal)?))
        }
        other => Err(unknown("Date", other).into_error(ruby)),
    }
}

/// A date and time made by `operation`, wrapped.
fn plain(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<time::PlainDateTime, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NPlain(value)).as_value())
}

/// `midnight` (`:1355-1366`).
fn date_midnight(ruby: &Ruby, date: &NDate) -> Result<Value, Error> {
    let date = date.0;
    plain(ruby, || Ok(date.midnight()))
}

/// `with_time` (`:1368-1380`).
fn date_with_time(ruby: &Ruby, date: &NDate, time: &NTime) -> Result<Value, Error> {
    let (date, time) = (date.0, time.0);
    plain(ruby, || Ok(date.with_time(time)))
}

/// `with_hms` (`:1382-1400`).
fn date_with_hms(
    ruby: &Ruby,
    date: &NDate,
    hour: u8,
    minute: u8,
    second: u8,
) -> Result<Value, Error> {
    let date = date.0;
    plain(ruby, || Ok(date.with_hms(hour, minute, second)?))
}

/// `with_hms_milli` (`:1402-1421`).
fn date_with_hms_milli(
    ruby: &Ruby,
    date: &NDate,
    hour: u8,
    minute: u8,
    second: u8,
    millisecond: u16,
) -> Result<Value, Error> {
    let date = date.0;
    plain(ruby, || {
        Ok(date.with_hms_milli(hour, minute, second, millisecond)?)
    })
}

/// `with_hms_micro` (`:1423-1442`).
fn date_with_hms_micro(
    ruby: &Ruby,
    date: &NDate,
    hour: u8,
    minute: u8,
    second: u8,
    microsecond: u32,
) -> Result<Value, Error> {
    let date = date.0;
    plain(ruby, || {
        Ok(date.with_hms_micro(hour, minute, second, microsecond)?)
    })
}

/// `with_hms_nano` (`:1444-1462`).
fn date_with_hms_nano(
    ruby: &Ruby,
    date: &NDate,
    hour: u8,
    minute: u8,
    second: u8,
    nanosecond: u32,
) -> Result<Value, Error> {
    let date = date.0;
    plain(ruby, || {
        Ok(date.with_hms_nano(hour, minute, second, nanosecond)?)
    })
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("date_constant", function!(date_constant, 1))?;
    native.define_singleton_method(
        "date_from_calendar_date",
        function!(date_from_calendar_date, 3),
    )?;
    native.define_singleton_method(
        "date_from_ordinal_date",
        function!(date_from_ordinal_date, 2),
    )?;
    native.define_singleton_method(
        "date_from_iso_week_date",
        function!(date_from_iso_week_date, 3),
    )?;
    native.define_singleton_method("date_from_julian_day", function!(date_from_julian_day, 1))?;
    native.define_singleton_method("date_int", function!(date_int, 2))?;
    native.define_singleton_method("date_ints", function!(date_ints, 2))?;
    native.define_singleton_method("date_option", function!(date_option, 2))?;
    native.define_singleton_method("date_occurrence", function!(date_occurrence, 4))?;
    native.define_singleton_method("date_arith", function!(date_arith, 3))?;
    native.define_singleton_method("date_difference", function!(date_difference, 2))?;
    native.define_singleton_method("date_replace", function!(date_replace, 3))?;
    native.define_singleton_method("date_midnight", function!(date_midnight, 1))?;
    native.define_singleton_method("date_with_time", function!(date_with_time, 2))?;
    native.define_singleton_method("date_with_hms", function!(date_with_hms, 4))?;
    native.define_singleton_method("date_with_hms_milli", function!(date_with_hms_milli, 5))?;
    native.define_singleton_method("date_with_hms_micro", function!(date_with_hms_micro, 5))?;
    native.define_singleton_method("date_with_hms_nano", function!(date_with_hms_nano, 5))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{add, occurrence, sub};
    use crate::{capture, Failure, Panic};
    use time::{Date, Month, SignedDuration, Weekday};

    fn panic_of(operation: impl FnOnce() -> Date) -> String {
        match capture(operation) {
            Err(Panic(message)) => message,
            Ok(value) => panic!("time did not panic: {value}"),
        }
    }

    fn refusal(result: Result<Date, Failure>) -> String {
        match result {
            Err(Failure::Range(message)) => message,
            other => panic!("not refused: {other:?}"),
        }
    }

    #[test]
    fn each_refusal_is_times_own_panic() {
        let max = Date::MAX;
        let min = Date::MIN;
        assert_eq!(
            refusal(add(max, SignedDuration::DAY)),
            panic_of(|| max + SignedDuration::DAY)
        );
        assert_eq!(
            refusal(sub(min, SignedDuration::DAY)),
            panic_of(|| min - SignedDuration::DAY)
        );
        for weekday in [Weekday::Monday, Weekday::Friday, Weekday::Sunday] {
            assert_eq!(
                refusal(occurrence(max, "next_occurrence", weekday, 0)),
                panic_of(|| max.next_occurrence(weekday))
            );
            assert_eq!(
                refusal(occurrence(min, "prev_occurrence", weekday, 0)),
                panic_of(|| min.prev_occurrence(weekday))
            );
            let near = max.checked_sub(SignedDuration::days(10)).unwrap();
            assert_eq!(
                refusal(occurrence(near, "nth_next_occurrence", weekday, 3)),
                panic_of(|| near.nth_next_occurrence(weekday, 3))
            );
            let date = Date::from_calendar_date(2023, Month::June, 25).unwrap();
            assert_eq!(
                refusal(occurrence(date, "nth_prev_occurrence", weekday, 0)),
                panic_of(|| date.nth_prev_occurrence(weekday, 0))
            );
        }
    }

    #[test]
    fn every_occurrence_time_computes_passes_through() {
        let date = Date::from_calendar_date(2023, Month::June, 25).unwrap();
        for weekday in [
            Weekday::Monday,
            Weekday::Tuesday,
            Weekday::Wednesday,
            Weekday::Thursday,
            Weekday::Friday,
            Weekday::Saturday,
            Weekday::Sunday,
        ] {
            assert_eq!(
                occurrence(date, "next_occurrence", weekday, 0).unwrap(),
                date.next_occurrence(weekday)
            );
            assert_eq!(
                occurrence(date, "prev_occurrence", weekday, 0).unwrap(),
                date.prev_occurrence(weekday)
            );
            for n in 1..=5 {
                assert_eq!(
                    occurrence(date, "nth_next_occurrence", weekday, n).unwrap(),
                    date.nth_next_occurrence(weekday, n)
                );
                assert_eq!(
                    occurrence(date, "nth_prev_occurrence", weekday, n).unwrap(),
                    date.nth_prev_occurrence(weekday, n)
                );
            }
        }
    }

    /// An occurrence method's name and a call of it on time's own date.
    type Call = (&'static str, Box<dyn Fn() -> Date>);

    /// Near either end of the range, every occurrence the gem refuses is
    /// one time panics on, and every one it lets through time computes.
    #[test]
    fn the_refusals_match_times_panics_at_both_ends() {
        let weekdays = [
            Weekday::Monday,
            Weekday::Tuesday,
            Weekday::Wednesday,
            Weekday::Thursday,
            Weekday::Friday,
            Weekday::Saturday,
            Weekday::Sunday,
        ];
        let ends = (0..21).flat_map(|days| {
            [
                Date::MIN.checked_add(SignedDuration::days(days)).unwrap(),
                Date::MAX.checked_sub(SignedDuration::days(days)).unwrap(),
            ]
        });
        for date in ends {
            for weekday in weekdays {
                for n in 0..=3 {
                    let real: [Call; 4] = [
                        (
                            "next_occurrence",
                            Box::new(move || date.next_occurrence(weekday)),
                        ),
                        (
                            "prev_occurrence",
                            Box::new(move || date.prev_occurrence(weekday)),
                        ),
                        (
                            "nth_next_occurrence",
                            Box::new(move || date.nth_next_occurrence(weekday, n)),
                        ),
                        (
                            "nth_prev_occurrence",
                            Box::new(move || date.nth_prev_occurrence(weekday, n)),
                        ),
                    ];
                    for (name, call) in real {
                        let ours =
                            occurrence(date, name, weekday, n).map_err(|failure| match failure {
                                Failure::Range(message) => message,
                                other => panic!("not refused: {other:?}"),
                            });
                        let theirs = capture(call).map_err(|Panic(message)| message);
                        assert_eq!(ours, theirs, "{date} {name} {weekday} {n}");
                    }
                }
            }
        }
    }
}
