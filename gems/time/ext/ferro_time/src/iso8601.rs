// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! ISO 8601 with any configuration (plan 007, decision 11).
//!
//! `Iso8601<CONFIG>` takes its configuration as a const parameter, so
//! every configuration is its own compiled formatter, and there are about
//! 130,000. time formats an ISO 8601 value as its date, then its time, then
//! its offset, each part reading only its own fields
//! (time 0.3.55 `src/formatting/formattable.rs:908-960`,
//! `src/formatting/iso8601.rs`). So this module compiles each part on its
//! own, 12 date, 1,536 time, and 4 offset formatters, formats a value's
//! date, time, and offset with them, and adds the two rules that join the
//! parts. time writes the time's `T` when `!USE_SEPARATORS || FORMAT_DATE`
//! (`src/formatting/iso8601.rs:118-123`): always in the basic format, and in
//! the extended format only after a date. A time-only formatter already
//! writes the first case, so `format` adds the `T` for an extended time
//! after a date. The second rule is `Z` for a UTC offset after a time
//! (`:185-187`). `tests` checks the result against time's own
//! formatter for every named configuration and many others.
//!
//! Parsing reads no configuration (`src/parsing/iso8601.rs`,
//! `src/parsing/parsable.rs:894-954`), so one instantiation parses for all.

use std::num::NonZero;

use time::format_description::well_known::iso8601::{
    Config, DateKind, EncodedConfig, FormattedComponents, OffsetPrecision, TimePrecision,
};
use time::format_description::well_known::Iso8601;
use time::{error, Date, Time, UtcOffset};

use crate::Failure;

/// A `Config`'s settings, as Ruby's `Iso8601::Config` holds them: the
/// formatted components, separators, six-digit years, the date kind, the
/// time precision with its decimal digits (0 for none), and the offset
/// precision, each enum by its declaration index
/// (`src/format_description/well_known/iso8601.rs:92-174`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Parts {
    pub components: u8,
    pub separators: bool,
    pub six_digit_years: bool,
    pub date_kind: u8,
    pub time_precision: u8,
    pub decimal_digits: u8,
    pub offset_precision: u8,
}

impl Parts {
    /// The settings, refusing an index no enum has.
    pub fn new(values: (u8, bool, bool, u8, u8, u8, u8)) -> Result<Self, Failure> {
        let (
            components,
            separators,
            six_digit_years,
            date_kind,
            time_precision,
            decimal_digits,
            offset_precision,
        ) = values;
        if components > 6 || date_kind > 2 || time_precision > 2 || offset_precision > 1 {
            return Err(Failure::Argument(format!(
                "not an Iso8601 configuration: {values:?}"
            )));
        }
        Ok(Self {
            components,
            separators,
            six_digit_years,
            date_kind,
            time_precision,
            decimal_digits,
            offset_precision,
        })
    }

    /// The `Config` these settings describe, built with time's setters.
    pub const fn config(self) -> Config {
        config(
            self.components,
            self.separators,
            self.six_digit_years,
            self.date_kind,
            self.time_precision,
            self.decimal_digits,
            self.offset_precision,
        )
    }
}

const fn components(index: u8) -> FormattedComponents {
    match index {
        0 => FormattedComponents::None,
        1 => FormattedComponents::Date,
        2 => FormattedComponents::Time,
        3 => FormattedComponents::Offset,
        4 => FormattedComponents::DateTime,
        5 => FormattedComponents::DateTimeOffset,
        _ => FormattedComponents::TimeOffset,
    }
}

const fn date_kind(index: u8) -> DateKind {
    match index {
        0 => DateKind::Calendar,
        1 => DateKind::Week,
        _ => DateKind::Ordinal,
    }
}

const fn time_precision(index: u8, digits: u8) -> TimePrecision {
    let decimal_digits = NonZero::new(digits);
    match index {
        0 => TimePrecision::Hour { decimal_digits },
        1 => TimePrecision::Minute { decimal_digits },
        _ => TimePrecision::Second { decimal_digits },
    }
}

const fn offset_precision(index: u8) -> OffsetPrecision {
    match index {
        0 => OffsetPrecision::Hour,
        _ => OffsetPrecision::Minute,
    }
}

/// A `Config` from its settings, through time's setters
/// (`src/format_description/well_known/iso8601.rs:212-264`).
pub const fn config(
    components_index: u8,
    separators: bool,
    six_digit_years: bool,
    date_kind_index: u8,
    precision_index: u8,
    digits: u8,
    offset_index: u8,
) -> Config {
    Config::DEFAULT
        .set_formatted_components(components(components_index))
        .set_use_separators(separators)
        .set_year_is_six_digits(six_digit_years)
        .set_date_kind(date_kind(date_kind_index))
        .set_time_precision(time_precision(precision_index, digits))
        .set_offset_precision(offset_precision(offset_index))
}

/// The encoding of a date-only configuration.
const fn date_part(separators: bool, six: bool, kind: u8) -> EncodedConfig {
    config(1, separators, six, kind, 2, 9, 1).encode()
}

/// The encoding of a time-only configuration.
const fn time_part(separators: bool, precision: u8, digits: u8) -> EncodedConfig {
    config(2, separators, false, 0, precision, digits, 1).encode()
}

/// The encoding of an offset-only configuration.
const fn offset_part(separators: bool, precision: u8) -> EncodedConfig {
    config(3, separators, false, 0, 2, 9, precision).encode()
}

/// The output of a part's formatter.
type Written = Result<usize, error::Format>;

/// Formats `date` with the date-only configuration.
fn format_date(date: Date, parts: Parts, out: &mut Vec<u8>) -> Written {
    macro_rules! arms {
        ($($sep:literal $six:literal $kind:literal),+) => {
            match (parts.separators, parts.six_digit_years, parts.date_kind) {
                $(($sep, $six, $kind) => date.format_into(out, &Iso8601::<{ date_part($sep, $six, $kind) }>),)+
                _ => unreachable!("Parts::new refuses another date kind"),
            }
        };
    }
    arms!(
        false false 0, false false 1, false false 2,
        false true 0, false true 1, false true 2,
        true false 0, true false 1, true false 2,
        true true 0, true true 1, true true 2
    )
}

/// Every decimal digit count a `TimePrecision` can hold.
macro_rules! with_digits {
    ($callback:ident!($($args:tt)*)) => {
        $callback!($($args)* [
            0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
            32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60
            61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89
            90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113
            114 115 116 117 118 119 120 121 122 123 124 125 126 127 128 129 130 131 132 133 134 135
            136 137 138 139 140 141 142 143 144 145 146 147 148 149 150 151 152 153 154 155 156 157
            158 159 160 161 162 163 164 165 166 167 168 169 170 171 172 173 174 175 176 177 178 179
            180 181 182 183 184 185 186 187 188 189 190 191 192 193 194 195 196 197 198 199 200 201
            202 203 204 205 206 207 208 209 210 211 212 213 214 215 216 217 218 219 220 221 222 223
            224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239 240 241 242 243 244 245
            246 247 248 249 250 251 252 253 254 255
        ])
    };
}

/// One time formatter per decimal digit count, for one precision.
macro_rules! time_digits {
    ($time:ident, $out:ident, $digits:expr, $sep:literal, $precision:literal, [$($digit:literal)*]) => {
        match $digits {
            $($digit => $time.format_into($out, &Iso8601::<{ time_part($sep, $precision, $digit) }>),)*
        }
    };
}

/// Formats `time` with the time-only configuration.
fn format_time(time: Time, parts: Parts, out: &mut Vec<u8>) -> Written {
    let digits = parts.decimal_digits;
    match (parts.separators, parts.time_precision) {
        (false, 0) => with_digits!(time_digits!(time, out, digits, false, 0,)),
        (false, 1) => with_digits!(time_digits!(time, out, digits, false, 1,)),
        (false, 2) => with_digits!(time_digits!(time, out, digits, false, 2,)),
        (true, 0) => with_digits!(time_digits!(time, out, digits, true, 0,)),
        (true, 1) => with_digits!(time_digits!(time, out, digits, true, 1,)),
        (true, 2) => with_digits!(time_digits!(time, out, digits, true, 2,)),
        _ => unreachable!("Parts::new refuses another time precision"),
    }
}

/// Formats `offset` with the offset-only configuration.
fn format_offset(offset: UtcOffset, parts: Parts, out: &mut Vec<u8>) -> Written {
    match (parts.separators, parts.offset_precision) {
        (false, 0) => offset.format_into(out, &Iso8601::<{ offset_part(false, 0) }>),
        (false, _) => offset.format_into(out, &Iso8601::<{ offset_part(false, 1) }>),
        (true, 0) => offset.format_into(out, &Iso8601::<{ offset_part(true, 0) }>),
        (true, _) => offset.format_into(out, &Iso8601::<{ offset_part(true, 1) }>),
    }
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: Jacob Pratt et al.
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the compile-time assertions of time 0.3.55's
//   Iso8601 formatter and the rules that join its parts
//   (src/formatting/formattable.rs:927-958, src/formatting/iso8601.rs:118-123,
//   :185-187)

/// Formats a value with the configuration `parts`, given the date, time,
/// and offset it holds, appending to `out` what time would have written
/// even when a part fails, and returning the byte count time's
/// `format_into` returns: each part's own count, so an hour or minute
/// fraction counts as time counts it (`format_float`'s bytes are not
/// added, `src/formatting/iso8601.rs:125-140`).
pub fn format(
    parts: Parts,
    date: Option<Date>,
    time: Option<Time>,
    offset: Option<UtcOffset>,
    out: &mut Vec<u8>,
) -> Result<usize, Failure> {
    let (with_date, with_time, with_offset) = match parts.components {
        1 => (true, false, false),
        2 => (false, true, false),
        3 => (false, false, true),
        4 => (true, true, false),
        5 => (true, true, true),
        6 => (false, true, true),
        _ => (false, false, false),
    };
    let refuse = |message: &str| Err(Failure::Type(message.to_owned()));
    if with_date && date.is_none() {
        return refuse(
            "this Iso8601 configuration formats date components, but this type cannot provide them",
        );
    }
    if with_time && time.is_none() {
        return refuse(
            "this Iso8601 configuration formats time components, but this type cannot provide them",
        );
    }
    if with_offset && offset.is_none() {
        return refuse(
            "this Iso8601 configuration formats offset components, but this type cannot provide \
             them",
        );
    }
    if !(with_date || with_time || with_offset) {
        return refuse("this Iso8601 configuration does not format any components");
    }

    let mut bytes = 0;
    if let (true, Some(date)) = (with_date, date) {
        bytes += format_date(date, parts, out)?;
    }
    if let (true, Some(time)) = (with_time, time) {
        if with_date && parts.separators {
            out.push(b'T');
            bytes += 1;
        }
        bytes += format_time(time, parts, out)?;
    }
    if let (true, Some(offset)) = (with_offset, offset) {
        if with_time && offset.is_utc() {
            out.push(b'Z');
            bytes += 1;
        } else {
            bytes += format_offset(offset, parts, out)?;
        }
    }
    Ok(bytes)
}

// SPDX-SnippetEnd

/// The one formatter-free instantiation every ISO 8601 parse goes through.
pub const PARSER: Iso8601 = Iso8601::DEFAULT;

/// `Iso8601`'s `Debug` for these settings
/// (`src/format_description/well_known/iso8601.rs:34-41`).
pub fn debug(parts: Parts) -> String {
    format!("Iso8601 {{ config: {:?} }}", parts.config())
}

#[cfg(test)]
mod tests {
    use super::{config, debug, format, Parts, PARSER};
    use time::format_description::well_known::Iso8601;
    use time::{Date, Month, OffsetDateTime, PlainDateTime, Time, UtcDateTime, UtcOffset};

    /// time's own result for a value and a configuration: the output it
    /// wrote, and the byte count it returned or the error it stopped with.
    type Outcome = (String, Result<usize, String>);

    fn ours(
        parts: Parts,
        date: Option<Date>,
        time: Option<Time>,
        offset: Option<UtcOffset>,
    ) -> Outcome {
        let mut out = Vec::new();
        let result = format(parts, date, time, offset, &mut out);
        (
            String::from_utf8(out).unwrap(),
            result.map_err(|failure| format!("{failure:?}")),
        )
    }

    fn theirs(out: Vec<u8>, result: Result<usize, time::error::Format>) -> Outcome {
        (
            String::from_utf8(out).unwrap(),
            result.map_err(|error| format!("{:?}", crate::Failure::Format(error))),
        )
    }

    fn values() -> Vec<(PlainDateTime, UtcOffset)> {
        let date = |y, m, d| Date::from_calendar_date(y, m, d).unwrap();
        let time = |h, m, s, n| Time::from_hms_nano(h, m, s, n).unwrap();
        let offset = |h, m, s| UtcOffset::from_hms(h, m, s).unwrap();
        vec![
            (
                date(1997, Month::November, 12).with_time(time(9, 55, 6, 0)),
                offset(-6, 0, 0),
            ),
            (
                date(2021, Month::January, 2).with_time(time(0, 0, 0, 123_456_789)),
                UtcOffset::UTC,
            ),
            (
                date(-1, Month::December, 31).with_time(time(23, 59, 59, 999_999_999)),
                offset(5, 30, 0),
            ),
            (
                date(9999, Month::March, 1).with_time(time(12, 30, 0, 1)),
                offset(1, 2, 3),
            ),
            (
                date(2020, Month::February, 29).with_time(time(7, 8, 9, 500_000_000)),
                offset(0, -30, 0),
            ),
        ]
    }

    /// Compares the composition with time's own formatter for each case,
    /// on one type: `$value` names the value and the parts it holds.
    /// Each type is checked only with the configurations it can format,
    /// since time refuses the rest when Rust compiles.
    macro_rules! check {
        ($kind:ident: $($index:literal),+ $(,)?) => {$({
            const C: (u8, bool, bool, u8, u8, u8, u8) = CASES[$index];
            const ENCODED: u128 = config(C.0, C.1, C.2, C.3, C.4, C.5, C.6).encode();
            let parts = Parts::new(C).unwrap();
            assert_eq!(debug(parts), format!("{:?}", Iso8601::<ENCODED>));
            for (plain, offset) in values() {
                let _ = (&plain, &offset);
                let (value, date, time, offset): (_, Option<Date>, Option<Time>, Option<UtcOffset>) =
                    check!(@$kind plain, offset);
                let mut out = Vec::new();
                let result = value.format_into(&mut out, &Iso8601::<ENCODED>);
                assert_eq!(ours(parts, date, time, offset), theirs(out, result), "{C:?} {value}");
            }
        })+};
        (@offset_date_time $plain:ident, $offset:ident) => {
            ($plain.assume_offset($offset), Some($plain.date()), Some($plain.time()), Some($offset))
        };
        (@utc_date_time $plain:ident, $offset:ident) => {
            ($plain.as_utc(), Some($plain.date()), Some($plain.time()), Some(UtcOffset::UTC))
        };
        (@plain_date_time $plain:ident, $offset:ident) => {
            ($plain, Some($plain.date()), Some($plain.time()), None)
        };
        (@date $plain:ident, $offset:ident) => {
            ($plain.date(), Some($plain.date()), None, None)
        };
        (@time $plain:ident, $offset:ident) => {
            ($plain.time(), None, Some($plain.time()), None)
        };
        (@utc_offset $plain:ident, $offset:ident) => {
            ($offset, None, None, Some($offset))
        };
    }

    /// The named configurations (`DEFAULT`, `DATE`, `TIME`, `OFFSET`,
    /// `DATE_TIME`, `TIME_OFFSET`, and serde's six-digit years), then others
    /// across every setting.
    const CASES: [(u8, bool, bool, u8, u8, u8, u8); 32] = [
        (5, true, false, 0, 2, 9, 1),
        (1, true, false, 0, 2, 9, 1),
        (2, true, false, 0, 2, 9, 1),
        (3, true, false, 0, 2, 9, 1),
        (4, true, false, 0, 2, 9, 1),
        (6, true, false, 0, 2, 9, 1),
        (5, true, true, 0, 2, 9, 1),
        (5, false, false, 0, 2, 9, 1),
        (5, false, true, 1, 0, 0, 0),
        (5, true, false, 2, 1, 3, 0),
        (4, false, false, 1, 2, 0, 1),
        (4, true, true, 2, 0, 12, 1),
        (6, false, false, 0, 1, 200, 0),
        (6, true, false, 0, 0, 1, 1),
        (2, false, false, 0, 2, 255, 1),
        (2, true, false, 0, 1, 9, 1),
        (2, true, false, 0, 0, 10, 1),
        (1, false, true, 0, 2, 9, 1),
        (1, false, false, 1, 2, 9, 1),
        (1, true, true, 2, 2, 9, 1),
        (3, false, false, 0, 2, 9, 0),
        (3, true, false, 0, 2, 9, 0),
        (3, false, false, 0, 2, 9, 1),
        (5, true, false, 1, 2, 1, 1),
        (5, false, true, 2, 1, 0, 1),
        (5, true, false, 0, 0, 8, 0),
        (5, true, false, 0, 2, 3, 1),
        (4, true, false, 0, 2, 0, 1),
        (6, true, true, 1, 2, 6, 0),
        (2, false, false, 0, 0, 0, 1),
        (2, false, false, 0, 1, 0, 1),
        (5, false, false, 1, 1, 20, 1),
    ];

    #[test]
    fn the_composition_formats_as_time_does() {
        check!(offset_date_time:
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
            24, 25, 26, 27, 28, 29, 30, 31,
        );
        check!(utc_date_time:
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
            24, 25, 26, 27, 28, 29, 30, 31,
        );
        check!(plain_date_time: 1, 2, 4, 10, 11, 14, 15, 16, 17, 18, 19, 27, 29, 30);
        check!(date: 1, 17, 18, 19);
        check!(time: 2, 14, 15, 16, 29, 30);
        check!(utc_offset: 3, 20, 21, 22);
    }

    #[test]
    fn what_a_type_cannot_provide_is_refused_with_times_assertion() {
        let parts = Parts::new((5, true, false, 0, 2, 9, 1)).unwrap();
        let date = Date::from_calendar_date(2020, Month::January, 2).unwrap();
        let mut out = Vec::new();
        let refused = format!(
            "{:?}",
            format(parts, Some(date), None, None, &mut out).unwrap_err()
        );
        assert!(refused.contains("formats time components, but this type cannot provide them"));
        let none = Parts::new((0, false, false, 0, 0, 0, 0)).unwrap();
        let refused = format!(
            "{:?}",
            format(none, Some(date), None, None, &mut out).unwrap_err()
        );
        assert!(refused.contains("does not format any components"));
        assert_eq!(out, Vec::<u8>::new());
    }

    #[test]
    fn parsing_reads_no_configuration() {
        const OTHER: u128 = config(1, false, true, 2, 0, 3, 0).encode();
        const PARSING: u128 = config(0, false, false, 0, 0, 0, 0).encode();
        let inputs = [
            "1997-11-12T09:55:06.000000000-06:00",
            "+001997-11-12T09:55:06Z",
            "19971112T095506-0600",
            "2021-W01-2T10:00Z",
            "2021-002T10.5Z",
            "2021-01-02T10:30.25+01",
            "not a date",
        ];
        for input in inputs {
            let expected = OffsetDateTime::parse(input, &PARSER).map_err(|e| e.to_string());
            assert_eq!(
                OffsetDateTime::parse(input, &Iso8601::<OTHER>).map_err(|e| e.to_string()),
                expected
            );
            assert_eq!(
                OffsetDateTime::parse(input, &Iso8601::<PARSING>).map_err(|e| e.to_string()),
                expected
            );
            assert_eq!(
                UtcDateTime::parse(input, &Iso8601::<OTHER>).map_err(|e| e.to_string()),
                UtcDateTime::parse(input, &PARSER).map_err(|e| e.to_string())
            );
        }
    }
}
