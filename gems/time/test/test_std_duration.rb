# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# std's Duration as ADR 001's 2026-11-05 amendment translates it: any
# Numeric number of seconds in, a Rational number of seconds out, and
# every refusal in the words of the panic Rust would raise.
class TestStdDuration < Minitest::Test
  include TimeSuite

  NANO = Rational(1, 1_000_000_000)

  private def assert_refused(error_class, message, &)
    error = assert_raises(error_class, &)
    assert_equal message, error.message
  end

  # A Float crosses as core's Duration::try_from_secs_f64 reads it: its
  # exact value rounded to the nearest nanosecond, ties to even. A tie
  # needs a Float whose exact value is a half nanosecond, such as 1/1024
  # of a second (976,562.5 ns); 2.5e-9 lies just above 2.5 ns.
  def test_a_float_rounds_as_core_does
    assert_equal Duration.nanoseconds(1), Duration.try_from(1.5e-9)
    assert_equal Duration.nanoseconds(3), Duration.try_from(2.5e-9)
    assert_equal Duration.nanoseconds(976_562), Duration.try_from(1.0 / 1024)
    assert_equal Duration.nanoseconds(2_929_688), Duration.try_from(3.0 / 1024)
    assert_equal Duration.nanoseconds(0), Duration.try_from(4e-10)
    assert_equal Duration.milliseconds(1_500), Duration.try_from(1.5)
  end

  def test_any_other_numeric_is_exact
    assert_equal Duration.new(3, 1), Duration.try_from(3 + NANO)
    assert_equal Duration.nanoseconds(2), Duration.try_from(Rational(5, 2_000_000_000))
    assert_equal Duration.nanoseconds(2), Duration.try_from(Rational(3, 2_000_000_000))
    assert_equal Duration.nanoseconds(976_562), Duration.try_from(Rational(1, 1024))
    assert_equal Duration.seconds(2 ** 40), Duration.try_from(2 ** 40)
  end

  def test_a_number_no_std_duration_holds_is_refused_in_rusts_words
    assert_refused(ArgumentError, "cannot convert float seconds to Duration: value is negative") { Duration.try_from(-1.0) }
    assert_refused(ArgumentError, "cannot convert float seconds to Duration: value is either too big or NaN") { Duration.try_from(Float::NAN) }
    assert_refused(ArgumentError, "cannot convert float seconds to Duration: value is either too big or NaN") { Duration.try_from(Float::INFINITY) }
    assert_raises(RangeError) { Duration.try_from(-1) }
    assert_raises(RangeError) { Duration.try_from(-NANO) }
    assert_raises(RangeError) { Duration.try_from(2 ** 64) }
    assert_raises(TypeError) { Duration.try_from("1") }
    assert_raises(TypeError) { Duration::SECOND + :one }
  end

  # Arguments never hands the native layer a nanosecond count of a second
  # or more, but the native layer refuses one itself: Duration::new would
  # carry it into the seconds and panic on overflow at u64::MAX.
  def test_the_native_layer_refuses_a_second_of_nanoseconds
    native = T.const_get(:Native)
    assert_equal Duration.new(0, 999_999_999), native.duration_try_from_std([0, 999_999_999])
    assert_refused(ArgumentError, "1000000000 nanoseconds is not under a second") { native.duration_try_from_std([0, 1_000_000_000]) }
    assert_refused(ArgumentError, "1000000000 nanoseconds is not under a second") { native.duration_try_from_std([(2 ** 64) - 1, 1_000_000_000]) }
  end

  def test_what_comes_back_is_an_exact_rational
    value = Duration.new(1, 5).to_r
    assert_instance_of Rational, value
    assert_equal 1 + (5 * NANO), value
    assert_equal (2 ** 63) + (999_999_999 * NANO), Duration::MIN.unsigned_abs
    assert_equal Duration::MAX, Duration::MIN.abs
    assert_equal Duration::MAX.whole_nanoseconds * NANO, Duration::MAX.unsigned_abs
  end

  def test_the_duration_operators_refuse_as_time_panics
    huge = 2 ** 63
    converting = "overflow converting `std::time::Duration` to `time::SignedDuration`: ConversionRange"
    assert_refused(RangeError, converting) { Duration::ZERO + huge }
    assert_refused(RangeError, converting) { Duration::ZERO - huge }
    assert_refused(RangeError, converting) { huge - Duration::ZERO }
    assert_refused(RangeError, converting) { huge + Duration::ZERO }
    assert_refused(RangeError, "overflow when adding durations") { Duration::MAX + NANO }
    assert_refused(RangeError, "overflow when subtracting durations") { Duration::MIN - NANO }
    assert_refused(RangeError, "overflow when subtracting durations") { 0 - Duration::MIN }
  end

  # Comparisons answer rather than raise: a number no std Duration holds
  # is unequal and unordered.
  def test_a_number_no_std_duration_holds_compares_as_nothing
    refute_equal Duration.seconds(-1), -1
    refute_equal Duration::ZERO, Float::NAN
    refute_equal Duration::ZERO, 2 ** 64
    assert_nil Duration::ZERO <=> -1
    assert_nil Duration::ZERO <=> Float::NAN
    assert_equal(-1, Duration::MAX <=> U64_MAX)
    assert_raises(ArgumentError) { Duration::ZERO < -1 }
    refute_equal Duration::ZERO, "0"
  end

  U64_MAX = (2 ** 64) - 1

  def test_equality_with_a_number_leaves_hashing_alone
    assert_equal Duration::MINUTE, 60
    refute Duration::MINUTE.eql?(60)
    refute_equal Duration::MINUTE.hash, 60.hash
  end

  def test_the_date_time_operators_refuse_as_time_panics
    adding = "overflow adding duration to date"
    subtracting = "overflow subtracting duration from date"
    out = "resulting value is out of range"
    assert_refused(RangeError, adding) { T::Date::MAX + 86_400 }
    assert_refused(RangeError, subtracting) { T::Date::MIN - 86_400 }
    assert_refused(RangeError, out) { T::PlainDateTime::MAX + NANO }
    assert_refused(RangeError, out) { T::PlainDateTime::MIN - NANO }
    assert_refused(RangeError, adding) { T::PlainDateTime::MIN + (2 ** 63) }
    assert_refused(RangeError, out) { T::PlainDateTime::MAX.as_utc + NANO }
    assert_refused(RangeError, subtracting) { T::PlainDateTime::MAX.assume_utc - (2 ** 63) }
    assert_equal T::Time::MIDNIGHT, T::Time::MAX + NANO
  end

  def test_date_checked_std_answers_nil
    assert_nil T::Date::MAX.checked_add_std(86_400)
    assert_nil T::Date::MIN.checked_sub_std(86_400)
    assert_nil date(2020, 1, 1).checked_add_std((2 ** 31) * 86_400)
    assert_equal date(2020, 1, 1), date(2020, 1, 1).checked_add_std(86_399.999)
    assert_equal T::Date::MAX, T::Date::MAX.checked_add_std(23 * 3_600)
  end

  def test_a_date_adds_whole_days_only
    assert_equal date(2019, 1, 1), date(2019, 1, 1) + 1
    assert_equal date(2019, 1, 2), date(2019, 1, 1) + 86_400
  end
end
