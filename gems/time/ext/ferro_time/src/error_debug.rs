// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's `Debug` text for its errors, which every Ruby error class
//! answers as `debug` (`doc/contributors/design/translation.md`; plan 007,
//! Follow-up: the four rulings).
//!
//! A Ruby error class and its fields name exactly one time value: the
//! type the class stands for (plan 007, decision 14), holding those
//! fields. time builds most of those values only inside the crate
//! (`ComponentRange`'s fields are `pub(crate)`, and most variants are
//! `#[non_exhaustive]`), so this module formats a copy of each type's
//! shape, derived as time derives it, from the class's path and the same
//! arguments its `new` takes (`failure::Target`). `tests` compares every
//! variant's text with the `Debug` of a value time itself returned, so a
//! later time that changes a shape fails the build. The unit structs,
//! which any crate can build, are time's own values.

use magnus::{function, prelude::*, Error, Integer, RArray, RModule, RString, Ruby, Value};
use time::error;

use crate::failure::Arg;
use crate::guarded;

/// Copies of the shapes of time's error types, named and nested as time
/// names and nests them (`src/error/*.rs`), so their derived `Debug` is
/// time's. A `&'static str` field is a `String` here; both print alike.
#[allow(
    dead_code,
    reason = "each field is read only by the derived Debug, which is what the shape is for"
)]
mod shape {
    /// `error::ComponentRange` (`src/error/component_range.rs:10-17`).
    #[derive(Debug)]
    pub struct ComponentRange {
        pub name: String,
        pub is_conditional: bool,
    }

    /// `error::Format` (`src/error/format.rs:9-24`), but `StdIo`, whose
    /// `io::Error` has no Ruby value.
    #[derive(Debug)]
    pub enum Format {
        InsufficientTypeInformation,
        InvalidComponent(String),
        ComponentRange(Box<ComponentRange>),
    }

    /// `error::ParseFromDescription` (`src/error/parse_from_description.rs:7-19`).
    #[derive(Debug)]
    pub enum ParseFromDescription {
        InvalidLiteral,
        InvalidComponent(String),
        UnexpectedTrailingCharacters,
    }

    /// `error::TryFromParsed` (`src/error/try_from_parsed.rs:8-17`).
    #[derive(Debug)]
    pub enum TryFromParsed {
        InsufficientInformation,
        ComponentRange(ComponentRange),
    }

    /// `error::Parse` (`src/error/parse.rs:9-27`), but the deprecated
    /// variant, which can never exist.
    #[derive(Debug)]
    pub enum Parse {
        TryFromParsed(TryFromParsed),
        ParseFromDescription(ParseFromDescription),
    }

    /// `error::InvalidFormatDescription`
    /// (`src/error/invalid_format_description.rs:8-84`).
    #[derive(Debug)]
    pub enum InvalidFormatDescription {
        UnclosedOpeningBracket {
            index: usize,
        },
        InvalidComponentName {
            name: String,
            index: usize,
        },
        InvalidModifier {
            value: String,
            index: usize,
        },
        MissingComponentName {
            index: usize,
        },
        MissingRequiredModifier {
            name: String,
            index: usize,
        },
        Expected {
            what: String,
            index: usize,
        },
        NotSupported {
            what: String,
            context: String,
            index: usize,
        },
        DuplicateModifier {
            name: String,
            index: usize,
        },
        InvalidModifierCombination {
            modifier: String,
            context: String,
            index: usize,
        },
    }
}

use shape::InvalidFormatDescription as Ifd;

/// The `ComponentRange` the arguments `[name, is_conditional]` name.
fn range(args: &[Arg]) -> Option<shape::ComponentRange> {
    match args {
        [Arg::Str(name), Arg::Bool(is_conditional)] => Some(shape::ComponentRange {
            name: name.clone(),
            is_conditional: *is_conditional,
        }),
        _ => None,
    }
}

/// The one string argument of a tuple variant.
fn one(args: &[Arg]) -> Option<String> {
    match args {
        [Arg::Str(text)] => Some(text.clone()),
        _ => None,
    }
}

/// `InvalidFormatDescription`'s variant `name` with `args`, its fields in
/// declaration order.
fn invalid_format_description(name: &str, args: &[Arg]) -> Option<Ifd> {
    use Arg::{Index, Str};
    Some(match (name, args) {
        ("UnclosedOpeningBracket", [Index(index)]) => Ifd::UnclosedOpeningBracket { index: *index },
        ("InvalidComponentName", [Str(name), Index(index)]) => Ifd::InvalidComponentName {
            name: name.clone(),
            index: *index,
        },
        ("InvalidModifier", [Str(value), Index(index)]) => Ifd::InvalidModifier {
            value: value.clone(),
            index: *index,
        },
        ("MissingComponentName", [Index(index)]) => Ifd::MissingComponentName { index: *index },
        ("MissingRequiredModifier", [Str(name), Index(index)]) => Ifd::MissingRequiredModifier {
            name: name.clone(),
            index: *index,
        },
        ("Expected", [Str(what), Index(index)]) => Ifd::Expected {
            what: what.clone(),
            index: *index,
        },
        ("NotSupported", [Str(what), Str(context), Index(index)]) => Ifd::NotSupported {
            what: what.clone(),
            context: context.clone(),
            index: *index,
        },
        ("DuplicateModifier", [Str(name), Index(index)]) => Ifd::DuplicateModifier {
            name: name.clone(),
            index: *index,
        },
        ("InvalidModifierCombination", [Str(modifier), Str(context), Index(index)]) => {
            Ifd::InvalidModifierCombination {
                modifier: modifier.clone(),
                context: context.clone(),
                index: *index,
            }
        }
        _ => return None,
    })
}

/// `ParseFromDescription`'s variant `name` with `args`.
fn parse_from_description(name: &str, args: &[Arg]) -> Option<shape::ParseFromDescription> {
    use shape::ParseFromDescription as P;
    Some(match (name, args) {
        ("InvalidLiteral", []) => P::InvalidLiteral,
        ("InvalidComponent", _) => P::InvalidComponent(one(args)?),
        ("UnexpectedTrailingCharacters", []) => P::UnexpectedTrailingCharacters,
        _ => return None,
    })
}

/// `TryFromParsed`'s variant `name` with `args`.
fn try_from_parsed(name: &str, args: &[Arg]) -> Option<shape::TryFromParsed> {
    use shape::TryFromParsed as T;
    Some(match (name, args) {
        ("InsufficientInformation", []) => T::InsufficientInformation,
        ("ComponentRange", _) => T::ComponentRange(range(args)?),
        _ => return None,
    })
}

/// time's `Debug` text for the value the Ruby class at `path` under
/// `Ferro::Time`, made with `args`, stands for; `None` where no time value
/// stands behind it: the enums' own classes, which hold a variant this gem
/// predates or a panic, `Format::StdIo`, and arguments of no Rust type.
pub fn debug_of(path: &str, args: &[Arg]) -> Option<String> {
    use shape::Format as F;
    let rest = path.strip_prefix("Error::")?;
    let (head, tail) = rest.split_once("::").unwrap_or((rest, ""));
    Some(match (head, tail, args) {
        ("ConversionRange", "", []) => format!("{:?}", error::ConversionRange),
        ("IndeterminateOffset", "", []) => format!("{:?}", error::IndeterminateOffset),
        ("DifferentVariant", "", []) => format!("{:?}", error::DifferentVariant),
        ("InvalidVariant", "", []) => format!("{:?}", error::InvalidVariant),
        ("ComponentRange", "", _) => format!("{:?}", range(args)?),
        ("Format", "InsufficientTypeInformation", []) => {
            format!("{:?}", F::InsufficientTypeInformation)
        }
        ("Format", "InvalidComponent", _) => format!("{:?}", F::InvalidComponent(one(args)?)),
        ("Format", "ComponentRange", _) => {
            format!("{:?}", F::ComponentRange(Box::new(range(args)?)))
        }
        ("ParseFromDescription", variant, _) => {
            format!("{:?}", parse_from_description(variant, args)?)
        }
        ("TryFromParsed", variant, _) => format!("{:?}", try_from_parsed(variant, args)?),
        ("Parse", nested, _) => {
            let (kind, variant) = nested.split_once("::")?;
            format!(
                "{:?}",
                match kind {
                    "TryFromParsed" => shape::Parse::TryFromParsed(try_from_parsed(variant, args)?),
                    "ParseFromDescription" => {
                        shape::Parse::ParseFromDescription(parse_from_description(variant, args)?)
                    }
                    _ => return None,
                }
            )
        }
        ("InvalidFormatDescription", variant, _) => {
            format!("{:?}", invalid_format_description(variant, args)?)
        }
        _ => return None,
    })
}

/// An argument from Ruby, as the error's `new` took it: a String, `true`
/// or `false`, or an Integer that fits a `usize`; `None` for anything
/// else, which no time value holds.
fn arg(ruby: &Ruby, value: Value) -> Option<Arg> {
    if let Some(text) = RString::from_value(value) {
        return text.to_string().ok().map(Arg::Str);
    }
    if let Some(integer) = Integer::from_value(value) {
        return integer.to_usize().ok().map(Arg::Index);
    }
    if value.is_kind_of(ruby.class_true_class()) {
        return Some(Arg::Bool(true));
    }
    value
        .is_kind_of(ruby.class_false_class())
        .then_some(Arg::Bool(false))
}

/// `Native.error_debug`: time's `Debug` text for the error class at
/// `path` with `fields`, or `nil`.
fn error_debug(ruby: &Ruby, path: RString, fields: RArray) -> Result<Option<String>, Error> {
    let path = path.to_string()?;
    let mut args = Vec::with_capacity(fields.len());
    for index in 0..fields.len() {
        let Some(value) = arg(ruby, fields.entry(index.cast_signed())?) else {
            return Ok(None);
        };
        args.push(value);
    }
    guarded(ruby, || Ok(debug_of(&path, &args)))
}

/// Defines the function on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("error_debug", function!(error_debug, 2))?;
    Ok(())
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the failures time 0.3.55 returns for these inputs,
//   whose Debug texts these tests pin

#[cfg(test)]
mod tests {
    use std::collections::BTreeSet;

    use time::error;
    use time::format_description::well_known::Iso8601;
    use time::format_description::{parse_owned, parse_strftime_owned};
    use time::{Date, Month, Time};

    use super::debug_of;
    use crate::failure::{Arg, Failure, Target};

    /// The text `debug_of` gives the Ruby class `failure` becomes.
    fn debug_of_target(failure: &Failure) -> Option<String> {
        match failure.target() {
            Target::Time(path, args) => debug_of(path, &args),
            other => panic!("not a time error: {other:?}"),
        }
    }

    fn parse_error(input: &str, description: &str) -> error::Parse {
        Date::parse(input, &parse_owned::<3>(description).unwrap()).unwrap_err()
    }

    #[test]
    fn every_error_debugs_as_the_value_time_returned() {
        let range = Date::from_calendar_date(2019, Month::February, 29).unwrap_err();
        let parses = [
            parse_error("2019-02-30", "[year]-[month]-[day]"),
            parse_error("x", "[year]"),
            parse_error("2020", "[year]"),
            parse_error("2020x", "[year]"),
            parse_error("2020x01", "[year]-[month]"),
        ];
        let mut cases: Vec<(String, Failure)> = vec![
            (format!("{range:?}"), Failure::ComponentRange(range)),
            (
                format!("{:?}", error::ConversionRange),
                Failure::ConversionRange,
            ),
            (
                format!("{:?}", error::IndeterminateOffset),
                Failure::IndeterminateOffset,
            ),
            (
                format!("{:?}", error::InvalidVariant),
                Failure::InvalidVariant,
            ),
        ];
        let formats = [
            Time::MIDNIGHT
                .format(&parse_owned::<3>("[year]").unwrap())
                .unwrap_err(),
            Date::from_calendar_date(-1, Month::January, 1)
                .unwrap()
                .format(&Iso8601::DATE)
                .unwrap_err(),
            error::Format::from(range),
        ];
        for format in formats {
            cases.push((format!("{format:?}"), Failure::Format(format)));
        }
        for parse in parses {
            cases.push((format!("{parse:?}"), Failure::Parse(parse)));
            if let Ok(alone) = error::ParseFromDescription::try_from(parse) {
                cases.push((format!("{alone:?}"), Failure::ParseFromDescription(alone)));
            }
            if let Ok(alone) = error::TryFromParsed::try_from(parse) {
                cases.push((format!("{alone:?}"), Failure::TryFromParsed(alone)));
            }
        }
        let mut variants = BTreeSet::new();
        let descriptions = [
            "[foo",
            "[foo]",
            "[day bar]",
            "[]",
            "[ignore]",
            "[optional]",
            "[day padding:zero padding:zero]",
            "[month repr:numerical case_sensitive:false]",
        ];
        let invalid = descriptions
            .iter()
            .map(|description| parse_owned::<3>(description).unwrap_err())
            .chain([parse_strftime_owned("%Z").unwrap_err()]);
        for failure in invalid {
            let text = format!("{failure:?}");
            variants.insert(text.split([' ', '(']).next().unwrap().to_owned());
            cases.push((text, Failure::InvalidFormatDescription(failure)));
        }
        assert_eq!(variants.len(), 9, "every variant, {variants:?}");
        assert_eq!(cases.len(), 4 + 3 + 5 + 5 + 9);
        for (expected, failure) in cases {
            assert_eq!(debug_of_target(&failure), Some(expected));
        }
        assert_eq!(
            debug_of("Error::DifferentVariant", &[]),
            Some(format!("{:?}", error::DifferentVariant))
        );
    }

    #[test]
    fn an_error_with_no_time_value_has_no_debug() {
        let text = || vec![Arg::Str("x".to_owned())];
        assert_eq!(debug_of("Error", &text()), None);
        assert_eq!(debug_of("Error::Format", &text()), None);
        assert_eq!(debug_of("Error::Format::StdIo", &text()), None);
        assert_eq!(debug_of("Error::Parse::TryFromParsed", &text()), None);
        assert_eq!(debug_of("Error::ComponentRange", &text()), None);
        assert_eq!(debug_of("Elsewhere::ComponentRange", &[]), None);
        let range = [Arg::Str("day".to_owned()), Arg::Bool(true)];
        assert_eq!(debug_of("Error::ComponentRange::Nested", &range), None);
        assert!(debug_of("Error::ComponentRange", &range).is_some());
    }
}

// SPDX-SnippetEnd
