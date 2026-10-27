// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `Month`, `Weekday`, and `util` (time 0.3.55 `src/month.rs`,
//! `src/weekday.rs`, `src/util.rs`, and time-core 0.1.9 `src/util.rs`).
//!
//! A month crosses as its number (`From<Month> for u8`) and a weekday as
//! its days from Monday; Ruby holds the frozen constants.

use std::str::FromStr;

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol};
use time::{util, Month, Weekday};

use crate::values::{month, weekday, weekday_number};
use crate::{guarded, Failure};

/// `Month::length(year)` (`src/month.rs:63-76`).
fn month_length(ruby: &Ruby, number: u8, year: i32) -> Result<u8, Error> {
    guarded(ruby, || Ok(month(number)?.length(year)))
}

/// `previous`, `next`, `nth_next`, or `nth_prev` (`src/month.rs:78-176`).
fn month_step(ruby: &Ruby, number: u8, name: Symbol, n: u8) -> Result<u8, Error> {
    let name = name.name()?;
    guarded(ruby, || {
        let month = month(number)?;
        let stepped = match name.as_ref() {
            "previous" => month.previous(),
            "next" => month.next(),
            "nth_next" => month.nth_next(n),
            "nth_prev" => month.nth_prev(n),
            other => return Err(unknown("Month", other)),
        };
        Ok(u8::from(stepped))
    })
}

/// `Month`'s `FromStr` (`src/month.rs:252-273`).
fn month_from_str(ruby: &Ruby, text: String) -> Result<u8, Error> {
    guarded(ruby, move || Ok(u8::from(Month::from_str(&text)?)))
}

/// `Month`'s `TryFrom<u8>` (`src/month.rs:282-292`).
fn month_try_from(ruby: &Ruby, value: u8) -> Result<u8, Error> {
    guarded(ruby, || Ok(u8::from(month(value)?)))
}

/// `Month`'s `Display` (`src/month.rs:205-250`).
fn month_display(ruby: &Ruby, number: u8) -> Result<String, Error> {
    guarded(ruby, || Ok(month(number)?.to_string()))
}

/// `previous`, `next`, `nth_next`, or `nth_prev` (`src/weekday.rs:35-126`).
fn weekday_step(ruby: &Ruby, days: u8, name: Symbol, n: u8) -> Result<u8, Error> {
    let name = name.name()?;
    guarded(ruby, || {
        let weekday = weekday(days)?;
        let stepped = match name.as_ref() {
            "previous" => weekday.previous(),
            "next" => weekday.next(),
            "nth_next" => weekday.nth_next(n),
            "nth_prev" => weekday.nth_prev(n),
            other => return Err(unknown("Weekday", other)),
        };
        Ok(weekday_number(stepped))
    })
}

/// `number_from_monday`, `number_from_sunday`, `number_days_from_monday`,
/// or `number_days_from_sunday` (`src/weekday.rs:128-170`).
fn weekday_number_of(ruby: &Ruby, days: u8, name: Symbol) -> Result<u8, Error> {
    let name = name.name()?;
    guarded(ruby, || {
        let weekday = weekday(days)?;
        Ok(match name.as_ref() {
            "number_from_monday" => weekday.number_from_monday(),
            "number_from_sunday" => weekday.number_from_sunday(),
            "number_days_from_monday" => weekday.number_days_from_monday(),
            "number_days_from_sunday" => weekday.number_days_from_sunday(),
            other => return Err(unknown("Weekday", other)),
        })
    })
}

/// `Weekday`'s `FromStr` (`src/weekday.rs:231-247`).
fn weekday_from_str(ruby: &Ruby, text: String) -> Result<u8, Error> {
    guarded(ruby, move || Ok(weekday_number(Weekday::from_str(&text)?)))
}

/// `Weekday`'s `Display` (`src/weekday.rs:194-229`).
fn weekday_display(ruby: &Ruby, days: u8) -> Result<String, Error> {
    guarded(ruby, || Ok(weekday(days)?.to_string()))
}

/// `util::is_leap_year` (time-core 0.1.9 `src/util.rs:68-101`).
fn util_is_leap_year(ruby: &Ruby, year: i32) -> Result<bool, Error> {
    guarded(ruby, || Ok(util::is_leap_year(year)))
}

/// `util::days_in_year` (time-core 0.1.9 `src/util.rs:103-115`).
fn util_days_in_year(ruby: &Ruby, year: i32) -> Result<u16, Error> {
    guarded(ruby, || Ok(util::days_in_year(year)))
}

/// `util::weeks_in_year` (time-core 0.1.9 `src/util.rs:117-142`).
fn util_weeks_in_year(ruby: &Ruby, year: i32) -> Result<u8, Error> {
    guarded(ruby, || Ok(util::weeks_in_year(year)))
}

/// `util::days_in_month` (`src/util.rs:26-39`).
fn util_days_in_month(ruby: &Ruby, number: u8, year: i32) -> Result<u8, Error> {
    guarded(ruby, || Ok(util::days_in_month(month(number)?, year)))
}

/// The deprecated `util::days_in_year_month` (`src/util.rs:41-56`).
#[allow(deprecated)]
fn util_days_in_year_month(ruby: &Ruby, year: i32, number: u8) -> Result<u8, Error> {
    guarded(ruby, || Ok(util::days_in_year_month(year, month(number)?)))
}

/// `util::refresh_tz` (`src/util.rs:126-133`): `Some(())` is `true`
/// (plan 007, decision 13).
fn util_refresh_tz(ruby: &Ruby) -> Result<Option<bool>, Error> {
    guarded(ruby, || Ok(util::refresh_tz().map(|()| true)))
}

/// A dispatch name the native layer does not know: only a direct call
/// into `Native` can reach this.
pub fn unknown(owner: &str, name: &str) -> Failure {
    Failure::Argument(format!("no {owner} method {name}"))
}

/// Defines the functions on `Native`.
pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("month_length", function!(month_length, 2))?;
    native.define_singleton_method("month_step", function!(month_step, 3))?;
    native.define_singleton_method("month_from_str", function!(month_from_str, 1))?;
    native.define_singleton_method("month_try_from", function!(month_try_from, 1))?;
    native.define_singleton_method("month_display", function!(month_display, 1))?;
    native.define_singleton_method("weekday_step", function!(weekday_step, 3))?;
    native.define_singleton_method("weekday_number", function!(weekday_number_of, 2))?;
    native.define_singleton_method("weekday_from_str", function!(weekday_from_str, 1))?;
    native.define_singleton_method("weekday_display", function!(weekday_display, 1))?;
    native.define_singleton_method("util_is_leap_year", function!(util_is_leap_year, 1))?;
    native.define_singleton_method("util_days_in_year", function!(util_days_in_year, 1))?;
    native.define_singleton_method("util_weeks_in_year", function!(util_weeks_in_year, 1))?;
    native.define_singleton_method("util_days_in_month", function!(util_days_in_month, 2))?;
    native.define_singleton_method(
        "util_days_in_year_month",
        function!(util_days_in_year_month, 2),
    )?;
    native.define_singleton_method("util_refresh_tz", function!(util_refresh_tz, 0))?;
    Ok(())
}
