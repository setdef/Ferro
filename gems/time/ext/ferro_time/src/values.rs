// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's value types as Ruby classes, and what every one of them shares:
//! equality, ordering, hashing, `Display`, and `Debug` (plan 007,
//! decision 3).
//!
//! Each wrapper's class is the public Ruby class. Ruby never allocates one
//! (`undef_default_alloc_func`), so every instance holds a value time made,
//! and `frozen` freezes each as it is made.

use std::fmt::{Debug, Display};
use std::hash::{DefaultHasher, Hash, Hasher};

use magnus::{function, prelude::*, Error, RModule, Ruby, TypedData};
use time::{
    Date, Month, OffsetDateTime, PlainDateTime, SignedDuration, Time, UtcDateTime, UtcOffset,
    Weekday,
};

use crate::{guarded, Failure};

/// `Ferro::Time::Date`, holding a `time::Date`.
#[magnus::wrap(class = "Ferro::Time::Date", free_immediately, size, frozen_shareable)]
pub struct NDate(pub Date);

/// `Ferro::Time::Time`, holding a `time::Time`.
#[magnus::wrap(class = "Ferro::Time::Time", free_immediately, size, frozen_shareable)]
pub struct NTime(pub Time);

/// `Ferro::Time::PlainDateTime`, holding a `time::PlainDateTime`.
#[magnus::wrap(
    class = "Ferro::Time::PlainDateTime",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NPlain(pub PlainDateTime);

/// `Ferro::Time::UtcDateTime`, holding a `time::UtcDateTime`.
#[magnus::wrap(
    class = "Ferro::Time::UtcDateTime",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NUtc(pub UtcDateTime);

/// `Ferro::Time::OffsetDateTime`, holding a `time::OffsetDateTime`.
#[magnus::wrap(
    class = "Ferro::Time::OffsetDateTime",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NOffsetDateTime(pub OffsetDateTime);

/// `Ferro::Time::UtcOffset`, holding a `time::UtcOffset`.
#[magnus::wrap(
    class = "Ferro::Time::UtcOffset",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NUtcOffset(pub UtcOffset);

/// `Ferro::Time::SignedDuration`, holding a `time::SignedDuration`.
#[magnus::wrap(
    class = "Ferro::Time::SignedDuration",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NDuration(pub SignedDuration);

/// A wrapper and the time value it holds.
pub trait Wrapped: TypedData {
    /// time's type.
    type Inner: Copy + Eq + Hash + Display + Debug;

    /// The value held.
    fn inner(&self) -> Self::Inner;

    /// A wrapper holding `inner`.
    fn new(inner: Self::Inner) -> Self;
}

macro_rules! wrapped {
    ($($wrapper:ident => $inner:ty),+ $(,)?) => {$(
        impl Wrapped for $wrapper {
            type Inner = $inner;

            fn inner(&self) -> $inner {
                self.0
            }

            fn new(inner: $inner) -> Self {
                Self(inner)
            }
        }
    )+};
}

wrapped! {
    NDate => Date,
    NTime => Time,
    NPlain => PlainDateTime,
    NUtc => UtcDateTime,
    NOffsetDateTime => OffsetDateTime,
    NUtcOffset => UtcOffset,
    NDuration => SignedDuration,
}

/// time's `PartialEq`, under `catch_unwind` as every crate call is.
fn eq<T: Wrapped>(ruby: &Ruby, left: &T, right: &T) -> Result<bool, Error> {
    guarded(ruby, || Ok(left.inner() == right.inner()))
}

/// time's `Ord`, as `<=>` answers it.
fn cmp<T: Wrapped>(ruby: &Ruby, left: &T, right: &T) -> Result<i8, Error>
where
    T::Inner: Ord,
{
    guarded(ruby, || Ok(left.inner().cmp(&right.inner()) as i8))
}

/// time's `Hash`, through Rust's `DefaultHasher`, whose keys are fixed, so
/// equal values hash alike.
fn hash<T: Wrapped>(ruby: &Ruby, value: &T) -> Result<u64, Error> {
    guarded(ruby, || {
        let mut hasher = DefaultHasher::new();
        value.inner().hash(&mut hasher);
        Ok(hasher.finish())
    })
}

/// time's `Display`.
fn display<T: Wrapped>(ruby: &Ruby, value: &T) -> Result<String, Error> {
    guarded(ruby, || Ok(value.inner().to_string()))
}

/// time's `Debug`.
fn debug<T: Wrapped>(ruby: &Ruby, value: &T) -> Result<String, Error> {
    guarded(ruby, || Ok(format!("{:?}", value.inner())))
}

/// The month numbered `number`, through time's `TryFrom<u8>`
/// (`src/month.rs:282-292`).
pub fn month(number: u8) -> Result<Month, Failure> {
    Month::try_from(number).map_err(Failure::from)
}

/// The weekday `days` after Monday, as `number_days_from_monday` counts
/// (`src/weekday.rs:150-158`).
pub fn weekday(days: u8) -> Result<Weekday, Failure> {
    if days < 7 {
        Ok(Weekday::Monday.nth_next(days))
    } else {
        Err(Failure::Argument(format!(
            "no weekday {days} days from Monday"
        )))
    }
}

/// A weekday as `number_days_from_monday` counts it, the form Ruby's
/// `Weekday` constants are found by.
pub const fn weekday_number(weekday: Weekday) -> u8 {
    weekday.number_days_from_monday()
}

/// Defines the shared methods on `Native` for one wrapper.
macro_rules! shared {
    ($native:ident, $prefix:literal, $wrapper:ty) => {
        $native.define_singleton_method(concat!($prefix, "_eq"), function!(eq::<$wrapper>, 2))?;
        $native
            .define_singleton_method(concat!($prefix, "_hash"), function!(hash::<$wrapper>, 1))?;
        $native.define_singleton_method(
            concat!($prefix, "_display"),
            function!(display::<$wrapper>, 1),
        )?;
        $native
            .define_singleton_method(concat!($prefix, "_debug"), function!(debug::<$wrapper>, 1))?;
        $native.define_singleton_method(concat!($prefix, "_cmp"), function!(cmp::<$wrapper>, 2))?;
    };
}

/// Defines the value classes under `Ferro::Time` and the methods they
/// share on `Native`.
pub fn define(ruby: &Ruby, time: RModule) -> Result<(), Error> {
    for name in [
        "Date",
        "Time",
        "PlainDateTime",
        "UtcDateTime",
        "OffsetDateTime",
        "UtcOffset",
        "SignedDuration",
    ] {
        time.define_class(name, ruby.class_object())?
            .undef_default_alloc_func();
    }
    let native: RModule = time.const_get("Native")?;
    shared!(native, "date", NDate);
    shared!(native, "time", NTime);
    shared!(native, "plain", NPlain);
    shared!(native, "utc", NUtc);
    shared!(native, "offset_date_time", NOffsetDateTime);
    shared!(native, "utc_offset", NUtcOffset);
    shared!(native, "duration", NDuration);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{weekday, weekday_number};
    use time::Weekday;

    #[test]
    fn weekdays_round_trip_by_their_days_from_monday() {
        for day in 0..7 {
            assert_eq!(weekday_number(weekday(day).unwrap()), day);
        }
        assert_eq!(weekday(0).unwrap(), Weekday::Monday);
        assert_eq!(weekday(6).unwrap(), Weekday::Sunday);
        assert!(weekday(7).is_err());
    }
}
