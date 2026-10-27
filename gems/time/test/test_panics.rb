# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Where time panics, the gem raises RangeError with time's own message,
# checked before time runs, and ZeroDivisionError for an integer division
# by zero (plan 007, decision 7). The Rust tests compare each message with
# the panic time really raises; these check the Ruby side gets them.
class TestPanics < Minitest::Test
  include TimeSuite

  CONSTRUCTING = "overflow constructing `time::SignedDuration`"

  private def assert_refused(message, &)
    error = assert_raises(RangeError, &)
    assert_equal message, error.message
  end

  def test_duration_constructors
    assert_refused(CONSTRUCTING) { Duration.new((2 ** 63) - 1, 1_000_000_000) }
    assert_refused(CONSTRUCTING) { Duration.weeks(2 ** 62) }
    assert_refused(CONSTRUCTING) { Duration.days(-(2 ** 62)) }
    assert_refused(CONSTRUCTING) { Duration.hours(2 ** 62) }
    assert_refused(CONSTRUCTING) { Duration.minutes(2 ** 62) }
    assert_refused(CONSTRUCTING) { Duration.nanoseconds_i128((2 ** 127) - 1) }
    assert_refused("passed NaN to `time::SignedDuration::seconds_f64`") { Duration.seconds_f64(Float::NAN) }
    assert_refused(CONSTRUCTING) { Duration.seconds_f64(Float::INFINITY) }
    assert_refused("passed NaN to `time::SignedDuration::seconds_f32`") { Duration.seconds_f32(Float::NAN) }
    assert_refused(CONSTRUCTING) { Duration.seconds_f32(-1e30) }
  end

  def test_duration_operators
    assert_refused("overflow when adding durations") { Duration::MAX + Duration::NANOSECOND }
    assert_refused("overflow when subtracting durations") { Duration::MIN - Duration::NANOSECOND }
    assert_refused("overflow when negating duration") { -Duration::MIN }
    assert_refused(CONSTRUCTING) { Duration::MAX * 2 }
    assert_refused(CONSTRUCTING) { Duration::MIN / -1 }
    assert_refused(CONSTRUCTING) { Duration::MAX * 2.0 }
    assert_refused(CONSTRUCTING) { Duration::SECOND / 0.0 }
    assert_refused("passed NaN to `time::SignedDuration::seconds_f64`") { Duration::SECOND * Float::NAN }
    error = assert_raises(ZeroDivisionError) { Duration::SECOND / 0 }
    assert_equal "divided by 0", error.message
  end

  # Rust picks Mul<i32> for an integer literal; an Integer outside it is
  # refused by magnus before time runs (plan 007, decision 8).
  def test_an_integer_scalar_is_an_i32
    assert_equal Duration.seconds((2 ** 31) - 1), Duration::SECOND * ((2 ** 31) - 1)
    assert_raises(RangeError) { Duration::SECOND * (2 ** 31) }
    assert_raises(TypeError) { Duration::SECOND * "2" }
  end

  def test_date_arithmetic
    assert_refused("overflow adding duration to date") { T::Date::MAX + Duration::DAY }
    assert_refused("overflow subtracting duration from date") { T::Date::MIN - Duration::DAY }
    next_message = "overflow calculating the next occurrence of a weekday"
    previous_message = "overflow calculating the previous occurrence of a weekday"
    assert_refused(next_message) { T::Date::MAX.next_occurrence(Weekday::Monday) }
    assert_refused(previous_message) { T::Date::MIN.prev_occurrence(Weekday::Monday) }
    assert_refused(next_message) { date(2023, 6, 25).nth_next_occurrence(Weekday::Monday, 0) }
    assert_refused(previous_message) { date(2023, 6, 27).nth_prev_occurrence(Weekday::Monday, 0) }
    near = T::Date::MAX - Duration.days(10)
    assert_refused(next_message) { near.nth_next_occurrence(Weekday::Saturday, 3) }
  end

  def test_date_time_arithmetic_and_offsets
    out_of_range = "resulting value is out of range"
    assert_refused(out_of_range) { T::PlainDateTime::MAX + Duration::DAY }
    assert_refused(out_of_range) { T::PlainDateTime::MIN - Duration::DAY }
    assert_refused(out_of_range) { T::UtcDateTime::MAX + Duration::DAY }
    assert_refused(out_of_range) { T::PlainDateTime::MAX.assume_utc + Duration::DAY }
    local = "local datetime out of valid range"
    assert_refused(local) { T::PlainDateTime::MAX.assume_utc.to_offset(offset(1)) }
    assert_refused(local) { T::UtcDateTime::MAX.to_offset(offset(1)) }
    west = T::PlainDateTime::MAX.assume_offset(offset(-1))
    assert_refused(local) { west.to_utc }
    assert_refused(local) { T::UtcDateTime.from(west) }
  end

  def test_what_does_not_panic_answers
    assert_nil T::Date::MAX.checked_add(Duration::DAY)
    assert_equal T::Date::MAX, T::Date::MAX.saturating_add(Duration::DAY)
    assert_nil Duration::MAX.checked_add(Duration::NANOSECOND)
    assert_nil T::PlainDateTime::MAX.assume_utc.checked_to_offset(offset(1))
    assert_equal T::Time.from_hms(0, 59, 0), T::Time.from_hms(23, 59, 0) + Duration::HOUR
  end
end
