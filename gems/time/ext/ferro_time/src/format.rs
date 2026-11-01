// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! Format descriptions, and `format`, `format_into`, and `parse` on every
//! type (time 0.3.55 `src/format_description`, `src/formatting`,
//! `src/parsing`; plan 007, decision 11).
//!
//! A description crosses from Ruby as one of four things: a wrapped
//! `FormatDescriptionV3`, the Symbol `:rfc2822` or `:rfc3339`, an
//! `Iso8601` configuration's seven settings in an Array, or format items
//! (`items::Items`, plan 009).

use magnus::{function, prelude::*, Error, Exception, RModule, RString, Ruby, Symbol, Value};
use time::format_description::well_known::{Rfc2822, Rfc3339};
use time::format_description::{self, FormatDescriptionV3, OwnedFormatItem};
use time::formatting::Formattable;
use time::parsing::Parsed;
use time::{error, Date, OffsetDateTime, PlainDateTime, Time, UtcDateTime, UtcOffset};

use crate::iso8601::{self, Parts};
use crate::items::Items;
use crate::parsed::Checked;
use crate::values::{NDate, NOffsetDateTime, NPlain, NTime, NUtc, NUtcOffset, Wrapped};
use crate::{frozen, guarded, Failure};

/// `Ferro::Time::FormatDescription::FormatDescriptionV3`, holding time's
/// opaque version 3 description (`src/format_description/format_description_v3.rs:11-51`).
#[magnus::wrap(
    class = "Ferro::Time::FormatDescription::FormatDescriptionV3",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NFormat(pub FormatDescriptionV3<'static>);

/// A description, as `format` and `parse` take it.
pub enum Description {
    /// A version 3 format description.
    V3(FormatDescriptionV3<'static>),
    /// `Rfc2822`.
    Rfc2822,
    /// `Rfc3339`.
    Rfc3339,
    /// `Iso8601` with these settings.
    Iso8601(Parts),
    /// An `OwnedFormatItem`.
    Item(OwnedFormatItem),
    /// A slice of them, `[OwnedFormatItem]`.
    Items(Vec<OwnedFormatItem>),
}

impl Description {
    /// The description `value` holds; the Ruby side has already refused
    /// anything else with `TypeError`.
    pub fn from_value(value: Value) -> Result<Self, Error> {
        if let Ok(v3) = <&NFormat>::try_convert(value) {
            return Ok(Self::V3(v3.0.clone()));
        }
        if let Ok(name) = Symbol::try_convert(value) {
            let ruby = Ruby::get_with(value);
            return match name.name()?.as_ref() {
                "rfc2822" => Ok(Self::Rfc2822),
                "rfc3339" => Ok(Self::Rfc3339),
                other => Err(Error::new(
                    ruby.exception_type_error(),
                    format!("no well-known format {other}"),
                )),
            };
        }
        match Items::from_value(&Ruby::get_with(value), value)? {
            Some(Items::One(item)) => return Ok(Self::Item(item)),
            Some(Items::Many(items)) => return Ok(Self::Items(items)),
            None => {}
        }
        let settings = <(u8, bool, bool, u8, u8, u8, u8)>::try_convert(value)?;
        Parts::new(settings)
            .map(Self::Iso8601)
            .map_err(|failure| failure.into_error(&Ruby::get_with(value)))
    }
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the compile-time assertions of time 0.3.55's RFC 2822
//   and RFC 3339 formatters (src/formatting/formattable.rs:702-708, :808-814)

/// time's assertion when a type cannot be formatted with RFC 2822.
pub const RFC2822_NEEDS: &str =
    "Rfc2822 requires date, time, and offset components, but not all can be provided by this type";

/// time's assertion when a type cannot be formatted with RFC 3339.
pub const RFC3339_NEEDS: &str =
    "Rfc3339 requires date, time, and offset components, but not all can be provided by this type";

// SPDX-SnippetEnd

/// What every formattable and parsable type answers.
pub trait Formatted: Sized + Copy {
    /// The date, time, and offset the value holds, for ISO 8601.
    fn parts(self) -> (Option<Date>, Option<Time>, Option<UtcOffset>);
    /// `format_into` with a version 3 description or format items.
    fn with<D: Formattable + ?Sized>(
        self,
        description: &D,
        out: &mut Vec<u8>,
    ) -> Result<usize, error::Format>;
    /// `format_into` with RFC 2822, or time's assertion for a type that
    /// cannot provide every component.
    fn rfc2822(self, out: &mut Vec<u8>) -> Result<usize, Failure>;
    /// `format_into` with RFC 3339, likewise.
    fn rfc3339(self, out: &mut Vec<u8>) -> Result<usize, Failure>;
    /// `parse` with each description.
    fn parse(input: &str, description: &Description) -> Result<Self, error::Parse>;
    /// `parse_with_defaults` with each description.
    fn parse_with_defaults(
        input: &[u8],
        description: &Description,
        defaults: Parsed,
    ) -> Result<Self, error::Parse>;
}

macro_rules! formatted {
    ($inner:ty, |$value:ident| $parts:expr, rfc: $rfc:tt) => {
        impl Formatted for $inner {
            fn parts(self) -> (Option<Date>, Option<Time>, Option<UtcOffset>) {
                let $value = self;
                $parts
            }

            fn with<D: Formattable + ?Sized>(self, description: &D, out: &mut Vec<u8>) -> Result<usize, error::Format> {
                self.format_into(out, description)
            }

            formatted!(@rfc $rfc);

            fn parse(input: &str, description: &Description) -> Result<Self, error::Parse> {
                match description {
                    Description::V3(description) => Self::parse(input, description),
                    Description::Rfc2822 => Self::parse(input, &Rfc2822),
                    Description::Rfc3339 => Self::parse(input, &Rfc3339),
                    Description::Iso8601(_) => Self::parse(input, &iso8601::PARSER),
                    Description::Item(item) => Self::parse(input, item),
                    Description::Items(items) => Self::parse(input, items.as_slice()),
                }
            }

            fn parse_with_defaults(input: &[u8], description: &Description, defaults: Parsed) -> Result<Self, error::Parse> {
                match description {
                    Description::V3(description) => Self::parse_with_defaults(input, description, defaults),
                    Description::Rfc2822 => Self::parse_with_defaults(input, &Rfc2822, defaults),
                    Description::Rfc3339 => Self::parse_with_defaults(input, &Rfc3339, defaults),
                    Description::Iso8601(_) => Self::parse_with_defaults(input, &iso8601::PARSER, defaults),
                    Description::Item(item) => Self::parse_with_defaults(input, item, defaults),
                    Description::Items(items) => Self::parse_with_defaults(input, items.as_slice(), defaults),
                }
            }
        }
    };
    (@rfc full) => {
        fn rfc2822(self, out: &mut Vec<u8>) -> Result<usize, Failure> {
            Ok(self.format_into(out, &Rfc2822)?)
        }

        fn rfc3339(self, out: &mut Vec<u8>) -> Result<usize, Failure> {
            Ok(self.format_into(out, &Rfc3339)?)
        }
    };
    (@rfc partial) => {
        fn rfc2822(self, _: &mut Vec<u8>) -> Result<usize, Failure> {
            Err(Failure::Type(RFC2822_NEEDS.to_owned()))
        }

        fn rfc3339(self, _: &mut Vec<u8>) -> Result<usize, Failure> {
            Err(Failure::Type(RFC3339_NEEDS.to_owned()))
        }
    };
}

formatted!(Date, |v| (Some(v), None, None), rfc: partial);
formatted!(Time, |v| (None, Some(v), None), rfc: partial);
formatted!(UtcOffset, |v| (None, None, Some(v)), rfc: partial);
formatted!(PlainDateTime, |v| (Some(v.date()), Some(v.time()), None), rfc: partial);
formatted!(UtcDateTime, |v| (Some(v.date()), Some(v.time()), Some(UtcOffset::UTC)), rfc: full);
formatted!(OffsetDateTime, |v| (Some(v.date()), Some(v.time()), Some(v.offset())), rfc: full);

/// Formats `value` into `out` with `description`, keeping in `out` what
/// time wrote before a failure, as its writer would.
fn write<T: Formatted>(
    value: T,
    description: &Description,
    out: &mut Vec<u8>,
) -> Result<usize, Failure> {
    match description {
        Description::V3(description) => Ok(value.with(description, out)?),
        Description::Item(item) => Ok(value.with(item, out)?),
        Description::Items(items) => Ok(value.with(items.as_slice(), out)?),
        Description::Rfc2822 => value.rfc2822(out),
        Description::Rfc3339 => value.rfc3339(out),
        Description::Iso8601(parts) => {
            let (date, time, offset) = value.parts();
            iso8601::format(*parts, date, time, offset, out)
        }
    }
}

/// `format` (`src/date.rs:1484-1489` and each type's): UTF-8 text, with
/// a deprecated `Literal`'s bytes that are not UTF-8 replaced, as time's
/// `format` replaces them (`src/formatting/formattable.rs:291-313`).
fn format<W: Wrapped>(ruby: &Ruby, value: &W, description: Value) -> Result<String, Error>
where
    W::Inner: Formatted,
{
    let description = Description::from_value(description)?;
    let value = value.inner();
    guarded(ruby, || {
        let mut out = Vec::new();
        write(value, &description, &mut out)?;
        Ok(String::from_utf8_lossy(&out).into_owned())
    })
}

/// `format_into` (`src/date.rs:1466-1482` and each type's): the bytes
/// time wrote, and the count time returned or the failure it stopped
/// with, unraised, so Ruby appends the bytes before it raises (plan 007,
/// decision 11).
fn format_into<W: Wrapped>(
    ruby: &Ruby,
    value: &W,
    description: Value,
) -> Result<(RString, Option<usize>, Option<Exception>), Error>
where
    W::Inner: Formatted,
{
    let description = Description::from_value(description)?;
    let value = value.inner();
    let (written, result) = guarded(ruby, || {
        let mut out = Vec::new();
        let result = write(value, &description, &mut out);
        Ok((out, result))
    })?;
    let (count, exception) = match result {
        Ok(count) => (Some(count), None),
        Err(failure) => (None, Some(failure.into_exception(ruby)?)),
    };
    Ok((ruby.str_from_slice(&written), count, exception))
}

/// `parse` (`src/date.rs:1491-1509` and each type's).
fn parse<W: Wrapped>(ruby: &Ruby, input: String, description: Value) -> Result<Value, Error>
where
    W::Inner: Checked,
{
    let description = Description::from_value(description)?;
    let parsed = guarded(ruby, move || W::Inner::checked_parse(&input, &description))?;
    Ok(frozen(ruby, W::new(parsed)).as_value())
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the version check of time 0.3.55's format
//   description parser (src/format_description/parse/mod.rs:17-23)

/// `parse_borrowed::<VERSION>` or `parse_owned::<VERSION>`
/// (`src/format_description/parse/mod.rs:116-187`) for any version but 1
/// and 2, whose items `items.rs` parses (plan 009, decision 9). Version 3
/// returns a `FormatDescriptionV3`; any other fails time's
/// `assert_version!`, which Rust's compiler would refuse.
fn format_description_parse(
    ruby: &Ruby,
    version: u8,
    owned: bool,
    input: String,
) -> Result<Value, Error> {
    let description = guarded(ruby, move || match version {
        3 if owned => Ok(format_description::parse_owned::<3>(&input)?),
        3 => Ok(format_description::parse_borrowed::<3>(&input)?.to_owned()),
        _ => Err(Failure::Type("invalid version provided".to_owned())),
    })?;
    Ok(frozen(ruby, NFormat(description)).as_value())
}

// SPDX-SnippetEnd

/// `FormatDescriptionV3`'s `Debug` (`format_description_v3.rs:28-33`).
fn format_description_debug(ruby: &Ruby, description: &NFormat) -> Result<String, Error> {
    guarded(ruby, || Ok(format!("{:?}", description.0)))
}

/// `Iso8601`'s `Debug` for a configuration
/// (`src/format_description/well_known/iso8601.rs:34-41`).
fn iso8601_debug(ruby: &Ruby, settings: (u8, bool, bool, u8, u8, u8, u8)) -> Result<String, Error> {
    guarded(ruby, || Ok(iso8601::debug(Parts::new(settings)?)))
}

/// `Config`'s derived `Debug` (`src/format_description/well_known/iso8601.rs:155-174`).
fn iso8601_config_debug(
    ruby: &Ruby,
    settings: (u8, bool, bool, u8, u8, u8, u8),
) -> Result<String, Error> {
    guarded(ruby, || Ok(format!("{:?}", Parts::new(settings)?.config())))
}

/// `Config::encode` (`src/format_description/well_known/iso8601/adt_hack.rs:51-87`).
fn iso8601_encode(ruby: &Ruby, settings: (u8, bool, bool, u8, u8, u8, u8)) -> Result<u128, Error> {
    guarded(ruby, || Ok(Parts::new(settings)?.config().encode()))
}

macro_rules! define_formatting {
    ($native:ident, $($prefix:literal => $wrapper:ty),+ $(,)?) => {$(
        $native.define_singleton_method(concat!($prefix, "_format"), function!(format::<$wrapper>, 2))?;
        $native.define_singleton_method(
            concat!($prefix, "_format_into"),
            function!(format_into::<$wrapper>, 2),
        )?;
        $native.define_singleton_method(concat!($prefix, "_parse"), function!(parse::<$wrapper>, 2))?;
    )+};
}

/// Defines `FormatDescription::FormatDescriptionV3` and the functions on
/// `Native`.
pub fn define(ruby: &Ruby, time: RModule, native: RModule) -> Result<(), Error> {
    time.define_module("FormatDescription")?
        .define_class("FormatDescriptionV3", ruby.class_object())?
        .undef_default_alloc_func();
    native.define_singleton_method(
        "format_description_parse",
        function!(format_description_parse, 3),
    )?;
    native.define_singleton_method(
        "format_description_debug",
        function!(format_description_debug, 1),
    )?;
    native.define_singleton_method("iso8601_debug", function!(iso8601_debug, 1))?;
    native.define_singleton_method("iso8601_encode", function!(iso8601_encode, 1))?;
    native.define_singleton_method("iso8601_config_debug", function!(iso8601_config_debug, 1))?;
    define_formatting!(
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
    use super::{write, Description, RFC2822_NEEDS, RFC3339_NEEDS};
    use crate::Failure;
    use time::format_description::{self, well_known::Rfc3339};
    use time::{Date, Month, OffsetDateTime};

    #[test]
    fn a_failed_format_keeps_what_time_wrote() {
        let description = format_description::parse_owned::<3>("[year]-[month]-[hour]").unwrap();
        let date = Date::from_calendar_date(2020, Month::March, 4).unwrap();
        let mut out = Vec::new();
        let failure = write(date, &Description::V3(description.clone()), &mut out).unwrap_err();
        assert!(matches!(
            failure,
            Failure::Format(time::error::Format::InsufficientTypeInformation { .. })
        ));
        let mut theirs = Vec::new();
        let result = date.format_into(&mut theirs, &description);
        assert!(result.is_err());
        assert_eq!(out, theirs);
        assert_eq!(String::from_utf8(out).unwrap(), "2020-03-");
    }

    #[test]
    #[allow(deprecated)]
    fn a_literal_that_is_not_utf8_formats_as_time_formats_it() {
        use time::format_description::OwnedFormatItem;
        let item = OwnedFormatItem::Literal(Box::new(*b"a\xFFb"));
        let mut out = Vec::new();
        write(Date::MIN, &Description::Item(item.clone()), &mut out).unwrap();
        assert_eq!(
            String::from_utf8_lossy(&out),
            Date::MIN.format(&item).unwrap()
        );
        assert_eq!(Date::MIN.format(&item).unwrap(), "a\u{FFFD}b");
    }

    #[test]
    fn the_rfc_assertions_read_as_times() {
        // The texts are time's const assertions, joined as Rust joins a
        // string literal continued with a backslash.
        assert!(RFC2822_NEEDS.starts_with("Rfc2822 requires date, time, and offset components"));
        assert!(RFC3339_NEEDS.ends_with("but not all can be provided by this type"));
        let date = Date::from_calendar_date(2020, Month::March, 4).unwrap();
        assert!(matches!(
            write(date, &Description::Rfc3339, &mut Vec::new()),
            Err(Failure::Type(message)) if message == RFC3339_NEEDS
        ));
        let mut out = Vec::new();
        write(OffsetDateTime::UNIX_EPOCH, &Description::Rfc3339, &mut out).unwrap();
        assert_eq!(
            out,
            OffsetDateTime::UNIX_EPOCH
                .format(&Rfc3339)
                .unwrap()
                .into_bytes()
        );
    }
}
