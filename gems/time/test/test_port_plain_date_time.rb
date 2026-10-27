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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/plain_date_time.rs
#++

# time's own tests in <tt>tests/integration/plain_date_time.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortPlainDateTime < Minitest::Test
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

  # <tt>plain_date_time.rs:10</tt>, +new+.
  def test_new
    [
      [T::PlainDateTime.new(date(2019, 1, 1), clock(0, 0, 0, 0)), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0)],
    ].each do |input, expected|
      assert_case expected, input
    end
  end

  # <tt>plain_date_time.rs:16</tt>, +date+.
  def test_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1)],
    ].each do |datetime, expected|
      assert_case expected, datetime.date
    end
  end

  # <tt>plain_date_time.rs:22</tt>, +time_+.
  def test_time_
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), clock(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.time
    end
  end

  # <tt>plain_date_time.rs:30</tt>, +year+.
  def test_year
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 2019],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), 2019],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), 2020],
    ].each do |datetime, expected|
      assert_case expected, datetime.year
    end
  end

  # <tt>plain_date_time.rs:37</tt>, +month+.
  def test_month
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), Month::January],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), Month::December],
    ].each do |datetime, expected|
      assert_case expected, datetime.month
    end
  end

  # <tt>plain_date_time.rs:44</tt>, +day+.
  def test_day
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), 31],
    ].each do |datetime, expected|
      assert_case expected, datetime.day
    end
  end

  # <tt>plain_date_time.rs:51</tt>, +ordinal+.
  def test_ordinal
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), 365],
    ].each do |datetime, expected|
      assert_case expected, datetime.ordinal
    end
  end

  # <tt>plain_date_time.rs:61</tt>, +iso_week+.
  def test_iso_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 10, 4).with_hms_nano(0, 0, 0, 0), 40],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0), 53],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0), 53],
    ].each do |datetime, expected|
      assert_case expected, datetime.iso_week
    end
  end

  # <tt>plain_date_time.rs:70</tt>, +sunday_based_week+.
  def test_sunday_based_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0), 52],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
    ].each do |datetime, expected|
      assert_case expected, datetime.sunday_based_week
    end
  end

  # <tt>plain_date_time.rs:79</tt>, +monday_based_week+.
  def test_monday_based_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0), 52],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
    ].each do |datetime, expected|
      assert_case expected, datetime.monday_based_week
    end
  end

  # <tt>plain_date_time.rs:85</tt>, +to_calendar_date+.
  def test_to_calendar_date
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0), [2019, Month::January, 2]],
    ].each do |datetime, expected|
      assert_case expected, datetime.to_calendar_date
    end
  end

  # <tt>plain_date_time.rs:91</tt>, +to_ordinal_date+.
  def test_to_ordinal_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), [2019, 1]],
    ].each do |datetime, expected|
      assert_case expected, datetime.to_ordinal_date
    end
  end

  # <tt>plain_date_time.rs:101</tt>, +to_iso_week_date+.
  def test_to_iso_week_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), [2019, 1, Weekday::Tuesday]],
      [date(2019, 10, 4).with_hms_nano(0, 0, 0, 0), [2019, 40, Weekday::Friday]],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), [2020, 1, Weekday::Wednesday]],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0), [2020, 53, Weekday::Thursday]],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0), [2020, 53, Weekday::Friday]],
    ].each do |datetime, expected|
      assert_case expected, datetime.to_iso_week_date
    end
  end

  # <tt>plain_date_time.rs:118</tt>, +weekday+.
  def test_weekday
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), Weekday::Tuesday],
      [date(2019, 2, 1).with_hms_nano(0, 0, 0, 0), Weekday::Friday],
      [date(2019, 3, 1).with_hms_nano(0, 0, 0, 0), Weekday::Friday],
      [date(2019, 4, 1).with_hms_nano(0, 0, 0, 0), Weekday::Monday],
      [date(2019, 5, 1).with_hms_nano(0, 0, 0, 0), Weekday::Wednesday],
      [date(2019, 6, 1).with_hms_nano(0, 0, 0, 0), Weekday::Saturday],
      [date(2019, 7, 1).with_hms_nano(0, 0, 0, 0), Weekday::Monday],
      [date(2019, 8, 1).with_hms_nano(0, 0, 0, 0), Weekday::Thursday],
      [date(2019, 9, 1).with_hms_nano(0, 0, 0, 0), Weekday::Sunday],
      [date(2019, 10, 1).with_hms_nano(0, 0, 0, 0), Weekday::Tuesday],
      [date(2019, 11, 1).with_hms_nano(0, 0, 0, 0), Weekday::Friday],
      [date(2019, 12, 1).with_hms_nano(0, 0, 0, 0), Weekday::Sunday],
    ].each do |datetime, expected|
      assert_case expected, datetime.weekday
    end
  end

  # <tt>plain_date_time.rs:128</tt>, +to_julian_day+.
  def test_to_julian_day
    [
      [date(-4713, 11, 24).with_hms_nano(0, 0, 0, 0), 0],
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0), 2_451_545],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 2_458_485],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), 2_458_849],
      # left out: large-dates year -999_999
    ].each do |datetime, expected|
      assert_case expected, datetime.to_julian_day
    end
  end

  # <tt>plain_date_time.rs:134</tt>, +as_hms+.
  def test_as_hms
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 0), [1, 2, 3]],
    ].each do |datetime, expected|
      assert_case expected, datetime.as_hms
    end
  end

  # <tt>plain_date_time.rs:140</tt>, +as_hms_milli+.
  def test_as_hms_milli
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4000000), [1, 2, 3, 4]],
    ].each do |datetime, expected|
      assert_case expected, datetime.as_hms_milli
    end
  end

  # <tt>plain_date_time.rs:146</tt>, +as_hms_micro+.
  def test_as_hms_micro
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4005000), [1, 2, 3, 4_005]],
    ].each do |datetime, expected|
      assert_case expected, datetime.as_hms_micro
    end
  end

  # <tt>plain_date_time.rs:152</tt>, +as_hms_nano+.
  def test_as_hms_nano
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4005006), [1, 2, 3, 4_005_006]],
    ].each do |datetime, expected|
      assert_case expected, datetime.as_hms_nano
    end
  end

  # <tt>plain_date_time.rs:159</tt>, +hour+.
  def test_hour
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0), 23],
    ].each do |datetime, expected|
      assert_case expected, datetime.hour
    end
  end

  # <tt>plain_date_time.rs:166</tt>, +minute+.
  def test_minute
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0), 59],
    ].each do |datetime, expected|
      assert_case expected, datetime.minute
    end
  end

  # <tt>plain_date_time.rs:173</tt>, +second+.
  def test_second
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0), 59],
    ].each do |datetime, expected|
      assert_case expected, datetime.second
    end
  end

  # <tt>plain_date_time.rs:180</tt>, +millisecond+.
  def test_millisecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999000000), 999],
    ].each do |datetime, expected|
      assert_case expected, datetime.millisecond
    end
  end

  # <tt>plain_date_time.rs:187</tt>, +microsecond+.
  def test_microsecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999999000), 999_999],
    ].each do |datetime, expected|
      assert_case expected, datetime.microsecond
    end
  end

  # <tt>plain_date_time.rs:194</tt>, +nanosecond+.
  def test_nanosecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999999999), 999_999_999],
    ].each do |datetime, expected|
      assert_case expected, datetime.nanosecond
    end
  end

  # <tt>plain_date_time.rs:201</tt>, +assume_offset+.
  def test_assume_offset
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), T::UtcOffset::UTC, 1_546_300_800],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), offset(-1, 0, 0), 1_546_304_400],
    ].each do |datetime, offset, expected|
      assert_case expected, datetime.assume_offset(offset).unix_timestamp
    end
  end

  # <tt>plain_date_time.rs:211</tt>, +assume_utc+.
  def test_assume_utc
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1_546_300_800],
    ].each do |datetime, expected|
      assert_case expected, datetime.assume_utc.unix_timestamp
    end
  end

  # <tt>plain_date_time.rs:217</tt>, +replace_time+.
  def test_replace_time
    [
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0), clock(5, 0, 0, 0), date(2020, 1, 1).with_hms_nano(5, 0, 0, 0)],
    ].each do |datetime, replacement, expected|
      assert_case expected, datetime.replace_time(replacement)
    end
  end

  # <tt>plain_date_time.rs:227</tt>, +replace_date+.
  def test_replace_date
    [
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0), date(2020, 1, 30), date(2020, 1, 30).with_hms_nano(12, 0, 0, 0)],
    ].each do |datetime, replacement, expected|
      assert_case expected, datetime.replace_date(replacement)
    end
  end

  # <tt>plain_date_time.rs:239</tt>, +replace_year+.
  def test_replace_year
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), 2019, date(2019, 2, 18).with_hms_nano(12, 0, 0, 0)],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), -1_000_000_000, nil],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), 1_000_000_000, nil],
    ].each do |datetime, year, expected|
      assert_case expected, ok { datetime.replace_year(year) }
    end
  end

  # <tt>plain_date_time.rs:250</tt>, +replace_month+.
  def test_replace_month
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), Month::January, date(2022, 1, 18).with_hms_nano(12, 0, 0, 0)],
      [date(2022, 1, 30).with_hms_nano(12, 0, 0, 0), Month::February, nil],
    ].each do |datetime, month, expected|
      assert_case expected, ok { datetime.replace_month(month) }
    end
  end

  # <tt>plain_date_time.rs:262</tt>, +replace_day+.
  def test_replace_day
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), 1, date(2022, 2, 1).with_hms_nano(12, 0, 0, 0)],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), 0, nil],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), 30, nil],
    ].each do |datetime, day, expected|
      assert_case expected, ok { datetime.replace_day(day) }
    end
  end

  # <tt>plain_date_time.rs:276</tt>, +replace_ordinal+.
  def test_replace_ordinal
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0), 1, T::Date.from_ordinal_date(2022, 1).with_hms_nano(12, 0, 0, 0)],
      [date(2024, 2, 29).with_hms_nano(12, 0, 0, 0), 366, T::Date.from_ordinal_date(2024, 366).with_hms_nano(12, 0, 0, 0)],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0), 0, nil],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0), 366, nil],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0), 367, nil],
    ].each do |datetime, ordinal, expected|
      assert_case expected, ok { datetime.replace_ordinal(ordinal) }
    end
  end

  # <tt>plain_date_time.rs:287</tt>, +replace_hour+.
  def test_replace_hour
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 7, date(2022, 2, 18).with_hms_nano(7, 2, 3, 4005006)],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 24, nil],
    ].each do |datetime, value, expected|
      assert_case expected, ok { datetime.replace_hour(value) }
    end
  end

  # <tt>plain_date_time.rs:298</tt>, +replace_minute+.
  def test_replace_minute
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 7, date(2022, 2, 18).with_hms_nano(1, 7, 3, 4005006)],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 60, nil],
    ].each do |datetime, value, expected|
      assert_case expected, ok { datetime.replace_minute(value) }
    end
  end

  # <tt>plain_date_time.rs:309</tt>, +replace_second+.
  def test_replace_second
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 7, date(2022, 2, 18).with_hms_nano(1, 2, 7, 4005006)],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 60, nil],
    ].each do |datetime, value, expected|
      assert_case expected, ok { datetime.replace_second(value) }
    end
  end

  # <tt>plain_date_time.rs:320</tt>, +replace_millisecond+.
  def test_replace_millisecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 7, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7000000)],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 1_000, nil],
    ].each do |datetime, value, expected|
      assert_case expected, ok { datetime.replace_millisecond(value) }
    end
  end

  # <tt>plain_date_time.rs:331</tt>, +replace_microsecond+.
  def test_replace_microsecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 7_008, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7008000)],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 1_000_000, nil],
    ].each do |datetime, value, expected|
      assert_case expected, ok { datetime.replace_microsecond(value) }
    end
  end

  # <tt>plain_date_time.rs:346</tt>, +replace_nanosecond+.
  def test_replace_nanosecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 7_008_009, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7008009)],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006), 1_000_000_000, nil],
    ].each do |datetime, value, expected|
      assert_case expected, ok { datetime.replace_nanosecond(value) }
    end
  end

  # <tt>plain_date_time.rs:357</tt>, +truncate_to_day+.
  def test_truncate_to_day
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.truncate_to_day
    end
  end

  # <tt>plain_date_time.rs:364</tt>, +truncate_to_hour+.
  def test_truncate_to_hour
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789), date(2021, 11, 12).with_hms_nano(17, 0, 0, 0)],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.truncate_to_hour
    end
  end

  # <tt>plain_date_time.rs:371</tt>, +truncate_to_minute+.
  def test_truncate_to_minute
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789), date(2021, 11, 12).with_hms_nano(17, 47, 0, 0)],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.truncate_to_minute
    end
  end

  # <tt>plain_date_time.rs:378</tt>, +truncate_to_second+.
  def test_truncate_to_second
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789), date(2021, 11, 12).with_hms_nano(17, 47, 53, 0)],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.truncate_to_second
    end
  end

  # <tt>plain_date_time.rs:385</tt>, +truncate_to_millisecond+.
  def test_truncate_to_millisecond
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789), date(2021, 11, 12).with_hms_nano(17, 47, 53, 123000000)],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.truncate_to_millisecond
    end
  end

  # <tt>plain_date_time.rs:392</tt>, +truncate_to_microsecond+.
  def test_truncate_to_microsecond
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789), date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456000)],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, expected|
      assert_case expected, datetime.truncate_to_microsecond
    end
  end

  # <tt>plain_date_time.rs:402</tt>, +add_duration+.
  def test_add_duration
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), Duration.days(5), date(2019, 1, 6).with_hms_nano(0, 0, 0, 0)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), Duration.days(1), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [date(2019, 12, 31).with_hms_nano(23, 59, 59, 0), Duration.seconds(2), date(2020, 1, 1).with_hms_nano(0, 0, 1, 0)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 1, 0), Duration.seconds(-2), date(2019, 12, 31).with_hms_nano(23, 59, 59, 0)],
      [date(1999, 12, 31).with_hms_nano(23, 0, 0, 0), Duration.hours(1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, duration, expected|
      assert_case expected, datetime + duration
    end
  end

  # <tt>plain_date_time.rs:427</tt>, +add_assign_duration+: Ruby's
  # <tt>+=</tt> is <tt>+</tt> and an assignment.
  def test_add_assign_duration
    [
      [datetime(2019, 1, 1), Duration.days(5), datetime(2019, 1, 6)],
      [datetime(2019, 12, 31), Duration.days(1), datetime(2020, 1, 1)],
      [datetime(2019, 12, 31, 23, 59, 59), Duration.seconds(2), datetime(2020, 1, 1, 0, 0, 1)],
      [datetime(2020, 1, 1, 0, 0, 1), Duration.seconds(-2), datetime(2019, 12, 31, 23, 59, 59)],
    ].each do |value, duration, expected|
      value += duration
      assert_case expected, value
    end
  end

  # <tt>plain_date_time.rs:455</tt>, +sub_duration+.
  def test_sub_duration
    [
      [date(2019, 1, 6).with_hms_nano(0, 0, 0, 0), Duration.days(5), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), Duration.days(1), date(2019, 12, 31).with_hms_nano(0, 0, 0, 0)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 1, 0), Duration.seconds(2), date(2019, 12, 31).with_hms_nano(23, 59, 59, 0)],
      [date(2019, 12, 31).with_hms_nano(23, 59, 59, 0), Duration.seconds(-2), date(2020, 1, 1).with_hms_nano(0, 0, 1, 0)],
      [date(1999, 12, 31).with_hms_nano(23, 0, 0, 0), Duration.hours(-1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0)],
    ].each do |datetime, duration, expected|
      assert_case expected, datetime - duration
    end
  end

  # <tt>plain_date_time.rs:480</tt>, +sub_assign_duration+.
  def test_sub_assign_duration
    [
      [datetime(2019, 1, 6), Duration.days(5), datetime(2019, 1, 1)],
      [datetime(2020, 1, 1), Duration.days(1), datetime(2019, 12, 31)],
      [datetime(2020, 1, 1, 0, 0, 1), Duration.seconds(2), datetime(2019, 12, 31, 23, 59, 59)],
      [datetime(2019, 12, 31, 23, 59, 59), Duration.seconds(-2), datetime(2020, 1, 1, 0, 0, 1)],
    ].each do |value, duration, expected|
      value -= duration
      assert_case expected, value
    end
  end

  # <tt>plain_date_time.rs:507</tt>, +sub_datetime+.
  def test_sub_datetime
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), Duration.days(1)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 2).with_hms_nano(0, 0, 0, 0), Duration.days(-1)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), Duration.days(1)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), Duration.days(-1)],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs - rhs
    end
  end

  # <tt>plain_date_time.rs:532</tt>, +ord+.
  def test_ord
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 0],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 2, 1).with_hms_nano(0, 0, 0, 0), -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 2).with_hms_nano(0, 0, 0, 0), -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(1, 0, 0, 0), -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 1, 0, 0), -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 1, 0), -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 1), -1],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 2, 1).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 1, 1).with_hms_nano(1, 0, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 1, 1).with_hms_nano(0, 1, 0, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 1, 0), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 1), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0), 1],
      [date(-1, 1, 1).with_hms_nano(0, 0, 0, 0), date(1, 1, 1).with_hms_nano(0, 0, 0, 0), -1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>plain_date_time.rs:563</tt>, +checked_add_duration+.
  def test_checked_add_duration
    [
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.nanoseconds(5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000005)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.seconds(4), date(2021, 10, 25).with_hms_nano(14, 1, 57, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.days(2), date(2021, 10, 27).with_hms_nano(14, 1, 53, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.weeks(1), date(2021, 11, 1).with_hms_nano(14, 1, 53, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.nanoseconds(-5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 449999995)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.seconds(-4), date(2021, 10, 25).with_hms_nano(14, 1, 49, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.days(-2), date(2021, 10, 23).with_hms_nano(14, 1, 53, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.weeks(-1), date(2021, 10, 18).with_hms_nano(14, 1, 53, 450000000)],
      [T::PlainDateTime::MIN, Duration.nanoseconds(-1), nil],
      [T::PlainDateTime::MIN, Duration::MIN, nil],
      [T::PlainDateTime::MIN, Duration.weeks(-530), nil],
      [T::PlainDateTime::MAX, Duration.nanoseconds(1), nil],
      [T::PlainDateTime::MAX, Duration::MAX, nil],
      [T::PlainDateTime::MAX, Duration.weeks(530), nil],
    ].each do |datetime, duration, expected|
      assert_case expected, datetime.checked_add(duration)
    end
  end

  # <tt>plain_date_time.rs:594</tt>, +checked_sub_duration+.
  def test_checked_sub_duration
    [
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.nanoseconds(-5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000005)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.seconds(-4), date(2021, 10, 25).with_hms_nano(14, 1, 57, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.days(-2), date(2021, 10, 27).with_hms_nano(14, 1, 53, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.weeks(-1), date(2021, 11, 1).with_hms_nano(14, 1, 53, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.nanoseconds(5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 449999995)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.seconds(4), date(2021, 10, 25).with_hms_nano(14, 1, 49, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.days(2), date(2021, 10, 23).with_hms_nano(14, 1, 53, 450000000)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000), Duration.weeks(1), date(2021, 10, 18).with_hms_nano(14, 1, 53, 450000000)],
      [T::PlainDateTime::MIN, Duration.nanoseconds(1), nil],
      [T::PlainDateTime::MIN, Duration::MIN, nil],
      [T::PlainDateTime::MIN, Duration.weeks(530), nil],
      [T::PlainDateTime::MAX, Duration.nanoseconds(-1), nil],
      [T::PlainDateTime::MAX, Duration::MAX, nil],
      [T::PlainDateTime::MAX, Duration.weeks(-530), nil],
    ].each do |datetime, duration, expected|
      assert_case expected, datetime.checked_sub(duration)
    end
  end

  # <tt>plain_date_time.rs:609</tt>, +saturating_add_duration+.
  def test_saturating_add_duration
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0), Duration.days(2), date(2021, 11, 14).with_hms_nano(17, 47, 0, 0)],
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0), Duration.days(-2), date(2021, 11, 10).with_hms_nano(17, 47, 0, 0)],
      [T::PlainDateTime::MIN, Duration.days(-10), T::PlainDateTime::MIN],
      [T::PlainDateTime::MAX, Duration.days(10), T::PlainDateTime::MAX],
      [T::PlainDateTime::MIN, Duration::ZERO, T::PlainDateTime::MIN],
      [T::PlainDateTime::MAX, Duration::ZERO, T::PlainDateTime::MAX],
    ].each do |datetime, duration, expected|
      assert_case expected, datetime.saturating_add(duration)
    end
  end

  # <tt>plain_date_time.rs:624</tt>, +saturating_sub_duration+.
  def test_saturating_sub_duration
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0), Duration.days(2), date(2021, 11, 10).with_hms_nano(17, 47, 0, 0)],
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0), Duration.days(-2), date(2021, 11, 14).with_hms_nano(17, 47, 0, 0)],
      [T::PlainDateTime::MIN, Duration.days(10), T::PlainDateTime::MIN],
      [T::PlainDateTime::MAX, Duration.days(-10), T::PlainDateTime::MAX],
      [T::PlainDateTime::MIN, Duration::ZERO, T::PlainDateTime::MIN],
      [T::PlainDateTime::MAX, Duration::ZERO, T::PlainDateTime::MAX],
    ].each do |datetime, duration, expected|
      assert_case expected, datetime.saturating_sub(duration)
    end
  end
end

#--
# SPDX-SnippetEnd
#++
