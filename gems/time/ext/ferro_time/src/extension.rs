// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's extension traits (time 0.3.55 `src/ext/`), which Ruby brings in
//! as refinements (ADR 001, 2026-11-05): `NumericalDuration` on `i64` and
//! `f64`, `NumericalStdDuration` on `u64` and `f64`, and `SystemTimeExt`
//! on `SystemTime`, Ruby's `::Time`. `NumericalDuration`'s `i64` impl calls
//! `SignedDuration`'s own constructors (`src/ext/numerical_duration.rs:79-125`),
//! so Ruby's Integer refinement calls `Native.duration_unit`.

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, Value};
use time::ext::{NumericalDuration, NumericalStdDuration, SystemTimeExt};
use time::SignedDuration;

use crate::calendar::unknown;
use crate::duration::CONSTRUCTING;
use crate::system_time::{since_epoch, system_time};
use crate::values::NDuration;
use crate::{frozen, guarded, Failure};

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the conditions and panic messages of time 0.3.55's
//   NumericalStdDuration (src/ext/numerical_std_duration.rs:70-212)

/// What `NumericalStdDuration for f64` panics with for a negative or NaN
/// count: its `assert!(self >= 0.)` (`:140-212`), as Rust words a failed
/// assertion.
pub const NEGATIVE: &str = "assertion failed: self >= 0.";

/// `NumericalDuration for f64` (`src/ext/numerical_duration.rs:128-168`),
/// which truncates toward zero and saturates, so it never panics.
pub fn float_duration(name: &str, value: f64) -> Result<SignedDuration, Failure> {
    Ok(match name {
        "nanoseconds" => value.nanoseconds(),
        "microseconds" => value.microseconds(),
        "milliseconds" => value.milliseconds(),
        "seconds" => value.seconds(),
        "minutes" => value.minutes(),
        "hours" => value.hours(),
        "days" => value.days(),
        "weeks" => value.weeks(),
        other => return Err(unknown("NumericalDuration", other)),
    })
}

/// `NumericalStdDuration for u64` (`:70-138`), refusing the overflow of
/// `std_minutes` to `std_weeks`' `checked_mul`, which time words as a
/// `SignedDuration`'s.
pub fn integer_std(name: &str, value: u64) -> Result<std::time::Duration, Failure> {
    let per = |seconds: u64| {
        value
            .checked_mul(seconds)
            .map(|_| ())
            .ok_or_else(|| Failure::Range(CONSTRUCTING.to_owned()))
    };
    Ok(match name {
        "std_nanoseconds" => value.std_nanoseconds(),
        "std_microseconds" => value.std_microseconds(),
        "std_milliseconds" => value.std_milliseconds(),
        "std_seconds" => value.std_seconds(),
        "std_minutes" => {
            per(60)?;
            value.std_minutes()
        }
        "std_hours" => {
            per(3_600)?;
            value.std_hours()
        }
        "std_days" => {
            per(86_400)?;
            value.std_days()
        }
        "std_weeks" => {
            per(604_800)?;
            value.std_weeks()
        }
        other => return Err(unknown("NumericalStdDuration", other)),
    })
}

/// `NumericalStdDuration for f64` (`:140-212`), refusing what its
/// assertion refuses; past that it truncates and saturates.
pub fn float_std(name: &str, value: f64) -> Result<std::time::Duration, Failure> {
    if value.is_nan() || value < 0.0 {
        return Err(Failure::Argument(NEGATIVE.to_owned()));
    }
    Ok(match name {
        "std_nanoseconds" => value.std_nanoseconds(),
        "std_microseconds" => value.std_microseconds(),
        "std_milliseconds" => value.std_milliseconds(),
        "std_seconds" => value.std_seconds(),
        "std_minutes" => value.std_minutes(),
        "std_hours" => value.std_hours(),
        "std_days" => value.std_days(),
        "std_weeks" => value.std_weeks(),
        other => return Err(unknown("NumericalStdDuration", other)),
    })
}

// SPDX-SnippetEnd

/// `NumericalDuration for f64`'s methods.
fn numerical_duration_float(ruby: &Ruby, name: Symbol, value: f64) -> Result<Value, Error> {
    let name = name.name()?;
    let duration = guarded(ruby, || float_duration(&name, value))?;
    Ok(frozen(ruby, NDuration(duration)).as_value())
}

/// `NumericalStdDuration for u64`'s methods, as whole nanoseconds.
fn numerical_std_integer(ruby: &Ruby, name: Symbol, value: u64) -> Result<u128, Error> {
    let name = name.name()?;
    guarded(ruby, || integer_std(&name, value).map(|std| std.as_nanos()))
}

/// `NumericalStdDuration for f64`'s methods, as whole nanoseconds.
fn numerical_std_float(ruby: &Ruby, name: Symbol, value: f64) -> Result<u128, Error> {
    let name = name.name()?;
    guarded(ruby, || float_std(&name, value).map(|std| std.as_nanos()))
}

/// `SystemTimeExt::checked_add_signed` or `checked_sub_signed`
/// (`src/ext/systemtime.rs:41-60`), on the `SystemTime` a Ruby `::Time`
/// names; `nil` where the result leaves `SystemTime`'s range.
fn system_time_checked_signed(
    ruby: &Ruby,
    seconds: i64,
    nanoseconds: u32,
    name: Symbol,
    duration: &NDuration,
) -> Result<Option<(i64, u32)>, Error> {
    let name = name.name()?;
    let duration = duration.0;
    guarded(ruby, || {
        let time = system_time(seconds, nanoseconds)?;
        let result = match name.as_ref() {
            "checked_add_signed" => time.checked_add_signed(duration),
            "checked_sub_signed" => time.checked_sub_signed(duration),
            other => return Err(unknown("SystemTimeExt", other)),
        };
        Ok(result.map(since_epoch))
    })
}

/// `SystemTimeExt::signed_duration_since` (`src/ext/systemtime.rs:62-75`),
/// which saturates rather than fails.
fn system_time_signed_duration_since(
    ruby: &Ruby,
    seconds: i64,
    nanoseconds: u32,
    earlier_seconds: i64,
    earlier_nanoseconds: u32,
) -> Result<Value, Error> {
    let duration = guarded(ruby, || {
        let time = system_time(seconds, nanoseconds)?;
        let earlier = system_time(earlier_seconds, earlier_nanoseconds)?;
        Ok(time.signed_duration_since(earlier))
    })?;
    Ok(frozen(ruby, NDuration(duration)).as_value())
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method(
        "numerical_duration_float",
        function!(numerical_duration_float, 2),
    )?;
    native.define_singleton_method("numerical_std_integer", function!(numerical_std_integer, 2))?;
    native.define_singleton_method("numerical_std_float", function!(numerical_std_float, 2))?;
    native.define_singleton_method(
        "system_time_checked_signed",
        function!(system_time_checked_signed, 4),
    )?;
    native.define_singleton_method(
        "system_time_signed_duration_since",
        function!(system_time_signed_duration_since, 4),
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{float_duration, float_std, integer_std, NEGATIVE};
    use crate::{capture, Failure, Panic};
    use time::ext::{NumericalDuration, NumericalStdDuration};

    const NAMES: [&str; 8] = [
        "nanoseconds",
        "microseconds",
        "milliseconds",
        "seconds",
        "minutes",
        "hours",
        "days",
        "weeks",
    ];

    /// The panic `operation` raises, if any.
    fn panic_of<T>(operation: impl FnOnce() -> T) -> Option<String> {
        match capture(operation) {
            Err(Panic(message)) => Some(message),
            Ok(_) => None,
        }
    }

    /// The message a refusal carries, if any.
    fn refusal<T>(result: Result<T, Failure>) -> Option<String> {
        match result {
            Ok(_) => None,
            Err(Failure::Range(message) | Failure::Argument(message)) => Some(message),
            Err(other) => panic!("refused as something else: {other:?}"),
        }
    }

    /// Calls `NumericalStdDuration`'s method `name` on `value`.
    fn real_std<T: NumericalStdDuration>(name: &str, value: T) -> std::time::Duration {
        match name {
            "nanoseconds" => value.std_nanoseconds(),
            "microseconds" => value.std_microseconds(),
            "milliseconds" => value.std_milliseconds(),
            "seconds" => value.std_seconds(),
            "minutes" => value.std_minutes(),
            "hours" => value.std_hours(),
            "days" => value.std_days(),
            _ => value.std_weeks(),
        }
    }

    #[test]
    fn the_std_refusals_are_times_panics() {
        for name in NAMES {
            let ours = format!("std_{name}");
            for value in [
                0,
                1,
                u64::MAX / 60,
                u64::MAX / 60 + 1,
                u64::MAX / 3_600,
                u64::MAX / 3_600 + 1,
                u64::MAX / 86_400,
                u64::MAX / 86_400 + 1,
                u64::MAX / 604_800,
                u64::MAX / 604_800 + 1,
                u64::MAX,
            ] {
                assert_eq!(
                    refusal(integer_std(&ours, value)),
                    panic_of(|| real_std(name, value)),
                    "{name} {value}"
                );
                if let Ok(std) = integer_std(&ours, value) {
                    assert_eq!(std, real_std(name, value));
                }
            }
            for value in [
                0.0,
                1.5,
                -0.0,
                -1.0,
                f64::NAN,
                f64::INFINITY,
                -f64::INFINITY,
            ] {
                assert_eq!(
                    refusal(float_std(&ours, value)),
                    panic_of(|| real_std(name, value)),
                    "{name} {value}"
                );
            }
        }
        assert_eq!(
            panic_of(|| (-1.0_f64).std_seconds()),
            Some(NEGATIVE.to_owned())
        );
    }

    #[test]
    fn the_float_durations_are_times() {
        for value in [1.5, -2.25, f64::NAN, f64::INFINITY, f64::MAX] {
            assert_eq!(float_duration("seconds", value).unwrap(), value.seconds());
            assert_eq!(float_duration("weeks", value).unwrap(), value.weeks());
            assert_eq!(
                float_duration("nanoseconds", value).unwrap(),
                value.nanoseconds()
            );
        }
    }
}
