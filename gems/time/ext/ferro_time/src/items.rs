// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The format-item tree: components, their modifiers, and the borrowed and
//! owned items of versions 1 and 2 and `strftime` descriptions (time 0.3.55
//! `src/format_description/component.rs`, `modifier.rs`,
//! `borrowed_format_item.rs`, `owned_format_item.rs`; plan 009).
//!
//! Ruby owns the tree as `Data` values. It crosses as nested Arrays: an
//! item is `[tag, payload]`, its tag the variant's place in time's enum
//! (`Literal` 0 to `First` 5), and a component is its variant's name and
//! then its modifier's fields in time's order, an enum as its variant's
//! place, a `bool` as itself, and `Ignore`'s count as an Integer.
//!
//! Rust rebuilds a modifier only through time's public `default` (or
//! `Ignore::count`) and `with_*` builders. It reads one back without
//! touching its `pub(crate)` fields: `modifier.with_field(v) == modifier`
//! holds exactly when the field is `v`, since each builder sets one field
//! and `PartialEq` is derived (plan 009, decision 10).

#![allow(deprecated)]

use std::num::NonZero;

use magnus::{
    function, prelude::*, Error, Integer, RArray, RModule, RString, Ruby, Symbol, TryConvert, Value,
};
use time::format_description::modifier::{
    self, MonthRepr, Padding, SubsecondDigits, TrailingInput, UnixTimestampPrecision,
    WeekNumberRepr, WeekdayRepr, YearRange, YearRepr,
};
use time::format_description::{BorrowedFormatItem, Component, OwnedFormatItem};

use crate::{guarded, Failure};

/// How deep a tree from Ruby may nest: the depth time's own parser stops
/// at, a `u8` count (`src/format_description/parse/lexer_ast.rs:330`,
/// `:502-509`). A deeper tree would recurse toward a stack overflow, which
/// aborts the process instead of raising (plan 009, decision 10).
pub const MAX_DEPTH: usize = 255;

/// A modifier field as it crosses to and from Ruby.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Encoded {
    /// An Integer: an enum variant's place, or `Ignore`'s count.
    Int(u64),
    /// `true` or `false`.
    Bool(bool),
}

impl Encoded {
    /// The field Ruby sent: an Integer, or `true` or `false` (magnus
    /// reads any other value as its truthiness, and the gem's Ruby sends
    /// only these).
    fn from_value(value: Value) -> Result<Self, Error> {
        if let Some(integer) = Integer::from_value(value) {
            return Ok(Self::Int(integer.to_u64()?));
        }
        Ok(Self::Bool(bool::try_convert(value)?))
    }

    /// The field as Ruby reads it.
    fn into_value(self, ruby: &Ruby) -> Value {
        match self {
            Self::Int(number) => ruby.integer_from_u64(number).as_value(),
            Self::Bool(true) => ruby.qtrue().as_value(),
            Self::Bool(false) => ruby.qfalse().as_value(),
        }
    }
}

/// A modifier field: one of time's modifier enums, or a `bool`.
trait Field: Copy + PartialEq + Sized + 'static {
    /// Every value the field takes, in time's declaration order.
    const DOMAIN: &'static [Self];

    /// The value `encoded` names, or `None`.
    fn decode(encoded: Encoded) -> Option<Self> {
        match encoded {
            Encoded::Int(index) => Self::DOMAIN.get(usize::try_from(index).ok()?).copied(),
            Encoded::Bool(_) => None,
        }
    }

    /// The value as it crosses to Ruby, or `None` for a variant time added
    /// after 0.3.55.
    fn encode(self) -> Option<Encoded> {
        let index = Self::DOMAIN.iter().position(|value| *value == self)?;
        Some(Encoded::Int(index as u64))
    }
}

impl Field for bool {
    const DOMAIN: &'static [Self] = &[false, true];

    fn decode(encoded: Encoded) -> Option<Self> {
        match encoded {
            Encoded::Bool(flag) => Some(flag),
            Encoded::Int(_) => None,
        }
    }

    fn encode(self) -> Option<Encoded> {
        Some(Encoded::Bool(self))
    }
}

macro_rules! fields {
    ($($type:ty => [$($variant:ident),+]),+ $(,)?) => {$(
        impl Field for $type {
            const DOMAIN: &'static [Self] = &[$(<$type>::$variant),+];
        }
    )+};
}

fields! {
    Padding => [Space, Zero, None],
    SubsecondDigits => [One, Two, Three, Four, Five, Six, Seven, Eight, Nine, OneOrMore],
    TrailingInput => [Prohibit, Discard],
    MonthRepr => [Numerical, Long, Short],
    WeekdayRepr => [Short, Long, Sunday, Monday],
    WeekNumberRepr => [Iso, Sunday, Monday],
    YearRepr => [Full, Century, LastTwo],
    YearRange => [Standard, Extended],
    UnixTimestampPrecision => [Second, Millisecond, Microsecond, Nanosecond],
}

/// The value of one field of `modifier`: the one `with` leaves unchanged.
fn read<M: Copy + PartialEq, F: Field>(modifier: M, with: impl Fn(M, F) -> M) -> Option<F> {
    F::DOMAIN
        .iter()
        .copied()
        .find(|value| with(modifier, *value) == modifier)
}

/// A component time added after 0.3.55, a modifier value this gem cannot
/// name, or a malformed encoding from the gem's own Ruby.
fn unknown(what: &str) -> Failure {
    Failure::Type(format!("{what} unknown to ferro-time"))
}

/// The next field of an encoded component, decoded as `F`.
fn next<F: Field>(fields: &mut impl Iterator<Item = Encoded>) -> Result<F, Failure> {
    fields
        .next()
        .and_then(F::decode)
        .ok_or_else(|| unknown("modifier field"))
}

macro_rules! modifiers {
    ($($name:ident { $($field:ident : $type:ty = $with:ident),+ }),+ $(,)?) => {
        /// The component named `name` with `fields`, built through time's
        /// `default` and `with_*` builders.
        fn build(name: &str, fields: &[Encoded]) -> Result<Component, Failure> {
            let mut fields = fields.iter().copied();
            match name {
                $(stringify!($name) => {
                    let modifier = modifier::$name::default();
                    $(let modifier = modifier.$with(next::<$type>(&mut fields)?);)+
                    Ok(Component::$name(modifier))
                })+
                "Ignore" => match fields.next() {
                    Some(Encoded::Int(count)) => {
                        let count = u16::try_from(count).ok().and_then(NonZero::new);
                        let count = count.ok_or_else(|| unknown("ignore count"))?;
                        Ok(Component::Ignore(modifier::Ignore::count(count)))
                    }
                    _ => Err(unknown("ignore count")),
                },
                _ => Err(unknown("component")),
            }
        }

        /// `component`'s name and its modifier's fields, read through
        /// time's builders and `PartialEq`.
        fn fields_of(component: Component) -> Result<(&'static str, Vec<Encoded>), Failure> {
            match component {
                $(Component::$name(modifier) => Ok((stringify!($name), vec![$(
                    read(modifier, |m, v: $type| m.$with(v))
                        .and_then(Field::encode)
                        .ok_or_else(|| unknown("modifier value"))?,
                )+])),)+
                Component::Ignore(modifier) => {
                    Ok(("Ignore", vec![Encoded::Int(u64::from(modifier.count.get()))]))
                }
                _ => Err(unknown("component")),
            }
        }

        /// time's `Debug` for the modifier `component` holds.
        fn modifier_debug(component: Component) -> Result<String, Failure> {
            match component {
                $(Component::$name(modifier) => Ok(format!("{modifier:?}")),)+
                Component::Ignore(modifier) => Ok(format!("{modifier:?}")),
                _ => Err(unknown("component")),
            }
        }

        /// Every component with every combination of its modifier's
        /// settings, and `Ignore` with a sample of counts.
        #[cfg(test)]
        fn every_component() -> Vec<Component> {
            let mut all = Vec::new();
            $(
                let mut modifiers = vec![modifier::$name::default()];
                $(
                    modifiers = modifiers
                        .into_iter()
                        .flat_map(|m| <$type as Field>::DOMAIN.iter().map(move |v| m.$with(*v)))
                        .collect();
                )+
                all.extend(modifiers.into_iter().map(Component::$name));
            )+
            for count in [1, 2, 3, 10, 100, 1_000, u16::MAX] {
                all.push(Component::Ignore(modifier::Ignore::count(NonZero::new(count).unwrap())));
            }
            all
        }
    };
}

modifiers! {
        Day { padding: Padding = with_padding },
        MonthShort { case_sensitive: bool = with_case_sensitive },
        MonthLong { case_sensitive: bool = with_case_sensitive },
        MonthNumerical { padding: Padding = with_padding },
        Month { padding: Padding = with_padding, repr: MonthRepr = with_repr, case_sensitive: bool = with_case_sensitive },
        Ordinal { padding: Padding = with_padding },
        WeekdayShort { case_sensitive: bool = with_case_sensitive },
        WeekdayLong { case_sensitive: bool = with_case_sensitive },
        WeekdaySunday { one_indexed: bool = with_one_indexed },
        WeekdayMonday { one_indexed: bool = with_one_indexed },
        Weekday { repr: WeekdayRepr = with_repr, one_indexed: bool = with_one_indexed, case_sensitive: bool = with_case_sensitive },
        WeekNumberIso { padding: Padding = with_padding },
        WeekNumberSunday { padding: Padding = with_padding },
        WeekNumberMonday { padding: Padding = with_padding },
        WeekNumber { padding: Padding = with_padding, repr: WeekNumberRepr = with_repr },
        CalendarYearFullExtendedRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        CalendarYearFullStandardRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        IsoYearFullExtendedRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        IsoYearFullStandardRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        CalendarYearCenturyExtendedRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        CalendarYearCenturyStandardRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        IsoYearCenturyExtendedRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        IsoYearCenturyStandardRange { padding: Padding = with_padding, sign_is_mandatory: bool = with_sign_is_mandatory },
        CalendarYearLastTwo { padding: Padding = with_padding },
        IsoYearLastTwo { padding: Padding = with_padding },
        Year { padding: Padding = with_padding, repr: YearRepr = with_repr, range: YearRange = with_range, iso_week_based: bool = with_iso_week_based, sign_is_mandatory: bool = with_sign_is_mandatory },
        Hour12 { padding: Padding = with_padding },
        Hour24 { padding: Padding = with_padding },
        Hour { padding: Padding = with_padding, is_12_hour_clock: bool = with_is_12_hour_clock },
        Minute { padding: Padding = with_padding },
        Period { is_uppercase: bool = with_is_uppercase, case_sensitive: bool = with_case_sensitive },
        Second { padding: Padding = with_padding },
        Subsecond { digits: SubsecondDigits = with_digits },
        OffsetHour { sign_is_mandatory: bool = with_sign_is_mandatory, padding: Padding = with_padding },
        OffsetMinute { padding: Padding = with_padding },
        OffsetSecond { padding: Padding = with_padding },
        UnixTimestampSecond { sign_is_mandatory: bool = with_sign_is_mandatory },
        UnixTimestampMillisecond { sign_is_mandatory: bool = with_sign_is_mandatory },
        UnixTimestampMicrosecond { sign_is_mandatory: bool = with_sign_is_mandatory },
        UnixTimestampNanosecond { sign_is_mandatory: bool = with_sign_is_mandatory },
        UnixTimestamp { precision: UnixTimestampPrecision = with_precision, sign_is_mandatory: bool = with_sign_is_mandatory },
        End { trailing_input: TrailingInput = with_trailing_input },
}

/// The component Ruby encoded as `value`: its name, then its fields.
fn component_value(ruby: &Ruby, value: Value) -> Result<Component, Error> {
    let array = RArray::try_convert(value)?;
    let name = String::try_convert(array.entry(0)?)?;
    let fields = (1..array.len())
        .map(|index| Encoded::from_value(array.entry(index.cast_signed())?))
        .collect::<Result<Vec<_>, _>>()?;
    build(&name, &fields).map_err(|failure| failure.into_error(ruby))
}

/// `component` as Ruby reads it: its name, then its fields.
fn component_to(ruby: &Ruby, component: Component) -> Result<RArray, Error> {
    let (name, fields) = fields_of(component).map_err(|failure| failure.into_error(ruby))?;
    let array = ruby.ary_new_capa(fields.len() + 1);
    array.push(name)?;
    for field in fields {
        array.push(field.into_value(ruby))?;
    }
    Ok(array)
}
/// The owned item Ruby encoded as `value`, `depth` levels down the tree.
pub fn item_from(ruby: &Ruby, value: Value, depth: usize) -> Result<OwnedFormatItem, Error> {
    if depth > MAX_DEPTH {
        return Err(Error::new(
            ruby.exception_arg_error(),
            format!("format items nested more than {MAX_DEPTH} levels deep"),
        ));
    }
    let array = RArray::try_convert(value)?;
    let tag = u8::try_convert(array.entry(0)?)?;
    let payload: Value = array.entry(1)?;
    Ok(match tag {
        0 => OwnedFormatItem::Literal(RString::try_convert(payload)?.to_bytes().to_vec().into()),
        1 => OwnedFormatItem::StringLiteral(String::try_convert(payload)?.into()),
        2 => OwnedFormatItem::Component(component_value(ruby, payload)?),
        3 => OwnedFormatItem::Compound(items_from(ruby, payload, depth + 1)?.into()),
        4 => OwnedFormatItem::Optional(Box::new(item_from(ruby, payload, depth + 1)?)),
        5 => OwnedFormatItem::First(items_from(ruby, payload, depth + 1)?.into()),
        other => {
            return Err(Error::new(
                ruby.exception_type_error(),
                format!("no format item variant {other}"),
            ))
        }
    })
}

/// The owned items Ruby encoded as the Array `value`, `depth` levels down.
pub fn items_from(ruby: &Ruby, value: Value, depth: usize) -> Result<Vec<OwnedFormatItem>, Error> {
    let array = RArray::try_convert(value)?;
    (0..array.len())
        .map(|index| item_from(ruby, array.entry(index.cast_signed())?, depth))
        .collect()
}

/// `item` as Ruby reads it.
fn item_to(ruby: &Ruby, item: &OwnedFormatItem) -> Result<RArray, Error> {
    let (tag, payload): (u8, Value) = match item {
        OwnedFormatItem::Literal(bytes) => (0, ruby.str_from_slice(bytes).as_value()),
        OwnedFormatItem::StringLiteral(text) => (1, ruby.str_new(text).as_value()),
        OwnedFormatItem::Component(component) => (2, component_to(ruby, *component)?.as_value()),
        OwnedFormatItem::Compound(items) => (3, items_to(ruby, items)?.as_value()),
        OwnedFormatItem::Optional(inner) => (4, item_to(ruby, inner)?.as_value()),
        OwnedFormatItem::First(items) => (5, items_to(ruby, items)?.as_value()),
        _ => return Err(unknown("format item").into_error(ruby)),
    };
    let array = ruby.ary_new_capa(2);
    array.push(tag)?;
    array.push(payload)?;
    Ok(array)
}

/// `items` as Ruby reads them.
fn items_to(ruby: &Ruby, items: &[OwnedFormatItem]) -> Result<RArray, Error> {
    let array = ruby.ary_new_capa(items.len());
    for item in items {
        array.push(item_to(ruby, item)?)?;
    }
    Ok(array)
}

/// Borrowed items, each owned through time's `From<&BorrowedFormatItem>`
/// (`owned_format_item.rs:85-107`): in Ruby a borrowed item holds its
/// own contents (plan 009, decision 5).
fn owned_items(items: &[BorrowedFormatItem<'_>]) -> Vec<OwnedFormatItem> {
    items.iter().map(OwnedFormatItem::from).collect()
}

/// What a version 1 or 2 parse returns, or time's version assertion,
/// which Rust's compiler would refuse.
fn v1_v2<T>(
    version: u8,
    one: impl FnOnce() -> Result<T, Failure>,
    two: impl FnOnce() -> Result<T, Failure>,
) -> Result<T, Failure> {
    match version {
        1 => one(),
        2 => two(),
        _ => Err(Failure::Type("invalid version provided".to_owned())),
    }
}

/// `parse_borrowed::<1>` or `::<2>`
/// (`src/format_description/parse/mod.rs:124-153`), encoded for Ruby.
fn format_description_items(ruby: &Ruby, version: u8, input: String) -> Result<RArray, Error> {
    use time::format_description::parse_borrowed;
    let items = guarded(ruby, move || {
        v1_v2(
            version,
            || Ok(owned_items(&parse_borrowed::<1>(&input)?)),
            || Ok(owned_items(&parse_borrowed::<2>(&input)?)),
        )
    })?;
    items_to(ruby, &items)
}

/// `parse_owned::<1>` or `::<2>`
/// (`src/format_description/parse/mod.rs:155-187`), encoded for Ruby.
fn format_description_item(ruby: &Ruby, version: u8, input: String) -> Result<RArray, Error> {
    use time::format_description::parse_owned;
    let item = guarded(ruby, move || {
        v1_v2(
            version,
            || Ok(parse_owned::<1>(&input)?),
            || Ok(parse_owned::<2>(&input)?),
        )
    })?;
    item_to(ruby, &item)
}

/// `parse_strftime_borrowed` (`src/format_description/parse/strftime.rs:12-29`),
/// encoded for Ruby.
fn format_description_strftime_items(ruby: &Ruby, input: String) -> Result<RArray, Error> {
    use time::format_description::parse_strftime_borrowed;
    let items = guarded(ruby, move || {
        Ok(owned_items(&parse_strftime_borrowed(&input)?))
    })?;
    items_to(ruby, &items)
}

/// `parse_strftime_owned` (`src/format_description/parse/strftime.rs:31-40`),
/// encoded for Ruby.
fn format_description_strftime_item(ruby: &Ruby, input: String) -> Result<RArray, Error> {
    use time::format_description::parse_strftime_owned;
    let item = guarded(ruby, move || Ok(parse_strftime_owned(&input)?))?;
    item_to(ruby, &item)
}

/// time's `Debug` for what Ruby encoded: an item (`kind` 0), a component
/// (1), or a component's modifier (2) (`borrowed_format_item.rs:44-57`,
/// `owned_format_item.rs:42-55`, and the derived `Debug`s).
fn format_item_debug(ruby: &Ruby, kind: u8, value: Value) -> Result<String, Error> {
    if kind == 0 {
        let item = item_from(ruby, value, 0)?;
        return guarded(ruby, || Ok(format!("{item:?}")));
    }
    let component = component_value(ruby, value)?;
    if kind == 1 {
        guarded(ruby, || Ok(format!("{component:?}")))
    } else {
        guarded(ruby, || modifier_debug(component))
    }
}

/// A description made of items, as `format` and `parse` take it.
pub enum Items {
    /// One `OwnedFormatItem`.
    One(OwnedFormatItem),
    /// A slice, `[OwnedFormatItem]`.
    Many(Vec<OwnedFormatItem>),
}

impl Items {
    /// The items Ruby encoded as `[:item, item]` or `[:items, [item, ...]]`,
    /// or `None` when `value` is no such Array.
    pub fn from_value(ruby: &Ruby, value: Value) -> Result<Option<Self>, Error> {
        let Ok(array) = RArray::try_convert(value) else {
            return Ok(None);
        };
        let Ok(kind) = Symbol::try_convert(array.entry::<Value>(0)?) else {
            return Ok(None);
        };
        let payload: Value = array.entry(1)?;
        match kind.name()?.as_ref() {
            "item" => Ok(Some(Self::One(item_from(ruby, payload, 0)?))),
            "items" => Ok(Some(Self::Many(items_from(ruby, payload, 0)?))),
            _ => Ok(None),
        }
    }
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method(
        "format_description_items",
        function!(format_description_items, 2),
    )?;
    native.define_singleton_method(
        "format_description_item",
        function!(format_description_item, 2),
    )?;
    native.define_singleton_method(
        "format_description_strftime_items",
        function!(format_description_strftime_items, 1),
    )?;
    native.define_singleton_method(
        "format_description_strftime_item",
        function!(format_description_strftime_item, 1),
    )?;
    native.define_singleton_method("format_item_debug", function!(format_item_debug, 2))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{build, every_component, fields_of, read, Encoded, Field};
    use time::format_description::modifier::{self, Padding};
    use time::format_description::{BorrowedFormatItem, OwnedFormatItem};
    use time::{Date, Month, PlainDateTime, Time, UtcDateTime, UtcOffset};

    #[test]
    fn reading_a_field_finds_the_one_its_builder_leaves_alone() {
        let year = modifier::CalendarYearFullStandardRange::default()
            .with_padding(Padding::Space)
            .with_sign_is_mandatory(true);
        assert_eq!(
            read(year, modifier::CalendarYearFullStandardRange::with_padding),
            Some(Padding::Space)
        );
        assert_eq!(
            read(
                year,
                modifier::CalendarYearFullStandardRange::with_sign_is_mandatory
            ),
            Some(true)
        );
        assert_eq!(
            <Padding as Field>::DOMAIN,
            &[Padding::Space, Padding::Zero, Padding::None]
        );
    }

    #[test]
    fn every_setting_reads_back_as_it_was_built() {
        let all = every_component();
        assert_eq!(all.len(), 268);
        for component in all {
            let (name, fields) = fields_of(component).unwrap();
            assert_eq!(build(name, &fields).unwrap(), component);
        }
    }

    #[test]
    fn a_malformed_encoding_is_refused() {
        assert!(build("Nope", &[]).is_err());
        assert!(build("Day", &[]).is_err());
        assert!(build("Day", &[Encoded::Int(3)]).is_err());
        assert!(build("Day", &[Encoded::Bool(true)]).is_err());
        assert!(build("Ignore", &[Encoded::Int(0)]).is_err());
        assert!(build("Ignore", &[Encoded::Int(65_536)]).is_err());
    }

    #[test]
    fn borrowed_and_owned_components_format_alike() {
        let date = Date::from_calendar_date(2021, Month::February, 3).unwrap();
        let time = Time::from_hms_nano(13, 4, 5, 6_007_008).unwrap();
        let offset = UtcOffset::from_hms(-2, -30, -15).unwrap();
        let plain = PlainDateTime::new(date, time);
        let odt = plain.assume_offset(offset);
        let utc = UtcDateTime::new(date, time);
        let mut compared = 0;
        for component in every_component() {
            let borrowed = BorrowedFormatItem::Component(component);
            let owned = OwnedFormatItem::Component(component);
            macro_rules! compare {
                ($value:expr) => {{
                    let mut left = Vec::new();
                    let mut right = Vec::new();
                    let l = $value
                        .format_into(&mut left, &borrowed)
                        .map_err(|e| e.to_string());
                    let r = $value
                        .format_into(&mut right, &owned)
                        .map_err(|e| e.to_string());
                    assert_eq!(l, r, "{component:?}");
                    assert_eq!(left, right, "{component:?}");
                    compared += 1;
                }};
            }
            compare!(date);
            compare!(time);
            compare!(offset);
            compare!(plain);
            compare!(odt);
            compare!(utc);
            assert_eq!(format!("{borrowed:?}"), format!("{owned:?}"));
        }
        assert_eq!(compared, 6 * 268);
    }
}
