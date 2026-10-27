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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/offset_date_time.rs
#++

# time's own tests in <tt>tests/integration/offset_date_time.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortOffsetDateTime < Minitest::Test
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

  # time's <tt>datetime!(date time UTC)</tt>.
  private def in_utc(year, month, day, hour = 0, minute = 0, second = 0, nanosecond = 0)
    datetime(year, month, day, hour, minute, second, nanosecond).assume_utc
  end

  # Names a deprecated method quietly, since the tests run under -w.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

  # <tt>offset_date_time.rs:14</tt>, +new_utc+.
  def test_new_utc
    dt = T::OffsetDateTime.new_utc(date(2023, 12, 18), clock(10, 13, 44, 250_000_000))
    assert_equal 2023, dt.year
    assert_equal 250, dt.millisecond
    assert_equal T::UtcOffset::UTC, dt.offset
  end

  # <tt>offset_date_time.rs:22</tt>, +new_in_offset+.
  def test_new_in_offset
    dt = T::OffsetDateTime.new_in_offset(date(2023, 12, 18), clock(10, 13, 44, 250_000_000), offset(-4))
    assert_equal 2023, dt.year
    assert_equal 250, dt.millisecond
    assert_equal(-4, dt.offset.whole_hours)
  end

  # <tt>offset_date_time.rs:30</tt>, +now_utc+.
  def test_now_utc
    assert_operator T::OffsetDateTime.now_utc.year, :>=, 2019
    assert_equal T::UtcOffset::UTC, T::OffsetDateTime.now_utc.offset
  end

  # <tt>offset_date_time.rs:36</tt>, +now_local+: Rust's +is_ok+ is not
  # raising here.
  def test_now_local
    assert_instance_of T::OffsetDateTime, T::OffsetDateTime.now_local
  end

  # <tt>offset_date_time.rs:48</tt>, +to_offset+.
  def test_to_offset
    [
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), offset(-1, 0, 0), date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(offset(-1, 0, 0))],
      [T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(0, 0, 2)), offset(0, 0, -59), T::Date.from_ordinal_date(-1, 365).with_hms_nano(23, 58, 59, 0).assume_offset(offset(0, 0, -59))],
      [T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), T::UtcOffset::UTC, T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, offset, expected|
      assert_case expected, input.to_offset(offset)
    end
  end

  # <tt>offset_date_time.rs:60</tt>, +to_offset_panic+: Rust's panic is
  # RangeError here.
  def test_to_offset_panic
    [
      [T::PlainDateTime::MAX.assume_utc, offset(1)],
      [T::PlainDateTime::MIN.assume_utc, offset(-1)],
    ].each do |input, offset|
      assert_raises(RangeError) { input.to_offset(offset) }
    end
  end

  # <tt>offset_date_time.rs:66</tt>, +to_offset_invalid_regression+.
  def test_to_offset_invalid_regression
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(13, 0, 0)), offset(-13, 0, 0), date(2018, 12, 30).with_hms_nano(22, 0, 0, 0).assume_offset(offset(-13, 0, 0))],
    ].each do |input, offset, expected|
      assert_case expected, input.to_offset(offset)
    end
  end

  # <tt>offset_date_time.rs:80</tt>, +checked_to_offset+.
  def test_checked_to_offset
    [
      [in_utc(2000, 1, 1), offset(-1), 1999],
      [T::PlainDateTime::MAX.assume_utc, offset(1), nil],
      [T::PlainDateTime::MIN.assume_utc, offset(-1), nil],
      [T::PlainDateTime::MAX.assume_utc, offset(0, 0, 1), nil],
      [T::PlainDateTime::MIN.assume_utc, offset(0, 0, -1), nil],
    ].each do |input, offset, expected|
      assert_case expected, input.checked_to_offset(offset)&.year
    end
  end

  # <tt>offset_date_time.rs:94</tt>, +to_utc+.
  def test_to_utc
    [
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).as_utc],
      [T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), T::Date.from_ordinal_date(0, 1).with_hms_nano(0, 0, 0, 0).as_utc],
    ].each do |input, expected|
      assert_case expected, input.to_utc
    end
  end

  # <tt>offset_date_time.rs:102</tt>, +to_utc_panic+.
  def test_to_utc_panic
    [
      T::PlainDateTime::MAX.assume_offset(offset(-1)),
      T::PlainDateTime::MIN.assume_offset(offset(1)),
    ].each do |input|
      assert_raises(RangeError) { input.to_utc }
    end
  end

  # <tt>offset_date_time.rs:112</tt>, +checked_to_utc+. The years past
  # ±9999 need large-dates:
  #   datetime!(+999999-12-31 23:59:59 -1), None
  #   datetime!(-999999-01-01 00:00:00 +1), None
  def test_checked_to_utc
    [
      [odt(2000, 1, 1, 0, 0, 0, 0, offset(1)), 1999],
      [T::PlainDateTime::MAX.assume_offset(offset(-1)), nil],
      [T::PlainDateTime::MIN.assume_offset(offset(1)), nil],
    ].each do |input, expected|
      assert_case expected, input.checked_to_utc&.year
    end
  end

  # <tt>offset_date_time.rs:122</tt>, +from_unix_timestamp+.
  def test_from_unix_timestamp
    [
      [0, T::OffsetDateTime::UNIX_EPOCH],
      [1_546_300_800, date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, expected|
      assert_case expected, T::OffsetDateTime.from_unix_timestamp(input)
    end
  end

  # <tt>offset_date_time.rs:131</tt>, +from_unix_timestamp_nanos+.
  def test_from_unix_timestamp_nanos
    [
      [0, T::OffsetDateTime::UNIX_EPOCH],
      [1_546_300_800_000_000_000, in_utc(2019, 1, 1)],
      [(2 ** 127) - 1, nil],
      [(1 << 64) * 1_000_000_000, nil],
    ].each do |input, expected|
      assert_case expected, ok { T::OffsetDateTime.from_unix_timestamp_nanos(input) }
    end
  end

  # <tt>offset_date_time.rs:145</tt>, +offset+.
  def test_offset
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), T::UtcOffset::UTC],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), offset(1, 0, 0)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(1, 0, 0)), offset(1, 0, 0)],
    ].each do |input, expected|
      assert_case expected, input.offset
    end
  end

  # <tt>offset_date_time.rs:153</tt>, +unix_timestamp+.
  def test_unix_timestamp
    [
      [T::OffsetDateTime::UNIX_EPOCH, 0],
      [T::OffsetDateTime::UNIX_EPOCH.to_offset(offset(1, 0, 0)), 0],
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(-1, 0, 0)), 3_600],
    ].each do |input, expected|
      assert_case expected, input.unix_timestamp
    end
  end

  # <tt>offset_date_time.rs:160</tt>, +unix_timestamp_nanos+.
  def test_unix_timestamp_nanos
    [
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(1970, 1, 1).with_hms_nano(1, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(-1, 0, 0)), 3_600_000_000_000],
    ].each do |input, expected|
      assert_case expected, input.unix_timestamp_nanos
    end
  end

  # <tt>offset_date_time.rs:167</tt>, +date+.
  def test_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 1)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(-1, 0, 0)), date(2018, 12, 31)],
    ].each do |input, expected|
      assert_case expected, input.date
    end
  end

  # <tt>offset_date_time.rs:174</tt>, +time_+.
  def test_time_
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), clock(0, 0, 0, 0)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(-1, 0, 0)), clock(23, 0, 0, 0)],
    ].each do |input, expected|
      assert_case expected, input.time
    end
  end

  # <tt>offset_date_time.rs:182</tt>, +year+.
  def test_year
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 2019],
      [date(2019, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(1, 0, 0)), 2020],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 2020],
    ].each do |input, expected|
      assert_case expected, input.year
    end
  end

  # <tt>offset_date_time.rs:189</tt>, +month+.
  def test_month
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Month::January],
      [date(2019, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(1, 0, 0)), Month::January],
    ].each do |input, expected|
      assert_case expected, input.month
    end
  end

  # <tt>offset_date_time.rs:196</tt>, +day+.
  def test_day
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 1],
      [date(2019, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(1, 0, 0)), 1],
    ].each do |input, expected|
      assert_case expected, input.day
    end
  end

  # <tt>offset_date_time.rs:203</tt>, +ordinal+.
  def test_ordinal
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 1],
      [date(2019, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(1, 0, 0)), 1],
    ].each do |input, expected|
      assert_case expected, input.ordinal
    end
  end

  # <tt>offset_date_time.rs:212</tt>, +iso_week+.
  def test_iso_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 1],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 1],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 53],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 53],
    ].each do |input, expected|
      assert_case expected, input.iso_week
    end
  end

  # <tt>offset_date_time.rs:221</tt>, +sunday_based_week+.
  def test_sunday_based_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 52],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
    ].each do |input, expected|
      assert_case expected, input.sunday_based_week
    end
  end

  # <tt>offset_date_time.rs:230</tt>, +monday_based_week+.
  def test_monday_based_week
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 52],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
    ].each do |input, expected|
      assert_case expected, input.monday_based_week
    end
  end

  # <tt>offset_date_time.rs:236</tt>, +to_calendar_date+.
  def test_to_calendar_date
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2019, Month::January, 2]],
    ].each do |input, expected|
      assert_case expected, input.to_calendar_date
    end
  end

  # <tt>offset_date_time.rs:242</tt>, +to_ordinal_date+.
  def test_to_ordinal_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2019, 1]],
    ].each do |input, expected|
      assert_case expected, input.to_ordinal_date
    end
  end

  # <tt>offset_date_time.rs:252</tt>, +to_iso_week_date+.
  def test_to_iso_week_date
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2019, 1, Weekday::Tuesday]],
      [date(2019, 10, 4).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2019, 40, Weekday::Friday]],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2020, 1, Weekday::Wednesday]],
      [date(2020, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2020, 53, Weekday::Thursday]],
      [date(2021, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), [2020, 53, Weekday::Friday]],
    ].each do |input, expected|
      assert_case expected, input.to_iso_week_date
    end
  end

  # <tt>offset_date_time.rs:260</tt>, +weekday+.
  def test_weekday
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Weekday::Tuesday],
      [date(2019, 2, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Weekday::Friday],
      [date(2019, 3, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Weekday::Friday],
    ].each do |input, expected|
      assert_case expected, input.weekday
    end
  end

  # <tt>offset_date_time.rs:270</tt>, +to_julian_day+.
  def test_to_julian_day
    [
      [date(-4713, 11, 24).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 2_451_545],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 2_458_485],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 2_458_849],
      # left out: large-dates year -999_999
    ].each do |input, expected|
      assert_case expected, input.to_julian_day
    end
  end

  # <tt>offset_date_time.rs:276</tt>, +to_hms+.
  def test_to_hms
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 0).assume_offset(T::UtcOffset::UTC), [1, 2, 3]],
    ].each do |input, expected|
      assert_case expected, input.to_hms
    end
  end

  # <tt>offset_date_time.rs:282</tt>, +to_hms_milli+.
  def test_to_hms_milli
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4000000).assume_offset(T::UtcOffset::UTC), [1, 2, 3, 4]],
    ].each do |input, expected|
      assert_case expected, input.to_hms_milli
    end
  end

  # <tt>offset_date_time.rs:288</tt>, +to_hms_micro+.
  def test_to_hms_micro
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4005000).assume_offset(T::UtcOffset::UTC), [1, 2, 3, 4_005]],
    ].each do |input, expected|
      assert_case expected, input.to_hms_micro
    end
  end

  # <tt>offset_date_time.rs:294</tt>, +to_hms_nano+.
  def test_to_hms_nano
    [
      [date(2020, 1, 1).with_hms_nano(1, 2, 3, 4005006).assume_offset(T::UtcOffset::UTC), [1, 2, 3, 4_005_006]],
    ].each do |input, expected|
      assert_case expected, input.to_hms_nano
    end
  end

  # <tt>offset_date_time.rs:304</tt>, +hour+.
  def test_hour
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(-2, 0, 0)), 21],
    ].each do |input, expected|
      assert_case expected, input.hour
    end
  end

  # <tt>offset_date_time.rs:314</tt>, +minute+.
  def test_minute
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(0, 30, 0)), 29],
    ].each do |input, expected|
      assert_case expected, input.minute
    end
  end

  # <tt>offset_date_time.rs:324</tt>, +second+.
  def test_second
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(0, 0, 30)), 29],
    ].each do |input, expected|
      assert_case expected, input.second
    end
  end

  # <tt>offset_date_time.rs:331</tt>, +millisecond+.
  def test_millisecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999000000).assume_offset(T::UtcOffset::UTC), 999],
    ].each do |input, expected|
      assert_case expected, input.millisecond
    end
  end

  # <tt>offset_date_time.rs:338</tt>, +microsecond+.
  def test_microsecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999999000).assume_offset(T::UtcOffset::UTC), 999_999],
    ].each do |input, expected|
      assert_case expected, input.microsecond
    end
  end

  # <tt>offset_date_time.rs:345</tt>, +nanosecond+.
  def test_nanosecond
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), 0],
      [date(2019, 1, 1).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC), 999_999_999],
    ].each do |input, expected|
      assert_case expected, input.nanosecond
    end
  end

  # <tt>offset_date_time.rs:353</tt>, +replace_time+.
  def test_replace_time
    [
      [date(2020, 1, 1).with_hms_nano(5, 0, 0, 0).assume_offset(T::UtcOffset::UTC), clock(12, 0, 0, 0), date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).assume_offset(offset(-5, 0, 0)), clock(7, 0, 0, 0), date(2020, 1, 1).with_hms_nano(7, 0, 0, 0).assume_offset(offset(-5, 0, 0))],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), clock(12, 0, 0, 0), date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, new_time, expected|
      assert_case expected, input.replace_time(new_time)
    end
  end

  # <tt>offset_date_time.rs:364</tt>, +replace_date+.
  def test_replace_date
    [
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2020, 1, 30), date(2020, 1, 30).with_hms_nano(12, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2020, 1, 30), date(2020, 1, 30).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, new_date, expected|
      assert_case expected, input.replace_date(new_date)
    end
  end

  # <tt>offset_date_time.rs:379</tt>, +replace_date_time+.
  def test_replace_date_time
    [
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2020, 1, 30).with_hms_nano(16, 0, 0, 0), date(2020, 1, 30).with_hms_nano(16, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2020, 1, 1).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2020, 1, 30).with_hms_nano(0, 0, 0, 0), date(2020, 1, 30).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, new_datetime, expected|
      assert_case expected, input.replace_date_time(new_datetime)
    end
  end

  # <tt>offset_date_time.rs:389</tt>, +replace_offset+.
  def test_replace_offset
    [
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), offset(-5, 0, 0), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(-5, 0, 0))],
    ].each do |input, new_offset, expected|
      assert_case expected, input.replace_offset(new_offset)
    end
  end

  # <tt>offset_date_time.rs:401</tt>, +replace_year+.
  def test_replace_year
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 2019, date(2019, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), -1_000_000_000, nil],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 1_000_000_000, nil],
    ].each do |input, year, expected|
      assert_case expected, ok { input.replace_year(year) }
    end
  end

  # <tt>offset_date_time.rs:412</tt>, +replace_month+.
  def test_replace_month
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), Month::January, date(2022, 1, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2022, 1, 30).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), Month::February, nil],
    ].each do |input, month, expected|
      assert_case expected, ok { input.replace_month(month) }
    end
  end

  # <tt>offset_date_time.rs:424</tt>, +replace_day+.
  def test_replace_day
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 1, date(2022, 2, 1).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 0, nil],
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 30, nil],
    ].each do |input, day, expected|
      assert_case expected, ok { input.replace_day(day) }
    end
  end

  # <tt>offset_date_time.rs:438</tt>, +replace_ordinal+.
  def test_replace_ordinal
    [
      [date(2022, 2, 18).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 1, T::Date.from_ordinal_date(2022, 1).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2024, 2, 29).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 366, T::Date.from_ordinal_date(2024, 366).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 0, nil],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 366, nil],
      [T::Date.from_ordinal_date(2022, 49).with_hms_nano(12, 0, 0, 0).assume_offset(offset(1, 0, 0)), 367, nil],
    ].each do |input, ordinal, expected|
      assert_case expected, ok { input.replace_ordinal(ordinal) }
    end
  end

  # <tt>offset_date_time.rs:453</tt>, +replace_hour+.
  def test_replace_hour
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 7, date(2022, 2, 18).with_hms_nano(7, 2, 3, 4005006).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 24, nil],
    ].each do |input, hour, expected|
      assert_case expected, ok { input.replace_hour(hour) }
    end
  end

  # <tt>offset_date_time.rs:468</tt>, +replace_minute+.
  def test_replace_minute
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 7, date(2022, 2, 18).with_hms_nano(1, 7, 3, 4005006).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 60, nil],
    ].each do |input, minute, expected|
      assert_case expected, ok { input.replace_minute(minute) }
    end
  end

  # <tt>offset_date_time.rs:482</tt>, +replace_second+.
  def test_replace_second
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 7, date(2022, 2, 18).with_hms_nano(1, 2, 7, 4005006).assume_offset(offset(1, 0, 0))],
    ].each do |input, second, expected|
      assert_case expected, ok { input.replace_second(second) }
    end
  end

  # <tt>offset_date_time.rs:493</tt>, +replace_millisecond+.
  def test_replace_millisecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 7, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7000000).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 1_000, nil],
    ].each do |input, millisecond, expected|
      assert_case expected, ok { input.replace_millisecond(millisecond) }
    end
  end

  # <tt>offset_date_time.rs:508</tt>, +replace_microsecond+.
  def test_replace_microsecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 7_008, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7008000).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 1_000_000, nil],
    ].each do |input, microsecond, expected|
      assert_case expected, ok { input.replace_microsecond(microsecond) }
    end
  end

  # <tt>offset_date_time.rs:523</tt>, +replace_nanosecond+.
  def test_replace_nanosecond
    [
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 7_008_009, date(2022, 2, 18).with_hms_nano(1, 2, 3, 7008009).assume_offset(offset(1, 0, 0))],
      [date(2022, 2, 18).with_hms_nano(1, 2, 3, 4005006).assume_offset(offset(1, 0, 0)), 1_000_000_000, nil],
    ].each do |input, nanosecond, expected|
      assert_case expected, ok { input.replace_nanosecond(nanosecond) }
    end
  end

  # <tt>offset_date_time.rs:534</tt>, +truncate_to_day+.
  def test_truncate_to_day
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, expected|
      assert_case expected, input.truncate_to_day
    end
  end

  # <tt>offset_date_time.rs:541</tt>, +truncate_to_hour+.
  def test_truncate_to_hour
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(17, 0, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, expected|
      assert_case expected, input.truncate_to_hour
    end
  end

  # <tt>offset_date_time.rs:548</tt>, +truncate_to_minute+.
  def test_truncate_to_minute
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).assume_offset(offset(1, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, expected|
      assert_case expected, input.truncate_to_minute
    end
  end

  # <tt>offset_date_time.rs:555</tt>, +truncate_to_second+.
  def test_truncate_to_second
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(17, 47, 53, 0).assume_offset(offset(1, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, expected|
      assert_case expected, input.truncate_to_second
    end
  end

  # <tt>offset_date_time.rs:562</tt>, +truncate_to_millisecond+.
  def test_truncate_to_millisecond
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(17, 47, 53, 123000000).assume_offset(offset(1, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, expected|
      assert_case expected, input.truncate_to_millisecond
    end
  end

  # <tt>offset_date_time.rs:569</tt>, +truncate_to_microsecond+.
  def test_truncate_to_microsecond
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456789).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(17, 47, 53, 123456000).assume_offset(offset(1, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0)), date(2021, 11, 12).with_hms_nano(0, 0, 0, 0).assume_offset(offset(1, 0, 0))],
    ].each do |input, expected|
      assert_case expected, input.truncate_to_microsecond
    end
  end

  # <tt>offset_date_time.rs:575</tt>, +partial_eq+.
  def test_partial_eq
    [
      [in_utc(2000, 1, 1).to_offset(offset(-1)), in_utc(2000, 1, 1)],
    ].each do |a, b|
      assert_equal a, b
    end
  end

  # <tt>offset_date_time.rs:585</tt>, +partial_ord+.
  def test_partial_ord
    [
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1).to_offset(offset(-1)), 0],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>offset_date_time.rs:601</tt>, +ord+.
  def test_ord
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC).to_offset(offset(-1, 0, 0)), 0],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 1).with_hms_nano(0, 0, 0, 1).assume_offset(T::UtcOffset::UTC), -1],
      [date(-1, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(1, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), -1],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>offset_date_time.rs:607</tt>, +hash+.
  def test_hash
    [
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1).to_offset(offset(-1))],
    ].each do |a, b|
      assert_equal a.hash, b.hash
    end
  end

  # <tt>offset_date_time.rs:627</tt>, +arithmetic_regression+. Its std
  # Duration half is left out (decision 9).
  def test_arithmetic_regression
    val = T::Date::MIN.next_day.midnight.assume_offset(offset(12, 0, 1))
    assert_equal val, val + Duration::ZERO
    assert_equal val, val - Duration::ZERO
  end

  # <tt>offset_date_time.rs:646</tt>, +add_duration+.
  def test_add_duration
    [
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(5), date(2019, 1, 6).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(1), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC), Duration.seconds(2), date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).assume_offset(T::UtcOffset::UTC), Duration.seconds(-2), date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC)],
      [date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.hours(1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, duration, expected|
      assert_case expected, input + duration
    end
  end

  # <tt>offset_date_time.rs:671</tt>, +add_assign_duration+: Ruby's
  # <tt>+=</tt> is <tt>+</tt> and an assignment.
  def test_add_assign_duration
    [
      [in_utc(2019, 1, 1), Duration.days(5), in_utc(2019, 1, 6)],
      [in_utc(2019, 12, 31), Duration.days(1), in_utc(2020, 1, 1)],
      [in_utc(2019, 12, 31, 23, 59, 59), Duration.seconds(2), in_utc(2020, 1, 1, 0, 0, 1)],
      [in_utc(2020, 1, 1, 0, 0, 1), Duration.seconds(-2), in_utc(2019, 12, 31, 23, 59, 59)],
    ].each do |input, duration, expected|
      input += duration
      assert_case expected, input
    end
  end

  # <tt>offset_date_time.rs:699</tt>, +sub_duration+.
  def test_sub_duration
    [
      [date(2019, 1, 6).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(5), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(1), date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).assume_offset(T::UtcOffset::UTC), Duration.seconds(2), date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC)],
      [date(2019, 12, 31).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC), Duration.seconds(-2), date(2020, 1, 1).with_hms_nano(0, 0, 1, 0).assume_offset(T::UtcOffset::UTC)],
      [date(1999, 12, 31).with_hms_nano(23, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.hours(-1), date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, duration, expected|
      assert_case expected, input - duration
    end
  end

  # <tt>offset_date_time.rs:724</tt>, +sub_assign_duration+.
  def test_sub_assign_duration
    [
      [in_utc(2019, 1, 6), Duration.days(5), in_utc(2019, 1, 1)],
      [in_utc(2020, 1, 1), Duration.days(1), in_utc(2019, 12, 31)],
      [in_utc(2020, 1, 1, 0, 0, 1), Duration.seconds(2), in_utc(2019, 12, 31, 23, 59, 59)],
      [in_utc(2019, 12, 31, 23, 59, 59), Duration.seconds(-2), in_utc(2020, 1, 1, 0, 0, 1)],
    ].each do |input, duration, expected|
      input -= duration
      assert_case expected, input
    end
  end

  # <tt>offset_date_time.rs:863</tt>, +sub_self+.
  def test_sub_self
    [
      [date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(1)],
      [date(2019, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 1, 2).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(-1)],
      [date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(1)],
      [date(2019, 12, 31).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), date(2020, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), Duration.days(-1)],
      # left out: large-dates year +999_999
    ].each do |a, b, expected|
      assert_case expected, a - b
    end
  end

  # <tt>offset_date_time.rs:905</tt>, +sub_std+: a SystemTime is a Ruby
  # ::Time (plan 007, decision 10).
  def test_sub_std
    [
      [in_utc(2019, 1, 2), in_utc(2019, 1, 1).to_time, Duration.days(1)],
      [in_utc(2019, 1, 1), in_utc(2019, 1, 2).to_time, Duration.days(-1)],
      [in_utc(2020, 1, 1), in_utc(2019, 12, 31).to_time, Duration.days(1)],
      [in_utc(2019, 12, 31), in_utc(2020, 1, 1).to_time, Duration.days(-1)],
    ].each do |input, system, expected|
      assert_case expected, input - system
    end
  end

  # <tt>offset_date_time.rs:915</tt>, +eq_std+.
  def test_eq_std
    [T::OffsetDateTime.now_utc].each do |now_datetime|
      now_systemtime = now_datetime.to_time
      assert_equal now_datetime, now_systemtime
    end
  end

  # <tt>offset_date_time.rs:922</tt>, +std_eq+: Ruby's ::Time#== asks
  # OffsetDateTime#<=> (decision 10).
  def test_std_eq
    [T::OffsetDateTime.now_utc].each do |now_datetime|
      now_systemtime = now_datetime.to_time
      assert_equal now_systemtime, now_datetime
    end
  end

  # <tt>offset_date_time.rs:998</tt>, +ord_std+.
  def test_ord_std
    [
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1).to_time, 0],
      [in_utc(2019, 1, 1), in_utc(2020, 1, 1).to_time, -1],
      [in_utc(2019, 1, 1), in_utc(2019, 2, 1).to_time, -1],
      [in_utc(2019, 1, 1), in_utc(2019, 1, 2).to_time, -1],
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1, 1).to_time, -1],
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1, 0, 1).to_time, -1],
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1, 0, 0, 1).to_time, -1],
      [in_utc(2019, 1, 1), in_utc(2019, 1, 1, 0, 0, 0, 1_000).to_time, -1],
      [in_utc(2020, 1, 1), in_utc(2019, 1, 1).to_time, 1],
      [in_utc(2019, 2, 1), in_utc(2019, 1, 1).to_time, 1],
      [in_utc(2019, 1, 2), in_utc(2019, 1, 1).to_time, 1],
      [in_utc(2019, 1, 1, 1), in_utc(2019, 1, 1).to_time, 1],
      [in_utc(2019, 1, 1, 0, 1), in_utc(2019, 1, 1).to_time, 1],
      [in_utc(2019, 1, 1, 0, 0, 1), in_utc(2019, 1, 1).to_time, 1],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>offset_date_time.rs:1073</tt>, +std_ord+: Ruby's ::Time#<=> asks
  # OffsetDateTime#<=> and inverts it (decision 10).
  def test_std_ord
    [
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 1, 1), 0],
      [in_utc(2019, 1, 1).to_time, in_utc(2020, 1, 1), -1],
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 2, 1), -1],
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 1, 2), -1],
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 1, 1, 1), -1],
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 1, 1, 0, 1), -1],
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 1, 1, 0, 0, 1), -1],
      [in_utc(2019, 1, 1).to_time, in_utc(2019, 1, 1, 0, 0, 0, 1), -1],
      [in_utc(2020, 1, 1).to_time, in_utc(2019, 1, 1), 1],
      [in_utc(2019, 2, 1).to_time, in_utc(2019, 1, 1), 1],
      [in_utc(2019, 1, 2).to_time, in_utc(2019, 1, 1), 1],
      [in_utc(2019, 1, 1, 1).to_time, in_utc(2019, 1, 1), 1],
      [in_utc(2019, 1, 1, 0, 1).to_time, in_utc(2019, 1, 1), 1],
      [in_utc(2019, 1, 1, 0, 0, 1).to_time, in_utc(2019, 1, 1), 1],
    ].each do |a, b, expected|
      assert_case expected, a <=> b
    end
  end

  # <tt>offset_date_time.rs:1081</tt>, +from_std+: <tt>1.std_days()</tt> is
  # 86,400 seconds of a Ruby ::Time.
  def test_from_std
    [
      [::Time.at(0), T::OffsetDateTime::UNIX_EPOCH],
      [::Time.at(-86_400), T::OffsetDateTime::UNIX_EPOCH - Duration.days(1)],
      [::Time.at(86_400), T::OffsetDateTime::UNIX_EPOCH + Duration.days(1)],
    ].each do |input, expected|
      assert_case expected, T::OffsetDateTime.from(input)
    end
  end

  # <tt>offset_date_time.rs:1089</tt>, +to_std+.
  def test_to_std
    [
      [T::OffsetDateTime::UNIX_EPOCH, ::Time.at(0)],
      [T::OffsetDateTime::UNIX_EPOCH + Duration.days(1), ::Time.at(86_400)],
      [T::OffsetDateTime::UNIX_EPOCH - Duration.days(1), ::Time.at(-86_400)],
    ].each do |input, expected|
      assert_case expected, input.to_time
    end
  end

  # <tt>offset_date_time.rs:1130</tt>, +checked_add_duration+.
  def test_checked_add_duration
    [
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.nanoseconds(5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000005).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.seconds(4), date(2021, 10, 25).with_hms_nano(14, 1, 57, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.days(2), date(2021, 10, 27).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.weeks(1), date(2021, 11, 1).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.nanoseconds(-5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 449999995).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.seconds(-4), date(2021, 10, 25).with_hms_nano(14, 1, 49, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.days(-2), date(2021, 10, 23).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.weeks(-1), date(2021, 10, 18).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      # left out: large-dates year -999_999
      # left out: large-dates year -999_999
      # left out: large-dates year -999_990
      # left out: large-dates year +999_999
      # left out: large-dates year +999_999
      # left out: large-dates year +999_990
      # left out: large-dates year +999_999
      # left out: large-dates year -999_999
    ].each do |input, duration, expected|
      assert_case expected, input.checked_add(duration)
    end
  end

  # <tt>offset_date_time.rs:1175</tt>, +checked_sub_duration+.
  def test_checked_sub_duration
    [
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.nanoseconds(-5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000005).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.seconds(-4), date(2021, 10, 25).with_hms_nano(14, 1, 57, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.days(-2), date(2021, 10, 27).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.weeks(-1), date(2021, 11, 1).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.nanoseconds(5), date(2021, 10, 25).with_hms_nano(14, 1, 53, 449999995).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.seconds(4), date(2021, 10, 25).with_hms_nano(14, 1, 49, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.days(2), date(2021, 10, 23).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      [date(2021, 10, 25).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC), Duration.weeks(1), date(2021, 10, 18).with_hms_nano(14, 1, 53, 450000000).assume_offset(T::UtcOffset::UTC)],
      # left out: large-dates year -999_999
      # left out: large-dates year -999_999
      # left out: large-dates year -999_990
      # left out: large-dates year +999_999
      # left out: large-dates year +999_999
      # left out: large-dates year +999_990
      # left out: large-dates year +999_999
      # left out: large-dates year -999_999
    ].each do |input, duration, expected|
      assert_case expected, input.checked_sub(duration)
    end
  end

  # <tt>offset_date_time.rs:1198</tt>, +saturating_add_duration+.
  def test_saturating_add_duration
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0)), Duration.days(2), date(2021, 11, 14).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0)), Duration.days(-2), date(2021, 11, 10).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0))],
      # left out: large-dates year -999999
      # left out: large-dates year +999999
      # left out: large-dates year -999999
      # left out: large-dates year +999999
    ].each do |input, duration, expected|
      assert_case expected, input.saturating_add(duration)
    end
  end

  # <tt>offset_date_time.rs:1221</tt>, +saturating_sub_duration+.
  def test_saturating_sub_duration
    [
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0)), Duration.days(2), date(2021, 11, 10).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0))],
      [date(2021, 11, 12).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0)), Duration.days(-2), date(2021, 11, 14).with_hms_nano(17, 47, 0, 0).assume_offset(offset(10, 0, 0))],
      # left out: large-dates year -999999
      # left out: large-dates year +999999
      # left out: large-dates year -999999
      # left out: large-dates year +999999
    ].each do |input, duration, expected|
      assert_case expected, input.saturating_sub(duration)
    end
  end

  # <tt>offset_date_time.rs:1236</tt>, +to_offset_regression+.
  def test_to_offset_regression
    value = odt(0, 1, 1, 0, 0, 0, 0, offset(24, 59)).to_offset(offset(-24, -59))
    assert_equal odt(-1, 12, 29, 22, 2, 0, 0, offset(-24, -59)), value
  end
end

#--
# SPDX-SnippetEnd
#++
