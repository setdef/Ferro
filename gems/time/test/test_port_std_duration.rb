# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: MIT OR Apache-2.0
# SPDX-SnippetCopyrightText: Jacob Pratt et al.
# SPDX-SnippetComment: the std Duration test cases of time 0.3.55
#   tests/integration/duration.rs, date.rs, time.rs, plain_date_time.rs,
#   utc_date_time.rs, offset_date_time.rs, and timestamp.rs
#++

# time's own tests of its operations with std's +Duration+, ported, each
# under its file's name and its Rust test's. A std +Duration+ is a Numeric
# number of seconds in and a Rational out (ADR 001, 2026-11-05), so
# <tt>1.std_seconds()</tt> is +1+ and <tt>500.std_milliseconds()</tt> is
# <tt>Rational(1, 2)</tt>. Rust's compound assignments are Ruby's +=+ and
# an operator, as elsewhere in these ports; Rust's +-=+ on a std
# +Duration+ keeps the std type and panics where it cannot
# (+std_sub_assign_overflow+), which Ruby's <tt>-=</tt>, an operator and
# an assignment, cannot reproduce, so that one is left out.
class TestPortStdDuration < Minitest::Test
  include TimeSuite

  MS = Rational(1, 1_000)
  MINUTE = 60
  HOUR = 3_600
  DAY = 86_400
  U64_MAX = (2 ** 64) - 1

  # duration.rs

  def test_duration_unsigned_abs
    [[Duration.seconds(1), 1], [Duration.seconds(0), 0], [Duration.seconds(-1), 1]].each do |input, expected|
      assert_equal expected, input.unsigned_abs
      assert_instance_of Rational, input.unsigned_abs
    end
  end

  def test_duration_try_from_std_duration_success
    assert_equal Duration.seconds(0), Duration.try_from(0)
    assert_equal Duration.seconds(1), Duration.try_from(1)
  end

  def test_duration_try_from_std_duration_error
    error = assert_raises(T::Error::ConversionRange) { Duration.try_from(U64_MAX) }
    assert_equal "Source value is out of range for the target type", error.message
  end

  def test_duration_try_to_std_duration_success
    assert_equal 0, Duration.seconds(0).to_r
    assert_equal 1, Duration.seconds(1).to_r
  end

  def test_duration_try_to_std_duration_error
    [Duration.seconds(-1), Duration.milliseconds(-500)].each do |duration|
      assert_raises(T::Error::ConversionRange) { duration.to_r }
    end
  end

  def test_duration_add_std
    [
      [Duration.seconds(1), 1, Duration.seconds(2)],
      [Duration.milliseconds(500), 500 * MS, Duration.seconds(1)],
      [Duration.seconds(-1), 1, Duration.seconds(0)],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs + rhs
    end
  end

  def test_duration_std_add
    [
      [1, Duration.seconds(1), Duration.seconds(2)],
      [500 * MS, Duration.milliseconds(500), Duration.seconds(1)],
      [1, Duration.seconds(-1), Duration.seconds(0)],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs + rhs
    end
  end

  def test_duration_add_assign_std
    duration = Duration.milliseconds(500)
    duration += 500 * MS
    assert_equal Duration.seconds(1), duration
  end

  def test_duration_std_add_assign
    duration = 1
    duration += Duration.seconds(-1)
    assert_equal Duration.seconds(0), duration
  end

  def test_duration_sub_std
    [
      [Duration.seconds(1), 1, Duration.seconds(0)],
      [Duration.milliseconds(1_500), 500 * MS, Duration.seconds(1)],
      [Duration.seconds(-1), 1, -Duration.seconds(2)],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs - rhs
    end
  end

  def test_duration_std_sub
    [
      [1, Duration.seconds(1), Duration.seconds(0)],
      [1_500 * MS, Duration.milliseconds(500), Duration.seconds(1)],
      [1, Duration.seconds(-1), Duration.seconds(2)],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs - rhs
    end
  end

  def test_duration_sub_assign_std
    duration = Duration.seconds(-1)
    duration -= 1
    assert_equal(-Duration.seconds(2), duration)
  end

  def test_duration_std_sub_assign
    duration = 1_500 * MS
    duration -= Duration.milliseconds(500)
    assert_equal Duration.seconds(1), duration
  end

  # Rust's Div<std::time::Duration> for SignedDuration has no operator
  # here, since / by a number divides by a count; its value is the ratio
  # with the converted span, as both impls compute it with as_seconds_f64.
  def test_duration_div_std
    assert_in_delta 2.0, Duration.seconds(1) / Duration.try_from(0.5), 0
    assert_in_delta 8.0, Duration.seconds(2) / Duration.try_from(0.25), 0
  end

  def test_duration_std_div
    assert_in_delta 2.0, 1 / Duration.seconds_f64(0.5), 0
    assert_in_delta 8.0, 2 / Duration.seconds_f64(0.25), 0
  end

  def test_duration_partial_eq_std
    [
      [Duration.seconds(1), 1, true],
      [Duration.seconds(0), 0, true],
      [Duration.seconds(1), 2, false],
      [Duration.seconds(-1), 1, false],
      [Duration.seconds(40), MINUTE, false],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs == rhs, "#{lhs.debug} == #{rhs}"
      assert_equal !expected, lhs != rhs
    end
  end

  def test_duration_std_partial_eq
    [
      [1, Duration.seconds(1), true],
      [0, Duration.seconds(0), true],
      [2, Duration.seconds(1), false],
      [1, Duration.seconds(-1), false],
      [MINUTE, Duration.seconds(40), false],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs == rhs, "#{lhs} == #{rhs.debug}"
      assert_equal !expected, lhs != rhs
    end
  end

  def test_duration_partial_ord_std
    [
      [Duration.seconds(0), 0, 0],
      [Duration.seconds(1), 0, 1],
      [Duration.seconds(-1), 1, -1],
      [Duration.seconds(0), 1, -1],
      [Duration.seconds(-1), 0, -1],
      [Duration.minutes(1), 1, 1],
      [Duration.seconds(0), U64_MAX, -1],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs <=> rhs, "#{lhs.debug} <=> #{rhs}"
    end
  end

  def test_duration_std_partial_ord
    [
      [0, Duration.seconds(0), 0],
      [1, Duration.seconds(0), 1],
      [1, Duration.seconds(-1), 1],
      [0, Duration.seconds(-1), 1],
      [0, Duration.seconds(1), -1],
      [MINUTE, Duration.seconds(1), 1],
].each do |lhs, rhs, expected|
      assert_equal expected, lhs <=> rhs, "#{lhs} <=> #{rhs.debug}"
    end
  end

  # date.rs

  def test_date_add_std
    assert_equal date(2019, 1, 6), date(2019, 1, 1) + (5 * DAY)
    assert_equal date(2020, 1, 1), date(2019, 12, 31) + DAY
  end

  def test_date_add_assign_std
    value = date(2019, 12, 31)
    value += DAY
    assert_equal date(2020, 1, 1), value
  end

  def test_date_sub_std
    assert_equal date(2019, 1, 1), date(2019, 1, 6) - (5 * DAY)
    assert_equal date(2019, 12, 31), date(2020, 1, 1) - DAY
  end

  def test_date_sub_assign_std
    value = date(2020, 1, 1)
    value -= DAY
    assert_equal date(2019, 12, 31), value
  end

  # time.rs

  def test_time_add_std_duration
    [
      [MS, clock(0, 0, 0, 1_000_000)],
      [1, clock(0, 0, 1)],
      [MINUTE, clock(0, 1)],
      [HOUR, clock(1, 0)],
      [DAY, clock(0, 0)],
].each do |duration, expected|
      assert_equal expected, clock(0, 0) + duration
    end
  end

  def test_time_add_assign_std_duration
    value = clock(0, 0)
    value += HOUR
    assert_equal clock(1, 0), value
  end

  def test_time_sub_std_duration
    assert_equal clock(11, 0), clock(12, 0) - HOUR
    [
      [MS, clock(23, 59, 59, 999_000_000)],
      [1, clock(23, 59, 59)],
      [MINUTE, clock(23, 59)],
      [HOUR, clock(23, 0)],
      [DAY, clock(0, 0)],
].each do |duration, expected|
      assert_equal expected, clock(0, 0) - duration
    end
  end

  def test_time_sub_assign_std_duration
    value = clock(0, 0)
    value -= MINUTE
    assert_equal clock(23, 59), value
  end

  # plain_date_time.rs, utc_date_time.rs, offset_date_time.rs: the same
  # cases on each type.

  ADD_CASES = [
    [[2019, 1, 1], 5 * DAY, [2019, 1, 6]],
    [[2019, 12, 31], DAY, [2020, 1, 1]],
    [[2019, 12, 31, 23, 59, 59], 2, [2020, 1, 1, 0, 0, 1]],
  ].freeze

  SUB_CASES = [
    [[2019, 1, 6], 5 * DAY, [2019, 1, 1]],
    [[2020, 1, 1], DAY, [2019, 12, 31]],
    [[2020, 1, 1, 0, 0, 1], 2, [2019, 12, 31, 23, 59, 59]],
  ].freeze

  private def each_kind(cases)
    kinds = [
      -> (parts) { datetime(*parts) },
      -> (parts) { utc(*parts) },
      -> (parts) { datetime(*parts).assume_utc },
    ]
    kinds.each do |make|
      cases.each { |from, duration, to| yield make.(from), duration, make.(to) }
    end
  end

  def test_date_time_add_std_duration
    each_kind(ADD_CASES) { |from, duration, to| assert_equal to, from + duration }
  end

  def test_date_time_add_assign_std_duration
    each_kind(ADD_CASES) do |from, duration, to|
      from += duration
      assert_equal to, from
    end
  end

  def test_date_time_sub_std_duration
    each_kind(SUB_CASES) { |from, duration, to| assert_equal to, from - duration }
  end

  def test_date_time_sub_assign_std_duration
    each_kind(SUB_CASES) do |from, duration, to|
      from -= duration
      assert_equal to, from
    end
  end

  # offset_date_time.rs and utc_date_time.rs: issue_621, a std Duration
  # too long for any date.
  def test_date_time_issue_621
    [T::OffsetDateTime::UNIX_EPOCH, T::UtcDateTime::UNIX_EPOCH].each do |epoch|
      error = assert_raises(RangeError) { epoch + 18_157_382_926_370_278_155 }
      assert_equal "overflow adding duration to date", error.message
    end
  end

  # timestamp.rs

  private def ts(seconds)
    T::Timestamp.new(seconds, 0)
  end

  def test_timestamp_add_std_duration
    assert_equal ts(432_000), ts(0) + (5 * DAY)
    assert_equal ts(86_400), ts(0) + DAY
    assert_equal ts(1_546_484_645), ts(1_546_398_245) + DAY
  end

  def test_timestamp_add_std_panics
    [
      [T::Timestamp::MAX, Rational(1, 1_000_000_000)],
      [T::Timestamp::MIN, U64_MAX],
      [T::Timestamp::UNIX_EPOCH, U64_MAX],
].each do |value, duration|
      error = assert_raises(RangeError) { value + duration }
      assert_equal "resulting value is out of range: Positive", error.message
    end
  end

  def test_timestamp_sub_std_duration
    assert_equal ts(0), ts(432_000) - (5 * DAY)
    assert_equal ts(0), ts(86_400) - DAY
    assert_equal ts(1_546_398_245), ts(1_546_484_645) - DAY
  end

  def test_timestamp_sub_std_panics
    [
      [T::Timestamp::MIN, Rational(1, 1_000_000_000)],
      [T::Timestamp::MAX, U64_MAX],
      [T::Timestamp::UNIX_EPOCH, U64_MAX],
].each do |value, duration|
      error = assert_raises(RangeError) { value - duration }
      assert_equal "resulting value is out of range: Negative", error.message
    end
  end

  def test_timestamp_add_assign_std_duration
    value = ts(1_546_398_245)
    value += DAY
    assert_equal ts(1_546_484_645), value
  end

  def test_timestamp_sub_assign_std_duration
    value = ts(1_546_484_645)
    value -= DAY
    assert_equal ts(1_546_398_245), value
  end
end

#--
# SPDX-SnippetEnd
#++
