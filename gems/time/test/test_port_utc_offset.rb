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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/utc_offset.rs
#++

# time's own tests in <tt>tests/integration/utc_offset.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortUtcOffset < Minitest::Test
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

  # <tt>utc_offset.rs:8</tt>, +utc_is_zero+.
  def test_utc_is_zero
    assert_equal offset(0), T::UtcOffset::UTC
  end

  # <tt>utc_offset.rs:25</tt>, +from_hms+.
  def test_from_hms
    [
      [0, 0, 0, T::UtcOffset::UTC],
      [0, 0, 1, offset(0, 0, 1)],
      [0, 0, -1, offset(0, 0, -1)],
      [1, 0, 0, offset(1, 0, 0)],
      [-1, 0, 0, offset(-1, 0, 0)],
      [23, 59, 0, offset(23, 59, 0)],
      [-23, -59, 0, offset(-23, -59, 0)],
      [23, 59, 59, offset(23, 59, 59)],
      [-23, -59, -59, offset(-23, -59, -59)],
      [1, 2, 3, offset(1, 2, 3)],
      [1, -2, -3, offset(1, 2, 3)],
      [0, 2, -3, offset(0, 2, 3)],
    ].each do |hours, minutes, seconds, expected|
      assert_case expected, T::UtcOffset.from_hms(hours, minutes, seconds)
    end
  end

  # <tt>utc_offset.rs:44</tt>, +from_whole_seconds+.
  def test_from_whole_seconds
    [
      [0, T::UtcOffset::UTC],
      [1, offset(0, 0, 1)],
      [-1, offset(0, 0, -1)],
      [3_600, offset(1, 0, 0)],
      [-3_600, offset(-1, 0, 0)],
      [86_340, offset(23, 59, 0)],
      [-86_340, offset(-23, -59, 0)],
      [86_399, offset(23, 59, 59)],
      [-86_399, offset(-23, -59, -59)],
    ].each do |seconds, expected|
      assert_case expected, T::UtcOffset.from_whole_seconds(seconds)
    end
  end

  # <tt>utc_offset.rs:58</tt>, +as_hms+.
  def test_as_hms
    [
      [T::UtcOffset::UTC, [0, 0, 0]],
      [offset(0, 0, 1), [0, 0, 1]],
      [offset(0, 0, -1), [0, 0, -1]],
      [offset(1, 0, 0), [1, 0, 0]],
      [offset(-1, 0, 0), [-1, 0, 0]],
      [offset(23, 59, 0), [23, 59, 0]],
      [offset(-23, -59, 0), [-23, -59, 0]],
      [offset(23, 59, 59), [23, 59, 59]],
      [offset(-23, -59, -59), [-23, -59, -59]],
    ].each do |offset, expected|
      assert_case expected, offset.as_hms
    end
  end

  # <tt>utc_offset.rs:65</tt>, +whole_hours+.
  def test_whole_hours
    [
      [offset(1, 2, 3), 1],
      [offset(-1, -2, -3), -1],
    ].each do |offset, expected|
      assert_case expected, offset.whole_hours
    end
  end

  # <tt>utc_offset.rs:72</tt>, +whole_minutes+.
  def test_whole_minutes
    [
      [offset(1, 2, 3), 62],
      [offset(-1, -2, -3), -62],
    ].each do |offset, expected|
      assert_case expected, offset.whole_minutes
    end
  end

  # <tt>utc_offset.rs:79</tt>, +minutes_past_hour+.
  def test_minutes_past_hour
    [
      [offset(1, 2, 3), 2],
      [offset(-1, -2, -3), -2],
    ].each do |offset, expected|
      assert_case expected, offset.minutes_past_hour
    end
  end

  # <tt>utc_offset.rs:93</tt>, +whole_seconds+.
  def test_whole_seconds
    [
      [T::UtcOffset::UTC, 0],
      [offset(0, 0, 1), 1],
      [offset(0, 0, -1), -1],
      [offset(1, 0, 0), 3_600],
      [offset(-1, 0, 0), -3_600],
      [offset(23, 59, 0), 86_340],
      [offset(-23, -59, 0), -86_340],
      [offset(23, 59, 59), 86_399],
      [offset(-23, -59, -59), -86_399],
    ].each do |offset, expected|
      assert_case expected, offset.whole_seconds
    end
  end

  # <tt>utc_offset.rs:100</tt>, +seconds_past_minute+.
  def test_seconds_past_minute
    [
      [offset(1, 2, 3), 3],
      [offset(-1, -2, -3), -3],
    ].each do |offset, expected|
      assert_case expected, offset.seconds_past_minute
    end
  end

  # <tt>utc_offset.rs:114</tt>, +is_utc+.
  def test_is_utc
    [
      [T::UtcOffset::UTC, true],
      [offset(0, 0, 1), false],
      [offset(0, 0, -1), false],
      [offset(1, 0, 0), false],
      [offset(-1, 0, 0), false],
      [offset(23, 59, 0), false],
      [offset(-23, -59, 0), false],
      [offset(23, 59, 59), false],
      [offset(-23, -59, -59), false],
    ].each do |offset, expected|
      assert_case expected, offset.is_utc
    end
  end

  # <tt>utc_offset.rs:128</tt>, +is_positive+.
  def test_is_positive
    [
      [T::UtcOffset::UTC, false],
      [offset(0, 0, 1), true],
      [offset(0, 0, -1), false],
      [offset(1, 0, 0), true],
      [offset(-1, 0, 0), false],
      [offset(23, 59, 0), true],
      [offset(-23, -59, 0), false],
      [offset(23, 59, 59), true],
      [offset(-23, -59, -59), false],
    ].each do |offset, expected|
      assert_case expected, offset.is_positive
    end
  end

  # <tt>utc_offset.rs:142</tt>, +is_negative+.
  def test_is_negative
    [
      [T::UtcOffset::UTC, false],
      [offset(0, 0, 1), false],
      [offset(0, 0, -1), true],
      [offset(1, 0, 0), false],
      [offset(-1, 0, 0), true],
      [offset(23, 59, 0), false],
      [offset(-23, -59, 0), true],
      [offset(23, 59, 59), false],
      [offset(-23, -59, -59), true],
    ].each do |offset, expected|
      assert_case expected, offset.is_negative
    end
  end

  # <tt>utc_offset.rs:157</tt>, +ordering+.
  def test_ordering
    [
      [T::UtcOffset::UTC, T::UtcOffset::UTC, 0],
      [offset(1, 0, 0), offset(1, 0, 0), 0],
      [offset(-1, 0, 0), offset(-1, 0, 0), 0],
      [offset(1, 0, 0), T::UtcOffset::UTC, 1],
      [T::UtcOffset::UTC, offset(-1, 0, 0), 1],
      [offset(-1, 0, 0), offset(1, 0, 0), -1],
      [offset(23, 59, 0), offset(23, 58, 0), 1],
      [offset(-23, -59, 0), offset(-23, -58, 0), -1],
      [offset(23, 59, 59), offset(23, 59, 58), 1],
      [offset(-23, -59, -59), offset(-23, -59, -58), -1],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>utc_offset.rs:171</tt>, +neg+.
  def test_neg
    [
      [T::UtcOffset::UTC, T::UtcOffset::UTC],
      [offset(0, 0, 1), offset(0, 0, -1)],
      [offset(0, 0, -1), offset(0, 0, 1)],
      [offset(1, 0, 0), offset(-1, 0, 0)],
      [offset(-1, 0, 0), offset(1, 0, 0)],
      [offset(23, 59, 0), offset(-23, -59, 0)],
      [offset(-23, -59, 0), offset(23, 59, 0)],
      [offset(23, 59, 59), offset(-23, -59, -59)],
      [offset(-23, -59, -59), offset(23, 59, 59)],
    ].each do |offset, expected|
      assert_case expected, -offset
    end
  end

  # <tt>utc_offset.rs:176</tt>, +local_offset_at+: Rust's +is_ok+ is not
  # raising here.
  def test_local_offset_at
    assert_instance_of T::UtcOffset, T::UtcOffset.local_offset_at(T::OffsetDateTime::UNIX_EPOCH)
  end

  # <tt>utc_offset.rs:181</tt>, +current_local_offset+.
  def test_current_local_offset
    assert_instance_of T::UtcOffset, T::UtcOffset.current_local_offset
  end

  # <tt>utc_offset.rs:186</tt>, +local_offset_success_when_multithreaded+,
  # from a Ruby Thread.
  def test_local_offset_success_when_multithreaded
    assert_instance_of T::UtcOffset, Thread.new { T::UtcOffset.current_local_offset }.value
  end
end

#--
# SPDX-SnippetEnd
#++
