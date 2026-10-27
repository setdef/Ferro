// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `Time`, the clock time of day (time 0.3.55 `src/time.rs`). Its
//! arithmetic wraps around midnight and never panics (`:1086-1225`).

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, Value};
use time::Time;

use crate::calendar::unknown;
use crate::values::{NDuration, NTime};
use crate::{frozen, guarded, Failure};

/// A time made by `operation`, wrapped.
fn made(ruby: &Ruby, operation: impl FnOnce() -> Result<Time, Failure>) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NTime(value)).as_value())
}

/// `MIDNIGHT` or `MAX` (`:131-157`).
fn time_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    made(ruby, || match name.as_ref() {
        "MIDNIGHT" => Ok(Time::MIDNIGHT),
        "MAX" => Ok(Time::MAX),
        other => Err(unknown("Time", other)),
    })
}

/// `from_hms` (`:183-232`).
fn time_from_hms(ruby: &Ruby, hour: u8, minute: u8, second: u8) -> Result<Value, Error> {
    made(ruby, || Ok(Time::from_hms(hour, minute, second)?))
}

/// `from_hms_milli` (`:234-261`).
fn time_from_hms_milli(
    ruby: &Ruby,
    hour: u8,
    minute: u8,
    second: u8,
    millisecond: u16,
) -> Result<Value, Error> {
    made(ruby, || {
        Ok(Time::from_hms_milli(hour, minute, second, millisecond)?)
    })
}

/// `from_hms_micro` (`:263-290`).
fn time_from_hms_micro(
    ruby: &Ruby,
    hour: u8,
    minute: u8,
    second: u8,
    microsecond: u32,
) -> Result<Value, Error> {
    made(ruby, || {
        Ok(Time::from_hms_micro(hour, minute, second, microsecond)?)
    })
}

/// `from_hms_nano` (`:292-312`).
fn time_from_hms_nano(
    ruby: &Ruby,
    hour: u8,
    minute: u8,
    second: u8,
    nanosecond: u32,
) -> Result<Value, Error> {
    made(ruby, || {
        Ok(Time::from_hms_nano(hour, minute, second, nanosecond)?)
    })
}

/// `hour` to `nanosecond` (`:384-474`).
fn time_int(ruby: &Ruby, time: &NTime, name: Symbol) -> Result<u32, Error> {
    let name = name.name()?;
    let time = time.0;
    guarded(ruby, || {
        clock_int(time, &name).ok_or_else(|| unknown("Time", &name))
    })
}

/// One of the clock readers every type with a time shares.
pub fn clock_int(time: Time, name: &str) -> Option<u32> {
    Some(match name {
        "hour" => time.hour().into(),
        "minute" => time.minute().into(),
        "second" => time.second().into(),
        "millisecond" => time.millisecond().into(),
        "microsecond" => time.microsecond(),
        "nanosecond" => time.nanosecond(),
        _ => return None,
    })
}

/// `as_hms`, `as_hms_milli`, `as_hms_micro`, or `as_hms_nano` (`:314-382`),
/// by the suffix after `hms`.
pub fn clock_ints(time: Time, suffix: &str) -> Option<Vec<u32>> {
    Some(match suffix {
        "" => {
            let (h, m, s) = time.as_hms();
            vec![h.into(), m.into(), s.into()]
        }
        "_milli" => {
            let (h, m, s, ms) = time.as_hms_milli();
            vec![h.into(), m.into(), s.into(), ms.into()]
        }
        "_micro" => {
            let (h, m, s, us) = time.as_hms_micro();
            vec![h.into(), m.into(), s.into(), us]
        }
        "_nano" => {
            let (h, m, s, ns) = time.as_hms_nano();
            vec![h.into(), m.into(), s.into(), ns]
        }
        _ => return None,
    })
}

fn time_ints(ruby: &Ruby, time: &NTime, name: Symbol) -> Result<Vec<u32>, Error> {
    let name = name.name()?;
    let time = time.0;
    guarded(ruby, || {
        name.strip_prefix("as_hms")
            .and_then(|suffix| clock_ints(time, suffix))
            .ok_or_else(|| unknown("Time", &name))
    })
}

/// `truncate_to_hour` to `truncate_to_microsecond` (`:698-886`).
fn time_truncate(ruby: &Ruby, time: &NTime, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    let time = time.0;
    made(ruby, || match name.as_ref() {
        "truncate_to_hour" => Ok(time.truncate_to_hour()),
        "truncate_to_minute" => Ok(time.truncate_to_minute()),
        "truncate_to_second" => Ok(time.truncate_to_second()),
        "truncate_to_millisecond" => Ok(time.truncate_to_millisecond()),
        "truncate_to_microsecond" => Ok(time.truncate_to_microsecond()),
        other => Err(unknown("Time", other)),
    })
}

/// `replace_hour` to `replace_nanosecond` (`:686-896`); magnus converts
/// `value` to each method's type.
fn time_replace(ruby: &Ruby, time: &NTime, name: Symbol, value: Value) -> Result<Value, Error> {
    let name = name.name()?;
    let time = time.0;
    match name.as_ref() {
        "replace_hour" => {
            let hour = u8::try_convert(value)?;
            made(ruby, || Ok(time.replace_hour(hour)?))
        }
        "replace_minute" => {
            let minute = u8::try_convert(value)?;
            made(ruby, || Ok(time.replace_minute(minute)?))
        }
        "replace_second" => {
            let second = u8::try_convert(value)?;
            made(ruby, || Ok(time.replace_second(second)?))
        }
        "replace_millisecond" => {
            let millisecond = u16::try_convert(value)?;
            made(ruby, || Ok(time.replace_millisecond(millisecond)?))
        }
        "replace_microsecond" => {
            let microsecond = u32::try_convert(value)?;
            made(ruby, || Ok(time.replace_microsecond(microsecond)?))
        }
        "replace_nanosecond" => {
            let nanosecond = u32::try_convert(value)?;
            made(ruby, || Ok(time.replace_nanosecond(nanosecond)?))
        }
        other => Err(unknown("Time", other).into_error(ruby)),
    }
}

/// `+` or `-` with a duration (`:1086-1180`), wrapping around midnight.
fn time_arith(
    ruby: &Ruby,
    time: &NTime,
    name: Symbol,
    duration: &NDuration,
) -> Result<Value, Error> {
    let name = name.name()?;
    let (time, duration) = (time.0, duration.0);
    made(ruby, || match name.as_ref() {
        "+" => Ok(time + duration),
        "-" => Ok(time - duration),
        other => Err(unknown("Time", other)),
    })
}

/// `duration_until`, `duration_since` (`:476-560`), or `Sub for Time`
/// (`:1182-1225`).
fn time_between(ruby: &Ruby, time: &NTime, name: Symbol, other: &NTime) -> Result<Value, Error> {
    let name = name.name()?;
    let (time, other) = (time.0, other.0);
    let value = guarded(ruby, || match name.as_ref() {
        "duration_until" => Ok(time.duration_until(other)),
        "duration_since" => Ok(time.duration_since(other)),
        "-" => Ok(time - other),
        other => Err(unknown("Time", other)),
    })?;
    Ok(frozen(ruby, NDuration(value)).as_value())
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("time_constant", function!(time_constant, 1))?;
    native.define_singleton_method("time_from_hms", function!(time_from_hms, 3))?;
    native.define_singleton_method("time_from_hms_milli", function!(time_from_hms_milli, 4))?;
    native.define_singleton_method("time_from_hms_micro", function!(time_from_hms_micro, 4))?;
    native.define_singleton_method("time_from_hms_nano", function!(time_from_hms_nano, 4))?;
    native.define_singleton_method("time_int", function!(time_int, 2))?;
    native.define_singleton_method("time_ints", function!(time_ints, 2))?;
    native.define_singleton_method("time_truncate", function!(time_truncate, 2))?;
    native.define_singleton_method("time_replace", function!(time_replace, 3))?;
    native.define_singleton_method("time_arith", function!(time_arith, 3))?;
    native.define_singleton_method("time_between", function!(time_between, 3))?;
    Ok(())
}
