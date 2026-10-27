// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! What a call into time can fail with, in Rust values, and the Ruby
//! exception each becomes (plan 007, decisions 7 and 14).
//!
//! time's error types are enums of enums. Each leaf is a Ruby class nested
//! under the variant it sits in, so a parse that fails on its year raises
//! `Ferro::Time::Error::Parse::ParseFromDescription::InvalidComponent`
//! with `"year"`. The Ruby class builds time's `Display` text from the
//! fields it is given; `failure::tests` pins each text against time.

use magnus::{prelude::*, Error, Exception, ExceptionClass, IntoValue, Ruby, Value};
use time::error;

use crate::namespace;

/// A failure, held as Rust values until it becomes a Ruby exception.
#[derive(Debug)]
pub enum Failure {
    /// time's `ComponentRange`.
    ComponentRange(error::ComponentRange),
    /// time's `IndeterminateOffset`.
    IndeterminateOffset,
    /// time's `InvalidVariant`.
    InvalidVariant,
    /// time's `Format`.
    Format(error::Format),
    /// time's `Parse`.
    Parse(error::Parse),
    /// time's `InvalidFormatDescription`.
    InvalidFormatDescription(error::InvalidFormatDescription),
    /// Ruby's `RangeError`: an input time would panic on (decision 7).
    Range(String),
    /// Ruby's `TypeError`: what Rust's compiler would refuse (decision 11).
    Type(String),
    /// Ruby's `ArgumentError`.
    Argument(String),
    /// Ruby's `ZeroDivisionError`, for an integer division by zero.
    ZeroDivision,
    /// A panic no check foresaw, raised as `Ferro::Time::Error`.
    Panic(String),
}

/// An argument of a Ruby exception's `new`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Arg {
    /// A String.
    Str(String),
    /// `true` or `false`.
    Bool(bool),
    /// An Integer.
    Index(usize),
}

/// The Ruby exception a failure becomes: a class under `Ferro::Time` and
/// the arguments of its `new`, or one of Ruby's own with a message.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Target {
    /// `Ferro::Time::<path>.new(*args)`.
    Time(&'static str, Vec<Arg>),
    /// `RangeError`.
    Range(String),
    /// `TypeError`.
    Type(String),
    /// `ArgumentError`.
    Argument(String),
    /// `ZeroDivisionError`.
    ZeroDivision,
}

/// A `ComponentRange`'s fields, as its Ruby class takes them.
fn range_args(range: error::ComponentRange) -> Vec<Arg> {
    vec![
        Arg::Str(range.name().to_owned()),
        Arg::Bool(range.is_conditional()),
    ]
}

/// A leaf with no fields, or an unknown variant: the class, and time's
/// text when the class is the enum's own (a variant this gem predates).
fn text(path: &'static str, display: &impl ToString) -> Target {
    Target::Time(path, vec![Arg::Str(display.to_string())])
}

/// The Ruby class and arguments of time's `Format`
/// (`src/error/format.rs:9-24`).
fn format_target(failure: &error::Format) -> Target {
    match failure {
        error::Format::InsufficientTypeInformation { .. } => {
            Target::Time("Error::Format::InsufficientTypeInformation", vec![])
        }
        error::Format::InvalidComponent(component) => Target::Time(
            "Error::Format::InvalidComponent",
            vec![Arg::Str((*component).to_owned())],
        ),
        error::Format::ComponentRange(range) => {
            Target::Time("Error::Format::ComponentRange", range_args(**range))
        }
        error::Format::StdIo(io) => text("Error::Format::StdIo", io),
        other => text("Error::Format", &other),
    }
}

/// The Ruby class and arguments of time's `TryFromParsed` under `Parse`
/// (`src/error/try_from_parsed.rs:8-17`).
fn try_from_parsed_target(failure: error::TryFromParsed) -> Target {
    match failure {
        error::TryFromParsed::InsufficientInformation => Target::Time(
            "Error::Parse::TryFromParsed::InsufficientInformation",
            vec![],
        ),
        error::TryFromParsed::ComponentRange(range) => Target::Time(
            "Error::Parse::TryFromParsed::ComponentRange",
            range_args(range),
        ),
        other => text("Error::Parse::TryFromParsed", &other),
    }
}

/// The Ruby class and arguments of time's `ParseFromDescription` under
/// `Parse` (`src/error/parse_from_description.rs:7-19`).
fn parse_from_description_target(failure: error::ParseFromDescription) -> Target {
    match failure {
        error::ParseFromDescription::InvalidLiteral { .. } => {
            Target::Time("Error::Parse::ParseFromDescription::InvalidLiteral", vec![])
        }
        error::ParseFromDescription::InvalidComponent(name) => Target::Time(
            "Error::Parse::ParseFromDescription::InvalidComponent",
            vec![Arg::Str(name.to_owned())],
        ),
        error::ParseFromDescription::UnexpectedTrailingCharacters { .. } => Target::Time(
            "Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters",
            vec![],
        ),
        other => text("Error::Parse::ParseFromDescription", &other),
    }
}

/// The Ruby class and arguments of time's `Parse` (`src/error/parse.rs:9-27`).
fn parse_target(failure: error::Parse) -> Target {
    match failure {
        error::Parse::TryFromParsed(inner) => try_from_parsed_target(inner),
        error::Parse::ParseFromDescription(inner) => parse_from_description_target(inner),
        other => text("Error::Parse", &other),
    }
}

/// The Ruby class and arguments of time's `InvalidFormatDescription`
/// (`src/error/invalid_format_description.rs:8-84`), its fields in
/// declaration order.
fn invalid_format_description_target(failure: &error::InvalidFormatDescription) -> Target {
    use error::InvalidFormatDescription as Ifd;
    let s = |value: &str| Arg::Str(value.to_owned());
    match failure {
        Ifd::UnclosedOpeningBracket { index, .. } => Target::Time(
            "Error::InvalidFormatDescription::UnclosedOpeningBracket",
            vec![Arg::Index(*index)],
        ),
        Ifd::InvalidComponentName { name, index, .. } => Target::Time(
            "Error::InvalidFormatDescription::InvalidComponentName",
            vec![s(name), Arg::Index(*index)],
        ),
        Ifd::InvalidModifier { value, index, .. } => Target::Time(
            "Error::InvalidFormatDescription::InvalidModifier",
            vec![s(value), Arg::Index(*index)],
        ),
        Ifd::MissingComponentName { index, .. } => Target::Time(
            "Error::InvalidFormatDescription::MissingComponentName",
            vec![Arg::Index(*index)],
        ),
        Ifd::MissingRequiredModifier { name, index, .. } => Target::Time(
            "Error::InvalidFormatDescription::MissingRequiredModifier",
            vec![s(name), Arg::Index(*index)],
        ),
        Ifd::Expected { what, index, .. } => Target::Time(
            "Error::InvalidFormatDescription::Expected",
            vec![s(what), Arg::Index(*index)],
        ),
        Ifd::NotSupported {
            what,
            context,
            index,
            ..
        } => Target::Time(
            "Error::InvalidFormatDescription::NotSupported",
            vec![s(what), s(context), Arg::Index(*index)],
        ),
        Ifd::DuplicateModifier { name, index, .. } => Target::Time(
            "Error::InvalidFormatDescription::DuplicateModifier",
            vec![s(name), Arg::Index(*index)],
        ),
        Ifd::InvalidModifierCombination {
            modifier,
            context,
            index,
            ..
        } => Target::Time(
            "Error::InvalidFormatDescription::InvalidModifierCombination",
            vec![s(modifier), s(context), Arg::Index(*index)],
        ),
        other => text("Error::InvalidFormatDescription", other),
    }
}

impl Failure {
    /// The Ruby exception this failure becomes, without touching Ruby.
    pub fn target(&self) -> Target {
        match self {
            Self::ComponentRange(range) => {
                Target::Time("Error::ComponentRange", range_args(*range))
            }
            Self::IndeterminateOffset => Target::Time("Error::IndeterminateOffset", vec![]),
            Self::InvalidVariant => Target::Time("Error::InvalidVariant", vec![]),
            Self::Format(failure) => format_target(failure),
            Self::Parse(failure) => parse_target(*failure),
            Self::InvalidFormatDescription(failure) => invalid_format_description_target(failure),
            Self::Range(message) => Target::Range(message.clone()),
            Self::Type(message) => Target::Type(message.clone()),
            Self::Argument(message) => Target::Argument(message.clone()),
            Self::ZeroDivision => Target::ZeroDivision,
            Self::Panic(message) => text("Error", &format!("time panicked: {message}")),
        }
    }

    /// The Ruby exception, which may look up classes and allocate.
    pub fn into_error(self, ruby: &Ruby) -> Error {
        match self.target() {
            Target::Range(message) => Error::new(ruby.exception_range_error(), message),
            Target::Type(message) => Error::new(ruby.exception_type_error(), message),
            Target::Argument(message) => Error::new(ruby.exception_arg_error(), message),
            Target::ZeroDivision => Error::new(ruby.exception_zero_div_error(), "divided by 0"),
            Target::Time(path, args) => {
                instance(ruby, path, &args).map_or_else(|error| error, Error::from)
            }
        }
    }

    /// The Ruby exception as an object, not yet raised.
    pub fn into_exception(self, ruby: &Ruby) -> Result<Exception, Error> {
        let (class, message) = match self.target() {
            Target::Time(path, args) => return instance(ruby, path, &args),
            Target::Range(message) => (ruby.exception_range_error(), message),
            Target::Type(message) => (ruby.exception_type_error(), message),
            Target::Argument(message) => (ruby.exception_arg_error(), message),
            Target::ZeroDivision => (ruby.exception_zero_div_error(), "divided by 0".to_owned()),
        };
        class.new_instance((message,))
    }
}

/// `Ferro::Time::<path>.new(*args)`.
fn instance(ruby: &Ruby, path: &str, args: &[Arg]) -> Result<Exception, Error> {
    let found = path
        .split("::")
        .try_fold(namespace(ruby)?.as_value(), |module, name| {
            module.funcall::<_, _, Value>("const_get", (name, false))
        })?;
    let class = ExceptionClass::try_convert(found)?;
    let values: Vec<Value> = args
        .iter()
        .map(|arg| match arg {
            Arg::Str(value) => value.as_str().into_value_with(ruby),
            Arg::Bool(value) => value.into_value_with(ruby),
            Arg::Index(value) => value.into_value_with(ruby),
        })
        .collect();
    class.funcall("new", values.as_slice())
}

impl From<error::ComponentRange> for Failure {
    fn from(failure: error::ComponentRange) -> Self {
        Self::ComponentRange(failure)
    }
}

impl From<error::Format> for Failure {
    fn from(failure: error::Format) -> Self {
        Self::Format(failure)
    }
}

impl From<error::Parse> for Failure {
    fn from(failure: error::Parse) -> Self {
        Self::Parse(failure)
    }
}

impl From<error::InvalidFormatDescription> for Failure {
    fn from(failure: error::InvalidFormatDescription) -> Self {
        Self::InvalidFormatDescription(failure)
    }
}

impl From<error::IndeterminateOffset> for Failure {
    fn from(_: error::IndeterminateOffset) -> Self {
        Self::IndeterminateOffset
    }
}

impl From<error::InvalidVariant> for Failure {
    fn from(_: error::InvalidVariant) -> Self {
        Self::InvalidVariant
    }
}

#[cfg(test)]
mod tests {
    use super::{Arg, Failure, Target};
    use time::error;
    use time::format_description::{self, well_known::Rfc3339};
    use time::{Date, Month, OffsetDateTime, Time};

    fn component_range() -> error::ComponentRange {
        Date::from_calendar_date(2019, Month::February, 29).unwrap_err()
    }

    fn invalid_literal() -> error::Parse {
        let description = format_description::parse_owned::<3>("[hour]:[minute]").unwrap();
        Time::parse("12x30", &description).unwrap_err()
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: Jacob Pratt et al.
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Display texts of time 0.3.55's errors
    //   (src/error/*.rs), which the Ruby classes copy

    #[test]
    fn each_display_text_the_ruby_classes_copy() {
        let range = component_range();
        assert_eq!(range.to_string(), "day was not in range");
        assert!(range.is_conditional());
        assert_eq!(
            error::ConversionRange.to_string(),
            "Source value is out of range for the target type"
        );
        assert_eq!(
            error::DifferentVariant.to_string(),
            "value was of a different variant than required"
        );
        assert_eq!(
            error::IndeterminateOffset.to_string(),
            "The system's UTC offset could not be determined"
        );
        assert_eq!(
            error::InvalidVariant.to_string(),
            "value was not a valid variant"
        );
        let date = Date::from_calendar_date(2020, Month::March, 4).unwrap();
        let hour = format_description::parse_owned::<3>("[hour]").unwrap();
        assert_eq!(
            date.format(&hour).unwrap_err().to_string(),
            "The type being formatted does not contain sufficient information to format a \
             component."
        );
        assert_eq!(
            error::Format::InvalidComponent("year").to_string(),
            "The year component cannot be formatted into the requested format."
        );
        assert_eq!(
            error::Format::from(range).to_string(),
            "day was not in range"
        );
        assert_eq!(
            invalid_literal().to_string(),
            "a character literal was not valid"
        );
        assert_eq!(
            error::ParseFromDescription::InvalidComponent("year").to_string(),
            "the 'year' component could not be parsed"
        );
        assert_eq!(
            Date::parse(
                "2020-01-02x",
                &format_description::parse_owned::<3>("[year]-[month]-[day]").unwrap()
            )
            .unwrap_err()
            .to_string(),
            "unexpected trailing characters; the end of input was expected"
        );
        assert_eq!(
            Date::parse(
                "2020",
                &format_description::parse_owned::<3>("[year]").unwrap()
            )
            .unwrap_err()
            .to_string(),
            "the `Parsed` struct did not include enough information to construct the type"
        );
        assert_eq!(
            error::TryFromParsed::ComponentRange(range).to_string(),
            "day was not in range"
        );
    }

    #[test]
    fn each_invalid_format_description_text() {
        // time's own cases (tests/integration/parse_format_description.rs:931-945),
        // through version 3.
        let cases = [
            ("[", "missing component name at byte index 0"),
            ("[foo", "unclosed opening bracket at byte index 0"),
            ("[foo]", "invalid component name `foo` at byte index 1"),
            ("[day bar]", "invalid modifier `bar` at byte index 5"),
            ("[]", "missing component name at byte index 0"),
            (
                "[ignore]",
                "missing required modifier `count` for component at byte index 1",
            ),
        ];
        for (description, message) in cases {
            let failure = format_description::parse_owned::<3>(description).unwrap_err();
            assert_eq!(failure.to_string(), message, "{description}");
        }
    }

    // SPDX-SnippetEnd

    #[test]
    fn each_failure_goes_to_its_class_with_its_fields() {
        let range = component_range();
        let range_args = vec![Arg::Str("day".to_owned()), Arg::Bool(true)];
        assert_eq!(
            Failure::ComponentRange(range).target(),
            Target::Time("Error::ComponentRange", range_args.clone())
        );
        assert_eq!(
            Failure::Format(range.into()).target(),
            Target::Time("Error::Format::ComponentRange", range_args.clone())
        );
        assert_eq!(
            Failure::Format(error::Format::InvalidComponent("year")).target(),
            Target::Time(
                "Error::Format::InvalidComponent",
                vec![Arg::Str("year".to_owned())]
            )
        );
        assert_eq!(
            Failure::Parse(error::TryFromParsed::ComponentRange(range).into()).target(),
            Target::Time("Error::Parse::TryFromParsed::ComponentRange", range_args)
        );
        assert_eq!(
            Failure::Parse(OffsetDateTime::parse("2019-01-01", &Rfc3339).unwrap_err()).target(),
            Target::Time(
                "Error::Parse::ParseFromDescription::InvalidComponent",
                vec![Arg::Str("separator".to_owned())]
            )
        );
        assert_eq!(
            Failure::Parse(invalid_literal()).target(),
            Target::Time("Error::Parse::ParseFromDescription::InvalidLiteral", vec![])
        );
        let trailing = Time::parse(
            "1:2x",
            &format_description::parse_owned::<3>("[hour padding:none]:[minute padding:none]")
                .unwrap(),
        )
        .unwrap_err();
        assert_eq!(
            Failure::Parse(trailing).target(),
            Target::Time(
                "Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters",
                vec![]
            )
        );
        let description = format_description::parse_owned::<3>("[foo]").unwrap_err();
        assert_eq!(
            Failure::InvalidFormatDescription(description).target(),
            Target::Time(
                "Error::InvalidFormatDescription::InvalidComponentName",
                vec![Arg::Str("foo".to_owned()), Arg::Index(1)]
            )
        );
        assert_eq!(
            Failure::Panic("boom".to_owned()).target(),
            Target::Time("Error", vec![Arg::Str("time panicked: boom".to_owned())])
        );
    }
}
