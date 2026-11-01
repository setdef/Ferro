// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `parsing::Parsed`, time's parser state, and every `parse_with_defaults`
//! and `TryFrom<Parsed>` (time 0.3.55 `src/parsing/parsed.rs`; plan 009).
//!
//! A Ruby `Parsed` is mutable, as Rust's `&mut self` setters make it, so
//! the native value sits behind a `Mutex`. The lock is held only to copy
//! the `Copy` value out or back: every crate call works on a copy, so no
//! Ruby code, and no crate code, runs under it (plan 005, decision 20).

use std::num::NonZero;
use std::sync::{Mutex, PoisonError};

use magnus::{
    function, method, prelude::*, typed_data::Obj, Error, RClass, RModule, RString, Ruby, Value,
};
use time::error;
use time::parsing::Parsed;
use time::{Date, Month, OffsetDateTime, PlainDateTime, Time, UtcDateTime, UtcOffset, Weekday};

use crate::datetime::LOCAL_OUT_OF_RANGE;
use crate::format::{Description, Formatted};
use crate::items::Items;
use crate::values::{self, NDate, NOffsetDateTime, NPlain, NTime, NUtc, NUtcOffset, Wrapped};
use crate::{frozen, guarded, quietly, Failure, Panic};

/// `Ferro::Time::Parsing::Parsed`, holding a `time::parsing::Parsed`.
#[magnus::wrap(class = "Ferro::Time::Parsing::Parsed", free_immediately, size)]
#[derive(Default)]
pub struct NParsed(Mutex<Parsed>);

impl NParsed {
    /// A copy of the value held.
    pub fn get(&self) -> Parsed {
        *self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Replaces the value held.
    fn set(&self, parsed: Parsed) {
        *self.0.lock().unwrap_or_else(PoisonError::into_inner) = parsed;
    }
}

/// A value as a `Parsed` component takes it from Ruby and gives it back.
trait Component: Copy {
    /// What Ruby passes and receives.
    type Ruby: magnus::TryConvert + magnus::IntoValue;

    /// The component Ruby passed, or `RangeError` in magnus's words for a
    /// zero where Rust takes a `NonZero`.
    fn from_ruby(ruby: &Ruby, value: Self::Ruby) -> Result<Self, Error>;

    /// The component as Ruby reads it.
    fn to_ruby(self) -> Self::Ruby;
}

macro_rules! plain {
    ($($type:ty),+) => {$(
        impl Component for $type {
            type Ruby = $type;

            fn from_ruby(_: &Ruby, value: $type) -> Result<Self, Error> {
                Ok(value)
            }

            fn to_ruby(self) -> $type {
                self
            }
        }
    )+};
}

plain!(i8, i16, i32, u8, u32, i128, bool);

macro_rules! nonzero {
    ($($type:ty => $name:literal),+) => {$(
        impl Component for NonZero<$type> {
            type Ruby = $type;

            fn from_ruby(ruby: &Ruby, value: $type) -> Result<Self, Error> {
                Self::new(value).ok_or_else(|| {
                    Error::new(
                        ruby.exception_range_error(),
                        concat!("integer 0 too small to convert into `", $name, "`"),
                    )
                })
            }

            fn to_ruby(self) -> $type {
                self.get()
            }
        }
    )+};
}

nonzero!(u8 => "NonZero<u8>", u16 => "NonZero<u16>");

impl Component for Month {
    type Ruby = u8;

    fn from_ruby(ruby: &Ruby, value: u8) -> Result<Self, Error> {
        values::month(value).map_err(|failure| failure.into_error(ruby))
    }

    fn to_ruby(self) -> u8 {
        self.into()
    }
}

impl Component for Weekday {
    type Ruby = u8;

    fn from_ruby(ruby: &Ruby, value: u8) -> Result<Self, Error> {
        values::weekday(value).map_err(|failure| failure.into_error(ruby))
    }

    fn to_ruby(self) -> u8 {
        values::weekday_number(self)
    }
}

macro_rules! accessors {
    ($($get:ident, $set:ident, $with:ident: $type:ty;)+) => {
        $(
            /// The getter of the same name (`src/parsing/parsed.rs:619-812`).
            fn $get(ruby: &Ruby, parsed: &NParsed) -> Result<Option<<$type as Component>::Ruby>, Error> {
                let value = parsed.get();
                guarded(ruby, || Ok(value.$get().map(Component::to_ruby)))
            }

            /// The setter of the same name (`src/parsing/parsed.rs:814-928`):
            /// `true` when time set the value, `nil` when it refused.
            fn $set(ruby: &Ruby, parsed: &NParsed, value: <$type as Component>::Ruby) -> Result<Option<bool>, Error> {
                let value = <$type as Component>::from_ruby(ruby, value)?;
                let mut copy = parsed.get();
                let set = guarded(ruby, || Ok(copy.$set(value)))?;
                parsed.set(copy);
                Ok(set.map(|()| true))
            }

            /// The builder of the same name (`src/parsing/parsed.rs:930-1137`):
            /// a new `Parsed`, or `nil` when time refused.
            fn $with(ruby: &Ruby, parsed: &NParsed, value: <$type as Component>::Ruby) -> Result<Option<Obj<NParsed>>, Error> {
                let value = <$type as Component>::from_ruby(ruby, value)?;
                let copy = parsed.get();
                let built = guarded(ruby, || Ok(copy.$with(value)))?;
                Ok(built.map(|built| ruby.obj_wrap(NParsed(Mutex::new(built)))))
            }
        )+

        /// Defines the accessors on `Native`.
        fn define_accessors(native: RModule) -> Result<(), Error> {
            $(
                native.define_singleton_method(concat!("parsed_", stringify!($get)), function!($get, 1))?;
                native.define_singleton_method(concat!("parsed_", stringify!($set)), function!($set, 2))?;
                native.define_singleton_method(concat!("parsed_", stringify!($with)), function!($with, 2))?;
            )+
            Ok(())
        }
    };
}

accessors! {
    year, set_year, with_year: i32;
    year_last_two, set_year_last_two, with_year_last_two: u8;
    iso_year, set_iso_year, with_iso_year: i32;
    iso_year_last_two, set_iso_year_last_two, with_iso_year_last_two: u8;
    month, set_month, with_month: Month;
    sunday_week_number, set_sunday_week_number, with_sunday_week_number: u8;
    monday_week_number, set_monday_week_number, with_monday_week_number: u8;
    iso_week_number, set_iso_week_number, with_iso_week_number: NonZero<u8>;
    weekday, set_weekday, with_weekday: Weekday;
    ordinal, set_ordinal, with_ordinal: NonZero<u16>;
    day, set_day, with_day: NonZero<u8>;
    hour_24, set_hour_24, with_hour_24: u8;
    hour_12, set_hour_12, with_hour_12: NonZero<u8>;
    hour_12_is_pm, set_hour_12_is_pm, with_hour_12_is_pm: bool;
    minute, set_minute, with_minute: u8;
    second, set_second, with_second: u8;
    subsecond, set_subsecond, with_subsecond: u32;
    offset_hour, set_offset_hour, with_offset_hour: i8;
    offset_minute_signed, set_offset_minute_signed, with_offset_minute_signed: i8;
    offset_second_signed, set_offset_second_signed, with_offset_second_signed: i8;
    unix_timestamp_nanos, set_unix_timestamp_nanos, with_unix_timestamp_nanos: i128;
}

macro_rules! centuries {
    ($($get:ident, $negative:ident, $set:ident, $with:ident;)+) => {
        $(
            /// The getter of the same name (`src/parsing/parsed.rs:631-682`).
            fn $get(ruby: &Ruby, parsed: &NParsed) -> Result<Option<i16>, Error> {
                let value = parsed.get();
                guarded(ruby, || Ok(value.$get()))
            }

            /// The getter of the same name (`src/parsing/parsed.rs:640-680`).
            fn $negative(ruby: &Ruby, parsed: &NParsed) -> Result<Option<bool>, Error> {
                let value = parsed.get();
                guarded(ruby, || Ok(value.$negative()))
            }

            /// The setter of the same name, whose sign comes from
            /// `is_negative` only when `value` is zero
            /// (`src/parsing/parsed.rs:838-875`).
            fn $set(ruby: &Ruby, parsed: &NParsed, value: i16, is_negative: bool) -> Result<Option<bool>, Error> {
                let mut copy = parsed.get();
                let set = guarded(ruby, || Ok(copy.$set(value, is_negative)))?;
                parsed.set(copy);
                Ok(set.map(|()| true))
            }

            /// The builder of the same name (`src/parsing/parsed.rs:941-982`).
            fn $with(ruby: &Ruby, parsed: &NParsed, value: i16, is_negative: bool) -> Result<Option<Obj<NParsed>>, Error> {
                let copy = parsed.get();
                let built = guarded(ruby, || Ok(copy.$with(value, is_negative)))?;
                Ok(built.map(|built| ruby.obj_wrap(NParsed(Mutex::new(built)))))
            }
        )+

        /// Defines the century accessors on `Native`.
        fn define_centuries(native: RModule) -> Result<(), Error> {
            $(
                native.define_singleton_method(concat!("parsed_", stringify!($get)), function!($get, 1))?;
                native.define_singleton_method(concat!("parsed_", stringify!($negative)), function!($negative, 1))?;
                native.define_singleton_method(concat!("parsed_", stringify!($set)), function!($set, 3))?;
                native.define_singleton_method(concat!("parsed_", stringify!($with)), function!($with, 3))?;
            )+
            Ok(())
        }
    };
}

centuries! {
    year_century, year_century_is_negative, set_year_century, with_year_century;
    iso_year_century, iso_year_century_is_negative, set_iso_year_century, with_iso_year_century;
}

/// The bytes of a Ruby String, as Rust's `&[u8]` input.
fn bytes(input: RString) -> Vec<u8> {
    input.to_bytes().to_vec()
}

/// What a `parse_*` method of `Parsed` leaves: the rest of the input, a
/// binary String, as Rust returns the rest of its `&[u8]`.
fn remaining(ruby: &Ruby, rest: &[u8]) -> Value {
    ruby.str_from_slice(rest).as_value()
}

/// `Parsed::parse_item` or `parse_items` (`src/parsing/parsed.rs:548-581`),
/// with the item or items Ruby encoded.
fn parse_items(
    ruby: &Ruby,
    parsed: &NParsed,
    input: RString,
    items: Value,
) -> Result<Value, Error> {
    let input = bytes(input);
    let items = Items::from_value(ruby, items)?
        .ok_or_else(|| Error::new(ruby.exception_type_error(), "no format items"))?;
    let mut copy = parsed.get();
    let rest = guarded(ruby, || {
        let rest = match &items {
            Items::One(item) => copy.parse_item(&input, item),
            Items::Many(items) => copy.parse_items(&input, items),
        };
        Ok(rest.map(<[u8]>::to_vec)?)
    })?;
    parsed.set(copy);
    Ok(remaining(ruby, &rest))
}

/// `Parsed::parse_literal` (`src/parsing/parsed.rs:583-591`).
fn parse_literal(ruby: &Ruby, input: RString, literal: RString) -> Result<Value, Error> {
    let (input, literal) = (bytes(input), bytes(literal));
    let rest = guarded(ruby, || {
        Ok(Parsed::parse_literal(&input, &literal).map(<[u8]>::to_vec)?)
    })?;
    Ok(remaining(ruby, &rest))
}

/// `Parsed::parse_component` (`src/parsing/parsed.rs:593-616`), with the
/// component Ruby encoded as an item.
fn parse_component(
    ruby: &Ruby,
    parsed: &NParsed,
    input: RString,
    item: Value,
) -> Result<Value, Error> {
    let Some(Items::One(time::format_description::OwnedFormatItem::Component(component))) =
        Items::from_value(ruby, item)?
    else {
        return Err(Error::new(ruby.exception_type_error(), "no component"));
    };
    let input = bytes(input);
    let mut copy = parsed.get();
    let rest = guarded(ruby, || {
        Ok(copy
            .parse_component(&input, component)
            .map(<[u8]>::to_vec)?)
    })?;
    parsed.set(copy);
    Ok(remaining(ruby, &rest))
}

/// `Parsed`'s derived `Debug`.
fn debug(ruby: &Ruby, parsed: &NParsed) -> Result<String, Error> {
    let value = parsed.get();
    guarded(ruby, || Ok(format!("{value:?}")))
}

/// `Clone`, for `dup` and `clone`: `initialize_copy` copies the value,
/// refusing to overwrite a frozen `Parsed` as Ruby's own
/// `initialize_copy` refuses (`rb_obj_init_copy` in Ruby's `object.c`).
fn initialize_copy(copy: Obj<NParsed>, original: &NParsed) -> Result<(), Error> {
    copy.check_frozen()?;
    copy.set(original.get());
    Ok(())
}

/// How each type is parsed and converted from a `Parsed`, refusing first
/// what time would panic on. Only `UtcDateTime` can panic: its
/// `TryFrom<Parsed>` converts the local date and time to UTC with the
/// panicking `to_utc` (`src/parsing/parsed.rs:1336-1341`), and its every
/// `parse` and `parse_with_defaults` goes through that conversion
/// (`src/parsing/parsable.rs:157-168`).
pub trait Checked: Formatted + TryFrom<Parsed, Error = error::TryFromParsed> {
    /// `parse`.
    fn checked_parse(input: &str, description: &Description) -> Result<Self, Failure> {
        Ok(<Self as Formatted>::parse(input, description)?)
    }

    /// `parse_with_defaults`.
    fn checked_parse_with_defaults(
        input: &[u8],
        description: &Description,
        defaults: Parsed,
    ) -> Result<Self, Failure> {
        Ok(<Self as Formatted>::parse_with_defaults(
            input,
            description,
            defaults,
        )?)
    }

    /// `TryFrom<Parsed>`.
    fn checked_try_from(parsed: Parsed) -> Result<Self, Failure> {
        Ok(Self::try_from(parsed)?)
    }
}

impl Checked for Date {}
impl Checked for Time {}
impl Checked for UtcOffset {}
impl Checked for PlainDateTime {}
impl Checked for OffsetDateTime {}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic message of time 0.3.55's to_utc
//   (src/offset_date_time.rs) and the conversion steps of its
//   TryFrom<Parsed> for UtcDateTime (src/parsing/parsed.rs:1308-1350)

/// Refuses a `UtcDateTime` whose UTC instant leaves the range, before
/// time's `to_utc` panics on it (plan 009, decision 19).
///
/// `odt` is the same input parsed, or the same `Parsed` converted, as an
/// `OffsetDateTime`, whose `TryFrom<Parsed>` takes time's
/// `UtcDateTime` steps one for one (unix timestamp first, then the
/// leap-second stand-in, the date, the time, and the offset) but keeps
/// the offset instead of calling `to_utc` (`src/parsing/parsed.rs:1352-1393`).
/// Where it succeeds, `checked_to_utc` answers exactly what `to_utc`
/// would. Where it needs an offset hour the input lacks, `UtcDateTime`
/// takes UTC, which `to_utc` cannot leave. Where it fails with the
/// conditional "second" range error, the input was a leap second whose
/// UTC instant is not a month's last moment, or none at all; time's
/// public API cannot tell those apart without the parsed hour and minute,
/// which `Time` refuses to convert at second 60, so that one case runs
/// time's conversion with its panic caught quietly and turned into the
/// same refusal. Every other failure comes before `to_utc`.
fn utc_refusing(
    odt: Result<OffsetDateTime, error::Parse>,
    convert: impl FnOnce() -> Result<UtcDateTime, Failure>,
) -> Result<UtcDateTime, Failure> {
    match odt {
        Ok(odt) if odt.checked_to_utc().is_none() => {
            Err(Failure::Range(LOCAL_OUT_OF_RANGE.to_owned()))
        }
        Err(error::Parse::TryFromParsed(error::TryFromParsed::ComponentRange(range)))
            if range.name() == "second" && range.is_conditional() =>
        {
            match quietly(convert) {
                Ok(result) => result,
                Err(Panic(message)) if message == LOCAL_OUT_OF_RANGE => {
                    Err(Failure::Range(message))
                }
                Err(Panic(message)) => Err(Failure::Panic(message)),
            }
        }
        _ => convert(),
    }
}

// SPDX-SnippetEnd

impl Checked for UtcDateTime {
    fn checked_parse(input: &str, description: &Description) -> Result<Self, Failure> {
        let odt = <OffsetDateTime as Formatted>::parse_with_defaults(
            input.as_bytes(),
            description,
            Parsed::new(),
        );
        utc_refusing(odt, || Ok(<Self as Formatted>::parse(input, description)?))
    }

    fn checked_parse_with_defaults(
        input: &[u8],
        description: &Description,
        defaults: Parsed,
    ) -> Result<Self, Failure> {
        let odt = <OffsetDateTime as Formatted>::parse_with_defaults(input, description, defaults);
        utc_refusing(odt, || {
            Ok(<Self as Formatted>::parse_with_defaults(
                input,
                description,
                defaults,
            )?)
        })
    }

    fn checked_try_from(parsed: Parsed) -> Result<Self, Failure> {
        let odt = OffsetDateTime::try_from(parsed).map_err(error::Parse::TryFromParsed);
        utc_refusing(odt, || Ok(Self::try_from(parsed)?))
    }
}

/// `TryFrom<Parsed>` for a date or time type (`src/parsing/parsed.rs:1139-1393`).
fn try_from_parsed<W: Wrapped>(ruby: &Ruby, parsed: &NParsed) -> Result<Obj<W>, Error>
where
    W::Inner: Checked,
{
    let value = parsed.get();
    let converted = guarded(ruby, || W::Inner::checked_try_from(value))?;
    Ok(frozen(ruby, W::new(converted)))
}

/// `parse_with_defaults` (`src/date.rs:1511-1533` and each type's).
fn parse_with_defaults<W: Wrapped>(
    ruby: &Ruby,
    input: RString,
    description: Value,
    defaults: &NParsed,
) -> Result<Obj<W>, Error>
where
    W::Inner: Checked,
{
    let input = bytes(input);
    let description = Description::from_value(description)?;
    let defaults = defaults.get();
    let parsed = guarded(ruby, move || {
        W::Inner::checked_parse_with_defaults(&input, &description, defaults)
    })?;
    Ok(frozen(ruby, W::new(parsed)))
}

macro_rules! per_type {
    ($native:ident, $($prefix:literal => $wrapper:ty),+ $(,)?) => {$(
        $native.define_singleton_method(
            concat!($prefix, "_try_from_parsed"),
            function!(try_from_parsed::<$wrapper>, 1),
        )?;
        $native.define_singleton_method(
            concat!($prefix, "_parse_with_defaults"),
            function!(parse_with_defaults::<$wrapper>, 3),
        )?;
    )+};
}

/// Defines `Parsing::Parsed` and the functions on `Native`.
pub fn define(ruby: &Ruby, time: RModule, native: RModule) -> Result<(), Error> {
    let class: RClass = time
        .define_module("Parsing")?
        .define_class("Parsed", ruby.class_object())?;
    class.define_alloc_func::<NParsed>();
    class.define_method("initialize_copy", method!(initialize_copy, 1))?;
    define_accessors(native)?;
    define_centuries(native)?;
    native.define_singleton_method("parsed_parse_items", function!(parse_items, 3))?;
    native.define_singleton_method("parsed_parse_literal", function!(parse_literal, 2))?;
    native.define_singleton_method("parsed_parse_component", function!(parse_component, 3))?;
    native.define_singleton_method("parsed_debug", function!(debug, 1))?;
    per_type!(
        native,
        "date" => NDate,
        "time" => NTime,
        "utc_offset" => NUtcOffset,
        "plain" => NPlain,
        "utc" => NUtc,
        "offset_date_time" => NOffsetDateTime,
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::num::NonZero;

    use time::format_description::well_known::Rfc3339;
    use time::parsing::Parsed;
    use time::{Month, UtcDateTime};

    use super::Checked;
    use crate::datetime::LOCAL_OUT_OF_RANGE;
    use crate::format::Description;
    use crate::{capture, Failure, Panic};

    /// A `Parsed` of the local `year`-`month`-`day` `hour`:00 at
    /// `offset` hours.
    fn local(year: i32, month: Month, day: u8, hour: u8, offset: i8) -> Parsed {
        Parsed::new()
            .with_year(year)
            .and_then(|p| p.with_month(month))
            .and_then(|p| p.with_day(NonZero::new(day).unwrap()))
            .and_then(|p| p.with_hour_24(hour))
            .and_then(|p| p.with_minute(0))
            .and_then(|p| p.with_offset_hour(offset))
            .unwrap()
    }

    fn is_refusal<T>(result: Result<T, Failure>) -> bool {
        matches!(result, Err(Failure::Range(message)) if message == LOCAL_OUT_OF_RANGE)
    }

    #[test]
    fn the_refusal_matches_times_panic_at_both_ends() {
        for parsed in [
            local(9999, Month::December, 31, 23, -5),
            local(-9999, Month::January, 1, 0, 5),
        ] {
            assert_eq!(
                capture(|| UtcDateTime::try_from(parsed)).err(),
                Some(Panic(LOCAL_OUT_OF_RANGE.to_owned()))
            );
            assert!(is_refusal(UtcDateTime::checked_try_from(parsed)));
        }
        for parsed in [
            local(9999, Month::December, 31, 23, 5),
            local(-9999, Month::January, 1, 0, -5),
            local(9999, Month::December, 31, 18, -5),
        ] {
            assert_eq!(
                UtcDateTime::checked_try_from(parsed).ok(),
                UtcDateTime::try_from(parsed).ok()
            );
            assert!(UtcDateTime::try_from(parsed).is_ok());
        }
    }

    #[test]
    fn a_leap_second_past_the_range_is_refused_too() {
        let input = "9999-12-31T23:59:60-05:00";
        assert_eq!(
            capture(|| UtcDateTime::parse(input, &Rfc3339)).err(),
            Some(Panic(LOCAL_OUT_OF_RANGE.to_owned()))
        );
        assert!(is_refusal(UtcDateTime::checked_parse(
            input,
            &Description::Rfc3339
        )));
        let valid = "2016-12-31T23:59:60Z";
        assert_eq!(
            UtcDateTime::checked_parse(valid, &Description::Rfc3339).ok(),
            UtcDateTime::parse(valid, &Rfc3339).ok()
        );
        assert!(UtcDateTime::parse(valid, &Rfc3339).is_ok());
        let not_last = "2016-12-30T23:59:60Z";
        assert!(matches!(
            UtcDateTime::checked_parse(not_last, &Description::Rfc3339),
            Err(Failure::Parse(_))
        ));
    }
}
