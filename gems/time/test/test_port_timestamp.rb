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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/timestamp.rs
#++

# time's own tests in <tt>tests/integration/timestamp.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. The cases that
# take std's Duration (<tt>add_std_duration</tt>, <tt>add_std_panics</tt>,
# <tt>sub_std_duration</tt>, <tt>sub_std_panics</tt>,
# <tt>add_assign_std_duration</tt>, <tt>sub_assign_std_duration</tt>) wait
# with std's Duration (plan 009, decision 18), and
# <tt>system_time_sub_timestamp</tt> needs <tt>Sub</tt> with a SystemTime on
# the left, which would change Ruby's ::Time (plan 007, decision 10); it
# pins Ruby's own refusal instead. The rest are all here.
class TestPortTimestamp < Minitest::Test
  include TimeSuite

  # time's <tt>timestamp!(1_546_398_245.006)</tt> for a decimal number: the
  # whole part, and a fraction of at most nine digits. A negative number is
  # the seconds below it and the complement of the fraction, as the macro
  # builds it (time-macros 0.2.32 <tt>src/timestamp.rs:55-110</tt>).
  private def stamp(text)
    negative = text.start_with?("-")
    whole, fraction = text.delete("_").delete_prefix("-").split(".")
    seconds = whole.to_i
    nanos = fraction ? fraction.ljust(9, "0").to_i : 0
    return T::Timestamp.new(seconds, nanos) unless negative
    return T::Timestamp.new(-seconds, 0) unless fraction

    T::Timestamp.new(-seconds - 1, 1_000_000_000 - nanos)
  end

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

  private def assert_refused(message, &)
    error = assert_raises(RangeError, &)
    assert_equal message, error.message
  end

  # <tt>timestamp.rs:13</tt>, +unix_epoch+.
  def test_unix_epoch
    assert_equal 0, T::Timestamp::UNIX_EPOCH.as_seconds
    assert_equal 0, T::Timestamp::UNIX_EPOCH.as_nanoseconds
  end

  # <tt>timestamp.rs:27</tt>, +new+.
  def test_new
    [
      [0, 0, stamp("0")],
      [1, 0, stamp("1")],
      [-1, 0, stamp("-1")],
      [1_546_398_245, 0, stamp("1_546_398_245")],
      [1_546_398_245, 1, stamp("1_546_398_245.000_000_001")],
      [(2 ** 63) - 1, 0, nil],
      [-(2 ** 63), 0, nil],
      [0, 1_000_000_000, nil],
    ].each do |seconds, nanoseconds, expected|
      assert_case expected, ok { T::Timestamp.new(seconds, nanoseconds) }
    end
  end

  # <tt>timestamp.rs:41</tt>, +from_seconds+.
  def test_from_seconds
    [
      [0, stamp("0")],
      [1, stamp("1")],
      [-1, stamp("-1")],
      [(2 ** 63) - 1, nil],
      [-(2 ** 63), nil],
    ].each do |seconds, expected|
      assert_case expected, ok { T::Timestamp.from_seconds(seconds) }
    end
  end

  # <tt>timestamp.rs:56</tt>, +from_milliseconds+.
  def test_from_milliseconds
    [
      [0, stamp("0")],
      [1_000, stamp("1")],
      [-1_000, stamp("-1")],
      [1_546_398_245_006, stamp("1_546_398_245.006")],
      [1_500, stamp("1.500")],
      [-1_500, stamp("-1.500")],
      [-500, stamp("-0.500")],
      [500, stamp("0.500")],
      [(2 ** 63) - 1, nil],
      [-(2 ** 63), nil],
    ].each do |milliseconds, expected|
      assert_case expected, ok { T::Timestamp.from_milliseconds(milliseconds) }
    end
  end

  # <tt>timestamp.rs:73</tt>, +from_microseconds+.
  def test_from_microseconds
    [
      [0, stamp("0")],
      [1_000_000, stamp("1")],
      [-1_000_000, stamp("-1")],
      [1_546_398_245_006_007, stamp("1_546_398_245.006_007")],
      [1_500_000, stamp("1.500_000")],
      [-1_500_000, stamp("-1.500_000")],
      [-500_000, stamp("-0.500_000")],
      [(2 ** 127) - 1, nil],
      [-(2 ** 127), nil],
    ].each do |microseconds, expected|
      assert_case expected, ok { T::Timestamp.from_microseconds(microseconds) }
    end
  end

  # <tt>timestamp.rs:90</tt>, +from_nanoseconds+.
  def test_from_nanoseconds
    [
      [0, stamp("0")],
      [1_000_000_000, stamp("1")],
      [-1_000_000_000, stamp("-1")],
      [1_546_398_245_006_007_008, stamp("1_546_398_245.006_007_008")],
      [1_500_000_000, stamp("1.500_000_000")],
      [-1_500_000_000, stamp("-1.500_000_000")],
      [-500_000_000, stamp("-0.500_000_000")],
      [(2 ** 127) - 1, nil],
      [-(2 ** 127), nil],
    ].each do |nanoseconds, expected|
      assert_case expected, ok { T::Timestamp.from_nanoseconds(nanoseconds) }
    end
  end

  # <tt>timestamp.rs:100</tt>, +to_offset+.
  def test_to_offset
    [
      [stamp("0"), T::UtcOffset::UTC, 0],
      [stamp("1_546_398_245"), offset(1), 4],
    ].each do |ts, offset_value, expected_hour|
      assert_equal expected_hour, ts.to_offset(offset_value).hour
    end
  end

  # <tt>timestamp.rs:108</tt>, +checked_to_offset+.
  def test_checked_to_offset
    [
      [stamp("1_546_398_245"), offset(1), true],
      [T::Timestamp::MAX, offset(1), false],
      [T::Timestamp::MIN, offset(-1), false],
    ].each do |ts, offset_value, expected|
      assert_equal expected, !ts.checked_to_offset(offset_value).nil?
    end
  end

  # <tt>timestamp.rs:115</tt>, +to_utc+.
  def test_to_utc
    [
      [stamp("0"), T::UtcDateTime::UNIX_EPOCH],
      [stamp("1_546_398_245"), utc(2019, 1, 2, 3, 4, 5)],
    ].each do |ts, expected|
      assert_equal expected, ts.to_utc
    end
  end

  # <tt>timestamp.rs:124</tt>, +as_seconds+.
  def test_as_seconds
    [
      [stamp("0"), 0],
      [stamp("-1"), -1],
      [stamp("1_546_398_245"), 1_546_398_245],
      [stamp("1_546_398_245.006_007_008"), 1_546_398_245],
    ].each do |ts, expected|
      assert_equal expected, ts.as_seconds
    end
  end

  # <tt>timestamp.rs:134</tt>, +as_milliseconds+.
  def test_as_milliseconds
    [
      [stamp("0"), 0],
      [stamp("1"), 1_000],
      [stamp("-1"), -1_000],
      [stamp("1_546_398_245.006"), 1_546_398_245_006],
      [stamp("1_546_398_245.006_007_008"), 1_546_398_245_006],
    ].each do |ts, expected|
      assert_equal expected, ts.as_milliseconds
    end
  end

  # <tt>timestamp.rs:144</tt>, +as_microseconds+.
  def test_as_microseconds
    [
      [stamp("0"), 0],
      [stamp("1"), 1_000_000],
      [stamp("-1"), -1_000_000],
      [stamp("1_546_398_245.006_007"), 1_546_398_245_006_007],
      [stamp("1_546_398_245.006_007_008"), 1_546_398_245_006_007],
    ].each do |ts, expected|
      assert_equal expected, ts.as_microseconds
    end
  end

  # <tt>timestamp.rs:153</tt>, +as_nanoseconds+.
  def test_as_nanoseconds
    [
      [stamp("0"), 0],
      [stamp("1"), 1_000_000_000],
      [stamp("-1"), -1_000_000_000],
      [stamp("1_546_398_245.006_007_008"), 1_546_398_245_006_007_008],
    ].each do |ts, expected|
      assert_equal expected, ts.as_nanoseconds
    end
  end

  # <tt>timestamp.rs:161</tt>, +date+.
  def test_date
    [
      [stamp("0"), date(1970, 1, 1)],
      [stamp("1_546_398_245"), date(2019, 1, 2)],
      [stamp("-1"), date(1969, 12, 31)],
    ].each do |ts, expected|
      assert_equal expected, ts.date
    end
  end

  # <tt>timestamp.rs:168</tt>, +time_+.
  def test_time_
    [
      [stamp("0"), clock(0, 0)],
      [stamp("1_546_398_245"), clock(3, 4, 5)],
    ].each do |ts, expected|
      assert_equal expected, ts.time
    end
  end

  # <tt>timestamp.rs:176</tt>, +year+.
  def test_year
    [[stamp("0"), 1970], [stamp("1_546_398_245"), 2019], [stamp("-1"), 1969]].each do |ts, expected|
      assert_equal expected, ts.year
    end
  end

  # <tt>timestamp.rs:183</tt>, +month+.
  def test_month
    [[stamp("0"), Month::January], [stamp("1_546_398_245"), Month::January]].each do |ts, expected|
      assert_equal expected, ts.month
    end
  end

  # <tt>timestamp.rs:190</tt>, +day+.
  def test_day
    [[stamp("0"), 1], [stamp("1_546_398_245"), 2]].each do |ts, expected|
      assert_equal expected, ts.day
    end
  end

  # <tt>timestamp.rs:197</tt>, +ordinal+.
  def test_ordinal
    [[stamp("0"), 1], [stamp("1_546_398_245"), 2]].each do |ts, expected|
      assert_equal expected, ts.ordinal
    end
  end

  # <tt>timestamp.rs:204</tt>, +iso_week+.
  def test_iso_week
    [[stamp("0"), 1], [stamp("1_546_398_245"), 1]].each do |ts, expected|
      assert_equal expected, ts.iso_week
    end
  end

  # <tt>timestamp.rs:211</tt>, +sunday_based_week+.
  def test_sunday_based_week
    [[stamp("0"), 0], [stamp("1_546_398_245"), 0]].each do |ts, expected|
      assert_equal expected, ts.sunday_based_week
    end
  end

  # <tt>timestamp.rs:218</tt>, +monday_based_week+.
  def test_monday_based_week
    [[stamp("0"), 0], [stamp("1_546_398_245"), 0]].each do |ts, expected|
      assert_equal expected, ts.monday_based_week
    end
  end

  # <tt>timestamp.rs:225</tt>, +to_calendar_date+.
  def test_to_calendar_date
    [
      [stamp("0"), [1970, Month::January, 1]],
      [stamp("1_546_398_245"), [2019, Month::January, 2]],
    ].each do |ts, expected|
      assert_equal expected, ts.to_calendar_date
    end
  end

  # <tt>timestamp.rs:232</tt>, +to_ordinal_date+.
  def test_to_ordinal_date
    [[stamp("0"), [1970, 1]], [stamp("1_546_398_245"), [2019, 2]]].each do |ts, expected|
      assert_equal expected, ts.to_ordinal_date
    end
  end

  # <tt>timestamp.rs:239</tt>, +to_iso_week_date+.
  def test_to_iso_week_date
    [
      [stamp("0"), [1970, 1, Weekday::Thursday]],
      [stamp("1_546_398_245"), [2019, 1, Weekday::Wednesday]],
    ].each do |ts, expected|
      assert_equal expected, ts.to_iso_week_date
    end
  end

  # <tt>timestamp.rs:246</tt>, +weekday+.
  def test_weekday
    [[stamp("0"), Weekday::Thursday], [stamp("1_546_398_245"), Weekday::Wednesday]].each do |ts, expected|
      assert_equal expected, ts.weekday
    end
  end

  # <tt>timestamp.rs:260</tt>, +weekday_exhaustive+.
  def test_weekday_exhaustive
    [
      [stamp("0"), Weekday::Thursday],
      [stamp("86_400"), Weekday::Friday],
      [stamp("172_800"), Weekday::Saturday],
      [stamp("259_200"), Weekday::Sunday],
      [stamp("345_600"), Weekday::Monday],
      [stamp("432_000"), Weekday::Tuesday],
      [stamp("518_400"), Weekday::Wednesday],
      [stamp("22_118_400"), Weekday::Monday],
      [stamp("-22_118_400"), Weekday::Sunday],
    ].each do |ts, expected|
      assert_equal expected, ts.weekday
    end
  end

  # <tt>timestamp.rs:267</tt>, +as_hms+.
  def test_as_hms
    [[stamp("0"), [0, 0, 0]], [stamp("1_546_398_245"), [3, 4, 5]]].each do |ts, expected|
      assert_equal expected, ts.as_hms
    end
  end

  # <tt>timestamp.rs:274</tt>, +as_hms_milli+.
  def test_as_hms_milli
    [[stamp("0"), [0, 0, 0, 0]], [stamp("1_546_398_245.006"), [3, 4, 5, 6]]].each do |ts, expected|
      assert_equal expected, ts.as_hms_milli
    end
  end

  # <tt>timestamp.rs:281</tt>, +as_hms_micro+.
  def test_as_hms_micro
    [[stamp("0"), [0, 0, 0, 0]], [stamp("1_546_398_245.006_007"), [3, 4, 5, 6_007]]].each do |ts, expected|
      assert_equal expected, ts.as_hms_micro
    end
  end

  # <tt>timestamp.rs:288</tt>, +as_hms_nano+.
  def test_as_hms_nano
    [[stamp("0"), [0, 0, 0, 0]], [stamp("1_546_398_245.006_007_008"), [3, 4, 5, 6_007_008]]].each do |ts, expected|
      assert_equal expected, ts.as_hms_nano
    end
  end

  # <tt>timestamp.rs:296</tt>, +hour+.
  def test_hour
    [[stamp("0"), 0], [stamp("1_546_398_245"), 3], [stamp("86_399"), 23]].each do |ts, expected|
      assert_equal expected, ts.hour
    end
  end

  # <tt>timestamp.rs:306</tt>, +minute+.
  def test_minute
    [
      [stamp("0"), 0],
      [stamp("1_546_398_245"), 4],
      [stamp("86_340"), 59],
      [stamp("-1"), 59],
      [stamp("-61"), 58],
    ].each do |ts, expected|
      assert_equal expected, ts.minute
    end
  end

  # <tt>timestamp.rs:314</tt>, +second+.
  def test_second
    [[stamp("0"), 0], [stamp("1_546_398_245"), 5], [stamp("86_399"), 59]].each do |ts, expected|
      assert_equal expected, ts.second
    end
  end

  # <tt>timestamp.rs:322</tt>, +millisecond+.
  def test_millisecond
    [[stamp("0"), 0], [stamp("1_546_398_245.006"), 6], [stamp("1_546_398_245.999"), 999]].each do |ts, expected|
      assert_equal expected, ts.millisecond
    end
  end

  # <tt>timestamp.rs:330</tt>, +microsecond+.
  def test_microsecond
    [
      [stamp("0"), 0],
      [stamp("1_546_398_245.006_007"), 6_007],
      [stamp("1_546_398_245.999_999"), 999_999],
    ].each do |ts, expected|
      assert_equal expected, ts.microsecond
    end
  end

  # <tt>timestamp.rs:338</tt>, +nanosecond+.
  def test_nanosecond
    [
      [stamp("0"), 0],
      [stamp("1_546_398_245.006_007_008"), 6_007_008],
      [stamp("1_546_398_245.999_999_999"), 999_999_999],
    ].each do |ts, expected|
      assert_equal expected, ts.nanosecond
    end
  end

  # <tt>timestamp.rs:347</tt>, +replace_time+.
  def test_replace_time
    [
      [stamp("1_546_398_245"), clock(12, 34, 56, 789_000_000), stamp("1_546_432_496.789")],
      [stamp("1_546_398_245"), clock(23, 59, 59), stamp("1_546_473_599")],
      [stamp("-1"), clock(0, 0), stamp("-86_400")],
      [stamp("-86_401"), clock(0, 0), stamp("-172_800")],
    ].each do |ts, replacement, expected|
      assert_equal expected, ts.replace_time(replacement)
    end
  end

  # <tt>timestamp.rs:353</tt>, +replace_date+.
  def test_replace_date
    [[stamp("1_546_398_245"), date(2020, 1, 2), stamp("1_577_934_245")]].each do |ts, replacement, expected|
      assert_equal expected, ts.replace_date(replacement)
    end
  end

  # <tt>timestamp.rs:361</tt>, +replace_year+.
  def test_replace_year
    [
      [stamp("1_546_398_245"), 2020, stamp("1_577_934_245")],
      [stamp("1_546_398_245"), -1_000_000, nil],
      [stamp("1_546_398_245"), 1_000_000, nil],
    ].each do |ts, year, expected|
      assert_case expected, ok { ts.replace_year(year) }
    end
  end

  # <tt>timestamp.rs:372</tt>, +replace_month+.
  def test_replace_month
    [
      [stamp("1_546_398_245"), Month::February, stamp("1_549_076_645")],
      [stamp("1_548_817_445"), Month::February, nil],
    ].each do |ts, month, expected|
      assert_case expected, ok { ts.replace_month(month) }
    end
  end

  # <tt>timestamp.rs:384</tt>, +replace_day+.
  def test_replace_day
    [
      [stamp("1_546_398_245"), 1, stamp("1_546_311_845")],
      [stamp("1_546_398_245"), 0, nil],
      [stamp("1_546_398_245"), 32, nil],
    ].each do |ts, day, expected|
      assert_case expected, ok { ts.replace_day(day) }
    end
  end

  # <tt>timestamp.rs:396</tt>, +replace_ordinal+.
  def test_replace_ordinal
    [
      [stamp("1_546_398_245"), 1, stamp("1_546_311_845")],
      [stamp("1_546_398_245"), 0, nil],
      [stamp("1_546_398_245"), 366, nil],
    ].each do |ts, ordinal, expected|
      assert_case expected, ok { ts.replace_ordinal(ordinal) }
    end
  end

  # <tt>timestamp.rs:409</tt>, +replace_hour+.
  def test_replace_hour
    [
      [stamp("1_546_398_245"), 0, stamp("1_546_387_445")],
      [stamp("1_546_398_245"), 24, nil],
      [stamp("-1"), 0, stamp("-82_801")],
      [stamp("-86_401"), 0, stamp("-169_201")],
    ].each do |ts, hour, expected|
      assert_case expected, ok { ts.replace_hour(hour) }
    end
  end

  # <tt>timestamp.rs:422</tt>, +replace_minute+.
  def test_replace_minute
    [
      [stamp("1_546_398_245"), 0, stamp("1_546_398_005")],
      [stamp("1_546_398_245"), 60, nil],
      [stamp("-1"), 0, stamp("-3_541")],
      [stamp("-86_401"), 0, stamp("-89_941")],
    ].each do |ts, minute, expected|
      assert_case expected, ok { ts.replace_minute(minute) }
    end
  end

  # <tt>timestamp.rs:435</tt>, +replace_second+.
  def test_replace_second
    [
      [stamp("1_546_398_245"), 0, stamp("1_546_398_240")],
      [stamp("1_546_398_245"), 60, nil],
      [stamp("-1"), 0, stamp("-60")],
      [stamp("-86_401"), 0, stamp("-86_460")],
    ].each do |ts, second, expected|
      assert_case expected, ok { ts.replace_second(second) }
    end
  end

  # <tt>timestamp.rs:456</tt>, +replace_millisecond+.
  def test_replace_millisecond
    [
      [stamp("1_546_398_245.006"), 7, stamp("1_546_398_245.007")],
      [stamp("1_546_398_245.006"), 1_000, nil],
      [stamp("-1"), 400, stamp("-0.6")],
      [stamp("-1.5"), 400, stamp("-1.4")],
      [stamp("-1.5"), 0, stamp("-1")],
      [stamp("-1"), 0, stamp("-1")],
      [T::Timestamp::MIN, 0, T::Timestamp::MIN],
      [T::Timestamp::MIN, 1, ok { T::Timestamp.new(T::Timestamp::MIN.as_seconds, 1_000_000) }],
    ].each do |ts, millisecond, expected|
      assert_case expected, ok { ts.replace_millisecond(millisecond) }
    end
  end

  # <tt>timestamp.rs:479</tt>, +replace_microsecond+.
  def test_replace_microsecond
    [
      [stamp("1_546_398_245.006_007"), 123_456, stamp("1_546_398_245.123_456")],
      [stamp("1_546_398_245.006_007"), 1_000_000, nil],
      [stamp("-1_546_398_245.006_007"), 123_456, stamp("-1_546_398_245.123_456")],
      [stamp("-1_546_398_245.006_007"), 0, stamp("-1_546_398_245")],
      [T::Timestamp::MIN, 0, T::Timestamp::MIN],
      [T::Timestamp::MIN, 1, ok { T::Timestamp.new(T::Timestamp::MIN.as_seconds, 1_000) }],
    ].each do |ts, microsecond, expected|
      assert_case expected, ok { ts.replace_microsecond(microsecond) }
    end
  end

  # <tt>timestamp.rs:505</tt>, +replace_nanosecond+.
  def test_replace_nanosecond
    [
      [stamp("1_546_398_245.006_007_008"), 123_456_789, stamp("1_546_398_245.123_456_789")],
      [stamp("-1_546_398_245.006_007_008"), 123_456_789, stamp("-1_546_398_245.123_456_789")],
      [stamp("1_546_398_245.006_007_008"), 1_000_000_000, nil],
      [T::Timestamp::MIN, 0, T::Timestamp::MIN],
      [T::Timestamp::MIN, 1, ok { T::Timestamp.new(T::Timestamp::MIN.as_seconds, 1) }],
    ].each do |ts, nanosecond, expected|
      assert_case expected, ok { ts.replace_nanosecond(nanosecond) }
    end
  end

  # <tt>timestamp.rs:518</tt>, +add_duration+.
  def test_add_duration
    [
      [stamp("0"), Duration.days(5), stamp("432_000")],
      [stamp("0"), Duration.days(1), stamp("86_400")],
      [stamp("1_546_398_245"), Duration.days(1), stamp("1_546_484_645")],
      [stamp("1_546_398_245"), Duration.days(-1), stamp("1_546_311_845")],
    ].each do |ts, duration, expected|
      assert_equal expected, ts + duration
    end
  end

  # <tt>timestamp.rs:541</tt>, +add_duration_panics+.
  def test_add_duration_panics
    assert_refused("resulting value is out of range") { T::Timestamp::MAX + Duration.nanoseconds(1) }
  end

  # <tt>timestamp.rs:559</tt>, +sub_duration+.
  def test_sub_duration
    [
      [stamp("432_000"), Duration.days(5), stamp("0")],
      [stamp("86_400"), Duration.days(1), stamp("0")],
      [stamp("1_546_398_245"), Duration.days(1), stamp("1_546_311_845")],
      [stamp("1_546_398_245"), Duration.days(-1), stamp("1_546_484_645")],
    ].each do |ts, duration, expected|
      assert_equal expected, ts - duration
    end
  end

  # <tt>timestamp.rs:582</tt>, +sub_duration_panics+.
  def test_sub_duration_panics
    assert_refused("resulting value is out of range") { T::Timestamp::MIN - Duration.nanoseconds(1) }
  end

  # <tt>timestamp.rs:600</tt>, +add_assign_duration+.
  def test_add_assign_duration
    [
      [stamp("0"), Duration.days(5), stamp("432_000")],
      [stamp("0"), Duration.days(1), stamp("86_400")],
      [stamp("1_546_398_245"), Duration.days(1), stamp("1_546_484_645")],
      [stamp("1_546_398_245"), Duration.days(-1), stamp("1_546_311_845")],
    ].each do |ts, duration, expected|
      ts += duration
      assert_equal expected, ts
    end
  end

  # <tt>timestamp.rs:627</tt>, +sub_assign_duration+.
  def test_sub_assign_duration
    [
      [stamp("432_000"), Duration.days(5), stamp("0")],
      [stamp("86_400"), Duration.days(1), stamp("0")],
      [stamp("1_546_398_245"), Duration.days(1), stamp("1_546_311_845")],
      [stamp("1_546_398_245"), Duration.days(-1), stamp("1_546_484_645")],
    ].each do |ts, duration, expected|
      ts -= duration
      assert_equal expected, ts
    end
  end

  # <tt>timestamp.rs:656</tt>, +sub_timestamp+.
  def test_sub_timestamp
    [
      [stamp("0"), stamp("0"), Duration::ZERO],
      [stamp("0"), stamp("0.000_000_001"), Duration.nanoseconds(-1)],
      [stamp("0.000_000_001"), stamp("0"), Duration.nanoseconds(1)],
      [stamp("-1"), stamp("-2"), Duration.seconds(1)],
      [stamp("1_546_484_645"), stamp("1_546_398_245"), Duration.days(1)],
      [stamp("1_546_398_245"), stamp("1_546_484_645"), Duration.days(-1)],
    ].each do |lhs, rhs, expected|
      assert_equal expected, lhs - rhs
    end
  end

  # <tt>timestamp.rs:675</tt>, +checked_add_duration+.
  def test_checked_add_duration
    [
      [stamp("1_546_398_245"), Duration.nanoseconds(5), stamp("1_546_398_245.000_000_005")],
      [stamp("1_546_398_245"), Duration.seconds(4), stamp("1_546_398_249")],
      [stamp("1_546_398_245"), Duration.days(2), stamp("1_546_571_045")],
      [stamp("1_546_398_245"), Duration.weeks(1), stamp("1_547_003_045")],
      [stamp("1_546_398_245"), Duration.nanoseconds(-5), stamp("1_546_398_244.999_999_995")],
      [stamp("1_546_398_245"), Duration.seconds(-4), stamp("1_546_398_241")],
      [stamp("1_546_398_245"), Duration.days(-2), stamp("1_546_225_445")],
      [stamp("1_546_398_245"), Duration.weeks(-1), stamp("1_545_793_445")],
      [T::Timestamp::MIN, Duration.nanoseconds(-1), nil],
      [T::Timestamp::MAX, Duration.nanoseconds(1), nil],
      [T::Timestamp::MIN, Duration::MIN, nil],
      [T::Timestamp::MAX, Duration::MAX, nil],
      [stamp("0.999_999_999"), Duration.seconds((2 ** 63) - 1) + Duration.nanoseconds(1), nil],
      [stamp("0"), Duration::MIN, nil],
    ].each do |ts, duration, expected|
      assert_case expected, ts.checked_add(duration)
    end
  end

  # <tt>timestamp.rs:696</tt>, +checked_sub_duration+.
  def test_checked_sub_duration
    [
      [stamp("1_546_398_245.000_000_005"), Duration.nanoseconds(5), stamp("1_546_398_245")],
      [stamp("1_546_398_249"), Duration.seconds(4), stamp("1_546_398_245")],
      [stamp("1_546_571_045"), Duration.days(2), stamp("1_546_398_245")],
      [stamp("1_547_003_045"), Duration.weeks(1), stamp("1_546_398_245")],
      [stamp("1_546_398_245"), Duration.days(-1), stamp("1_546_484_645")],
      [stamp("1_546_398_245"), Duration.weeks(-1), stamp("1_547_003_045")],
      [T::Timestamp::MIN, Duration.nanoseconds(1), nil],
      [T::Timestamp::MAX, Duration.nanoseconds(-1), nil],
      [T::Timestamp::MIN, Duration::MIN, nil],
      [T::Timestamp::MIN, Duration::MAX, nil],
      [stamp("-1"), Duration.seconds((2 ** 63) - 1) + Duration.nanoseconds(1), nil],
      [stamp("0.999_999_999"), Duration.seconds(-((2 ** 63) - 1)) - Duration.nanoseconds(1), nil],
    ].each do |ts, duration, expected|
      assert_case expected, ts.checked_sub(duration)
    end
  end

  # <tt>timestamp.rs:711</tt>, +saturating_add_duration+.
  def test_saturating_add_duration
    [
      [stamp("1_546_398_245"), Duration.days(2), stamp("1_546_571_045")],
      [stamp("1_546_398_245"), Duration.days(-2), stamp("1_546_225_445")],
      [T::Timestamp::MIN, Duration.days(-10), T::Timestamp::MIN],
      [T::Timestamp::MAX, Duration.days(10), T::Timestamp::MAX],
      [T::Timestamp::MIN, Duration.nanoseconds(-1), T::Timestamp::MIN],
      [T::Timestamp::MAX, Duration.nanoseconds(1), T::Timestamp::MAX],
    ].each do |ts, duration, expected|
      assert_equal expected, ts.saturating_add(duration)
    end
  end

  # <tt>timestamp.rs:726</tt>, +saturating_sub_duration+.
  def test_saturating_sub_duration
    [
      [stamp("1_546_571_045"), Duration.days(2), stamp("1_546_398_245")],
      [stamp("1_546_571_045"), Duration.days(-2), stamp("1_546_743_845")],
      [T::Timestamp::MIN, Duration.days(10), T::Timestamp::MIN],
      [T::Timestamp::MAX, Duration.days(-10), T::Timestamp::MAX],
      [T::Timestamp::MIN, Duration.nanoseconds(1), T::Timestamp::MIN],
      [T::Timestamp::MAX, Duration.nanoseconds(-1), T::Timestamp::MAX],
    ].each do |ts, duration, expected|
      assert_equal expected, ts.saturating_sub(duration)
    end
  end

  # <tt>timestamp.rs:737</tt>, +add_panics+.
  def test_add_panics
    assert_raises(RangeError) { T::Timestamp::MAX + Duration.nanoseconds(1) }
  end

  # <tt>timestamp.rs:744</tt>, +sub_panics+.
  def test_sub_panics
    assert_raises(RangeError) { T::Timestamp::MIN - Duration.nanoseconds(1) }
  end

  # <tt>timestamp.rs:759</tt>, +ord+.
  def test_ord
    [
      [stamp("0"), stamp("0"), 0],
      [stamp("0"), stamp("1"), -1],
      [stamp("0"), stamp("-1"), 1],
      [stamp("1_546_398_245"), stamp("1_546_398_245"), 0],
      [stamp("1_546_398_245"), stamp("1_546_398_246"), -1],
      [stamp("1_546_398_246"), stamp("1_546_398_245"), 1],
      [stamp("-1"), stamp("0"), -1],
      [stamp("1"), stamp("0"), 1],
      [stamp("0"), stamp("0.000_000_001"), -1],
      [stamp("0.000_000_001"), stamp("0"), 1],
    ].each do |lhs, rhs, expected|
      assert_equal expected, lhs <=> rhs
    end
  end

  # <tt>timestamp.rs:769</tt>, +eq+.
  def test_eq
    [
      [stamp("0"), stamp("0"), true],
      [stamp("0"), stamp("1"), false],
      [stamp("0"), stamp("-1"), false],
      [stamp("1_546_398_245.006_007_008"), stamp("1_546_398_245.006_007_008"), true],
      [stamp("1_546_398_245.006_007_008"), stamp("1_546_398_245.006_007_009"), false],
    ].each do |lhs, rhs, expected|
      assert_equal expected, lhs == rhs
    end
  end

  # <tt>timestamp.rs:776</tt>, +hash+.
  def test_hash
    [[stamp("0"), stamp("0")], [stamp("1_546_398_245"), stamp("1_546_398_245")]].each do |a, b|
      assert_equal a.hash, b.hash
      assert a.eql?(b)
    end
  end

  # <tt>timestamp.rs:798</tt>, +display+.
  def test_display
    [
      [stamp("0"), "0"],
      [stamp("1"), "1"],
      [stamp("-1"), "-1"],
      [stamp("1_234_567_890.001"), "1234567890.001"],
      [stamp("1_234_567_890.123_456_789"), "1234567890.123456789"],
      [stamp("1_234_567_890.123_456"), "1234567890.123456"],
      [stamp("1_234_567_890.123"), "1234567890.123"],
      [stamp("-0.5"), "-0.5"],
      [stamp("-1") + Duration.nanoseconds(400_000_000), "-0.6"],
      [stamp("-123_456_789") + Duration.nanoseconds(123_456_789), "-123456788.876543211"],
    ].each do |ts, expected|
      assert_equal expected, ts.to_s
    end
  end

  # <tt>timestamp.rs:805</tt>, +debug+.
  def test_debug
    [[stamp("0"), "0"], [stamp("1_546_398_245"), "1546398245"]].each do |ts, expected|
      assert_equal expected, ts.debug
    end
  end

  # <tt>timestamp.rs:810</tt>, +now+.
  def test_now
    assert_operator T::Timestamp.now.year, :>=, 2019
  end

  # <tt>timestamp.rs:817</tt>, +to_julian_day+.
  def test_to_julian_day
    [[stamp("0"), 2_440_588], [stamp("1_546_398_245"), 2_458_486]].each do |ts, expected|
      assert_equal expected, ts.to_julian_day
    end
  end

  # <tt>timestamp.rs:822</tt>, +unix_timestamp_format+.
  def test_unix_timestamp_format
    format = fd("[unix_timestamp]")
    assert_equal stamp("1_546_398_245"), T::Timestamp.parse("1546398245", format)
    assert_equal "1546398245", stamp("1_546_398_245").format(format)
  end

  # <tt>timestamp.rs:837</tt>, +from_utc_datetime_into_timestamp+.
  def test_from_utc_datetime_into_timestamp
    [
      [utc(1970, 1, 1, 0, 0), stamp("0")],
      [utc(2019, 1, 2, 3, 4, 5), stamp("1_546_398_245")],
    ].each do |source, expected|
      assert_equal expected, T::Timestamp.from(source)
    end
  end

  # <tt>timestamp.rs:844</tt>, +from_timestamp_into_utc_datetime+.
  def test_from_timestamp_into_utc_datetime
    [
      [stamp("0"), utc(1970, 1, 1, 0, 0)],
      [stamp("1_546_398_245"), utc(2019, 1, 2, 3, 4, 5)],
    ].each do |source, expected|
      assert_equal expected, T::UtcDateTime.from(source)
    end
  end

  # <tt>timestamp.rs:849</tt>, +utc_datetime_sub_timestamp+.
  def test_utc_datetime_sub_timestamp
    assert_equal Duration::ZERO, utc(2019, 1, 2, 3, 4, 5) - stamp("1_546_398_245")
  end

  # <tt>timestamp.rs:857</tt>, +timestamp_utc_datetime_partial_eq+.
  def test_timestamp_utc_datetime_partial_eq
    assert_equal stamp("0"), utc(1970, 1, 1, 0, 0)
    assert_equal utc(1970, 1, 1, 0, 0), stamp("0")
    refute_equal stamp("1"), utc(1970, 1, 1, 0, 0)
  end

  # <tt>timestamp.rs:864</tt>, +timestamp_utc_datetime_partial_ord+.
  def test_timestamp_utc_datetime_partial_ord
    assert_operator stamp("0"), :<, utc(1970, 1, 2, 0, 0)
    assert_operator utc(1970, 1, 2, 0, 0), :>, stamp("0")
  end

  # <tt>timestamp.rs:872</tt>, +from_offset_date_time+.
  def test_from_offset_date_time
    [stamp("0"), stamp("1_546_398_245")].each do |expected|
      assert_equal expected, T::Timestamp.from(T::OffsetDateTime.from_unix_timestamp(expected.as_seconds))
    end
  end

  # <tt>timestamp.rs:882</tt>, +into_offset_date_time+.
  def test_into_offset_date_time
    [stamp("0"), stamp("1_546_398_245")].each do |source|
      odt = T::OffsetDateTime.from(source)
      assert_equal source.as_seconds, odt.unix_timestamp
      assert_equal source.nanosecond, odt.nanosecond
    end
  end

  # <tt>timestamp.rs:891</tt>, +sub_utc_date_time_implicit_utc+.
  def test_sub_utc_date_time_implicit_utc
    [
      [stamp("1") - utc(1970, 1, 1, 0, 0), Duration.seconds(1)],
      [stamp("0") - utc(1970, 1, 1, 0, 0), Duration::ZERO],
    ].each do |result, expected|
      assert_equal expected, result
    end
  end

  # <tt>timestamp.rs:899</tt>, +sub_offset_date_time+.
  def test_sub_offset_date_time
    assert_equal Duration.seconds(86_400), T::OffsetDateTime.from_unix_timestamp(1_546_398_245) - stamp("1_546_311_845")
    assert_equal Duration.seconds(-86_400), stamp("1_546_311_845") - T::OffsetDateTime.from_unix_timestamp(1_546_398_245)
  end

  # <tt>timestamp.rs:908</tt>, +eq_offset_date_time+.
  def test_eq_offset_date_time
    odt = T::OffsetDateTime.from_unix_timestamp(0)
    assert_equal stamp("0"), odt
    assert_equal odt, stamp("0")
    refute_equal stamp("1"), odt
  end

  # <tt>timestamp.rs:915</tt>, +ord_offset_date_time+.
  def test_ord_offset_date_time
    assert_operator stamp("86_400"), :>, T::OffsetDateTime.from_unix_timestamp(0)
    assert_operator stamp("0"), :<, T::OffsetDateTime.from_unix_timestamp(86_400)
    assert_operator T::OffsetDateTime.from_unix_timestamp(86_400), :>, stamp("0")
  end

  # <tt>timestamp.rs:923</tt>, +from_system_time_into_timestamp+.
  def test_from_system_time_into_timestamp
    assert_equal stamp("0"), T::Timestamp.from(::Time.at(0))
    assert_equal T::Timestamp.from_milliseconds(-5_001), T::Timestamp.from(::Time.at(0, -5_001, :millisecond))
    assert_equal T::Timestamp.from_milliseconds(5_001), T::Timestamp.from(::Time.at(0, 5_001, :millisecond))
  end

  # <tt>timestamp.rs:940</tt>, +from_timestamp_into_system_time+.
  def test_from_timestamp_into_system_time
    assert_equal ::Time.at(0), stamp("0").to_time
  end

  # <tt>timestamp.rs:946</tt>, +timestamp_sub_system_time+.
  def test_timestamp_sub_system_time
    assert_equal Duration.seconds(86_400), stamp("86_400") - ::Time.at(0)
    assert_equal Duration.seconds(5), stamp("0") - ::Time.at(-5)
  end

  # <tt>timestamp.rs:954</tt>, +system_time_sub_timestamp+: Sub with a
  # SystemTime on the left is Ruby's own ::Time#-, which refuses the
  # Timestamp (plan 007, decision 10).
  def test_system_time_sub_timestamp
    assert_raises(TypeError) { ::Time.at(0) - stamp("0") }
  end

  # <tt>timestamp.rs:962</tt>, +timestamp_system_time_partial_eq+.
  def test_timestamp_system_time_partial_eq
    assert_equal stamp("0"), ::Time.at(0)
    assert_equal ::Time.at(0), stamp("0")
    refute_equal stamp("1"), ::Time.at(0)
  end

  # <tt>timestamp.rs:969</tt>, +timestamp_system_time_partial_ord+.
  def test_timestamp_system_time_partial_ord
    assert_operator stamp("0"), :<, ::Time.at(1)
    assert_operator ::Time.at(1), :>, stamp("0")
  end

  # <tt>timestamp.rs:975</tt>, +format_into_timestamp+.
  def test_format_into_timestamp
    output = +""
    assert_equal 10, stamp("1_546_398_245").format_into(output, fd("[unix_timestamp]"))
    assert_equal "1546398245", output
  end
end

#--
# SPDX-SnippetEnd
#++
