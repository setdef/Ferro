// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! time's `iter` module: `DateIter`, `MonthIter`, `WeekdayIter`, and
//! `Rev` (time 0.3.55 `src/iter/*.rs`; plan 010, batch 1).
//!
//! An iterator advances through `&mut self`, so a Ruby iterator is
//! mutable and its native value sits behind a `Mutex`, as `Parsed`'s does.
//! The lock is held only to clone the iterator out or write it back: every
//! crate call works on the copy, so no Ruby code, and no crate code, runs
//! under it (plan 005, decision 20). A month crosses as its number and a
//! weekday as its days from Monday, as everywhere in the gem.

use std::fmt::{self, Debug};
use std::sync::{Mutex, PoisonError};

use magnus::{
    function, method, prelude::*, typed_data::Obj, Error, RClass, RModule, Ruby, Symbol, TypedData,
    Value,
};
use time::iter::{DateIter, MonthIter, Rev, WeekdayIter};
use time::{Date, Month, Weekday};

use crate::values::{month, weekday, weekday_number, NDate};
use crate::{frozen_option, guarded, Failure};

/// A native value behind a lock, cloned out and written back whole.
pub trait Held: TypedData {
    /// time's iterator.
    type Inner: Clone + PartialEq + Debug;

    /// The lock around it.
    fn cell(&self) -> &Mutex<Self::Inner>;

    /// A copy of the iterator held.
    fn get(&self) -> Self::Inner {
        self.cell()
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .clone()
    }

    /// Replaces the iterator held.
    fn set(&self, inner: Self::Inner) {
        *self.cell().lock().unwrap_or_else(PoisonError::into_inner) = inner;
    }
}

macro_rules! held {
    ($($wrapper:ident($inner:ty) => $class:literal, $placeholder:expr;)+) => {$(
        #[doc = concat!("`", $class, "`, holding a `", stringify!($inner), "`.")]
        #[magnus::wrap(class = $class, free_immediately, size)]
        pub struct $wrapper(Mutex<$inner>);

        impl Default for $wrapper {
            /// What Ruby's allocator makes before `initialize` or
            /// `initialize_copy` replaces it: a value time's public API
            /// also builds (plan 010, decision 1).
            fn default() -> Self {
                Self(Mutex::new($placeholder))
            }
        }

        impl Held for $wrapper {
            type Inner = $inner;

            fn cell(&self) -> &Mutex<$inner> {
                &self.0
            }
        }
    )+};
}

held! {
    NDateIter(DateIter) => "Ferro::Time::Iter::DateIter", DateIter::new(Date::MAX, Date::MIN);
    NMonthIter(MonthIter) => "Ferro::Time::Iter::MonthIter", MonthIter::new(Month::January);
    NWeekdayIter(WeekdayIter) => "Ferro::Time::Iter::WeekdayIter", WeekdayIter::new(Weekday::Monday);
    NRev(Reversed) => "Ferro::Time::Iter::Rev", Reversed::Month(MonthIter::new(Month::January).rev());
}

/// time's two `Rev` types, which Ruby holds in one class (plan 010,
/// decision 7).
#[derive(Clone, PartialEq, Eq)]
pub enum Reversed {
    /// `Rev<MonthIter>`.
    Month(Rev<MonthIter>),
    /// `Rev<WeekdayIter>`.
    Weekday(Rev<WeekdayIter>),
}

impl Debug for Reversed {
    /// The `Debug` of the `Rev` held, as time derives it.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Month(rev) => rev.fmt(f),
            Self::Weekday(rev) => rev.fmt(f),
        }
    }
}

/// Which of the two methods that panic on an infinite iterator.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Infinite {
    /// `count`.
    Count,
    /// `last`.
    Last,
}

/// time's panic message for `count` or `last` on the infinite iterator
/// `name` (`src/iter/month_iter.rs:73-79`, `:136-142`;
/// `src/iter/weekday_iter.rs:72-78`, `:119-125`).
fn infinite_message(name: &str, method: Infinite) -> String {
    match method {
        Infinite::Count => format!("`{name}` is infinite and cannot be counted"),
        Infinite::Last => format!("`{name}` is infinite and has no last element"),
    }
}

/// One of time's four infinite iterators, its items as the numbers that
/// cross to Ruby.
pub trait Cycle: Clone + PartialEq + Debug {
    /// The type name time's panics use.
    fn name(&self) -> &'static str;

    /// `Iterator::next`, which never ends.
    fn next_number(&mut self) -> u8;

    /// `Iterator::nth`, which never ends.
    fn nth_number(&mut self, n: usize) -> u8;

    /// `Iterator::size_hint`.
    fn hint(&self) -> (usize, Option<usize>);

    /// `Iterator::all`, over the numbers.
    fn all_numbers(&mut self, f: &mut dyn FnMut(u8) -> bool) -> bool;

    /// `Iterator::any`, over the numbers.
    fn any_numbers(&mut self, f: &mut dyn FnMut(u8) -> bool) -> bool;

    /// `max`, `min`, and `is_sorted`, which only month iterators have
    /// (plan 010, decision 10).
    fn ordered(&self) -> Option<Ordered>;
}

/// What time's `max`, `min`, and `is_sorted` answer for a month iterator.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Ordered {
    /// `max`, as a month number.
    max: u8,
    /// `min`, as a month number.
    min: u8,
    /// `is_sorted`.
    is_sorted: bool,
}

/// The `Ordered` answers of a month iterator, through time's own methods.
fn ordered_months(iter: impl Iterator<Item = Month> + Clone) -> Option<Ordered> {
    Some(Ordered {
        max: u8::from(iter.clone().max()?),
        min: u8::from(iter.clone().min()?),
        is_sorted: iter.is_sorted(),
    })
}

macro_rules! cycle {
    ($($type:ty => $name:literal, $number:expr, $ordered:expr;)+) => {$(
        impl Cycle for $type {
            fn name(&self) -> &'static str {
                $name
            }

            fn next_number(&mut self) -> u8 {
                self.next().map_or(0, $number)
            }

            fn nth_number(&mut self, n: usize) -> u8 {
                self.nth(n).map_or(0, $number)
            }

            fn hint(&self) -> (usize, Option<usize>) {
                self.size_hint()
            }

            fn all_numbers(&mut self, f: &mut dyn FnMut(u8) -> bool) -> bool {
                self.all(|item| f($number(item)))
            }

            fn any_numbers(&mut self, f: &mut dyn FnMut(u8) -> bool) -> bool {
                self.any(|item| f($number(item)))
            }

            fn ordered(&self) -> Option<Ordered> {
                $ordered(self)
            }
        }
    )+};
}

cycle! {
    MonthIter => "MonthIter", u8::from, |iter: &MonthIter| ordered_months(iter.clone());
    Rev<MonthIter> => "Rev<MonthIter>", u8::from, |iter: &Rev<MonthIter>| ordered_months(iter.clone());
    WeekdayIter => "WeekdayIter", weekday_number, |_: &WeekdayIter| None;
    Rev<WeekdayIter> => "Rev<WeekdayIter>", weekday_number, |_: &Rev<WeekdayIter>| None;
}

impl Cycle for Reversed {
    fn name(&self) -> &'static str {
        match self {
            Self::Month(rev) => rev.name(),
            Self::Weekday(rev) => rev.name(),
        }
    }

    fn next_number(&mut self) -> u8 {
        match self {
            Self::Month(rev) => rev.next_number(),
            Self::Weekday(rev) => rev.next_number(),
        }
    }

    fn nth_number(&mut self, n: usize) -> u8 {
        match self {
            Self::Month(rev) => rev.nth_number(n),
            Self::Weekday(rev) => rev.nth_number(n),
        }
    }

    fn hint(&self) -> (usize, Option<usize>) {
        match self {
            Self::Month(rev) => rev.hint(),
            Self::Weekday(rev) => rev.hint(),
        }
    }

    fn all_numbers(&mut self, f: &mut dyn FnMut(u8) -> bool) -> bool {
        match self {
            Self::Month(rev) => rev.all_numbers(f),
            Self::Weekday(rev) => rev.all_numbers(f),
        }
    }

    fn any_numbers(&mut self, f: &mut dyn FnMut(u8) -> bool) -> bool {
        match self {
            Self::Month(rev) => rev.any_numbers(f),
            Self::Weekday(rev) => rev.any_numbers(f),
        }
    }

    fn ordered(&self) -> Option<Ordered> {
        match self {
            Self::Month(rev) => rev.ordered(),
            Self::Weekday(rev) => rev.ordered(),
        }
    }
}

/// Replaces `held`'s iterator with `inner`, refusing a frozen one with
/// Ruby's own `FrozenError`.
fn replace<H: Held>(held: Obj<H>, inner: H::Inner) -> Result<(), Error> {
    held.check_frozen()?;
    held.set(inner);
    Ok(())
}

/// `DateIter::new(start, end)` (`src/iter/date_iter.rs:16-40`), for
/// `initialize`.
fn date_iter_initialize(iter: Obj<NDateIter>, start: &NDate, end: &NDate) -> Result<(), Error> {
    replace(iter, DateIter::new(start.0, end.0))
}

/// `next` or `next_back` (`src/iter/date_iter.rs:69-82`, `:157-169`).
fn date_iter_step(ruby: &Ruby, iter: Obj<NDateIter>, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    iter.check_frozen()?;
    let mut copy = iter.get();
    let item = guarded(ruby, || match name.as_ref() {
        "next" => Ok(copy.next()),
        "next_back" => Ok(copy.next_back()),
        other => Err(unknown("DateIter", other)),
    })?;
    iter.set(copy);
    Ok(frozen_option(ruby, item.map(NDate)))
}

/// `nth` or `nth_back` (`src/iter/date_iter.rs:100-138`, `:171-204`).
fn date_iter_nth(
    ruby: &Ruby,
    iter: Obj<NDateIter>,
    name: Symbol,
    n: usize,
) -> Result<Value, Error> {
    let name = name.name()?;
    iter.check_frozen()?;
    let mut copy = iter.get();
    let item = guarded(ruby, || match name.as_ref() {
        "nth" => Ok(copy.nth(n)),
        "nth_back" => Ok(copy.nth_back(n)),
        other => Err(unknown("DateIter", other)),
    })?;
    iter.set(copy);
    Ok(frozen_option(ruby, item.map(NDate)))
}

/// `len` or `count` (`src/iter/date_iter.rs:90-93`, `:207-216`), on a
/// copy: `count` takes the iterator by value.
fn date_iter_count(ruby: &Ruby, iter: &NDateIter, name: Symbol) -> Result<usize, Error> {
    let name = name.name()?;
    let copy = iter.get();
    guarded(ruby, || match name.as_ref() {
        "len" => Ok(copy.len()),
        "count" => Ok(copy.count()),
        other => Err(unknown("DateIter", other)),
    })
}

/// `last`, `max`, or `min` (`src/iter/date_iter.rs:95-98`, `:140-148`),
/// on a copy.
fn date_iter_end(ruby: &Ruby, iter: &NDateIter, name: Symbol) -> Result<Value, Error> {
    let name = name.name()?;
    let copy = iter.get();
    let item = guarded(ruby, || match name.as_ref() {
        "last" => Ok(copy.last()),
        "max" => Ok(copy.max()),
        "min" => Ok(copy.min()),
        other => Err(unknown("DateIter", other)),
    })?;
    Ok(frozen_option(ruby, item.map(NDate)))
}

/// `size_hint` (`src/iter/date_iter.rs:84-88`).
fn date_iter_size_hint(ruby: &Ruby, iter: &NDateIter) -> Result<(usize, Option<usize>), Error> {
    let copy = iter.get();
    guarded(ruby, || Ok(copy.size_hint()))
}

/// `is_sorted` (`src/iter/date_iter.rs:150-153`), on a copy.
fn date_iter_is_sorted(ruby: &Ruby, iter: &NDateIter) -> Result<bool, Error> {
    let copy = iter.get();
    guarded(ruby, || Ok(copy.is_sorted()))
}

/// `MonthIter::new(start)` (`src/iter/month_iter.rs:21-34`), for
/// `initialize`.
fn month_iter_initialize(ruby: &Ruby, iter: Obj<NMonthIter>, number: u8) -> Result<(), Error> {
    let start = month(number).map_err(|failure| failure.into_error(ruby))?;
    replace(iter, MonthIter::new(start))
}

/// `WeekdayIter::new(start)` (`src/iter/weekday_iter.rs:20-33`), for
/// `initialize`.
fn weekday_iter_initialize(ruby: &Ruby, iter: Obj<NWeekdayIter>, days: u8) -> Result<(), Error> {
    let start = weekday(days).map_err(|failure| failure.into_error(ruby))?;
    replace(iter, WeekdayIter::new(start))
}

/// The private subclass of `Rev` that holds `reversed`: `Rev::Months` for
/// a `Rev<MonthIter>`, `Rev::Weekdays` for a `Rev<WeekdayIter>`, so each
/// answers `respond_to?` as Rust's two types do (plan 010, decision 10).
fn rev_class(ruby: &Ruby, reversed: &Reversed) -> Result<RClass, Error> {
    let name = match reversed {
        Reversed::Month(_) => "Months",
        Reversed::Weekday(_) => "Weekdays",
    };
    NRev::class(ruby).const_get(name)
}

/// `reversed`, wrapped as its private subclass of `Rev`.
fn wrap_rev(ruby: &Ruby, reversed: Reversed) -> Result<Obj<NRev>, Error> {
    let class = rev_class(ruby, &reversed)?;
    Ok(ruby.obj_wrap_as(NRev(Mutex::new(reversed)), class))
}

/// `MonthIter::rev` (`src/iter/month_iter.rs:36-48`), on a copy, as
/// `rev` takes the iterator by value.
fn month_iter_rev(ruby: &Ruby, iter: &NMonthIter) -> Result<Obj<NRev>, Error> {
    wrap_rev(ruby, Reversed::Month(iter.get().rev()))
}

/// `WeekdayIter::rev` (`src/iter/weekday_iter.rs:35-47`), on a copy.
fn weekday_iter_rev(ruby: &Ruby, iter: &NWeekdayIter) -> Result<Obj<NRev>, Error> {
    wrap_rev(ruby, Reversed::Weekday(iter.get().rev()))
}

/// `next` on one of the infinite iterators.
fn cycle_next<H: Held>(ruby: &Ruby, iter: Obj<H>) -> Result<u8, Error>
where
    H::Inner: Cycle,
{
    iter.check_frozen()?;
    let mut copy = iter.get();
    let number = guarded(ruby, || Ok(copy.next_number()))?;
    iter.set(copy);
    Ok(number)
}

/// `nth` on one of the infinite iterators.
fn cycle_nth<H: Held>(ruby: &Ruby, iter: Obj<H>, n: usize) -> Result<u8, Error>
where
    H::Inner: Cycle,
{
    iter.check_frozen()?;
    let mut copy = iter.get();
    let number = guarded(ruby, || Ok(copy.nth_number(n)))?;
    iter.set(copy);
    Ok(number)
}

/// `size_hint` on one of the infinite iterators.
fn cycle_size_hint<H: Held>(ruby: &Ruby, iter: &H) -> Result<(usize, Option<usize>), Error>
where
    H::Inner: Cycle,
{
    let copy = iter.get();
    guarded(ruby, || Ok(copy.hint()))
}

/// `count` or `last` on one of the infinite iterators: time panics for
/// both, so the gem refuses with `RangeError` and time's message, never
/// calling it (plan 010, decision 8).
fn cycle_infinite<H: Held>(ruby: &Ruby, iter: &H, name: Symbol) -> Result<(), Error>
where
    H::Inner: Cycle,
{
    let name = name.name()?;
    let copy = iter.get();
    guarded(ruby, || {
        let method = match name.as_ref() {
            "count" => Infinite::Count,
            "last" => Infinite::Last,
            other => return Err(unknown(copy.name(), other)),
        };
        Err(Failure::Range(infinite_message(copy.name(), method)))
    })
}

/// `all` or `any` on one of the infinite iterators, through time's own
/// overrides (`src/iter/month_iter.rs:81-95`), yielding each item's number
/// to the block. `yield_value` runs the block under `rb_protect`, so an
/// exception or a `break` comes back as an `Err`, which stops time's loop
/// and resumes in Ruby once this returns (plan 010, decision 9). time's
/// overrides leave the iterator unchanged, so nothing is written back.
fn cycle_test<H: Held>(ruby: &Ruby, iter: &H, name: Symbol) -> Result<bool, Error>
where
    H::Inner: Cycle,
{
    let name = name.name()?;
    let all = match name.as_ref() {
        "all" => true,
        "any" => false,
        other => return Err(unknown("Iterator", other).into_error(ruby)),
    };
    let mut copy = iter.get();
    let mut stopped: Option<Error> = None;
    let mut test = |number: u8| match ruby.yield_value::<u8, Value>(number) {
        Ok(answer) => answer.to_bool(),
        Err(error) => {
            stopped = Some(error);
            !all
        }
    };
    let answer = guarded(ruby, || {
        Ok(if all {
            copy.all_numbers(&mut test)
        } else {
            copy.any_numbers(&mut test)
        })
    })?;
    stopped.map_or(Ok(answer), Err)
}

/// `max`, `min`, or `is_sorted` on a month iterator (`src/iter/month_iter.rs:97-111`,
/// `:160-173`), on a copy; `nil` for a weekday iterator, which has none.
fn cycle_ordered<H: Held>(ruby: &Ruby, iter: &H, name: Symbol) -> Result<Option<Value>, Error>
where
    H::Inner: Cycle,
{
    let name = name.name()?;
    let copy = iter.get();
    let ordered = guarded(ruby, || Ok(copy.ordered()))?;
    let Some(ordered) = ordered else {
        return Ok(None);
    };
    Ok(Some(match name.as_ref() {
        "max" => ruby.into_value(ordered.max),
        "min" => ruby.into_value(ordered.min),
        "is_sorted" => ruby.into_value(ordered.is_sorted),
        other => return Err(unknown(copy.name(), other).into_error(ruby)),
    }))
}

/// time's derived `PartialEq`.
fn eq<H: Held>(ruby: &Ruby, left: &H, right: &H) -> Result<bool, Error> {
    let (left, right) = (left.get(), right.get());
    guarded(ruby, || Ok(left == right))
}

/// time's derived `Debug`.
fn debug<H: Held>(ruby: &Ruby, iter: &H) -> Result<String, Error> {
    let copy = iter.get();
    guarded(ruby, || Ok(format!("{copy:?}")))
}

/// `Clone`, for `dup` and `clone`: `initialize_copy` copies the iterator,
/// refusing to overwrite a frozen one as Ruby's own `initialize_copy`
/// refuses (`rb_obj_init_copy` in Ruby's `object.c`).
fn initialize_copy<H: Held>(copy: Obj<H>, original: &H) -> Result<(), Error> {
    replace(copy, original.get())
}

/// `initialize_copy` for a `Rev`, which also refuses an original of the
/// other kind, worded as Ruby's own `initialize_copy` refuses an object of
/// another class (`rb_obj_init_copy` in Ruby's `object.c`), so a
/// `Rev::Weekdays` never holds a `Rev<MonthIter>`.
fn rev_initialize_copy(ruby: &Ruby, copy: Obj<NRev>, original: Obj<NRev>) -> Result<(), Error> {
    if !copy.class().equal(original.class())? {
        return Err(Error::new(
            ruby.exception_type_error(),
            "initialize_copy should take same class object",
        ));
    }
    initialize_copy(copy, &original)
}

/// A method name the Ruby side never passes.
fn unknown(type_name: &str, name: &str) -> Failure {
    Failure::Argument(format!("unknown {type_name} method: {name}"))
}

/// The four iterator classes under `Ferro::Time::Iter`, each with an
/// allocator for `dup` and `new`, and `initialize_copy`.
fn define_classes(ruby: &Ruby, time: RModule) -> Result<(), Error> {
    let iter = time.define_module("Iter")?;
    let date: RClass = iter.define_class("DateIter", ruby.class_object())?;
    date.define_alloc_func::<NDateIter>();
    date.define_method("initialize_copy", method!(initialize_copy::<NDateIter>, 1))?;
    let month: RClass = iter.define_class("MonthIter", ruby.class_object())?;
    month.define_alloc_func::<NMonthIter>();
    month.define_method("initialize_copy", method!(initialize_copy::<NMonthIter>, 1))?;
    let weekday: RClass = iter.define_class("WeekdayIter", ruby.class_object())?;
    weekday.define_alloc_func::<NWeekdayIter>();
    weekday.define_method(
        "initialize_copy",
        method!(initialize_copy::<NWeekdayIter>, 1),
    )?;
    let rev: RClass = iter.define_class("Rev", ruby.class_object())?;
    rev.define_alloc_func::<NRev>();
    rev.define_method("initialize_copy", method!(rev_initialize_copy, 1))?;
    // Each subclass inherits the allocator, which Ruby's `dup` calls with
    // the original's class; `initialize_copy` then copies the original's
    // `Rev`, of the same kind.
    rev.define_class("Months", rev)?;
    rev.define_class("Weekdays", rev)?;
    Ok(())
}

/// Defines the methods one infinite iterator's Ruby class calls on
/// `Native`.
macro_rules! cyclic {
    ($native:ident, $prefix:literal, $wrapper:ty) => {
        $native.define_singleton_method(
            concat!($prefix, "_next"),
            function!(cycle_next::<$wrapper>, 1),
        )?;
        $native.define_singleton_method(
            concat!($prefix, "_nth"),
            function!(cycle_nth::<$wrapper>, 2),
        )?;
        $native.define_singleton_method(
            concat!($prefix, "_size_hint"),
            function!(cycle_size_hint::<$wrapper>, 1),
        )?;
        $native.define_singleton_method(
            concat!($prefix, "_infinite"),
            function!(cycle_infinite::<$wrapper>, 2),
        )?;
        $native.define_singleton_method(
            concat!($prefix, "_test"),
            function!(cycle_test::<$wrapper>, 2),
        )?;
        $native.define_singleton_method(
            concat!($prefix, "_ordered"),
            function!(cycle_ordered::<$wrapper>, 2),
        )?;
        $native.define_singleton_method(concat!($prefix, "_eq"), function!(eq::<$wrapper>, 2))?;
        $native
            .define_singleton_method(concat!($prefix, "_debug"), function!(debug::<$wrapper>, 1))?;
    };
}

/// Defines the iterator classes and their native methods.
pub fn define(ruby: &Ruby, time: RModule, native: RModule) -> Result<(), Error> {
    define_classes(ruby, time)?;
    native.define_singleton_method("date_iter_initialize", function!(date_iter_initialize, 3))?;
    native.define_singleton_method("date_iter_step", function!(date_iter_step, 2))?;
    native.define_singleton_method("date_iter_nth", function!(date_iter_nth, 3))?;
    native.define_singleton_method("date_iter_count", function!(date_iter_count, 2))?;
    native.define_singleton_method("date_iter_end", function!(date_iter_end, 2))?;
    native.define_singleton_method("date_iter_size_hint", function!(date_iter_size_hint, 1))?;
    native.define_singleton_method("date_iter_is_sorted", function!(date_iter_is_sorted, 1))?;
    native.define_singleton_method("date_iter_eq", function!(eq::<NDateIter>, 2))?;
    native.define_singleton_method("date_iter_debug", function!(debug::<NDateIter>, 1))?;
    native.define_singleton_method("month_iter_initialize", function!(month_iter_initialize, 2))?;
    native.define_singleton_method("month_iter_rev", function!(month_iter_rev, 1))?;
    native.define_singleton_method(
        "weekday_iter_initialize",
        function!(weekday_iter_initialize, 2),
    )?;
    native.define_singleton_method("weekday_iter_rev", function!(weekday_iter_rev, 1))?;
    cyclic!(native, "month_iter", NMonthIter);
    cyclic!(native, "weekday_iter", NWeekdayIter);
    cyclic!(native, "rev", NRev);
    Ok(())
}

#[cfg(test)]
mod tests {
    use time::iter::{MonthIter, WeekdayIter};
    use time::{Month, Weekday};

    use super::{infinite_message, Cycle, Infinite, Reversed};
    use crate::{capture, Panic};

    #[test]
    fn the_refusals_carry_times_panic_messages() {
        fn month() -> MonthIter {
            MonthIter::new(Month::March)
        }
        fn weekday() -> WeekdayIter {
            WeekdayIter::new(Weekday::Friday)
        }
        // Each name is the one the gem's refusal uses (`Cycle::name`),
        // compared with the real panic, and with the name time's panic
        // spells out.
        /// The name the gem uses, the name time spells, the method, and
        /// the call that panics.
        type Case = (&'static str, &'static str, Infinite, fn());
        let cases: [Case; 8] = [
            (month().name(), "MonthIter", Infinite::Count, || {
                let _ = month().count();
            }),
            (month().name(), "MonthIter", Infinite::Last, || {
                let _ = month().last();
            }),
            (
                month().rev().name(),
                "Rev<MonthIter>",
                Infinite::Count,
                || {
                    let _ = month().rev().count();
                },
            ),
            (
                Reversed::Month(month().rev()).name(),
                "Rev<MonthIter>",
                Infinite::Last,
                || {
                    let _ = month().rev().last();
                },
            ),
            (weekday().name(), "WeekdayIter", Infinite::Count, || {
                let _ = weekday().count();
            }),
            (weekday().name(), "WeekdayIter", Infinite::Last, || {
                let _ = weekday().last();
            }),
            (
                weekday().rev().name(),
                "Rev<WeekdayIter>",
                Infinite::Count,
                || {
                    let _ = weekday().rev().count();
                },
            ),
            (
                Reversed::Weekday(weekday().rev()).name(),
                "Rev<WeekdayIter>",
                Infinite::Last,
                || {
                    let _ = weekday().rev().last();
                },
            ),
        ];
        for (name, spelled, method, call) in cases {
            assert_eq!(name, spelled);
            assert_eq!(
                capture(call),
                Err(Panic(infinite_message(name, method))),
                "{name} {method:?}"
            );
        }
    }
}
