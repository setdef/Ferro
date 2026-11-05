// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's `Debug` text, and the integer values of its fieldless enums, for
//! the values Ruby holds as frozen constants
//! rather than wrapped Rust values: the enums, time-core's unit structs,
//! and the well-known formats. Each function builds the Rust value from
//! what names it and formats it, so `debug` answers Rust's own text (ADR
//! 001, 2026-11-05) and cannot drift from it.

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol};
use time::format_description::well_known::{Rfc2822, Rfc3339};
use time::unit::{self, Day, Hour, Microsecond, Millisecond, Minute, Nanosecond, Second, Week};

use crate::calendar::unknown;
use crate::iso8601::{components, date_kind, offset_precision, time_precision};
use crate::values::{month, weekday};
use crate::{guarded, Failure};

/// `Month`'s derived `Debug` (`src/month.rs:13`), for the month numbered
/// `number`.
fn month_debug(ruby: &Ruby, number: u8) -> Result<String, Error> {
    guarded(ruby, || Ok(format!("{:?}", month(number)?)))
}

/// `Weekday`'s derived `Debug` (`src/weekday.rs:12`), for the weekday
/// `days` after Monday.
fn weekday_debug(ruby: &Ruby, days: u8) -> Result<String, Error> {
    guarded(ruby, || Ok(format!("{:?}", weekday(days)?)))
}

/// The derived `Debug` of time-core's unit struct `name`
/// (`time-core-0.1.9/src/unit.rs:21-28`), whose const `N` is 1.
pub fn unit_struct_debug(name: &str) -> Result<String, Failure> {
    Ok(match name {
        "Nanosecond" => format!("{:?}", Nanosecond::<1>),
        "Microsecond" => format!("{:?}", Microsecond::<1>),
        "Millisecond" => format!("{:?}", Millisecond::<1>),
        "Second" => format!("{:?}", Second::<1>),
        "Minute" => format!("{:?}", Minute::<1>),
        "Hour" => format!("{:?}", Hour::<1>),
        "Day" => format!("{:?}", Day::<1>),
        "Week" => format!("{:?}", Week::<1>),
        other => return Err(unknown("Unit", other)),
    })
}

/// The derived `Debug` of time-core's `Unit` variant `name`
/// (`time-core-0.1.9/src/unit.rs:289-309`).
pub fn unit_variant_debug(name: &str) -> Result<String, Failure> {
    let variant: unit::Unit<1> = match name {
        "Nanosecond" => unit::Unit::Nanosecond,
        "Microsecond" => unit::Unit::Microsecond,
        "Millisecond" => unit::Unit::Millisecond,
        "Second" => unit::Unit::Second,
        "Minute" => unit::Unit::Minute,
        "Hour" => unit::Unit::Hour,
        "Day" => unit::Unit::Day,
        "Week" => unit::Unit::Week,
        other => return Err(unknown("Unit::Unit", other)),
    };
    Ok(format!("{variant:?}"))
}

/// `Native.unit_debug`: a unit struct, or with `variant` a `Unit` variant.
fn unit_debug(ruby: &Ruby, name: Symbol, variant: bool) -> Result<String, Error> {
    let name = name.name()?;
    guarded(ruby, || {
        if variant {
            unit_variant_debug(&name)
        } else {
            unit_struct_debug(&name)
        }
    })
}

/// The derived `Debug` of an ISO 8601 configuration enum's variant at
/// `index` (`src/format_description/well_known/iso8601/adt_hack.rs` and
/// `iso8601.rs:176-210`); `TimePrecision` also takes its decimal digits, 0
/// for `None`.
fn iso8601_enum_debug(ruby: &Ruby, kind: Symbol, index: u8, digits: u8) -> Result<String, Error> {
    let kind = kind.name()?;
    guarded(ruby, || {
        Ok(match kind.as_ref() {
            "FormattedComponents" => format!("{:?}", components(index)),
            "DateKind" => format!("{:?}", date_kind(index)),
            "TimePrecision" => format!("{:?}", time_precision(index, digits)),
            "OffsetPrecision" => format!("{:?}", offset_precision(index)),
            other => return Err(unknown("Iso8601", other)),
        })
    })
}

/// `Weekday::X as u8`, the `#[repr(u8)]` discriminant of the weekday
/// `days` after Monday (`src/weekday.rs:16-33`), which ADR 001's
/// 2026-11-05 amendment binds as `to_i`.
fn weekday_to_i(ruby: &Ruby, days: u8) -> Result<u8, Error> {
    guarded(ruby, || Ok(weekday(days)? as u8))
}

/// `X as u8` for an exhaustive, fieldless ISO 8601 configuration enum's
/// variant at `index` (`src/format_description/well_known/iso8601.rs:92-155`):
/// its discriminant, as `to_i` binds it.
fn iso8601_enum_to_i(ruby: &Ruby, kind: Symbol, index: u8) -> Result<u8, Error> {
    let kind = kind.name()?;
    guarded(ruby, || {
        Ok(match kind.as_ref() {
            "FormattedComponents" => components(index) as u8,
            "DateKind" => date_kind(index) as u8,
            "OffsetPrecision" => offset_precision(index) as u8,
            other => return Err(unknown("Iso8601", other)),
        })
    })
}

/// The derived `Debug` of the unit struct `Rfc2822` or `Rfc3339`
/// (`src/format_description/well_known/rfc2822.rs`, `rfc3339.rs`).
fn well_known_debug(ruby: &Ruby, name: Symbol) -> Result<String, Error> {
    let name = name.name()?;
    guarded(ruby, || match name.as_ref() {
        "Rfc2822" => Ok(format!("{Rfc2822:?}")),
        "Rfc3339" => Ok(format!("{Rfc3339:?}")),
        other => Err(unknown("WellKnown", other)),
    })
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("month_debug", function!(month_debug, 1))?;
    native.define_singleton_method("weekday_debug", function!(weekday_debug, 1))?;
    native.define_singleton_method("unit_debug", function!(unit_debug, 2))?;
    native.define_singleton_method("iso8601_enum_debug", function!(iso8601_enum_debug, 3))?;
    native.define_singleton_method("well_known_debug", function!(well_known_debug, 1))?;
    native.define_singleton_method("weekday_to_i", function!(weekday_to_i, 1))?;
    native.define_singleton_method("iso8601_enum_to_i", function!(iso8601_enum_to_i, 2))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{unit_struct_debug, unit_variant_debug};

    #[test]
    fn units_debug_as_time_core_derives() {
        assert_eq!(unit_struct_debug("Nanosecond").unwrap(), "Nanosecond");
        assert_eq!(unit_variant_debug("Week").unwrap(), "Week");
        assert!(unit_struct_debug("Fortnight").is_err());
    }
}
