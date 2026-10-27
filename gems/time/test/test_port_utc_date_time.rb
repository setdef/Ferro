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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/utc_date_time.rs
#++

# time's own tests in <tt>tests/integration/utc_date_time.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortUtcDateTime < Minitest::Test
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

  # <tt>utc_date_time.rs:11</tt>, +new+.
  def test_new
    dt = T::UtcDateTime.new(date(2023, 12, 18), clock(10, 13, 44, 250_000_000))
    assert_equal 2023, dt.year
    assert_equal 250, dt.millisecond
  end

  # <tt>utc_date_time.rs:18</tt>, +now+.
  def test_now
    assert_operator T::UtcDateTime.now.year, :>=, 2019
  end

  # <tt>utc_date_time.rs:25</tt>, +to_offset+.
  def test_to_offset
    [
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, offset(-1, 0, 0), date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(offset(-1, 0, 0))],
      [T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).as_utc, T::UtcOffset::UTC, T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |udt, offset, expected|
      assert_case expected, udt.to_offset(offset)
    end
  end

  # <tt>utc_date_time.rs:37</tt>, +to_offset_panic+: Rust's panic is
  # RangeError here.
  def test_to_offset_panic
    [
      [T::UtcDateTime::MAX, offset(1)],
      [T::UtcDateTime::MIN, offset(-1)],
    ].each do |udt, offset|
      assert_raises(RangeError) { udt.to_offset(offset) }
    end
  end

  # <tt>utc_date_time.rs:47</tt>, +checked_to_offset+.
  def test_checked_to_offset
    [
      [utc(2000, 1, 1), offset(-1), 1999],
      [T::UtcDateTime::MAX, offset(1), nil],
      [T::UtcDateTime::MIN, offset(-1), nil],
      [T::UtcDateTime::MAX, offset(0, 0, 1), nil],
      [T::UtcDateTime::MIN, offset(0, 0, -1), nil],
    ].each do |udt, offset, expected|
      assert_case expected, udt.checked_to_offset(offset)&.year
    end
  end

  # <tt>utc_date_time.rs:61</tt>, +from_unix_timestamp+.
  def test_from_unix_timestamp
    [
      [0, T::UtcDateTime::UNIX_EPOCH],
      [1_546_300_800, date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |timestamp, expected|
      assert_case expected, T::UtcDateTime.from_unix_timestamp(timestamp)
    end
  end

  # <tt>utc_date_time.rs:70</tt>, +from_unix_timestamp_nanos+.
  def test_from_unix_timestamp_nanos
    [
      [0, T::UtcDateTime::UNIX_EPOCH],
      [1_546_300_800_000_000_000, utc(2019, 1, 1)],
      [(2 ** 127) - 1, nil],
      [(1 << 64) * 1_000_000_000, nil],
    ].each do |timestamp, expected|
      assert_case expected, ok { T::UtcDateTime.from_unix_timestamp_nanos(timestamp) }
    end
  end

  # <tt>utc_date_time.rs:82</tt>, +unix_timestamp+.
  def test_unix_timestamp
    [
      [T::UtcDateTime::UNIX_EPOCH, 0],
    ].each do |udt, expected|
      assert_case expected, udt.unix_timestamp
    end
  end

  # <tt>utc_date_time.rs:88</tt>, +unix_timestamp_nanos+.
  def test_unix_timestamp_nanos
    [
      [T::UtcDateTime::UNIX_EPOCH, 0],
    ].each do |udt, expected|
      assert_case expected, udt.unix_timestamp_nanos
    end
  end

  # <tt>utc_date_time.rs:95</tt>, +date+.
  def test_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 1)],
      [date(2020, 12, 31).with_hms_nano(23, 59, 0, 0).as_utc, date(2020, 12, 31)],
    ].each do |udt, expected|
      assert_case expected, udt.date
    end
  end

  # <tt>utc_date_time.rs:102</tt>, +time_+.
  def test_time_
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, clock(0, 0, 0, 0)],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999000000).as_utc, clock(23, 59, 59, 999000000)],
    ].each do |udt, expected|
      assert_case expected, udt.time
    end
  end

  # <tt>utc_date_time.rs:109</tt>, +year+.
  def test_year
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 2019],
      [date(2020, 12, 31).with_hms_nano(23, 59, 59, 0).as_utc, 2020],
    ].each do |udt, expected|
      assert_case expected, udt.year
    end
  end

  # <tt>utc_date_time.rs:116</tt>, +month+.
  def test_month
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Month::January],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, Month::December],
    ].each do |udt, expected|
      assert_case expected, udt.month
    end
  end

  # <tt>utc_date_time.rs:123</tt>, +day+.
  def test_day
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 1],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, 31],
    ].each do |udt, expected|
      assert_case expected, udt.day
    end
  end

  # <tt>utc_date_time.rs:130</tt>, +ordinal+.
  def test_ordinal
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 1],
      [date(2020, 2, 29).with_hms_nano(0, 0, 0, 0).as_utc, 60],
    ].each do |udt, expected|
      assert_case expected, udt.ordinal
    end
  end

  # <tt>utc_date_time.rs:139</tt>, +iso_week+.
  def test_iso_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 1],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 1],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, 53],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 53],
    ].each do |udt, expected|
      assert_case expected, udt.iso_week
    end
  end

  # <tt>utc_date_time.rs:148</tt>, +sunday_based_week+.
  def test_sunday_based_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, 52],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
    ].each do |udt, expected|
      assert_case expected, udt.sunday_based_week
    end
  end

  # <tt>utc_date_time.rs:157</tt>, +monday_based_week+.
  def test_monday_based_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, 52],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
    ].each do |udt, expected|
      assert_case expected, udt.monday_based_week
    end
  end

  # <tt>utc_date_time.rs:164</tt>, +to_calendar_date+.
  def test_to_calendar_date
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).as_utc, [2019, Month::January, 2]],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, [2020, Month::December, 31]],
    ].each do |udt, expected|
      assert_case expected, udt.to_calendar_date
    end
  end

  # <tt>utc_date_time.rs:171</tt>, +to_ordinal_date+.
  def test_to_ordinal_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, [2019, 1]],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, [2020, 366]],
    ].each do |udt, expected|
      assert_case expected, udt.to_ordinal_date
    end
  end

  # <tt>utc_date_time.rs:181</tt>, +to_iso_week_date+.
  def test_to_iso_week_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, [2019, 1, Weekday::Tuesday]],
      [date(2019, 10, 4).with_hms_nano(0, 0, 0, 0).as_utc, [2019, 40, Weekday::Friday]],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, [2020, 1, Weekday::Wednesday]],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, [2020, 53, Weekday::Thursday]],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, [2020, 53, Weekday::Friday]],
    ].each do |udt, expected|
      assert_case expected, udt.to_iso_week_date
    end
  end

  # <tt>utc_date_time.rs:189</tt>, +weekday+.
  def test_weekday
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Weekday::Tuesday],
      [date(2019, 2, 1).with_hms_nano(0, 0, 0, 0).as_utc, Weekday::Friday],
      [date(2019, 3, 1).with_hms_nano(0, 0, 0, 0).as_utc, Weekday::Friday],
    ].each do |udt, expected|
      assert_case expected, udt.weekday
    end
  end

  # <tt>utc_date_time.rs:199</tt>, +to_julian_day+.
  def test_to_julian_day
    [
      [date(-4713, 11, 24).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 2_451_545],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 2_458_485],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, 2_458_849],
      # left out: large-dates year -999_999
    ].each do |udt, expected|
      assert_case expected, udt.to_julian_day
    end
  end

  # <tt>utc_date_time.rs:205</tt>, +as_hms+.
  def test_as_hms
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 0).as_utc, [1, 2, 3]],
    ].each do |udt, expected|
      assert_case expected, udt.as_hms
    end
  end

  # <tt>utc_date_time.rs:211</tt>, +as_hms_milli+.
  def test_as_hms_milli
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4000000).as_utc, [1, 2, 3, 4]],
    ].each do |udt, expected|
      assert_case expected, udt.as_hms_milli
    end
  end

  # <tt>utc_date_time.rs:217</tt>, +as_hms_micro+.
  def test_as_hms_micro
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4005000).as_utc, [1, 2, 3, 4_005]],
    ].each do |udt, expected|
      assert_case expected, udt.as_hms_micro
    end
  end

  # <tt>utc_date_time.rs:223</tt>, +as_hms_nano+.
  def test_as_hms_nano
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4005006).as_utc, [1, 2, 3, 4_005_006]],
    ].each do |udt, expected|
      assert_case expected, udt.as_hms_nano
    end
  end

  # <tt>utc_date_time.rs:230</tt>, +hour+.
  def test_hour
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0).as_utc, 23],
    ].each do |udt, expected|
      assert_case expected, udt.hour
    end
  end

  # <tt>utc_date_time.rs:237</tt>, +minute+.
  def test_minute
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(0, 1, 0, 0).as_utc, 1],
    ].each do |udt, expected|
      assert_case expected, udt.minute
    end
  end

  # <tt>utc_date_time.rs:244</tt>, +second+.
  def test_second
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(0, 0, 1, 0).as_utc, 1],
    ].each do |udt, expected|
      assert_case expected, udt.second
    end
  end

  # <tt>utc_date_time.rs:251</tt>, +millisecond+.
  def test_millisecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999000000).as_utc, 999],
    ].each do |udt, expected|
      assert_case expected, udt.millisecond
    end
  end

  # <tt>utc_date_time.rs:258</tt>, +microsecond+.
  def test_microsecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999999000).as_utc, 999_999],
    ].each do |udt, expected|
      assert_case expected, udt.microsecond
    end
  end

  # <tt>utc_date_time.rs:265</tt>, +nanosecond+.
  def test_nanosecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999999999).as_utc, 999_999_999],
    ].each do |udt, expected|
      assert_case expected, udt.nanosecond
    end
  end

  # <tt>utc_date_time.rs:271</tt>, +replace_time+.
  def test_replace_time
    [
      [date(2020, 1, 1).with_hms_nano(5, 0, 0, 0).as_utc, clock(12, 0, 0, 0), date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).as_utc],
    ].each do |udt, replacement, expected|
      assert_case expected, udt.replace_time(replacement)
    end
  end

  # <tt>utc_date_time.rs:281</tt>, +replace_date+.
  def test_replace_date
    [
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).as_utc, date(2020, 1, 30), date(2020, 1, 30).with_hms_nano(12, 0, 0, 0).as_utc],
    ].each do |udt, replacement, expected|
      assert_case expected, udt.replace_date(replacement)
    end
  end

  # <tt>utc_date_time.rs:293</tt>, +replace_year+.
  def test_replace_year
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, 2019, date(2019, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, -1_000_000_000, nil],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, 1_000_000_000, nil],
    ].each do |udt, year, expected|
      assert_case expected, ok { udt.replace_year(year) }
    end
  end

  # <tt>utc_date_time.rs:304</tt>, +replace_month+.
  def test_replace_month
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, Month::January, date(2022, 1, 18).with_hms_nano(12, 0, 0, 0).as_utc],
      [date(2022, 1, 30).with_hms_nano(12, 0, 0, 0).as_utc, Month::February, nil],
    ].each do |udt, month, expected|
      assert_case expected, ok { udt.replace_month(month) }
    end
  end

  # <tt>utc_date_time.rs:316</tt>, +replace_day+.
  def test_replace_day
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, 1, date(2022, 2, 1).with_hms_nano(12, 0, 0, 0).as_utc],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, 0, nil],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, 30, nil],
    ].each do |udt, day, expected|
      assert_case expected, ok { udt.replace_day(day) }
    end
  end

  # <tt>utc_date_time.rs:330</tt>, +replace_ordinal+.
  def test_replace_ordinal
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).as_utc, 1, T::Date.from_ordinal_date(2022, 1).with_hms_nano(12, 0, 0, 0).as_utc],
      [date(2024, 2, 29).with_hms_nano(12, 0, 0, 0).as_utc, 366, T::Date.from_ordinal_date(2024, 366).with_hms_nano(12, 0, 0, 0).as_utc],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0).as_utc, 0, nil],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0).as_utc, 366, nil],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0).as_utc, 367, nil],
    ].each do |udt, ordinal, expected|
      assert_case expected, ok { udt.replace_ordinal(ordinal) }
    end
  end

  # <tt>utc_date_time.rs:345</tt>, +replace_hour+.
  def test_replace_hour
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 7, date(2022, 2, 18).with_hms_nano(7, 2, 3, 4005006).as_utc],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 24, nil],
    ].each do |udt, value, expected|
      assert_case expected, ok { udt.replace_hour(value) }
    end
  end

  # <tt>utc_date_time.rs:360</tt>, +replace_minute+.
  def test_replace_minute
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 7, date(2022, 2, 18).with_hms_nano(1, 7, 3, 4005006).as_utc],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 60, nil],
    ].each do |udt, value, expected|
      assert_case expected, ok { udt.replace_minute(value) }
    end
  end

  # <tt>utc_date_time.rs:375</tt>, +replace_second+.
  def test_replace_second
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 7, date(2022, 2, 18).with_hms_nano(1, 2, 7, 4005006).as_utc],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 60, nil],
    ].each do |udt, value, expected|
      assert_case expected, ok { udt.replace_second(value) }
    end
  end

  # <tt>utc_date_time.rs:386</tt>, +replace_millisecond+.
  def test_replace_millisecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 7, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7000000).as_utc],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 1_000, nil],
    ].each do |udt, value, expected|
      assert_case expected, ok { udt.replace_millisecond(value) }
    end
  end

  # <tt>utc_date_time.rs:401</tt>, +replace_microsecond+.
  def test_replace_microsecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 7_008, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7008000).as_utc],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 1_000_000, nil],
    ].each do |udt, value, expected|
      assert_case expected, ok { udt.replace_microsecond(value) }
    end
  end

  # <tt>utc_date_time.rs:416</tt>, +replace_nanosecond+.
  def test_replace_nanosecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 7_008_009, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7008009).as_utc],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).as_utc, 1_000_000_000, nil],
    ].each do |udt, value, expected|
      assert_case expected, ok { udt.replace_nanosecond(value) }
    end
  end

  # <tt>utc_date_time.rs:427</tt>, +truncate_to_day+.
  def test_truncate_to_day
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, expected|
      assert_case expected, udt.truncate_to_day
    end
  end

  # <tt>utc_date_time.rs:434</tt>, +truncate_to_hour+.
  def test_truncate_to_hour
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).as_utc, date(2021, 11, 12).with_hms_nano(17, 0, 0, 0).as_utc],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, expected|
      assert_case expected, udt.truncate_to_hour
    end
  end

  # <tt>utc_date_time.rs:441</tt>, +truncate_to_minute+.
  def test_truncate_to_minute
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).as_utc, date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).as_utc],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, expected|
      assert_case expected, udt.truncate_to_minute
    end
  end

  # <tt>utc_date_time.rs:448</tt>, +truncate_to_second+.
  def test_truncate_to_second
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).as_utc, date(2021, 11, 12).with_hms_nano(17, 47, 53, 0).as_utc],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, expected|
      assert_case expected, udt.truncate_to_second
    end
  end

  # <tt>utc_date_time.rs:455</tt>, +truncate_to_millisecond+.
  def test_truncate_to_millisecond
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).as_utc, date(2021, 11, 12).with_hms_nano(17, 47, 53, 123000000).as_utc],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, expected|
      assert_case expected, udt.truncate_to_millisecond
    end
  end

  # <tt>utc_date_time.rs:462</tt>, +truncate_to_microsecond+.
  def test_truncate_to_microsecond
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).as_utc, date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456000).as_utc],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc, date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, expected|
      assert_case expected, udt.truncate_to_microsecond
    end
  end

  # <tt>utc_date_time.rs:468</tt>, +partial_eq+.
  def test_partial_eq
    [
      [utc(2000, 1, 1), utc(2000, 1, 1)],
    ].each do |a, b|
      assert_equal a, b
    end
  end

  # <tt>utc_date_time.rs:476</tt>, +partial_ord+.
  def test_partial_ord
    [
      [utc(2019, 1, 1), utc(2019, 1, 1), 0],
      [utc(2020, 1, 1), utc(2019, 1, 1), 1],
      [utc(2019, 1, 1), utc(2020, 1, 1), -1],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>utc_date_time.rs:492</tt>, +ord+.
  def test_ord
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 0],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 1).with_hms_nano(0, 0, 0, 1).as_utc, -1],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 1).as_utc, date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, 1],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>utc_date_time.rs:499</tt>, +hash+.
  def test_hash
    [
      utc(2019, 1, 1),
      utc(2020, 2, 29, 12, 34, 56, 789_000_000),
    ].each do |udt|
      assert_equal udt.hash, udt.hash
    end
  end

  # <tt>utc_date_time.rs:523</tt>, +add_duration+.
  def test_add_duration
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(5), date(2019, 1, 6).with_hms_nano(0, 0, 0, 0).as_utc],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(1), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc],
      [date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).as_utc, Duration.seconds(2), date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).as_utc],
      [date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).as_utc, Duration.seconds(-2), date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).as_utc],
      [date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).as_utc, Duration.hours(1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, duration, expected|
      assert_case expected, udt + duration
    end
  end

  # <tt>utc_date_time.rs:548</tt>, +add_assign_duration+: Ruby's
  # <tt>+=</tt> is <tt>+</tt> and an assignment.
  def test_add_assign_duration
    [
      [utc(2019, 1, 1), Duration.days(5), utc(2019, 1, 6)],
      [utc(2019, 12, 31), Duration.days(1), utc(2020, 1, 1)],
      [utc(2019, 12, 31, 23, 59, 59), Duration.seconds(2), utc(2020, 1, 1, 0, 0, 1)],
      [utc(2020, 1, 1, 0, 0, 1), Duration.seconds(-2), utc(2019, 12, 31, 23, 59, 59)],
    ].each do |udt, duration, expected|
      udt += duration
      assert_case expected, udt
    end
  end

  # <tt>utc_date_time.rs:576</tt>, +sub_duration+.
  def test_sub_duration
    [
      [date(2019, 1, 6).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(5), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(1), date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc],
      [date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).as_utc, Duration.seconds(2), date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).as_utc],
      [date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).as_utc, Duration.seconds(-2), date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).as_utc],
      [date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).as_utc, Duration.hours(-1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |udt, duration, expected|
      assert_case expected, udt - duration
    end
  end

  # <tt>utc_date_time.rs:601</tt>, +sub_assign_duration+.
  def test_sub_assign_duration
    [
      [utc(2019, 1, 6), Duration.days(5), utc(2019, 1, 1)],
      [utc(2020, 1, 1), Duration.days(1), utc(2019, 12, 31)],
      [utc(2020, 1, 1, 0, 0, 1), Duration.seconds(2), utc(2019, 12, 31, 23, 59, 59)],
      [utc(2019, 12, 31, 23, 59, 59), Duration.seconds(-2), utc(2020, 1, 1, 0, 0, 1)],
    ].each do |udt, duration, expected|
      udt -= duration
      assert_case expected, udt
    end
  end

  # <tt>utc_date_time.rs:719</tt>, +sub_self+.
  def test_sub_self
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(1)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(-1)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(1)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(-1)],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs - rhs
    end
  end

  # <tt>utc_date_time.rs:753</tt>, +sub_std+: a SystemTime is a Ruby
  # ::Time (plan 007, decision 10).
  def test_sub_std
    [
      [utc(2019, 1, 2), utc(2019, 1, 1).to_time, Duration.days(1)],
      [utc(2019, 1, 1), utc(2019, 1, 2).to_time, Duration.days(-1)],
      [utc(2020, 1, 1), utc(2019, 12, 31).to_time, Duration.days(1)],
      [utc(2019, 12, 31), utc(2020, 1, 1).to_time, Duration.days(-1)],
    ].each do |udt, rhs, expected|
      assert_case expected, udt - rhs
    end
  end

  # <tt>utc_date_time.rs:762</tt>, +odt_sub+.
  def test_odt_sub
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(1)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(-1)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(1)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, Duration.days(-1)],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs - rhs
    end
  end

  # <tt>utc_date_time.rs:775</tt>, +sub_odt+.
  def test_sub_odt
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(1)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(-1)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(1)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).as_utc, date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(-1)],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs - rhs
    end
  end

  # <tt>utc_date_time.rs:785</tt>, +eq_std+.
  def test_eq_std
    [utc(2019, 1, 1)].each do |now_datetime|
      now_systemtime = now_datetime.to_time
      assert_equal now_datetime, now_systemtime
    end
  end

  # <tt>utc_date_time.rs:792</tt>, +std_eq+: Ruby's ::Time#== asks
  # UtcDateTime#<=> (decision 10).
  def test_std_eq
    [utc(2019, 1, 1)].each do |now_datetime|
      now_systemtime = now_datetime.to_time
      assert_equal now_systemtime, now_datetime
    end
  end

  # <tt>utc_date_time.rs:799</tt>, +eq_odt+.
  def test_eq_odt
    [utc(2019, 1, 1)].each do |now_datetime|
      now_odt = T::OffsetDateTime.from(now_datetime)
      assert_equal now_datetime, now_odt
    end
  end

  # <tt>utc_date_time.rs:806</tt>, +odt_eq+.
  def test_odt_eq
    [utc(2019, 1, 1)].each do |now_datetime|
      now_odt = T::OffsetDateTime.from(now_datetime)
      assert_equal now_odt, now_datetime
    end
  end

  # <tt>utc_date_time.rs:887</tt>, +ord_std+.
  def test_ord_std
    [
      [utc(2019, 1, 1), utc(2019, 1, 1).to_time, 0],
      [utc(2019, 1, 1), utc(2020, 1, 1).to_time, -1],
      [utc(2019, 1, 1), utc(2019, 2, 1).to_time, -1],
      [utc(2019, 1, 1), utc(2019, 1, 2).to_time, -1],
      [utc(2019, 1, 1), utc(2019, 1, 1, 1).to_time, -1],
      [utc(2019, 1, 1), utc(2019, 1, 1, 0, 1).to_time, -1],
      [utc(2019, 1, 1), utc(2019, 1, 1, 0, 0, 1).to_time, -1],
      [utc(2019, 1, 1), utc(2019, 1, 1, 0, 0, 0, 1_000_000).to_time, -1],
      [utc(2020, 1, 1), utc(2019, 1, 1).to_time, 1],
      [utc(2019, 2, 1), utc(2019, 1, 1).to_time, 1],
      [utc(2019, 1, 2), utc(2019, 1, 1).to_time, 1],
      [utc(2019, 1, 1, 1), utc(2019, 1, 1).to_time, 1],
      [utc(2019, 1, 1, 0, 1), utc(2019, 1, 1).to_time, 1],
      [utc(2019, 1, 1, 0, 0, 1), utc(2019, 1, 1).to_time, 1],
      [utc(2019, 1, 1, 0, 0, 0, 1), utc(2019, 1, 1).to_time, 1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>utc_date_time.rs:967</tt>, +std_ord+: Ruby's ::Time#<=> asks
  # UtcDateTime#<=> and inverts it (decision 10).
  def test_std_ord
    [
      [utc(2019, 1, 1).to_time, utc(2019, 1, 1), 0],
      [utc(2019, 1, 1).to_time, utc(2020, 1, 1), -1],
      [utc(2019, 1, 1).to_time, utc(2019, 2, 1), -1],
      [utc(2019, 1, 1).to_time, utc(2019, 1, 2), -1],
      [utc(2019, 1, 1).to_time, utc(2019, 1, 1, 1), -1],
      [utc(2019, 1, 1).to_time, utc(2019, 1, 1, 0, 1), -1],
      [utc(2019, 1, 1).to_time, utc(2019, 1, 1, 0, 0, 1), -1],
      [utc(2019, 1, 1).to_time, utc(2019, 1, 1, 0, 0, 0, 1), -1],
      [utc(2020, 1, 1).to_time, utc(2019, 1, 1), 1],
      [utc(2019, 2, 1).to_time, utc(2019, 1, 1), 1],
      [utc(2019, 1, 2).to_time, utc(2019, 1, 1), 1],
      [utc(2019, 1, 1, 1).to_time, utc(2019, 1, 1), 1],
      [utc(2019, 1, 1, 0, 1).to_time, utc(2019, 1, 1), 1],
      [utc(2019, 1, 1, 0, 0, 1).to_time, utc(2019, 1, 1), 1],
      [utc(2019, 1, 1, 0, 0, 0, 1_000_000).to_time, utc(2019, 1, 1), 1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>utc_date_time.rs:991</tt>, +odt_ord+.
  def test_odt_ord
    u = T::UtcOffset::UTC
    [
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 1), 0],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2020, 1, 1), -1],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 2, 1), -1],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 2), -1],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 1, 1), -1],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 1, 0, 1), -1],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 1, 0, 0, 1), -1],
      [odt(2019, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 1, 0, 0, 0, 1), -1],
      [odt(2020, 1, 1, 0, 0, 0, 0, u), utc(2019, 1, 1), 1],
      [odt(2019, 2, 1, 0, 0, 0, 0, u), utc(2019, 1, 1), 1],
      [odt(2019, 1, 2, 0, 0, 0, 0, u), utc(2019, 1, 1), 1],
      [odt(2019, 1, 1, 1, 0, 0, 0, u), utc(2019, 1, 1), 1],
      [odt(2019, 1, 1, 0, 1, 0, 0, u), utc(2019, 1, 1), 1],
      [odt(2019, 1, 1, 0, 0, 1, 0, u), utc(2019, 1, 1), 1],
      [odt(2019, 1, 1, 0, 0, 0, 1_000_000, u), utc(2019, 1, 1), 1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>utc_date_time.rs:1015</tt>, +ord_odt+.
  def test_ord_odt
    u = T::UtcOffset::UTC
    [
      [utc(2019, 1, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 0],
      [utc(2019, 1, 1), odt(2020, 1, 1, 0, 0, 0, 0, u), -1],
      [utc(2019, 1, 1), odt(2019, 2, 1, 0, 0, 0, 0, u), -1],
      [utc(2019, 1, 1), odt(2019, 1, 2, 0, 0, 0, 0, u), -1],
      [utc(2019, 1, 1), odt(2019, 1, 1, 1, 0, 0, 0, u), -1],
      [utc(2019, 1, 1), odt(2019, 1, 1, 0, 1, 0, 0, u), -1],
      [utc(2019, 1, 1), odt(2019, 1, 1, 0, 0, 1, 0, u), -1],
      [utc(2019, 1, 1), odt(2019, 1, 1, 0, 0, 0, 1_000_000, u), -1],
      [utc(2020, 1, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
      [utc(2019, 2, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
      [utc(2019, 1, 2), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
      [utc(2019, 1, 1, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
      [utc(2019, 1, 1, 0, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
      [utc(2019, 1, 1, 0, 0, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
      [utc(2019, 1, 1, 0, 0, 0, 1), odt(2019, 1, 1, 0, 0, 0, 0, u), 1],
    ].each do |lhs, rhs, expected|
      assert_case expected, lhs <=> rhs
    end
  end

  # <tt>utc_date_time.rs:1023</tt>, +from_std+: <tt>1.std_days()</tt> is
  # 86,400 seconds of a Ruby ::Time.
  def test_from_std
    [
      ::Time.at(0),
      ::Time.at(-86_400),
      ::Time.at(86_400),
    ].each do |input|
      assert_equal T::UtcDateTime.from(input), input
    end
  end

  # <tt>utc_date_time.rs:1031</tt>, +to_std+.
  def test_to_std
    [
      T::UtcDateTime::UNIX_EPOCH,
      T::UtcDateTime::UNIX_EPOCH + Duration.days(1),
      T::UtcDateTime::UNIX_EPOCH - Duration.days(1),
    ].each do |input|
      assert_equal input.to_time, input
    end
  end

  # <tt>utc_date_time.rs:1039</tt>, +from_odt+: <tt>1.std_days()</tt> is
  # the same span as a SignedDuration (std's Duration is not bound,
  # decision 9).
  def test_from_odt
    [
      T::OffsetDateTime::UNIX_EPOCH,
      T::OffsetDateTime::UNIX_EPOCH - Duration.days(1),
      T::OffsetDateTime::UNIX_EPOCH + Duration.days(1),
    ].each do |input|
      assert_equal T::UtcDateTime.from(input), input
    end
  end

  # <tt>utc_date_time.rs:1047</tt>, +to_odt+.
  def test_to_odt
    [
      T::UtcDateTime::UNIX_EPOCH,
      T::UtcDateTime::UNIX_EPOCH + Duration.days(1),
      T::UtcDateTime::UNIX_EPOCH - Duration.days(1),
    ].each do |input|
      assert_equal T::OffsetDateTime.from(input), input
    end
  end

  # <tt>utc_date_time.rs:1078</tt>, +checked_add_duration+.
  def test_checked_add_duration
    [
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.nanoseconds(5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000005).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.seconds(4), date(2021, 10, 25).with_hms_nano(14, 1, 57, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.days(2), date(2021, 10, 27).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.weeks(1), date(2021, 11, 1).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.nanoseconds(-5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 449999995).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.seconds(-4), date(2021, 10, 25).with_hms_nano(14, 1, 49, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.days(-2), date(2021, 10, 23).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.weeks(-1), date(2021, 10, 18).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [T::UtcDateTime::MIN, Duration.nanoseconds(-1), nil],
      [T::UtcDateTime::MIN, Duration::MIN, nil],
      [T::UtcDateTime::MIN, Duration.weeks(-530), nil],
      [T::UtcDateTime::MAX, Duration.nanoseconds(1), nil],
      [T::UtcDateTime::MAX, Duration::MAX, nil],
      [T::UtcDateTime::MAX, Duration.weeks(530), nil],
    ].each do |input, duration, expected|
      assert_case expected, input.checked_add(duration)
    end
  end

  # <tt>utc_date_time.rs:1115</tt>, +checked_sub_duration+.
  def test_checked_sub_duration
    [
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.nanoseconds(-5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000005).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.seconds(-4), date(2021, 10, 25).with_hms_nano(14, 1, 57, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.days(-2), date(2021, 10, 27).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.weeks(-1), date(2021, 11, 1).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.nanoseconds(5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 449999995).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.seconds(4), date(2021, 10, 25).with_hms_nano(14, 1, 49, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.days(2), date(2021, 10, 23).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).as_utc, Duration.weeks(1), date(2021, 10, 18).with_hms_nano(14, 1, 53, 450000000).as_utc],
      [T::UtcDateTime::MIN, Duration.nanoseconds(1), nil],
      [T::UtcDateTime::MIN, Duration::MAX, nil],
      [T::UtcDateTime::MIN, Duration.weeks(530), nil],
      [T::UtcDateTime::MAX, Duration.nanoseconds(-1), nil],
      [T::UtcDateTime::MAX, Duration::MIN, nil],
      [T::UtcDateTime::MAX, Duration.weeks(-530), nil],
      [T::UtcDateTime::MAX, Duration::ZERO, T::UtcDateTime::MAX],
      [T::UtcDateTime::MIN, Duration::ZERO, T::UtcDateTime::MIN],
    ].each do |input, duration, expected|
      assert_case expected, input.checked_sub(duration)
    end
  end

  # <tt>utc_date_time.rs:1130</tt>, +saturating_add_duration+.
  def test_saturating_add_duration
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).as_utc, Duration.days(2), date(2021, 11, 14).with_hms_nano(17, 47, 0, 0).as_utc],
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).as_utc, Duration.days(-2), date(2021, 11, 10).with_hms_nano(17, 47, 0, 0).as_utc],
      [T::UtcDateTime::MIN, Duration.days(-10), T::UtcDateTime::MIN],
      [T::UtcDateTime::MAX, Duration.days(10), T::UtcDateTime::MAX],
      [T::UtcDateTime::MIN, Duration::ZERO, T::UtcDateTime::MIN],
      [T::UtcDateTime::MAX, Duration::ZERO, T::UtcDateTime::MAX],
    ].each do |input, duration, expected|
      assert_case expected, input.saturating_add(duration)
    end
  end

  # <tt>utc_date_time.rs:1145</tt>, +saturating_sub_duration+.
  def test_saturating_sub_duration
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).as_utc, Duration.days(2), date(2021, 11, 10).with_hms_nano(17, 47, 0, 0).as_utc],
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).as_utc, Duration.days(-2), date(2021, 11, 14).with_hms_nano(17, 47, 0, 0).as_utc],
      [T::UtcDateTime::MIN, Duration.days(10), T::UtcDateTime::MIN],
      [T::UtcDateTime::MAX, Duration.days(-10), T::UtcDateTime::MAX],
      [T::UtcDateTime::MIN, Duration::ZERO, T::UtcDateTime::MIN],
      [T::UtcDateTime::MAX, Duration::ZERO, T::UtcDateTime::MAX],
    ].each do |input, duration, expected|
      assert_case expected, input.saturating_sub(duration)
    end
  end

  # <tt>utc_date_time.rs:1160</tt>, +to_offset_regression+.
  def test_to_offset_regression
    value = utc(0, 1, 1, 23, 59).to_offset(offset(24, 59))
    assert_equal odt(0, 1, 3, 0, 58, 0, 0, offset(24, 59)), value
  end
end

#--
# SPDX-SnippetEnd
#++
