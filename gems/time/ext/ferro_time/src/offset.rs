// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `UtcOffset` (time 0.3.55 `src/utc_offset.rs`), with the system's local
//! offset from the `local-offset` feature (plan 007, decision 13).

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol, Value};
use time::UtcOffset;

use crate::calendar::unknown;
use crate::values::{NOffsetDateTime, NUtcOffset};
use crate::{frozen, guarded, Failure};

fn made(
    ruby: &Ruby,
    operation: impl FnOnce() -> Result<UtcOffset, Failure>,
) -> Result<Value, Error> {
    let value = guarded(ruby, operation)?;
    Ok(frozen(ruby, NUtcOffset(value)).as_value())
}

/// `UTC` (`:155`).
fn utc_offset_constant(ruby: &Ruby, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    made(ruby, || match name.as_ref() {
        "UTC" => Ok(UtcOffset::UTC),
        other => Err(unknown("UtcOffset", other)),
    })
}

/// `from_hms` (`:183-274`).
fn utc_offset_from_hms(ruby: &Ruby, hours: i8, minutes: i8, seconds: i8) -> Result<Value, Error> {
    made(ruby, || Ok(UtcOffset::from_hms(hours, minutes, seconds)?))
}

/// `from_whole_seconds` (`:276-305`).
fn utc_offset_from_whole_seconds(ruby: &Ruby, seconds: i32) -> Result<Value, Error> {
    made(ruby, || Ok(UtcOffset::from_whole_seconds(seconds)?))
}

/// `as_hms` (`:307-322`).
fn utc_offset_as_hms(ruby: &Ruby, offset: &NUtcOffset) -> Result<(i8, i8, i8), Error> {
    let offset = offset.0;
    guarded(ruby, || Ok(offset.as_hms()))
}

/// `whole_hours`, `whole_minutes`, `minutes_past_hour`, `whole_seconds`,
/// or `seconds_past_minute` (`:324-398`).
fn utc_offset_int(ruby: &Ruby, offset: &NUtcOffset, name: Symbol) -> Result<i32, Error> {
    let name = name.name()?;
    let offset = offset.0;
    guarded(ruby, || {
        Ok(match name.as_ref() {
            "whole_hours" => offset.whole_hours().into(),
            "whole_minutes" => offset.whole_minutes().into(),
            "minutes_past_hour" => offset.minutes_past_hour().into(),
            "whole_seconds" => offset.whole_seconds(),
            "seconds_past_minute" => offset.seconds_past_minute().into(),
            other => return Err(unknown("UtcOffset", other)),
        })
    })
}

/// `is_utc`, `is_positive`, or `is_negative` (`:400-436`).
fn utc_offset_bool(ruby: &Ruby, offset: &NUtcOffset, name: Symbol) -> Result<bool, Error> {
    let name = name.name()?;
    let offset = offset.0;
    guarded(ruby, || match name.as_ref() {
        "is_utc" => Ok(offset.is_utc()),
        "is_positive" => Ok(offset.is_positive()),
        "is_negative" => Ok(offset.is_negative()),
        other => Err(unknown("UtcOffset", other)),
    })
}

/// `Neg` (`:618-625`).
fn utc_offset_neg(ruby: &Ruby, offset: &NUtcOffset) -> Result<Value, Error> {
    let offset = offset.0;
    made(ruby, || Ok(-offset))
}

/// `local_offset_at` (`:438-450`).
fn utc_offset_local_offset_at(ruby: &Ruby, datetime: &NOffsetDateTime) -> Result<Value, Error> {
    let datetime = datetime.0;
    made(ruby, || Ok(UtcOffset::local_offset_at(datetime)?))
}

/// `current_local_offset` (`:452-468`).
fn utc_offset_current_local_offset(ruby: &Ruby) -> Result<Value, Error> {
    made(ruby, || Ok(UtcOffset::current_local_offset()?))
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("utc_offset_constant", function!(utc_offset_constant, 1))?;
    native.define_singleton_method("utc_offset_from_hms", function!(utc_offset_from_hms, 3))?;
    native.define_singleton_method(
        "utc_offset_from_whole_seconds",
        function!(utc_offset_from_whole_seconds, 1),
    )?;
    native.define_singleton_method("utc_offset_as_hms", function!(utc_offset_as_hms, 1))?;
    native.define_singleton_method("utc_offset_int", function!(utc_offset_int, 2))?;
    native.define_singleton_method("utc_offset_bool", function!(utc_offset_bool, 2))?;
    native.define_singleton_method("utc_offset_neg", function!(utc_offset_neg, 1))?;
    native.define_singleton_method(
        "utc_offset_local_offset_at",
        function!(utc_offset_local_offset_at, 1),
    )?;
    native.define_singleton_method(
        "utc_offset_current_local_offset",
        function!(utc_offset_current_local_offset, 0),
    )?;
    Ok(())
}
