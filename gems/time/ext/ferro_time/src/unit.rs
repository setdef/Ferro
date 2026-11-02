// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's `unit` module, which is time-core 0.1.9's (`src/unit.rs`,
//! re-exported at time 0.3.55 `src/lib.rs:139`; plan 010, batch 2).
//!
//! Ruby holds the units and `Unit`'s variants as frozen values and passes
//! their names here; each function names time-core's own types and calls
//! its own `per`, `per_t`, `PartialEq`, and `PartialOrd` for them.

use std::cmp::Ordering;

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol};
use time::unit::{Day, Hour, Microsecond, Millisecond, Minute, Nanosecond, Second, Unit, Week};

use crate::{guarded, Failure};

/// What `per` and `per_t` answer for one pair of units: `per`'s value, in
/// whatever unsigned type time-core picks, widened; `per_t::<u128>`; and
/// `per_t::<f64>`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Per {
    /// `per`, in its default type.
    default: u64,
    /// `per_t::<u128>`, the integer Ruby's one Integer stands for.
    integer: u128,
    /// `per_t::<f64>`, the float Ruby's one Float stands for.
    float: f64,
}

macro_rules! per_table {
    ($($small:ident => [$($large:ident),+];)+) => {
        /// `small::per(large)` and its `per_t` forms for every pair
        /// time-core implements (`src/unit.rs:200-254`), or `None` for a
        /// pair that does not compile.
        fn per_of(small: &str, large: &str) -> Option<Per> {
            match (small, large) {
                $($(
                    (stringify!($small), stringify!($large)) => Some(Per {
                        default: u64::from($small::per($large)),
                        integer: $small::per_t::<u128>($large),
                        float: $small::per_t::<f64>($large),
                    }),
                )+)+
                _ => None,
            }
        }
    };
}

per_table! {
    Nanosecond => [Nanosecond, Microsecond, Millisecond, Second, Minute, Hour, Day, Week];
    Microsecond => [Microsecond, Millisecond, Second, Minute, Hour, Day, Week];
    Millisecond => [Millisecond, Second, Minute, Hour, Day, Week];
    Second => [Second, Minute, Hour, Day, Week];
    Minute => [Minute, Hour, Day, Week];
    Hour => [Hour, Day, Week];
    Day => [Day, Week];
    Week => [Week];
}

/// The diagnostic time-core gives when `larger` does not hold a whole
/// number of `small` (`#[diagnostic::on_unimplemented]`, `src/unit.rs:167`),
/// with the types' names (plan 010, decision 13).
fn not_a_multiple(larger: &str, small: &str) -> String {
    format!("`{larger}` is not an integer multiple of `{small}`")
}

/// The pair's answers, or `TypeError` as Rust's compiler refuses it.
fn per_or_refuse(small: &str, large: &str) -> Result<Per, Failure> {
    per_of(small, large).ok_or_else(|| Failure::Type(not_a_multiple(large, small)))
}

/// `small::per(large)` (`src/unit.rs:38-56`).
fn unit_per(ruby: &Ruby, small: Symbol, large: Symbol) -> Result<u64, Error> {
    let (small, large) = (small.name()?, large.name()?);
    guarded(ruby, || Ok(per_or_refuse(&small, &large)?.default))
}

/// `small::per_t::<u128>(large)` (`src/unit.rs:58-71`).
fn unit_per_integer(ruby: &Ruby, small: Symbol, large: Symbol) -> Result<u128, Error> {
    let (small, large) = (small.name()?, large.name()?);
    guarded(ruby, || Ok(per_or_refuse(&small, &large)?.integer))
}

/// `small::per_t::<f64>(large)` (`src/unit.rs:58-71`).
fn unit_per_float(ruby: &Ruby, small: Symbol, large: Symbol) -> Result<f64, Error> {
    let (small, large) = (small.name()?, large.name()?);
    guarded(ruby, || Ok(per_or_refuse(&small, &large)?.float))
}

/// One side of a comparison: a unit struct or a `Unit` variant, by its
/// place from `Nanosecond` (0) to `Week` (7).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Side {
    /// The unit struct of that place.
    Struct(u8),
    /// The `Unit` variant of that place.
    Variant(Unit),
}

/// `Unit`'s variants in declaration order (`src/unit.rs:292-309`).
const VARIANTS: [Unit; 8] = [
    Unit::Nanosecond,
    Unit::Microsecond,
    Unit::Millisecond,
    Unit::Second,
    Unit::Minute,
    Unit::Hour,
    Unit::Day,
    Unit::Week,
];

/// The side Ruby described, or `ArgumentError` for a place past `Week`.
fn side(variant: bool, place: u8) -> Result<Side, Failure> {
    let unit = VARIANTS
        .get(usize::from(place))
        .copied()
        .ok_or_else(|| Failure::Argument(format!("no unit of time at {place}")))?;
    Ok(if variant {
        Side::Variant(unit)
    } else {
        Side::Struct(place)
    })
}

/// A type time-core compares with every unit and with `Unit`.
trait Comparing:
    PartialOrd<Nanosecond>
    + PartialOrd<Microsecond>
    + PartialOrd<Millisecond>
    + PartialOrd<Second>
    + PartialOrd<Minute>
    + PartialOrd<Hour>
    + PartialOrd<Day>
    + PartialOrd<Week>
    + PartialOrd<Unit>
{
}

impl<T> Comparing for T where
    T: PartialOrd<Nanosecond>
        + PartialOrd<Microsecond>
        + PartialOrd<Millisecond>
        + PartialOrd<Second>
        + PartialOrd<Minute>
        + PartialOrd<Hour>
        + PartialOrd<Day>
        + PartialOrd<Week>
        + PartialOrd<Unit>
{
}

/// time-core's `PartialEq` and `PartialOrd` of `left` with `right`.
fn against<L: Comparing>(left: &L, right: Side) -> (bool, Option<Ordering>) {
    macro_rules! with {
        ($value:expr) => {{
            let value = $value;
            (left.eq(&value), left.partial_cmp(&value))
        }};
    }
    match right {
        Side::Struct(0) => with!(Nanosecond),
        Side::Struct(1) => with!(Microsecond),
        Side::Struct(2) => with!(Millisecond),
        Side::Struct(3) => with!(Second),
        Side::Struct(4) => with!(Minute),
        Side::Struct(5) => with!(Hour),
        Side::Struct(6) => with!(Day),
        Side::Struct(_) => with!(Week),
        Side::Variant(unit) => with!(unit),
    }
}

/// time-core's `PartialEq` and `PartialOrd` between any two sides
/// (`src/unit.rs:90-161`, `:256-311`, and the derives at `:25`, `:291`).
fn compare(left: Side, right: Side) -> (bool, Option<Ordering>) {
    match left {
        Side::Struct(0) => against(&Nanosecond, right),
        Side::Struct(1) => against(&Microsecond, right),
        Side::Struct(2) => against(&Millisecond, right),
        Side::Struct(3) => against(&Second, right),
        Side::Struct(4) => against(&Minute, right),
        Side::Struct(5) => against(&Hour, right),
        Side::Struct(6) => against(&Day, right),
        Side::Struct(_) => against(&Week, right),
        Side::Variant(unit) => against(&unit, right),
    }
}

/// `<=>` between two units or variants, as time-core's `PartialOrd`
/// answers it.
fn unit_cmp(
    ruby: &Ruby,
    left_variant: bool,
    left: u8,
    right_variant: bool,
    right: u8,
) -> Result<Option<i8>, Error> {
    guarded(ruby, || {
        let (_, ordering) = compare(side(left_variant, left)?, side(right_variant, right)?);
        Ok(ordering.map(|ordering| ordering as i8))
    })
}

/// Defines the unit functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("unit_per", function!(unit_per, 2))?;
    native.define_singleton_method("unit_per_integer", function!(unit_per_integer, 2))?;
    native.define_singleton_method("unit_per_float", function!(unit_per_float, 2))?;
    native.define_singleton_method("unit_cmp", function!(unit_cmp, 4))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::cmp::Ordering;

    use super::{compare, not_a_multiple, per_of, side, Side};

    /// The units, smallest first, with each one's length in nanoseconds
    /// (time-core's docs and `src/unit.rs:201-210`).
    const UNITS: [(&str, u128); 8] = [
        ("Nanosecond", 1),
        ("Microsecond", 1_000),
        ("Millisecond", 1_000_000),
        ("Second", 1_000_000_000),
        ("Minute", 60_000_000_000),
        ("Hour", 3_600_000_000_000),
        ("Day", 86_400_000_000_000),
        ("Week", 604_800_000_000_000),
    ];

    #[test]
    fn every_pair_time_core_implements_answers_the_ratio_of_lengths() {
        let mut pairs = 0;
        for (small, small_ns) in UNITS {
            for (large, large_ns) in UNITS {
                let found = per_of(small, large);
                if large_ns < small_ns {
                    assert_eq!(found, None, "{small} per {large}");
                    continue;
                }
                pairs += 1;
                let ratio = large_ns / small_ns;
                let found = found.unwrap();
                assert_eq!(u128::from(found.default), ratio, "{small} per {large}");
                assert_eq!(found.integer, ratio, "{small} per {large}");
                // Every ratio is a whole number below 2**53, so its float
                // prints as the same digits.
                assert_eq!(
                    found.float.to_string(),
                    ratio.to_string(),
                    "{small} per {large}"
                );
            }
        }
        assert_eq!(pairs, 36);
    }

    #[test]
    fn issue_749() {
        // time's tests/integration/convert.rs:4-7.
        assert_eq!(
            per_of("Nanosecond", "Second").unwrap().default,
            1_000_000_000
        );
    }

    #[test]
    fn a_smaller_unit_is_refused_with_time_cores_diagnostic() {
        assert_eq!(
            not_a_multiple("Nanosecond", "Second"),
            "`Nanosecond` is not an integer multiple of `Second`"
        );
    }

    #[test]
    fn equality_and_order_agree_and_follow_the_units_lengths() {
        let sides = (0..8_u8).flat_map(|place| [side(false, place), side(true, place)]);
        let sides: Vec<Side> = sides.map(Result::unwrap).collect();
        let place = |side: Side| match side {
            Side::Struct(place) => place,
            Side::Variant(unit) => {
                u8::try_from(super::VARIANTS.iter().position(|v| *v == unit).unwrap()).unwrap()
            }
        };
        let mut pairs = 0;
        for &left in &sides {
            for &right in &sides {
                let (eq, ordering) = compare(left, right);
                assert_eq!(
                    ordering,
                    Some(place(left).cmp(&place(right))),
                    "{left:?} {right:?}"
                );
                assert_eq!(eq, ordering == Some(Ordering::Equal), "{left:?} {right:?}");
                pairs += 1;
            }
        }
        assert_eq!(pairs, 256);
        assert!(side(false, 8).is_err());
    }
}
