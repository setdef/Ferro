// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `SignedDuration` (time 0.3.55 `src/signed_duration.rs`).
//!
//! Every operation time documents as panicking is refused first, with
//! `RangeError` and the message time's `expect` or `panic!` carries, by
//! checking the condition time checks (plan 007, decision 7). The tests
//! drive each real operation into its panic and compare messages.

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic messages and conditions of time 0.3.55's
//   SignedDuration (src/signed_duration.rs:443-861, :1457-1716)

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, Value};
use time::SignedDuration;

use crate::calendar::unknown;
use crate::values::NDuration;
use crate::{frozen, frozen_option, guarded, Failure};

/// The message of every constructor's overflow.
pub const CONSTRUCTING: &str = "overflow constructing `time::SignedDuration`";

/// `SignedDuration::new` (`:443-466`), refusing its overflow.
pub fn new(seconds: i64, nanoseconds: i32) -> Result<SignedDuration, Failure> {
    seconds
        .checked_add(i64::from(nanoseconds) / 1_000_000_000)
        .ok_or_else(|| Failure::Range(CONSTRUCTING.to_owned()))?;
    Ok(SignedDuration::new(seconds, nanoseconds))
}

/// `weeks`, `days`, `hours`, `minutes` (`:490-565`), refusing the
/// overflow of their `checked_mul`; `seconds` to `nanoseconds` cannot
/// overflow (`:567-835`).
pub fn unit(name: &str, value: i64) -> Result<SignedDuration, Failure> {
    let per = |seconds: i64| {
        value
            .checked_mul(seconds)
            .map(|_| ())
            .ok_or_else(|| Failure::Range(CONSTRUCTING.to_owned()))
    };
    Ok(match name {
        "weeks" => {
            per(604_800)?;
            SignedDuration::weeks(value)
        }
        "days" => {
            per(86_400)?;
            SignedDuration::days(value)
        }
        "hours" => {
            per(3_600)?;
            SignedDuration::hours(value)
        }
        "minutes" => {
            per(60)?;
            SignedDuration::minutes(value)
        }
        "seconds" => SignedDuration::seconds(value),
        "milliseconds" => SignedDuration::milliseconds(value),
        "microseconds" => SignedDuration::microseconds(value),
        "nanoseconds" => SignedDuration::nanoseconds(value),
        other => return Err(unknown("SignedDuration", other)),
    })
}

/// `nanoseconds_i128` (`:844-861`), refusing seconds past `i64`.
pub fn nanoseconds_i128(nanoseconds: i128) -> Result<SignedDuration, Failure> {
    i64::try_from(nanoseconds / 1_000_000_000)
        .map_err(|_| Failure::Range(CONSTRUCTING.to_owned()))?;
    Ok(SignedDuration::nanoseconds_i128(nanoseconds))
}

/// `seconds_f64` (`:612-633`), refusing NaN and overflow with its two
/// messages.
pub fn seconds_f64(seconds: f64) -> Result<SignedDuration, Failure> {
    SignedDuration::checked_seconds_f64(seconds).ok_or_else(|| {
        Failure::Range(if seconds.is_nan() {
            "passed NaN to `time::SignedDuration::seconds_f64`".to_owned()
        } else {
            CONSTRUCTING.to_owned()
        })
    })
}

/// `seconds_f32` (`:635-659`), likewise.
pub fn seconds_f32(seconds: f32) -> Result<SignedDuration, Failure> {
    SignedDuration::checked_seconds_f32(seconds).ok_or_else(|| {
        Failure::Range(if seconds.is_nan() {
            "passed NaN to `time::SignedDuration::seconds_f32`".to_owned()
        } else {
            CONSTRUCTING.to_owned()
        })
    })
}

/// `Add` (`:1457-1469`).
pub fn add(left: SignedDuration, right: SignedDuration) -> Result<SignedDuration, Failure> {
    left.checked_add(right)
        .ok_or_else(|| Failure::Range("overflow when adding durations".to_owned()))
}

/// `Sub` (`:1547-1559`).
pub fn sub(left: SignedDuration, right: SignedDuration) -> Result<SignedDuration, Failure> {
    left.checked_sub(right)
        .ok_or_else(|| Failure::Range("overflow when subtracting durations".to_owned()))
}

/// `Neg` (`:1534-1545`).
pub fn neg(value: SignedDuration) -> Result<SignedDuration, Failure> {
    value
        .checked_neg()
        .ok_or_else(|| Failure::Range("overflow when negating duration".to_owned()))
}

/// `Mul<i32>` (`:1640-1652`): the integer widens to `i128`, then
/// `nanoseconds_i128`.
pub fn mul_int(value: SignedDuration, scalar: i128) -> Result<SignedDuration, Failure> {
    let product = value
        .whole_nanoseconds()
        .checked_mul(scalar)
        .ok_or_else(|| Failure::Range("overflow when multiplying duration".to_owned()))?;
    nanoseconds_i128(product)
}

/// `Div<i32>` (`:1681-1694`): Rust's own division panics on zero, which
/// Ruby words as `ZeroDivisionError`.
pub fn div_int(value: SignedDuration, scalar: i128) -> Result<SignedDuration, Failure> {
    if scalar == 0 {
        return Err(Failure::ZeroDivision);
    }
    nanoseconds_i128(value.whole_nanoseconds() / scalar)
}

/// `Mul<f64>` (`:1744-1755`), through `seconds_f64`.
pub fn mul_float(value: SignedDuration, scalar: f64) -> Result<SignedDuration, Failure> {
    seconds_f64(value.as_seconds_f64() * scalar)
}

/// `Div<f64>` (`:1805-1816`), through `seconds_f64`.
pub fn div_float(value: SignedDuration, scalar: f64) -> Result<SignedDuration, Failure> {
    seconds_f64(value.as_seconds_f64() / scalar)
}

// SPDX-SnippetEnd

/// The constant named `name` (`:240-317`).
fn duration_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    let value = guarded(ruby, || {
        Ok(match name.as_ref() {
            "ZERO" => SignedDuration::ZERO,
            "NANOSECOND" => SignedDuration::NANOSECOND,
            "MICROSECOND" => SignedDuration::MICROSECOND,
            "MILLISECOND" => SignedDuration::MILLISECOND,
            "SECOND" => SignedDuration::SECOND,
            "MINUTE" => SignedDuration::MINUTE,
            "HOUR" => SignedDuration::HOUR,
            "DAY" => SignedDuration::DAY,
            "WEEK" => SignedDuration::WEEK,
            "MIN" => SignedDuration::MIN,
            "MAX" => SignedDuration::MAX,
            other => return Err(unknown("SignedDuration", other)),
        })
    })?;
    Ok(frozen(ruby, NDuration(value)).as_value())
}

/// A duration made by `operation`, wrapped.
fn made(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<SignedDuration, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NDuration(value)).as_value())
}

fn duration_new(ruby: &Ruby, seconds: i64, nanoseconds: i32) -> Result<Value, Error> {
    made(ruby, || new(seconds, nanoseconds))
}

fn duration_unit(ruby: &Ruby, name: Symbol, value: i64) -> Result<Value, Error> {
    let name = name.name()?;
    made(ruby, || unit(&name, value))
}

fn duration_nanoseconds_i128(ruby: &Ruby, value: i128) -> Result<Value, Error> {
    made(ruby, || nanoseconds_i128(value))
}

/// `seconds_f64` or `saturating_seconds_f64` (`:579-747`).
fn duration_float(ruby: &Ruby, name: Symbol, seconds: f64) -> Result<Value, Error> {
    let name = name.name()?;
    made(ruby, || match name.as_ref() {
        "seconds_f64" => seconds_f64(seconds),
        "saturating_seconds_f64" => Ok(SignedDuration::saturating_seconds_f64(seconds)),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// `seconds_f32` or `saturating_seconds_f32` (`:579-747`). magnus takes
/// the Float as Rust's `as f32` rounds it (magnus 0.9.3
/// `src/try_convert.rs:181-186`).
fn duration_float32(ruby: &Ruby, name: Symbol, seconds: f32) -> Result<Value, Error> {
    let name = name.name()?;
    made(ruby, || match name.as_ref() {
        "seconds_f32" => seconds_f32(seconds),
        "saturating_seconds_f32" => Ok(SignedDuration::saturating_seconds_f32(seconds)),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// `checked_seconds_f64` (`:749-765`).
fn duration_checked_float(ruby: &Ruby, seconds: f64) -> Result<Value, Error> {
    let value = guarded(ruby, || Ok(SignedDuration::checked_seconds_f64(seconds)))?;
    Ok(frozen_option(ruby, value.map(NDuration)))
}

/// `checked_seconds_f32` (`:767-782`).
fn duration_checked_float32(ruby: &Ruby, seconds: f32) -> Result<Value, Error> {
    let value = guarded(ruby, || Ok(SignedDuration::checked_seconds_f32(seconds)))?;
    Ok(frozen_option(ruby, value.map(NDuration)))
}

/// `is_zero`, `is_negative`, or `is_positive` (`:319-363`).
fn duration_bool(ruby: &Ruby, value: &NDuration, name: Symbol) -> Result<bool, Error> {
    let name = name.name()?;
    let value = value.0;
    guarded(ruby, || match name.as_ref() {
        "is_zero" => Ok(value.is_zero()),
        "is_negative" => Ok(value.is_negative()),
        "is_positive" => Ok(value.is_positive()),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// The whole and subsecond counts (`:863-1049`).
fn duration_int(ruby: &Ruby, value: &NDuration, name: Symbol) -> Result<i128, Error> {
    let name = name.name()?;
    let value = value.0;
    guarded(ruby, || {
        Ok(match name.as_ref() {
            "whole_weeks" => value.whole_weeks().into(),
            "whole_days" => value.whole_days().into(),
            "whole_hours" => value.whole_hours().into(),
            "whole_minutes" => value.whole_minutes().into(),
            "whole_seconds" => value.whole_seconds().into(),
            "whole_milliseconds" => value.whole_milliseconds(),
            "subsec_milliseconds" => value.subsec_milliseconds().into(),
            "whole_microseconds" => value.whole_microseconds(),
            "subsec_microseconds" => value.subsec_microseconds().into(),
            "whole_nanoseconds" => value.whole_nanoseconds(),
            "subsec_nanoseconds" => value.subsec_nanoseconds().into(),
            other => return Err(unknown("SignedDuration", other)),
        })
    })
}

/// `as_seconds_f64` or `as_seconds_f32` (`:939-963`), the latter widened
/// to a Float exactly.
fn duration_as_float(ruby: &Ruby, value: &NDuration, name: Symbol) -> Result<f64, Error> {
    let name = name.name()?;
    let value = value.0;
    guarded(ruby, || match name.as_ref() {
        "as_seconds_f64" => Ok(value.as_seconds_f64()),
        "as_seconds_f32" => Ok(f64::from(value.as_seconds_f32())),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// `abs` (`:365-370`).
fn duration_abs(ruby: &Ruby, value: &NDuration) -> Result<Value, Error> {
    let value = value.0;
    made(ruby, || Ok(value.abs()))
}

/// `checked_add`, `checked_sub`, `saturating_add`, or `saturating_sub`
/// with another duration (`:1051-1286`); the checked forms answer `nil`.
fn duration_with(
    ruby: &Ruby,
    value: &NDuration,
    name: Symbol,
    other: &NDuration,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, other) = (value.0, other.0);
    let result = guarded(ruby, || {
        Ok(match name.as_ref() {
            "checked_add" => value.checked_add(other),
            "checked_sub" => value.checked_sub(other),
            "saturating_add" => Some(value.saturating_add(other)),
            "saturating_sub" => Some(value.saturating_sub(other)),
            other => return Err(unknown("SignedDuration", other)),
        })
    })?;
    Ok(frozen_option(ruby, result.map(NDuration)))
}

/// `checked_mul`, `checked_div`, or `saturating_mul` by an `i32`
/// (`:1108-1296`).
fn duration_by(ruby: &Ruby, value: &NDuration, name: Symbol, scalar: i32) -> Result<Value, Error> {
    let name = name.name()?;
    let value = value.0;
    let result = guarded(ruby, || {
        Ok(match name.as_ref() {
            "checked_mul" => value.checked_mul(scalar),
            "checked_div" => value.checked_div(scalar),
            "saturating_mul" => Some(value.saturating_mul(scalar)),
            other => return Err(unknown("SignedDuration", other)),
        })
    })?;
    Ok(frozen_option(ruby, result.map(NDuration)))
}

/// `checked_neg` (`:1158-1176`).
fn duration_checked_neg(ruby: &Ruby, value: &NDuration) -> Result<Value, Error> {
    let value = value.0;
    let result = guarded(ruby, || Ok(value.checked_neg()))?;
    Ok(frozen_option(ruby, result.map(NDuration)))
}

/// `+`, `-` with another duration, or `-@`.
fn duration_op(
    ruby: &Ruby,
    value: &NDuration,
    name: Symbol,
    other: &NDuration,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (value, other) = (value.0, other.0);
    made(ruby, || match name.as_ref() {
        "+" => add(value, other),
        "-" => sub(value, other),
        "-@" => neg(value),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// An Integer scalar, as the `i32` impl takes it, Rust's type for an
/// integer literal; magnus raises `RangeError` outside it (plan 007,
/// decision 8).
fn scalar(value: Value) -> Result<i128, Error> {
    i32::try_convert(value).map(i128::from)
}

/// `*` or `/` by an Integer.
fn duration_scale_int(
    ruby: &Ruby,
    value: &NDuration,
    name: Symbol,
    rhs: Value,
) -> Result<Value, Error> {
    let name = name.name()?;
    let value = value.0;
    let rhs = scalar(rhs)?;
    made(ruby, || match name.as_ref() {
        "*" => mul_int(value, rhs),
        "/" => div_int(value, rhs),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// `*` or `/` by a Float.
fn duration_scale_float(
    ruby: &Ruby,
    value: &NDuration,
    name: Symbol,
    rhs: f64,
) -> Result<Value, Error> {
    let name = name.name()?;
    let value = value.0;
    made(ruby, || match name.as_ref() {
        "*" => mul_float(value, rhs),
        "/" => div_float(value, rhs),
        other => Err(unknown("SignedDuration", other)),
    })
}

/// `Div<SignedDuration>` (`:1840-1851`), a Float.
fn duration_ratio(ruby: &Ruby, value: &NDuration, other: &NDuration) -> Result<f64, Error> {
    let (value, other) = (value.0, other.0);
    guarded(ruby, || Ok(value / other))
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("duration_constant", function!(duration_constant, 1))?;
    native.define_singleton_method("duration_new", function!(duration_new, 2))?;
    native.define_singleton_method("duration_unit", function!(duration_unit, 2))?;
    native.define_singleton_method(
        "duration_nanoseconds_i128",
        function!(duration_nanoseconds_i128, 1),
    )?;
    native.define_singleton_method("duration_float", function!(duration_float, 2))?;
    native.define_singleton_method("duration_float32", function!(duration_float32, 2))?;
    native.define_singleton_method(
        "duration_checked_float",
        function!(duration_checked_float, 1),
    )?;
    native.define_singleton_method(
        "duration_checked_float32",
        function!(duration_checked_float32, 1),
    )?;
    native.define_singleton_method("duration_bool", function!(duration_bool, 2))?;
    native.define_singleton_method("duration_int", function!(duration_int, 2))?;
    native.define_singleton_method("duration_as_float", function!(duration_as_float, 2))?;
    native.define_singleton_method("duration_abs", function!(duration_abs, 1))?;
    native.define_singleton_method("duration_with", function!(duration_with, 3))?;
    native.define_singleton_method("duration_by", function!(duration_by, 3))?;
    native.define_singleton_method("duration_checked_neg", function!(duration_checked_neg, 1))?;
    native.define_singleton_method("duration_op", function!(duration_op, 3))?;
    native.define_singleton_method("duration_scale_int", function!(duration_scale_int, 3))?;
    native.define_singleton_method("duration_scale_float", function!(duration_scale_float, 3))?;
    native.define_singleton_method("duration_ratio", function!(duration_ratio, 2))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        add, div_float, div_int, mul_float, mul_int, nanoseconds_i128, neg, new, seconds_f32,
        seconds_f64, sub, unit,
    };
    use crate::{capture, Failure, Panic};
    use time::SignedDuration;

    /// The message of the panic `operation` raises in time.
    fn panic_of(operation: impl FnOnce() -> SignedDuration) -> String {
        match capture(operation) {
            Err(Panic(message)) => message,
            Ok(value) => panic!("time did not panic: {value:?}"),
        }
    }

    /// The `RangeError` message a refusal carries.
    fn refusal(result: Result<SignedDuration, Failure>) -> String {
        match result {
            Err(Failure::Range(message)) => message,
            other => panic!("not refused: {other:?}"),
        }
    }

    #[test]
    fn each_refusal_is_times_own_panic() {
        let max = SignedDuration::MAX;
        let min = SignedDuration::MIN;
        let cases: Vec<(Result<SignedDuration, Failure>, String)> = vec![
            (
                new(i64::MAX, 1_000_000_000),
                panic_of(|| SignedDuration::new(i64::MAX, 1_000_000_000)),
            ),
            (
                unit("weeks", i64::MAX),
                panic_of(|| SignedDuration::weeks(i64::MAX)),
            ),
            (
                unit("days", i64::MIN),
                panic_of(|| SignedDuration::days(i64::MIN)),
            ),
            (
                unit("hours", i64::MAX),
                panic_of(|| SignedDuration::hours(i64::MAX)),
            ),
            (
                unit("minutes", i64::MAX),
                panic_of(|| SignedDuration::minutes(i64::MAX)),
            ),
            (
                nanoseconds_i128(i128::MAX),
                panic_of(|| SignedDuration::nanoseconds_i128(i128::MAX)),
            ),
            (
                seconds_f64(f64::NAN),
                panic_of(|| SignedDuration::seconds_f64(f64::NAN)),
            ),
            (
                seconds_f64(f64::INFINITY),
                panic_of(|| SignedDuration::seconds_f64(f64::INFINITY)),
            ),
            (
                seconds_f32(f32::NAN),
                panic_of(|| SignedDuration::seconds_f32(f32::NAN)),
            ),
            (
                seconds_f32(-1e30),
                panic_of(|| SignedDuration::seconds_f32(-1e30)),
            ),
            (
                add(max, SignedDuration::NANOSECOND),
                panic_of(|| max + SignedDuration::NANOSECOND),
            ),
            (
                sub(min, SignedDuration::NANOSECOND),
                panic_of(|| min - SignedDuration::NANOSECOND),
            ),
            (neg(min), panic_of(|| -min)),
            (mul_int(max, 2), panic_of(|| max * 2_i32)),
            (div_int(min, -1), panic_of(|| min / -1_i32)),
            (mul_float(max, 2.0), panic_of(|| max * 2.0_f64)),
            (
                div_float(SignedDuration::SECOND, 0.0),
                panic_of(|| SignedDuration::SECOND / 0.0_f64),
            ),
            (
                mul_float(SignedDuration::SECOND, f64::NAN),
                panic_of(|| SignedDuration::SECOND * f64::NAN),
            ),
        ];
        for (index, (result, message)) in cases.into_iter().enumerate() {
            assert_eq!(refusal(result), message, "case {index}");
        }
    }

    #[test]
    fn what_time_computes_passes_through() {
        assert_eq!(new(1, 2_000_000_000).unwrap(), SignedDuration::seconds(3));
        assert_eq!(unit("days", 2).unwrap(), SignedDuration::hours(48));
        assert_eq!(
            mul_int(SignedDuration::SECOND, i128::from(i32::MAX)).unwrap(),
            SignedDuration::SECOND * i32::MAX
        );
        // time's unsigned impls reinterpret the bits as signed
        // (`cast_signed`, `src/signed_duration.rs:1620-1660`), so a large
        // `u8`, `u16`, or `u32` multiplies as a negative number; Ruby's
        // Integer takes the `i32` impl and never meets them.
        assert_eq!(
            SignedDuration::SECOND * 200_u8,
            SignedDuration::SECOND * -56_i32
        );
        assert_eq!(
            div_int(SignedDuration::SECOND, 4).unwrap(),
            SignedDuration::SECOND / 4_i32
        );
        assert_eq!(
            mul_float(SignedDuration::SECOND, 1.5).unwrap(),
            SignedDuration::SECOND * 1.5_f64
        );
        assert!(matches!(
            div_int(SignedDuration::SECOND, 0),
            Err(Failure::ZeroDivision)
        ));
        assert!(capture(|| SignedDuration::SECOND / std::hint::black_box(0_i32)).is_err());
    }
}
