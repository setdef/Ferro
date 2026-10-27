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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/time.rs
#++

# time's own tests in <tt>tests/integration/time.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortTime < Minitest::Test
  include TimeSuite

  # Asserts +actual+ is +expected+, which may be +nil+, as Rust's
  # +assert_eq!+ compares an +Option+.
  private def assert_case(expected, actual, message = nil)
    return assert_nil(actual, message) if expected.nil?

    assert_equal expected, actual, message
  end

  # The block's value, or +nil+ when it raises time's error, as Rust's
  # +Result::ok+ turns an +Err+ into +None+.
  private def ok
    yield
  rescue T::Error
    nil
  end

  # Names a deprecated method quietly, since the tests run under -w.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

  # <tt>time.rs:13</tt>, +from_hms+.
  def test_from_hms
    [
      [1, 2, 3, clock(1, 2, 3, 0)],
      [24, 0, 0, nil],
      [0, 60, 0, nil],
      [0, 0, 60, nil],
    ].each do |hour, minute, second, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { T::Time.from_hms(hour, minute, second) }
      else
        assert_case expected, T::Time.from_hms(hour, minute, second)
      end
    end
  end

  # <tt>time.rs:28</tt>, +from_hms_milli+.
  def test_from_hms_milli
    [
      [1, 2, 3, 4, clock(1, 2, 3, 4_000_000)],
      [24, 0, 0, 0, nil],
      [0, 60, 0, 0, nil],
      [0, 0, 60, 0, nil],
      [0, 0, 0, 1_000, nil],
    ].each do |hour, minute, second, milli, expected|
      assert_case expected, ok { T::Time.from_hms_milli(hour, minute, second, milli) }
    end
  end

  # <tt>time.rs:47</tt>, +from_hms_micro+.
  def test_from_hms_micro
    [
      [1, 2, 3, 4, clock(1, 2, 3, 4_000)],
      [24, 0, 0, 0, nil],
      [0, 60, 0, 0, nil],
      [0, 0, 60, 0, nil],
      [0, 0, 0, 1_000_000, nil],
    ].each do |hour, minute, second, micro, expected|
      assert_case expected, ok { T::Time.from_hms_micro(hour, minute, second, micro) }
    end
  end

  # <tt>time.rs:66</tt>, +from_hms_nano+.
  def test_from_hms_nano
    [
      [1, 2, 3, 4, clock(1, 2, 3, 4)],
      [24, 0, 0, 0, nil],
      [0, 60, 0, 0, nil],
      [0, 0, 60, 0, nil],
      [0, 0, 0, 1_000_000_000, nil],
    ].each do |hour, minute, second, nano, expected|
      assert_case expected, ok { T::Time.from_hms_nano(hour, minute, second, nano) }
    end
  end

  # <tt>time.rs:81</tt>, +as_hms+.
  def test_as_hms
    [
      [clock(1, 2, 3, 0), [1, 2, 3]],
    ].each do |value, expected|
      assert_case expected, value.as_hms
    end
  end

  # <tt>time.rs:87</tt>, +as_hms_milli+.
  def test_as_hms_milli
    [
      [clock(1, 2, 3, 4000000), [1, 2, 3, 4]],
    ].each do |value, expected|
      assert_case expected, value.as_hms_milli
    end
  end

  # <tt>time.rs:93</tt>, +as_hms_micro+.
  def test_as_hms_micro
    [
      [clock(1, 2, 3, 4005000), [1, 2, 3, 4_005]],
    ].each do |value, expected|
      assert_case expected, value.as_hms_micro
    end
  end

  # <tt>time.rs:99</tt>, +as_hms_nano+.
  def test_as_hms_nano
    [
      [clock(1, 2, 3, 4005006), [1, 2, 3, 4_005_006]],
    ].each do |value, expected|
      assert_case expected, value.as_hms_nano
    end
  end

  # <tt>time.rs:107</tt>, +hour+.
  def test_hour
    [
      0,
      12,
      23,
    ].each do |hour|
      assert_equal hour, T::Time.from_hms(hour, 0, 0).hour
      assert_equal hour, T::Time.from_hms(hour, 59, 59).hour
    end
  end

  # <tt>time.rs:117</tt>, +minute+.
  def test_minute
    [
      0,
      30,
      59,
    ].each do |minute|
      assert_equal minute, T::Time.from_hms(0, minute, 0).minute
      assert_equal minute, T::Time.from_hms(23, minute, 59).minute
    end
  end

  # <tt>time.rs:127</tt>, +second+.
  def test_second
    [
      0,
      30,
      59,
    ].each do |second|
      assert_equal second, T::Time.from_hms(0, 0, second).second
      assert_equal second, T::Time.from_hms(23, 59, second).second
    end
  end

  # <tt>time.rs:137</tt>, +millisecond+.
  def test_millisecond
    [
      0,
      500,
      999,
    ].each do |milli|
      assert_equal milli, T::Time.from_hms_milli(0, 0, 0, milli).millisecond
      assert_equal milli, T::Time.from_hms_milli(23, 59, 59, milli).millisecond
    end
  end

  # <tt>time.rs:150</tt>, +microsecond+.
  def test_microsecond
    [
      0,
      4_005,
      999_000,
    ].each do |micro|
      assert_equal micro, T::Time.from_hms_micro(0, 0, 0, micro).microsecond
      assert_equal micro, T::Time.from_hms_micro(23, 59, 59, micro).microsecond
    end
  end

  # <tt>time.rs:163</tt>, +nanosecond+.
  def test_nanosecond
    [
      0,
      4_005_006,
      999_000_000,
    ].each do |nano|
      assert_equal nano, T::Time.from_hms_nano(0, 0, 0, nano).nanosecond
      assert_equal nano, T::Time.from_hms_nano(23, 59, 59, nano).nanosecond
    end
  end

  # <tt>time.rs:173</tt>, +duration_until+.
  def test_duration_until
    [
      [clock(18, 0, 0, 0), T::Time::MIDNIGHT, Duration.hours(6)],
      [clock(23, 0, 0, 0), clock(1, 0, 0, 0), Duration.hours(2)],
      [clock(12, 30, 0, 0), clock(14, 0, 0, 0), Duration.minutes(90)],
    ].each do |start, finish, expected|
      assert_case expected, start.duration_until(finish)
    end
  end

  # <tt>time.rs:181</tt>, +duration_since+.
  def test_duration_since
    [
      [T::Time::MIDNIGHT, clock(18, 0, 0, 0), Duration.hours(6)],
      [clock(1, 0, 0, 0), clock(23, 0, 0, 0), Duration.hours(2)],
      [clock(14, 0, 0, 0), clock(12, 30, 0, 0), Duration.minutes(90)],
    ].each do |finish, start, expected|
      assert_case expected, finish.duration_since(start)
    end
  end

  # <tt>time.rs:188</tt>, +replace_hour+.
  def test_replace_hour
    [
      [clock(1, 2, 3, 4005006), 7, clock(7, 2, 3, 4005006)],
      [clock(1, 2, 3, 4005006), 24, nil],
    ].each do |value, hour, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { value.replace_hour(hour) }
      else
        assert_case expected, value.replace_hour(hour)
      end
    end
  end

  # <tt>time.rs:199</tt>, +replace_minute+.
  def test_replace_minute
    [
      [clock(1, 2, 3, 4005006), 7, clock(1, 7, 3, 4005006)],
      [clock(1, 2, 3, 4005006), 60, nil],
    ].each do |value, minute, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { value.replace_minute(minute) }
      else
        assert_case expected, value.replace_minute(minute)
      end
    end
  end

  # <tt>time.rs:210</tt>, +replace_second+.
  def test_replace_second
    [
      [clock(1, 2, 3, 4005006), 7, clock(1, 2, 7, 4005006)],
      [clock(1, 2, 3, 4005006), 60, nil],
    ].each do |value, second, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { value.replace_second(second) }
      else
        assert_case expected, value.replace_second(second)
      end
    end
  end

  # <tt>time.rs:221</tt>, +replace_millisecond+.
  def test_replace_millisecond
    [
      [clock(1, 2, 3, 4005006), 7, clock(1, 2, 3, 7000000)],
      [clock(1, 2, 3, 4005006), 1_000, nil],
    ].each do |value, milli, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { value.replace_millisecond(milli) }
      else
        assert_case expected, value.replace_millisecond(milli)
      end
    end
  end

  # <tt>time.rs:233</tt>, +replace_millisecond_regression+.
  def test_replace_millisecond_regression
    [9999, 4294, 4295].each do |milli|
      assert_raises(T::Error::ComponentRange) { T::Time::MIDNIGHT.replace_millisecond(milli) }
    end
  end

  # <tt>time.rs:240</tt>, +replace_microsecond+.
  def test_replace_microsecond
    [
      [clock(1, 2, 3, 4005006), 7_008, clock(1, 2, 3, 7008000)],
      [clock(1, 2, 3, 4005006), 1_000_000, nil],
    ].each do |value, micro, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { value.replace_microsecond(micro) }
      else
        assert_case expected, value.replace_microsecond(micro)
      end
    end
  end

  # <tt>time.rs:251</tt>, +replace_nanosecond+.
  def test_replace_nanosecond
    [
      [clock(1, 2, 3, 4005006), 7_008_009, clock(1, 2, 3, 7008009)],
      [clock(1, 2, 3, 4005006), 1_000_000_000, nil],
    ].each do |value, nano, expected|
      if expected.nil?
        assert_raises(T::Error::ComponentRange) { value.replace_nanosecond(nano) }
      else
        assert_case expected, value.replace_nanosecond(nano)
      end
    end
  end

  # <tt>time.rs:262</tt>, +truncate_to_hour+.
  def test_truncate_to_hour
    [
      [clock(1, 2, 3, 4005006), clock(1, 0, 0, 0)],
      [T::Time::MIDNIGHT, T::Time::MIDNIGHT],
    ].each do |value, expected|
      assert_case expected, value.truncate_to_hour
    end
  end

  # <tt>time.rs:269</tt>, +truncate_to_minute+.
  def test_truncate_to_minute
    [
      [clock(1, 2, 3, 4005006), clock(1, 2, 0, 0)],
      [T::Time::MIDNIGHT, T::Time::MIDNIGHT],
    ].each do |value, expected|
      assert_case expected, value.truncate_to_minute
    end
  end

  # <tt>time.rs:276</tt>, +truncate_to_second+.
  def test_truncate_to_second
    [
      [clock(1, 2, 3, 4005006), clock(1, 2, 3, 0)],
      [T::Time::MIDNIGHT, T::Time::MIDNIGHT],
    ].each do |value, expected|
      assert_case expected, value.truncate_to_second
    end
  end

  # <tt>time.rs:283</tt>, +truncate_to_millisecond+.
  def test_truncate_to_millisecond
    [
      [clock(1, 2, 3, 4005006), clock(1, 2, 3, 4000000)],
      [T::Time::MIDNIGHT, T::Time::MIDNIGHT],
    ].each do |value, expected|
      assert_case expected, value.truncate_to_millisecond
    end
  end

  # <tt>time.rs:290</tt>, +truncate_to_microsecond+.
  def test_truncate_to_microsecond
    [
      [clock(1, 2, 3, 4005006), clock(1, 2, 3, 4005000)],
      [T::Time::MIDNIGHT, T::Time::MIDNIGHT],
    ].each do |value, expected|
      assert_case expected, value.truncate_to_microsecond
    end
  end

  # <tt>time.rs:299</tt>, +add_duration+.
  def test_add_duration
    [
      [clock(0, 0, 0, 0), Duration.seconds(1), clock(0, 0, 1, 0)],
      [clock(0, 0, 0, 0), Duration.minutes(1), clock(0, 1, 0, 0)],
      [clock(0, 0, 0, 0), Duration.hours(1), clock(1, 0, 0, 0)],
      [clock(0, 0, 0, 0), Duration.days(1), clock(0, 0, 0, 0)],
    ].each do |value, duration, expected|
      assert_case expected, value + duration
    end
  end

  # <tt>time.rs:308</tt>, +add_assign_duration+: Ruby's <tt>+=</tt> is
  # <tt>+</tt> and an assignment.
  def test_add_assign_duration
    [
      [clock(0, 0), Duration.seconds(1), clock(0, 0, 1)],
      [clock(0, 0), Duration.minutes(1), clock(0, 1)],
      [clock(0, 0), Duration.hours(1), clock(1, 0)],
      [clock(0, 0), Duration.days(1), clock(0, 0)],
    ].each do |time, duration, expected|
      time += duration
      assert_case expected, time
    end
  end

  # <tt>time.rs:323</tt>, +sub_duration+.
  def test_sub_duration
    [
      [clock(12, 0, 0, 0), Duration.hours(1), clock(11, 0, 0, 0)],
      [clock(0, 0, 0, 0), Duration.seconds(1), clock(23, 59, 59, 0)],
      [clock(0, 0, 0, 0), Duration.minutes(1), clock(23, 59, 0, 0)],
      [clock(0, 0, 0, 0), Duration.hours(1), clock(23, 0, 0, 0)],
      [clock(0, 0, 0, 0), Duration.days(1), clock(0, 0, 0, 0)],
    ].each do |value, duration, expected|
      assert_case expected, value - duration
    end
  end

  # <tt>time.rs:332</tt>, +sub_assign_duration+.
  def test_sub_assign_duration
    [
      [clock(0, 0), Duration.seconds(1), clock(23, 59, 59)],
      [clock(0, 0), Duration.minutes(1), clock(23, 59)],
      [clock(0, 0), Duration.hours(1), clock(23, 0)],
      [clock(0, 0), Duration.days(1), clock(0, 0)],
    ].each do |time, duration, expected|
      time -= duration
      assert_case expected, time
    end
  end

  # <tt>time.rs:402</tt>, +sub_time+.
  def test_sub_time
    [
      [clock(0, 0, 0, 0), clock(0, 0, 0, 0), Duration.seconds(0)],
      [clock(1, 0, 0, 0), clock(0, 0, 0, 0), Duration.hours(1)],
      [clock(1, 0, 0, 0), clock(0, 0, 1, 0), Duration.minutes(59) + Duration.seconds(59)],
    ].each do |a, b, expected|
      assert_case expected, a - b
    end
  end

  # <tt>time.rs:411</tt>, +ordering+.
  def test_ordering
    [
      [clock(0, 0, 0, 0), clock(0, 0, 0, 1), -1],
      [clock(0, 0, 0, 0), clock(0, 0, 1, 0), -1],
      [clock(12, 0, 0, 0), clock(11, 0, 0, 0), 1],
      [clock(0, 0, 0, 0), clock(0, 0, 0, 0), 0],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>time.rs:423</tt>, +ordering_lexico_endianness+.
  def test_ordering_lexico_endianness
    [
      [clock(0, 0, 0, 400000000), clock(0, 0, 0, 100000000)],
      [clock(1, 0, 0, 0), clock(0, 1, 0, 0)],
      [clock(1, 0, 0, 0), clock(0, 0, 1, 0)],
      [clock(1, 0, 0, 0), clock(0, 0, 0, 100000000)],
      [clock(0, 1, 0, 0), clock(0, 0, 1, 0)],
      [clock(0, 1, 0, 0), clock(0, 0, 0, 100000000)],
      [clock(0, 0, 1, 0), clock(0, 0, 0, 100000000)],
    ].each do |higher, lower|
      assert_operator higher, :>, lower
    end
  end

  # <tt>time.rs:430</tt>, +issue_481+.
  def test_issue_481
    [
      [clock(0, 0, 0, 0), clock(1, 0, 0, 100000000), Duration.nanoseconds((-3600.1 * 1_000_000_000).to_i)],
      [clock(0, 0, 0, 0), clock(23, 59, 59, 999999999), Duration.nanoseconds((-86_399.999_999_999 * 1_000_000_000).to_i)],
    ].each do |a, b, expected|
      assert_case expected, a - b
    end
  end
end

#--
# SPDX-SnippetEnd
#++
