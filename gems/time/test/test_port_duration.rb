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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/duration.rs
#++

# time's own tests in <tt>tests/integration/duration.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortDuration < Minitest::Test
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

  # <tt>duration.rs:19</tt>, +unit_values+.
  def test_unit_values
    [
      [Duration::ZERO, Duration.seconds(0)],
      [Duration::NANOSECOND, Duration.nanoseconds(1)],
      [Duration::MICROSECOND, Duration.microseconds(1)],
      [Duration::MILLISECOND, Duration.milliseconds(1)],
      [Duration::SECOND, Duration.seconds(1)],
      [Duration::MINUTE, Duration.seconds(60)],
      [Duration::HOUR, Duration.seconds(3_600)],
      [Duration::DAY, Duration.seconds(86_400)],
      [Duration::WEEK, Duration.seconds(604_800)],
    ].each do |input, expected|
      assert_case expected, input
    end
  end

  # <tt>duration.rs:24</tt>, +default+.
  def test_default
    assert_equal Duration::ZERO, Duration.default
  end

  # <tt>duration.rs:32</tt>, +is_zero+.
  def test_is_zero
    [
      [Duration.seconds(-1), false],
      [Duration.seconds(0), true],
      [Duration.seconds(1), false],
    ].each do |input, expected|
      assert_case expected, input.is_zero
    end
  end

  # <tt>duration.rs:40</tt>, +is_negative+.
  def test_is_negative
    [
      [Duration.seconds(-1), true],
      [Duration.seconds(0), false],
      [Duration.seconds(1), false],
    ].each do |input, expected|
      assert_case expected, input.is_negative
    end
  end

  # <tt>duration.rs:48</tt>, +is_positive+.
  def test_is_positive
    [
      [Duration.seconds(-1), false],
      [Duration.seconds(0), false],
      [Duration.seconds(1), true],
    ].each do |input, expected|
      assert_case expected, input.is_positive
    end
  end

  # <tt>duration.rs:57</tt>, +abs+.
  def test_abs
    [
      [Duration.seconds(1), Duration.seconds(1)],
      [Duration.seconds(0), Duration.seconds(0)],
      [Duration.seconds(-1), Duration.seconds(1)],
      [Duration.new(-(2 ** 63), 0), Duration::MAX],
    ].each do |input, expected|
      assert_case expected, input.abs
    end
  end

  # <tt>duration.rs:89</tt>, +new+.
  def test_new
    [
      [1, 0, Duration.seconds(1)],
      [-1, 0, Duration.seconds(-1)],
      [1, 2_000_000_000, Duration.seconds(3)],
      [0, 0, Duration.seconds(0)],
      [0, 1_000_000_000, Duration.seconds(1)],
      [-1, 1_000_000_000, Duration.seconds(0)],
      [-2, 1_000_000_000, Duration.seconds(-1)],
      [1, -1, Duration.nanoseconds(999_999_999)],
      [-1, 1, Duration.nanoseconds(-999_999_999)],
      [1, 1, Duration.nanoseconds(1_000_000_001)],
      [-1, -1, Duration.nanoseconds(-1_000_000_001)],
      [0, 1, Duration.nanoseconds(1)],
      [0, -1, Duration.nanoseconds(-1)],
      [-1, 1_400_000_000, Duration.milliseconds(400)],
      [-2, 1_400_000_000, Duration.milliseconds(-600)],
      [-3, 1_400_000_000, Duration.milliseconds(-1_600)],
      [1, -1_400_000_000, Duration.milliseconds(-400)],
      [2, -1_400_000_000, Duration.milliseconds(600)],
      [3, -1_400_000_000, Duration.milliseconds(1_600)],
    ].each do |seconds, nanoseconds, expected|
      assert_case expected, Duration.new(seconds, nanoseconds)
    end
  end

  # <tt>duration.rs:97</tt>, +new_panic+.
  def test_new_panic
    [
      [((2 ** 63) - 1), 1_000_000_000],
      [-(2 ** 63), -1_000_000_000],
    ].each do |seconds, nanoseconds|
      assert_raises(RangeError) { Duration.new(seconds, nanoseconds) }
    end
  end

  # <tt>duration.rs:106</tt>, +weeks+.
  def test_weeks
    [
      [1, 604_800],
      [2, 2 * 604_800],
      [-1, -604_800],
      [-2, -2 * 604_800],
    ].each do |weeks, expected|
      assert_equal Duration.seconds(expected), Duration.weeks(weeks)
    end
  end

  # <tt>duration.rs:114</tt>, +weeks_panic+.
  def test_weeks_panic
    [
      ((2 ** 63) - 1),
      -(2 ** 63),
    ].each do |weeks|
      assert_raises(RangeError) { Duration.weeks(weeks) }
    end
  end

  # <tt>duration.rs:123</tt>, +whole_weeks+.
  def test_whole_weeks
    [
      [7, 1],
      [-7, -1],
      [6, 0],
      [-6, 0],
    ].each do |days, expected|
      assert_case expected, Duration.days(days).whole_weeks
    end
  end

  # <tt>duration.rs:132</tt>, +days+.
  def test_days
    [
      [1, 86_400],
      [2, 2 * 86_400],
      [-1, -86_400],
      [-2, -2 * 86_400],
    ].each do |days, expected|
      assert_equal Duration.seconds(expected), Duration.days(days)
    end
  end

  # <tt>duration.rs:140</tt>, +days_panic+.
  def test_days_panic
    [
      ((2 ** 63) - 1),
      -(2 ** 63),
    ].each do |days|
      assert_raises(RangeError) { Duration.days(days) }
    end
  end

  # <tt>duration.rs:149</tt>, +whole_days+.
  def test_whole_days
    [
      [24, 1],
      [-24, -1],
      [23, 0],
      [-23, 0],
    ].each do |hours, expected|
      assert_case expected, Duration.hours(hours).whole_days
    end
  end

  # <tt>duration.rs:158</tt>, +hours+.
  def test_hours
    [
      [1, 3_600],
      [2, 2 * 3_600],
      [-1, -3_600],
      [-2, -2 * 3_600],
    ].each do |hours, expected|
      assert_equal Duration.seconds(expected), Duration.hours(hours)
    end
  end

  # <tt>duration.rs:166</tt>, +hours_panic+.
  def test_hours_panic
    [
      ((2 ** 63) - 1),
      -(2 ** 63),
    ].each do |hours|
      assert_raises(RangeError) { Duration.hours(hours) }
    end
  end

  # <tt>duration.rs:175</tt>, +whole_hours+.
  def test_whole_hours
    [
      [60, 1],
      [-60, -1],
      [59, 0],
      [-59, 0],
    ].each do |minutes, expected|
      assert_case expected, Duration.minutes(minutes).whole_hours
    end
  end

  # <tt>duration.rs:184</tt>, +minutes+.
  def test_minutes
    [
      [1, 60],
      [2, 2 * 60],
      [-1, -60],
      [-2, -2 * 60],
    ].each do |minutes, expected|
      assert_equal Duration.seconds(expected), Duration.minutes(minutes)
    end
  end

  # <tt>duration.rs:192</tt>, +minutes_panic+.
  def test_minutes_panic
    [
      ((2 ** 63) - 1),
      -(2 ** 63),
    ].each do |minutes|
      assert_raises(RangeError) { Duration.minutes(minutes) }
    end
  end

  # <tt>duration.rs:201</tt>, +whole_minutes+.
  def test_whole_minutes
    [
      [60, 1],
      [-60, -1],
      [59, 0],
      [-59, 0],
    ].each do |seconds, expected|
      assert_case expected, Duration.seconds(seconds).whole_minutes
    end
  end

  # <tt>duration.rs:210</tt>, +seconds+.
  def test_seconds
    [
      [1, 1_000],
      [2, 2 * 1_000],
      [-1, -1_000],
      [-2, -2 * 1_000],
    ].each do |seconds, expected|
      assert_equal Duration.milliseconds(expected), Duration.seconds(seconds)
    end
  end

  # <tt>duration.rs:219</tt>, +whole_seconds+.
  def test_whole_seconds
    [
      1,
      -1,
      60,
      -60,
    ].each do |seconds|
      assert_equal seconds, Duration.seconds(seconds).whole_seconds
    end
  end

  # <tt>duration.rs:228</tt>, +seconds_f64+.
  def test_seconds_f64
    [
      [0.5, Duration.milliseconds(500)],
      [-0.5, Duration.milliseconds(-500)],
      [123.250, Duration.milliseconds(123_250)],
      [0.000_000_000_012, Duration::ZERO],
    ].each do |seconds, expected|
      assert_case expected, Duration.seconds_f64(seconds)
    end
  end

  # <tt>duration.rs:237</tt>, +seconds_f64_panic+.
  def test_seconds_f64_panic
    [
      Float::MAX,
      -Float::MAX,
      Float::NAN,
    ].each do |seconds|
      assert_raises(RangeError) { Duration.seconds_f64(seconds) }
    end
  end

  # <tt>duration.rs:249</tt>, +saturating_seconds_f64+.
  def test_saturating_seconds_f64
    [
      [0.5, Duration.milliseconds(500)],
      [-0.5, Duration.milliseconds(-500)],
      [123.250, Duration.milliseconds(123_250)],
      [0.000_000_000_012, Duration::ZERO],
      [Float::MAX, Duration::MAX],
      [-Float::MAX, Duration::MIN],
      [Float::NAN, Duration::ZERO],
    ].each do |seconds, expected|
      assert_case expected, Duration.saturating_seconds_f64(seconds)
    end
  end

  # <tt>duration.rs:258</tt>, +checked_seconds_f64_success+.
  def test_checked_seconds_f64_success
    [
      [0.5, 0.5],
      [-0.5, -0.5],
      [123.250, 123.250],
      [0.000_000_000_012, 0.0],
    ].each do |seconds, expected|
      assert_equal Duration.nanoseconds((expected * 1_000_000_000).to_i), Duration.checked_seconds_f64(seconds)
    end
  end

  # <tt>duration.rs:269</tt>, +checked_seconds_f64_edge_cases+.
  def test_checked_seconds_f64_edge_cases
    [
      Float::MAX,
      -Float::MAX,
      Float::NAN,
    ].each do |seconds|
      assert_nil Duration.checked_seconds_f64(seconds)
    end
  end

  # <tt>duration.rs:280</tt>, +as_seconds_f64+.
  def test_as_seconds_f64
    [
      1.0,
      -1.0,
      60.0,
      -60.0,
      1.5,
      -1.5,
    ].each do |seconds|
      assert_equal seconds, Duration.seconds_f64(seconds).as_seconds_f64
    end
  end

  # <tt>duration.rs:292</tt>, +seconds_f32_success+.
  def test_seconds_f32_success
    [
      [0.5, Duration.milliseconds(500)],
      [-0.5, Duration.milliseconds(-500)],
      [123.250, Duration.milliseconds(123_250)],
      [0.000_000_000_012, Duration::ZERO],
    ].each do |seconds, expected|
      assert_case expected, Duration.seconds_f32(seconds)
    end
  end

  # <tt>duration.rs:301</tt>, +seconds_f32_panic+.
  def test_seconds_f32_panic
    [
      3.4028235e38,
      -3.4028235e38,
      Float::NAN,
    ].each do |seconds|
      assert_raises(RangeError) { Duration.seconds_f32(seconds) }
    end
  end

  # <tt>duration.rs:313</tt>, +saturating_seconds_f32+.
  def test_saturating_seconds_f32
    [
      [0.5, Duration.milliseconds(500)],
      [-0.5, Duration.milliseconds(-500)],
      [123.250, Duration.milliseconds(123_250)],
      [0.000_000_000_012, Duration::ZERO],
      [3.4028235e38, Duration::MAX],
      [-3.4028235e38, Duration::MIN],
      [Float::NAN, Duration::ZERO],
    ].each do |seconds, expected|
      assert_case expected, Duration.saturating_seconds_f32(seconds)
    end
  end

  # <tt>duration.rs:322</tt>, +checked_seconds_f32_success+.
  def test_checked_seconds_f32_success
    [
      [0.5, 0.5],
      [-0.5, -0.5],
      [123.250, 123.250],
      [0.000_000_000_012, 0.0],
    ].each do |seconds, expected|
      assert_equal Duration.nanoseconds((expected * 1_000_000_000).to_i), Duration.checked_seconds_f32(seconds)
    end
  end

  # <tt>duration.rs:333</tt>, +checked_seconds_f32_none+.
  def test_checked_seconds_f32_none
    [
      3.4028235e38,
      -3.4028235e38,
      Float::NAN,
    ].each do |seconds|
      assert_nil Duration.checked_seconds_f32(seconds)
    end
  end

  # <tt>duration.rs:344</tt>, +as_seconds_f32+.
  def test_as_seconds_f32
    [
      [1.0, 1.0],
      [-1.0, -1.0],
      [60.0, 60.0],
      [-60.0, -60.0],
      [1.5, 1.5],
      [-1.5, -1.5],
    ].each do |seconds, expected|
      assert_equal [expected].pack("f").unpack1("f"), Duration.seconds_f32(seconds).as_seconds_f32
    end
  end

  # <tt>duration.rs:354</tt>, +milliseconds+.
  def test_milliseconds
    [
      [1, 1_000],
      [-1, -1_000],
    ].each do |input, expected|
      assert_equal Duration.microseconds(expected), Duration.milliseconds(input)
    end
  end

  # <tt>duration.rs:363</tt>, +whole_milliseconds+.
  def test_whole_milliseconds
    [
      [Duration.seconds(1), 1_000],
      [Duration.seconds(-1), -1_000],
      [Duration.milliseconds(1), 1],
      [Duration.milliseconds(-1), -1],
    ].each do |input, expected|
      assert_case expected, input.whole_milliseconds
    end
  end

  # <tt>duration.rs:370</tt>, +subsec_milliseconds+.
  def test_subsec_milliseconds
    [
      [Duration.nanoseconds((1.4 * 1_000_000_000).to_i), 400],
      [Duration.nanoseconds((-1.4 * 1_000_000_000).to_i), -400],
    ].each do |duration, expected|
      assert_case expected, duration.subsec_milliseconds
    end
  end

  # <tt>duration.rs:377</tt>, +microseconds+.
  def test_microseconds
    [
      [1, 1_000],
      [-1, -1_000],
    ].each do |input, expected|
      assert_equal Duration.nanoseconds(expected), Duration.microseconds(input)
    end
  end

  # <tt>duration.rs:386</tt>, +whole_microseconds+.
  def test_whole_microseconds
    [
      [Duration.milliseconds(1), 1_000],
      [Duration.milliseconds(-1), -1_000],
      [Duration.microseconds(1), 1],
      [Duration.microseconds(-1), -1],
    ].each do |input, expected|
      assert_case expected, input.whole_microseconds
    end
  end

  # <tt>duration.rs:393</tt>, +subsec_microseconds+.
  def test_subsec_microseconds
    [
      [Duration.nanoseconds((1.0004 * 1_000_000_000).to_i), 400],
      [Duration.nanoseconds((-1.0004 * 1_000_000_000).to_i), -400],
    ].each do |duration, expected|
      assert_case expected, duration.subsec_microseconds
    end
  end

  # <tt>duration.rs:400</tt>, +nanoseconds+.
  def test_nanoseconds
    [
      [1, Duration.microseconds(1) / 1_000],
      [-1, Duration.microseconds(-1) / 1_000],
    ].each do |input, expected|
      assert_case expected, Duration.nanoseconds(input)
    end
  end

  # <tt>duration.rs:409</tt>, +whole_nanoseconds+.
  def test_whole_nanoseconds
    [
      [Duration.microseconds(1), 1_000],
      [Duration.microseconds(-1), -1_000],
      [Duration.nanoseconds(1), 1],
      [Duration.nanoseconds(-1), -1],
    ].each do |input, expected|
      assert_case expected, input.whole_nanoseconds
    end
  end

  # <tt>duration.rs:416</tt>, +subsec_nanoseconds+.
  def test_subsec_nanoseconds
    [
      [Duration.nanoseconds((1.000_000_4 * 1_000_000_000).to_i), 400],
      [Duration.nanoseconds((-1.000_000_4 * 1_000_000_000).to_i), -400],
    ].each do |duration, expected|
      assert_case expected, duration.subsec_nanoseconds
    end
  end

  # <tt>duration.rs:424</tt>, +checked_add_some+.
  def test_checked_add_some
    [
      [Duration.seconds(5), Duration.seconds(5), Duration.seconds(10)],
      [Duration.seconds(-5), Duration.seconds(5), Duration.seconds(0)],
      [Duration.seconds(1), Duration.milliseconds(-1), Duration.milliseconds(999)],
    ].each do |a, b, expected|
      assert_case expected, a.checked_add(b)
    end
  end

  # <tt>duration.rs:436</tt>, +checked_add_none+.
  def test_checked_add_none
    [
      [Duration::MAX, Duration.nanoseconds(1)],
      [Duration.seconds(5), Duration::MAX],
      [Duration::MIN, Duration::MIN],
    ].each do |a, b|
      assert_nil a.checked_add(b)
    end
  end

  # <tt>duration.rs:443</tt>, +checked_sub_some+.
  def test_checked_sub_some
    [
      [Duration.seconds(5), Duration.seconds(5), Duration.seconds(0)],
      [Duration.seconds(5), Duration.seconds(10), Duration.seconds(-5)],
    ].each do |a, b, expected|
      assert_case expected, a.checked_sub(b)
    end
  end

  # <tt>duration.rs:455</tt>, +checked_sub_none+.
  def test_checked_sub_none
    [
      [Duration::MIN, Duration.nanoseconds(1)],
      [Duration.seconds(5), Duration::MIN],
      [Duration::MAX, Duration::MIN],
    ].each do |a, b|
      assert_nil a.checked_sub(b)
    end
  end

  # <tt>duration.rs:463</tt>, +checked_mul_some+.
  def test_checked_mul_some
    [
      [Duration.seconds(5), 2, Duration.seconds(10)],
      [Duration.seconds(5), -2, Duration.seconds(-10)],
      [Duration.seconds(5), 0, Duration::ZERO],
    ].each do |duration, rhs, expected|
      assert_case expected, duration.checked_mul(rhs)
    end
  end

  # <tt>duration.rs:475</tt>, +checked_mul_none+.
  def test_checked_mul_none
    [
      [Duration::MIN, -1],
      [Duration::MAX, 2],
      [Duration::MIN, 2],
    ].each do |duration, rhs|
      assert_nil duration.checked_mul(rhs)
    end
  end

  # <tt>duration.rs:482</tt>, +checked_div_some+.
  def test_checked_div_some
    [
      [Duration.seconds(10), 2, Duration.seconds(5)],
      [Duration.seconds(10), -2, Duration.seconds(-5)],
    ].each do |duration, rhs, expected|
      assert_case expected, duration.checked_div(rhs)
    end
  end

  # <tt>duration.rs:493</tt>, +checked_div_none+.
  def test_checked_div_none
    [
      [Duration.seconds(1), 0],
      [Duration::MIN, -1],
    ].each do |duration, rhs|
      assert_nil duration.checked_div(rhs)
    end
  end

  # <tt>duration.rs:498</tt>, +checked_div_regression+.
  def test_checked_div_regression
    assert_equal Duration.new(0, 142_857_143), Duration.new(1, 1).checked_div(7)
  end

  # <tt>duration.rs:509</tt>, +checked_neg+.
  def test_checked_neg
    [
      [Duration.seconds(5), Duration.seconds(-5)],
      [Duration.seconds(-5), Duration.seconds(5)],
      [Duration::MIN, nil],
    ].each do |duration, expected|
      assert_case expected, duration.checked_neg
    end
  end

  # <tt>duration.rs:522</tt>, +saturating_add+.
  def test_saturating_add
    [
      [Duration.seconds(5), Duration.seconds(5), Duration.seconds(10)],
      [Duration::MAX, Duration.nanoseconds(1), Duration::MAX],
      [Duration::MAX, Duration.seconds(1), Duration::MAX],
      [Duration::MIN, Duration.nanoseconds(-1), Duration::MIN],
      [Duration::MIN, Duration.seconds(-1), Duration::MIN],
      [Duration.seconds(-5), Duration.seconds(5), Duration::ZERO],
      [Duration.milliseconds(1_600), Duration.milliseconds(1_600), Duration.milliseconds(3_200)],
      [Duration.seconds(1), Duration.milliseconds(-1), Duration.milliseconds(999)],
    ].each do |a, b, expected|
      assert_case expected, a.saturating_add(b)
    end
  end

  # <tt>duration.rs:541</tt>, +saturating_sub+.
  def test_saturating_sub
    [
      [Duration.seconds(5), Duration.seconds(5), Duration::ZERO],
      [Duration::MIN, Duration.nanoseconds(1), Duration::MIN],
      [Duration::MAX, Duration.nanoseconds(-1), Duration::MAX],
      [Duration::MAX, Duration.seconds(-1), Duration::MAX],
      [Duration.seconds(5), Duration.seconds(10), Duration.seconds(-5)],
      [Duration.milliseconds(-1_600), Duration.milliseconds(1_600), Duration.milliseconds(-3_200)],
      [Duration.seconds(0), Duration::MIN, Duration::MIN],
      [Duration::MIN, Duration.seconds(5), Duration::MIN],
      [Duration.milliseconds(1_200), Duration.milliseconds(600), Duration.milliseconds(600)],
      [Duration.milliseconds(-1_200), Duration.milliseconds(-600), Duration.milliseconds(-600)],
    ].each do |a, b, expected|
      assert_case expected, a.saturating_sub(b)
    end
  end

  # <tt>duration.rs:563</tt>, +saturating_mul+.
  def test_saturating_mul
    [
      [Duration.seconds(5), 2, Duration.seconds(10)],
      [Duration.seconds(5), -2, Duration.seconds(-10)],
      [Duration.seconds(5), 0, Duration::ZERO],
      [Duration::MAX, 2, Duration::MAX],
      [Duration::MIN, 2, Duration::MIN],
      [Duration::MAX, -2, Duration::MIN],
      [Duration::MIN, -2, Duration::MAX],
      [Duration.new(1_844_674_407_370_955_161, 600_000_000), 5, Duration::MAX],
      [Duration.new(1_844_674_407_370_955_161, 800_000_000), -5, Duration::MIN],
    ].each do |duration, rhs, expected|
      assert_case expected, duration.saturating_mul(rhs)
    end
  end

  # <tt>duration.rs:602</tt>, +display_basic+.
  def test_display_basic
    [
      [Duration.seconds(0), "0s"],
      [Duration.days(60), "60d"],
      [Duration.hours(-48), "-2d"],
      [Duration.hours(48), "2d"],
      [Duration.minutes(1), "1m"],
      [Duration.minutes(10), "10m"],
      [Duration.seconds(1), "1s"],
      [Duration.seconds(10), "10s"],
      [Duration.milliseconds(1), "1ms"],
      [Duration.milliseconds(10), "10ms"],
      [Duration.milliseconds(100), "100ms"],
      [Duration.microseconds(1), "1µs"],
      [Duration.microseconds(10), "10µs"],
      [Duration.microseconds(100), "100µs"],
      [Duration.nanoseconds(1), "1ns"],
      [Duration.nanoseconds(10), "10ns"],
      [Duration.nanoseconds(100), "100ns"],
    ].each do |duration, expected|
      assert_case expected, duration.to_s
    end
  end

  # <tt>duration.rs:614</tt>, +display_compound+.
  def test_display_compound
    [
      [Duration.days(1), "1d"],
      [Duration.hours(26), "1d2h"],
      [Duration.minutes(1_563), "1d2h3m"],
      [Duration.seconds(93_784), "1d2h3m4s"],
      [Duration.milliseconds(93_784_005), "1d2h3m4s5ms"],
      [Duration.microseconds(93_784_005_006), "1d2h3m4s5ms6µs"],
      [Duration.nanoseconds(93_784_005_006_007), "1d2h3m4s5ms6µs7ns"],
    ].each do |duration, expected|
      assert_case expected, duration.to_s
    end
  end

  # <tt>duration.rs:688</tt>, +add+.
  def test_add
    [
      [Duration.seconds(1), Duration.seconds(1), Duration.seconds(2)],
      [Duration.milliseconds(500), Duration.milliseconds(500), Duration.seconds(1)],
      [Duration.seconds(1), Duration.seconds(-1), Duration.seconds(0)],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs + rhs
    end
  end

  # <tt>duration.rs:720</tt>, +add_assign+.
  def test_add_assign
    [
      [Duration.seconds(1), Duration.seconds(1), Duration.seconds(2)],
      [Duration.milliseconds(500), Duration.milliseconds(500), Duration.seconds(1)],
      [Duration.seconds(1), Duration.seconds(-1), Duration.seconds(0)],
    ].each do |lhs, rhs, expected|
      lhs += rhs
      assert_case expected, lhs
    end
  end

  # <tt>duration.rs:759</tt>, +neg+.
  def test_neg
    [
      [Duration.seconds(1), Duration.seconds(-1)],
      [Duration.seconds(-1), Duration.seconds(1)],
      [Duration.seconds(0), Duration.seconds(0)],
    ].each do |duration, expected|
      assert_case expected, -duration
    end
  end

  # <tt>duration.rs:767</tt>, +sub+.
  def test_sub
    [
      [Duration.seconds(1), Duration.seconds(1), Duration.seconds(0)],
      [Duration.milliseconds(1_500), Duration.milliseconds(500), Duration.seconds(1)],
      [Duration.seconds(1), Duration.seconds(-1), Duration.seconds(2)],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs - rhs
    end
  end

  # <tt>duration.rs:799</tt>, +sub_assign+.
  def test_sub_assign
    [
      [Duration.seconds(1), Duration.seconds(1), Duration.seconds(0)],
      [Duration.milliseconds(1_500), Duration.milliseconds(500), Duration.seconds(1)],
      [Duration.seconds(1), Duration.seconds(-1), Duration.seconds(2)],
    ].each do |lhs, rhs, expected|
      lhs -= rhs
      assert_case expected, lhs
    end
  end

  # <tt>duration.rs:844</tt>, +mul_int_success+.
  def test_mul_int_success
    [
      [Duration.seconds(1), 2, Duration.seconds(2)],
      [Duration.seconds(1), -2, Duration.seconds(-2)],
    ].each do |duration, rhs, expected|
      assert_case expected, duration * rhs
    end
  end

  # <tt>duration.rs:856</tt>, +mul_int_panic+.
  def test_mul_int_panic
    [
      [Duration::MAX, 2],
      [Duration::MIN, 2],
    ].each do |duration, rhs|
      assert_raises(RangeError) { duration * rhs }
    end
  end

  # <tt>duration.rs:863</tt>, +mul_int_assign+.
  def test_mul_int_assign
    [
      [Duration.seconds(1), 2, Duration.seconds(2)],
      [Duration.seconds(1), -2, Duration.seconds(-2)],
    ].each do |duration, rhs, expected|
      duration *= rhs
      assert_case expected, duration
    end
  end

  # <tt>duration.rs:875</tt>, +int_mul+, through SignedDuration#coerce.
  def test_int_mul
    [
      [2, Duration.seconds(1), Duration.seconds(2)],
      [-2, Duration.seconds(1), Duration.seconds(-2)],
    ].each do |lhs, duration, expected|
      assert_case expected, lhs * duration
    end
  end

  # <tt>duration.rs:882</tt>, +div_int+.
  def test_div_int
    [
      [Duration.seconds(1), 2, Duration.milliseconds(500)],
      [Duration.seconds(1), -2, Duration.milliseconds(-500)],
    ].each do |duration, rhs, expected|
      assert_case expected, duration / rhs
    end
  end

  # <tt>duration.rs:889</tt>, +div_int_assign+.
  def test_div_int_assign
    [
      [Duration.seconds(1), 2, Duration.milliseconds(500)],
      [Duration.seconds(1), -2, Duration.milliseconds(-500)],
    ].each do |duration, rhs, expected|
      duration /= rhs
      assert_case expected, duration
    end
  end

  # <tt>duration.rs:901</tt>, +div+.
  def test_div
    [
      [Duration.seconds(1), Duration.nanoseconds((0.5 * 1_000_000_000).to_i), 2.0],
      [Duration.seconds(2), Duration.nanoseconds((0.25 * 1_000_000_000).to_i), 8.0],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs / rhs
    end
  end

  # <tt>duration.rs:934</tt>, +mul_f64+.
  def test_mul_f64
    [
      [Duration.seconds(1), 1.5, Duration.milliseconds(1_500)],
      [Duration.seconds(1), 2.5, Duration.milliseconds(2_500)],
      [Duration.seconds(1), -1.5, Duration.milliseconds(-1_500)],
      [Duration.seconds(1), 0.0, Duration.seconds(0)],
    ].each do |duration, rhs, expected|
      assert_case expected, duration * rhs
    end
  end

  # <tt>duration.rs:952</tt>, +f64_mul+, through SignedDuration#coerce.
  def test_f64_mul
    [
      [1.5, Duration.seconds(1), Duration.milliseconds(1_500)],
      [2.5, Duration.seconds(1), Duration.milliseconds(2_500)],
      [-1.5, Duration.seconds(1), Duration.milliseconds(-1_500)],
      [0.0, Duration.seconds(1), Duration.seconds(0)],
    ].each do |lhs, duration, expected|
      assert_case expected, lhs * duration
    end
  end

  # <tt>duration.rs:975</tt>, +mul_f64_assign+.
  def test_mul_f64_assign
    [
      [Duration.seconds(1), 1.5, Duration.milliseconds(1_500)],
      [Duration.seconds(1), 2.5, Duration.milliseconds(2_500)],
      [Duration.seconds(1), -1.5, Duration.milliseconds(-1_500)],
      [Duration.seconds(1), 0.0, Duration.seconds(0)],
    ].each do |duration, rhs, expected|
      duration *= rhs
      assert_case expected, duration
    end
  end

  # <tt>duration.rs:1000</tt>, +div_f64+.
  def test_div_f64
    [
      [Duration.seconds(1), 1.0, Duration.seconds(1)],
      [Duration.seconds(1), 2.0, Duration.milliseconds(500)],
      [Duration.seconds(1), 4.0, Duration.milliseconds(250)],
      [Duration.seconds(1), 0.25, Duration.seconds(4)],
      [Duration.seconds(1), -1.0, Duration.seconds(-1)],
    ].each do |duration, rhs, expected|
      assert_case expected, duration / rhs
    end
  end

  # <tt>duration.rs:1025</tt>, +div_f64_assign+.
  def test_div_f64_assign
    [
      [Duration.seconds(1), 1.0, Duration.seconds(1)],
      [Duration.seconds(1), 2.0, Duration.milliseconds(500)],
      [Duration.seconds(1), 4.0, Duration.milliseconds(250)],
      [Duration.seconds(1), 0.25, Duration.seconds(4)],
      [Duration.seconds(1), -1.0, Duration.seconds(-1)],
    ].each do |duration, rhs, expected|
      duration /= rhs
      assert_case expected, duration
    end
  end

  # <tt>duration.rs:1041</tt>, +partial_eq+.
  def test_partial_eq
    [
      [Duration.seconds(1), Duration.seconds(1), true],
      [Duration.seconds(0), Duration.seconds(0), true],
      [Duration.seconds(1), Duration.seconds(2), false],
      [Duration.seconds(1), Duration.seconds(-1), false],
      [Duration.seconds(-1), Duration.seconds(-1), true],
      [Duration.seconds(40), Duration.minutes(1), false],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs == rhs
    end
  end

  # <tt>duration.rs:1075</tt>, +partial_ord+.
  def test_partial_ord
    [
      [Duration.seconds(0), Duration.seconds(0), 0],
      [Duration.seconds(1), Duration.seconds(0), 1],
      [Duration.seconds(1), Duration.seconds(-1), 1],
      [Duration.seconds(-1), Duration.seconds(1), -1],
      [Duration.seconds(0), Duration.seconds(-1), 1],
      [Duration.seconds(0), Duration.seconds(1), -1],
      [Duration.seconds(-1), Duration.seconds(0), -1],
      [Duration.minutes(1), Duration.seconds(1), 1],
      [Duration.minutes(-1), Duration.seconds(-1), -1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>duration.rs:1126</tt>, +ord+.
  def test_ord
    [
      [Duration.seconds(0), Duration.seconds(0), 0],
      [Duration.seconds(1), Duration.seconds(0), 1],
      [Duration.seconds(1), Duration.seconds(-1), 1],
      [Duration.seconds(-1), Duration.seconds(1), -1],
      [Duration.seconds(0), Duration.seconds(-1), 1],
      [Duration.seconds(0), Duration.seconds(1), -1],
      [Duration.seconds(-1), Duration.seconds(0), -1],
      [Duration.minutes(1), Duration.seconds(1), 1],
      [Duration.minutes(-1), Duration.seconds(-1), -1],
      [Duration.nanoseconds(100), Duration.nanoseconds(200), -1],
      [Duration.nanoseconds(-100), Duration.nanoseconds(-200), 1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>duration.rs:1131</tt>, +arithmetic_regression+.
  def test_arithmetic_regression
    added = Duration.seconds_f64(1.6) + Duration.seconds_f64(1.6)
    assert_equal 3, added.whole_seconds
    assert_equal 200, added.subsec_milliseconds

    subtracted = Duration.seconds_f64(1.6) - Duration.seconds_f64(-1.6)
    assert_equal 3, subtracted.whole_seconds
    assert_equal 200, subtracted.subsec_milliseconds
  end

  # <tt>duration.rs:1142</tt>, +sum_iter_ref+, and

  # <tt>duration.rs:1149</tt>, +sum_iter+: Rust's +Sum+ is Ruby's
  # <tt>sum(Duration::ZERO)</tt>, which folds with the same <tt>+</tt>
  # (plan 007, row 23); Ruby has no borrowed iterator to tell them apart.
  def test_sum_iter
    i = [Duration.seconds_f64(1.6), Duration.seconds_f64(1.6)]
    assert_equal Duration.seconds_f64(3.2), i.sum(Duration::ZERO)
  end
end

#--
# SPDX-SnippetEnd
#++
