# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

using Ferro::Time::Ext::NumericalDuration
using Ferro::Time::Ext::NumericalStdDuration
using Ferro::Time::Ext::SystemTimeExt

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: MIT OR Apache-2.0
# SPDX-SnippetCopyrightText: Jacob Pratt et al.
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/ext.rs
#   and the doc examples of src/ext/systemtime.rs
#++

# time's own tests in <tt>tests/integration/ext.rs</tt>, ported, with the
# refinements in scope as Rust's tests bring the traits in with +use+
# (ADR 001, 2026-11-05). A std +Duration+ is a Rational number of seconds.
class TestPortExt < Minitest::Test
  include TimeSuite

  NAMES = %i[nanoseconds microseconds milliseconds seconds minutes hours days weeks].freeze

  def test_numerical_duration_unsigned
    NAMES.each { |name| assert_equal Duration.public_send(name, 5), 5.public_send(name), name.to_s }
  end

  def test_numerical_duration_signed
    NAMES.each { |name| assert_equal Duration.public_send(name, -5), -5.public_send(name), name.to_s }
    assert_equal Duration.seconds(-5), (-5).seconds
  end

  def test_numerical_duration_float
    assert_equal Duration.nanoseconds(1), 1.9.nanoseconds, "truncate_not_round"
    NAMES.each { |name| assert_equal Duration.public_send(name, 1), 1.0.public_send(name), name.to_s }
    [
      [1.5.nanoseconds, Duration.nanoseconds(1)],
      [1.5.microseconds, Duration.nanoseconds(1_500)],
      [1.5.milliseconds, Duration.microseconds(1_500)],
      [1.5.seconds, Duration.milliseconds(1_500)],
      [1.5.minutes, Duration.seconds(90)],
      [1.5.hours, Duration.minutes(90)],
      [1.5.days, Duration.hours(36)],
      [1.5.weeks, Duration.hours(252)],
].each do |actual, expected|
      assert_equal expected, actual
    end
  end

  def test_numerical_duration_arithmetic
    assert_equal 2_500.milliseconds, 2.seconds + 500.milliseconds
    assert_equal 1_500.milliseconds, 2.seconds - 500.milliseconds
  end

  def test_numerical_std_duration_unsigned
    [
      [5.std_nanoseconds, Rational(5, 1_000_000_000)],
      [5.std_microseconds, Rational(5, 1_000_000)],
      [5.std_milliseconds, Rational(5, 1_000)],
      [5.std_seconds, 5],
      [5.std_minutes, 5 * 60],
      [5.std_hours, 5 * 3_600],
      [5.std_days, 5 * 86_400],
      [5.std_weeks, 5 * 604_800],
].each do |actual, expected|
      assert_instance_of Rational, actual
      assert_equal expected, actual
    end
  end

  def test_numerical_std_duration_float
    assert_equal Rational(1, 1_000_000_000), 1.9.std_nanoseconds, "truncate_not_round"
    [
      [1.0.std_nanoseconds, Rational(1, 1_000_000_000)],
      [1.0.std_microseconds, Rational(1, 1_000_000)],
      [1.0.std_milliseconds, Rational(1, 1_000)],
      [1.0.std_seconds, 1],
      [1.0.std_minutes, 60],
      [1.0.std_hours, 3_600],
      [1.0.std_days, 86_400],
      [1.0.std_weeks, 604_800],
      [1.5.std_nanoseconds, Rational(1, 1_000_000_000)],
      [1.5.std_microseconds, Rational(1_500, 1_000_000_000)],
      [1.5.std_milliseconds, Rational(1_500, 1_000_000)],
      [1.5.std_seconds, Rational(3, 2)],
      [1.5.std_minutes, 90],
      [1.5.std_hours, 90 * 60],
      [1.5.std_days, 36 * 3_600],
      [1.5.std_weeks, 252 * 3_600],
].each do |actual, expected|
      assert_equal expected, actual
    end
  end

  def test_numerical_std_duration_arithmetic
    assert_equal 2_500.std_milliseconds, 2.std_seconds + 500.std_milliseconds
    assert_equal 1_500.std_milliseconds, 2.std_seconds - 500.std_milliseconds
  end

  # src/ext/systemtime.rs:46-52, signed_duration_since's example.
  def test_system_time_ext_signed_duration_since
    epoch = ::Time.at(0)
    other = epoch.checked_add_signed(1.seconds)
    assert_equal 1.seconds, other.signed_duration_since(epoch)
    assert_equal(-1.seconds, epoch.signed_duration_since(other))
  end
end

#--
# SPDX-SnippetEnd
#++

# What the refinements do beyond time's own tests: their refusals, in the
# words of the panic or conversion Rust would raise, and SystemTimeExt's
# other two methods.
class TestExt < Minitest::Test
  include TimeSuite

  def test_an_integer_is_an_i64_or_a_u64
    assert_raises(RangeError) { (2 ** 63).seconds }
    assert_raises(RangeError) { -1.std_seconds }
    assert_raises(RangeError) { (2 ** 64).std_seconds }
    assert_equal Rational((2 ** 64) - 1), ((2 ** 64) - 1).std_seconds
  end

  def test_an_overflow_raises_times_message
    constructing = "overflow constructing `time::SignedDuration`"
    error = assert_raises(RangeError) { (2 ** 62).weeks }
    assert_equal constructing, error.message
    error = assert_raises(RangeError) { (2 ** 62).std_minutes }
    assert_equal constructing, error.message
  end

  def test_a_negative_or_nan_float_std_duration_raises_times_assertion
    [-1.0, Float::NAN, -Float::INFINITY].each do |value|
      error = assert_raises(ArgumentError) { value.std_seconds }
      assert_equal "assertion failed: self >= 0.", error.message
    end
    assert_equal 0, -0.0.std_seconds
  end

  def test_a_float_duration_saturates_and_never_raises
    assert_equal Duration.nanoseconds((2 ** 63) - 1), Float::INFINITY.seconds
    assert_equal Duration.nanoseconds(-(2 ** 63)), (-Float::INFINITY).seconds
    assert_equal Duration::ZERO, Float::NAN.seconds
  end

  def test_system_time_ext_checks_its_range
    at = ::Time.at(1_000, 5, :nsec)
    later = at.checked_add_signed(Duration.new(1, 1))
    assert_equal ::Time.at(1_001, 6, :nsec), later
    assert_predicate later, :utc?
    assert_equal ::Time.at(999, 4, :nsec), at.checked_sub_signed(Duration.new(1, 1))
    assert_equal ::Time.at(999, 4, :nsec), at.checked_add_signed(-Duration.new(1, 1))
    assert_nil at.checked_add_signed(Duration::MAX)
    assert_raises(TypeError) { at.checked_add_signed(1) }
    assert_equal Duration::MAX, ::Time.at(2 ** 62).signed_duration_since(::Time.at(-(2 ** 62)))
  end

  # A refinement reaches only the files that ask for it; this file asks,
  # so the methods are here, and test_ext_scope.rb, which does not, sees
  # Ruby's own classes unchanged.
  def test_the_methods_are_in_scope_here
    assert_equal Duration::SECOND, 1.seconds
  end
end
