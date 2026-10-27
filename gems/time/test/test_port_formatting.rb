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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/formatting.rs
#++

# time's own tests in <tt>tests/integration/formatting.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortFormatting < Minitest::Test
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

  # <tt>formatting.rs:16</tt>, +rfc_2822_odt+.
  def test_rfc_2822_odt
    [
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), "Sat, 02 Jan 2021 03:04:05 +0000"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(6, 7, 0)), "Sat, 02 Jan 2021 03:04:05 +0607"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(-6, -7, 0)), "Sat, 02 Jan 2021 03:04:05 -0607"],
    ].each do |datetime, expected|
      assert_case expected, datetime.format(WellKnown::Rfc2822)
    end
  end

  # <tt>formatting.rs:22</tt>, +rfc_2822_udt+.
  def test_rfc_2822_udt
    [
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).as_utc, "Sat, 02 Jan 2021 03:04:05 +0000"],
    ].each do |datetime, expected|
      assert_case expected, datetime.format(WellKnown::Rfc2822)
    end
  end

  # <tt>formatting.rs:29</tt>, +rfc_2822_invalid_odt+.
  def test_rfc_2822_invalid_odt
    [
      [date(1885, 1, 1).with_hms_nano(1, 1, 1, 0).assume_offset(T::UtcOffset::UTC), "year"],
      [date(2000, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(0, 0, 1)), "offset_second"],
    ].each do |datetime, component|
      error = assert_raises(T::Error::Format::InvalidComponent) { datetime.format(WellKnown::Rfc2822) }
      assert_equal component, error.component
    end
  end

  # <tt>formatting.rs:38</tt>, +rfc_2822_invalid_udt+.
  def test_rfc_2822_invalid_udt
    [
      [date(1885, 1, 1).with_hms_nano(1, 1, 1, 0).as_utc, "year"],
    ].each do |datetime, component|
      error = assert_raises(T::Error::Format::InvalidComponent) { datetime.format(WellKnown::Rfc2822) }
      assert_equal component, error.component
    end
  end

  # <tt>formatting.rs:58</tt>, +rfc_3339+.
  def test_rfc_3339
    [
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 100000000).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.1Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 120000000).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.12Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123000000).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.123Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123400000).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.1234Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123450000).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.12345Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456000).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.123456Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456700).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.1234567Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456780).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.12345678Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456789).assume_offset(T::UtcOffset::UTC), "2021-01-02T03:04:05.123456789Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456789).assume_offset(offset(-1, -2, 0)), "2021-01-02T03:04:05.123456789-01:02"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456789).assume_offset(offset(1, 2, 0)), "2021-01-02T03:04:05.123456789+01:02"],
    ].each do |datetime, expected|
      assert_case expected, datetime.format(WellKnown::Rfc3339)
    end
  end

  # <tt>formatting.rs:65</tt>, +rfc_3339_err+.
  def test_rfc_3339_err
    [
      [date(-1, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), "year"],
      [date(0, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(offset(0, 0, 1)), "offset_second"],
    ].each do |datetime, component|
      error = assert_raises(T::Error::Format::InvalidComponent) { datetime.format(WellKnown::Rfc3339) }
      assert_equal component, error.component
    end
  end

  # <tt>formatting.rs:74</tt>, +iso_8601_time+.
  def test_iso_8601_time
    [
      [clock(1, 2, 3, 123456789), Iso8601::TIME, "01:02:03.123456789"],
    ].each do |value, format, expected|
      assert_case expected, value.format(format)
    end
  end

  # <tt>formatting.rs:183</tt>, +iso_8601_odt+.
  def test_iso_8601_odt
    [
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(1, 0, 0)), Iso8601::DEFAULT, "2021-01-02T03:04:05.000000000+01:00"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(1, 0, 0)), Iso8601.new(Iso8601::Config::DEFAULT.set_offset_precision(Iso8601::OffsetPrecision::Hour)), "2021-01-02T03:04:05.000000000+01"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601::DEFAULT, "2021-01-02T03:04:05.000000000Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_use_separators(false)), "20210102T030405.000000000Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_year_is_six_digits(true)), "+002021-01-02T03:04:05.000000000Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Hour.new(decimal_digits: nil))), "2021-01-02T03Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Minute.new(decimal_digits: nil))), "2021-01-02T03:04Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Second.new(decimal_digits: nil))), "2021-01-02T03:04:05Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_date_kind(Iso8601::DateKind::Ordinal)), "2021-002T03:04:05.000000000Z"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_date_kind(Iso8601::DateKind::Week)), "2020-W53-6T03:04:05.000000000Z"],
      [date(2026, 3, 23).with_hms_nano(9, 27, 3, 631670000).assume_offset(T::UtcOffset::UTC), Iso8601.new(Iso8601::Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Second.new(decimal_digits: 6))), "2026-03-23T09:27:03.631670Z"],
      # left out: large-dates year -123_456
      # left out: large-dates year -123_456
      # left out: large-dates year -123_456
    ].each do |value, format, expected|
      assert_case expected, value.format(format)
    end
  end

  # <tt>formatting.rs:213</tt>, +iso_8601_invalid+.
  def test_iso_8601_invalid
    [
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(0, 0, 1)), Iso8601::DEFAULT, "offset_second"],
      [date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(0, 1, 0)), Iso8601.new(Iso8601::Config::DEFAULT.set_offset_precision(Iso8601::OffsetPrecision::Hour)), "offset_minute"],
      # left out: large-dates year +10_000
      # left out: large-dates year +10_000
      # left out: large-dates year +10_000
    ].each do |value, format, component|
      error = assert_raises(T::Error::Format::InvalidComponent) { value.format(format) }
      assert_equal component, error.component
    end
  end

  # <tt>formatting.rs:250</tt>, +iso_8601_issue_678+.
  def test_iso_8601_issue_678
    seconds = -> (digits) { Iso8601.new(Iso8601::Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Second.new(decimal_digits: digits))) }
    [
      [Iso8601::DEFAULT, "2021-01-02T03:04:05.999999999Z"],
      [seconds.call(9), "2021-01-02T03:04:05.999999999Z"],
      [seconds.call(6), "2021-01-02T03:04:05.999999Z"],
      [seconds.call(3), "2021-01-02T03:04:05.999Z"],
    ].each do |format, expected|
      assert_equal expected, datetime(2021, 1, 2, 3, 4, 5, 999_999_999).assume_utc.format(format)
    end
  end

  # <tt>formatting.rs:298</tt>, +format_time+.
  def test_format_time
    [
      [clock(13, 2, 3, 456789012), fd("[hour]"), "13"],
      [clock(13, 2, 3, 456789012), fd("[hour repr:12]"), "01"],
      [clock(13, 2, 3, 456789012), fd("[hour repr:12 padding:none]"), "1"],
      [clock(13, 2, 3, 456789012), fd("[hour repr:12 padding:space]"), " 1"],
      [clock(13, 2, 3, 456789012), fd("[hour repr:24]"), "13"],
      [clock(13, 2, 3, 456789012), fd("[hour repr:24 padding:none]"), "13"],
      [clock(13, 2, 3, 456789012), fd("[hour repr:24 padding:space]"), "13"],
      [clock(13, 2, 3, 456789012), fd("[minute]"), "02"],
      [clock(13, 2, 3, 456789012), fd("[minute padding:none]"), "2"],
      [clock(13, 2, 3, 456789012), fd("[minute padding:space]"), " 2"],
      [clock(13, 2, 3, 456789012), fd("[minute padding:zero]"), "02"],
      [clock(13, 2, 3, 456789012), fd("[period]"), "PM"],
      [clock(13, 2, 3, 456789012), fd("[period case:upper]"), "PM"],
      [clock(13, 2, 3, 456789012), fd("[period case:lower]"), "pm"],
      [clock(13, 2, 3, 456789012), fd("[second]"), "03"],
      [clock(13, 2, 3, 456789012), fd("[second padding:none]"), "3"],
      [clock(13, 2, 3, 456789012), fd("[second padding:space]"), " 3"],
      [clock(13, 2, 3, 456789012), fd("[second padding:zero]"), "03"],
      [clock(13, 2, 3, 456789012), fd("[subsecond]"), "456789012"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:1]"), "4"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:2]"), "45"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:3]"), "456"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:4]"), "4567"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:5]"), "45678"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:6]"), "456789"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:7]"), "4567890"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:8]"), "45678901"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:9]"), "456789012"],
      [clock(13, 2, 3, 456789012), fd("[subsecond digits:1+]"), "456789012"],
      [clock(1, 2, 3, 0), fd("[hour repr:12][period]"), "01AM"],
      [T::Time::MIDNIGHT, fd("[hour repr:12][period case:lower]"), "12am"],
      [T::Time::MIDNIGHT, fd("[subsecond digits:1+]"), "0"],
      [clock(0, 0, 0, 10000000), fd("[subsecond digits:1+]"), "01"],
      [clock(0, 0, 0, 1000000), fd("[subsecond digits:1+]"), "001"],
      [clock(0, 0, 0, 100000), fd("[subsecond digits:1+]"), "0001"],
      [clock(0, 0, 0, 10000), fd("[subsecond digits:1+]"), "00001"],
      [clock(0, 0, 0, 1000), fd("[subsecond digits:1+]"), "000001"],
      [clock(0, 0, 0, 100), fd("[subsecond digits:1+]"), "0000001"],
      [clock(0, 0, 0, 10), fd("[subsecond digits:1+]"), "00000001"],
      [clock(0, 0, 0, 1), fd("[subsecond digits:1+]"), "000000001"],
    ].each do |value, description, output|
      assert_equal output, value.format(description)
      out = +""
      value.format_into(out, description)
      assert_equal output, out
    end
  end

  # <tt>formatting.rs:336</tt>, +display_time+.
  def test_display_time
    [
      [clock(0, 0, 0, 0), "0:00:00.0"],
      [clock(23, 59, 0, 0), "23:59:00.0"],
      [clock(23, 59, 59, 0), "23:59:59.0"],
      [clock(0, 0, 1, 0), "0:00:01.0"],
      [clock(0, 0, 0, 100000000), "0:00:00.1"],
      [clock(0, 0, 0, 10000000), "0:00:00.01"],
      [clock(0, 0, 0, 1000000), "0:00:00.001"],
      [clock(0, 0, 0, 100000), "0:00:00.0001"],
      [clock(0, 0, 0, 10000), "0:00:00.00001"],
      [clock(0, 0, 0, 1000), "0:00:00.000001"],
      [clock(0, 0, 0, 100), "0:00:00.0000001"],
      [clock(0, 0, 0, 10), "0:00:00.00000001"],
      [clock(0, 0, 0, 1), "0:00:00.000000001"],
    ].each do |value, expected|
      assert_equal expected, value.to_s
    end
  end

  # <tt>formatting.rs:373</tt>, +format_date+.
  def test_format_date
    [
      [fd("[day]"), "31"],
      [fd("[month]"), "12"],
      [fd("[month repr:short]"), "Dec"],
      [fd("[month repr:long]"), "December"],
      [fd("[ordinal]"), "365"],
      [fd("[weekday]"), "Tuesday"],
      [fd("[weekday repr:short]"), "Tue"],
      [fd("[weekday repr:sunday]"), "3"],
      [fd("[weekday repr:sunday one_indexed:false]"), "2"],
      [fd("[weekday repr:monday]"), "2"],
      [fd("[weekday repr:monday one_indexed:false]"), "1"],
      [fd("[week_number]"), "01"],
      [fd("[week_number padding:none]"), "1"],
      [fd("[week_number padding:space]"), " 1"],
      [fd("[week_number repr:sunday]"), "52"],
      [fd("[week_number repr:monday]"), "52"],
      [fd("[year]"), "2019"],
      [fd("[year base:iso_week]"), "2020"],
      [fd("[year sign:mandatory]"), "+2019"],
      [fd("[year base:iso_week sign:mandatory]"), "+2020"],
      [fd("[year repr:century]"), "20"],
      [fd("[year repr:last_two]"), "19"],
      [fd("[year base:iso_week repr:last_two]"), "20"],
      # left out: large-dates range modifier
      # left out: large-dates range modifier
      # left out: large-dates range modifier
    ].each do |description, output|
      assert_equal output, date(2019, 12, 31).format(description)
      out = +""
      date(2019, 12, 31).format_into(out, description)
      assert_equal output, out
    end
  end

  # <tt>formatting.rs:419</tt>, +display_date+.
  def test_display_date
    [
      [date(2019, 1, 1), "2019-01-01"],
      [date(2019, 12, 31), "2019-12-31"],
      [date(-4713, 11, 24), "-4713-11-24"],
      [date(-1, 1, 1), "-0001-01-01"],
      # left out: large-dates year +10_000
      # left out: large-dates year +100_000
      # left out: large-dates year -10_000
      # left out: large-dates year -100_000
    ].each do |value, expected|
      assert_equal expected, value.to_s
    end
  end

  # <tt>formatting.rs:430</tt>, +format_offset+.
  def test_format_offset
    [
      [offset(1, 2, 3), fd("[offset_hour sign:automatic]"), "01"],
      [offset(1, 2, 3), fd("[offset_hour sign:mandatory]"), "+01"],
      [offset(-1, -2, -3), fd("[offset_hour sign:automatic]"), "-01"],
      [offset(-1, -2, -3), fd("[offset_hour sign:mandatory]"), "-01"],
      [offset(1, 2, 3), fd("[offset_minute]"), "02"],
      [offset(1, 2, 3), fd("[offset_second]"), "03"],
    ].each do |value, description, output|
      assert_equal output, value.format(description)
      out = +""
      value.format_into(out, description)
      assert_equal output, out
    end
  end

  # <tt>formatting.rs:464</tt>, +display_offset+.
  def test_display_offset
    [
      [T::UtcOffset::UTC, "+00:00:00"],
      [offset(0, 0, 1), "+00:00:01"],
      [offset(0, 0, -1), "-00:00:01"],
      [offset(1, 0, 0), "+01:00:00"],
      [offset(-1, 0, 0), "-01:00:00"],
      [offset(23, 59, 0), "+23:59:00"],
      [offset(-23, -59, 0), "-23:59:00"],
      [offset(23, 59, 59), "+23:59:59"],
      [offset(-23, -59, -59), "-23:59:59"],
    ].each do |value, expected|
      assert_equal expected, value.to_s
    end
  end

  # <tt>formatting.rs:480</tt>, +format_pdt+.
  def test_format_pdt
    [
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0), fd("[year]-[month]-[day] [hour]:[minute]:[second].[subsecond]"), "1970-01-01 00:00:00.0"],
    ].each do |value, description, expected|
      assert_equal expected, value.format(description)
      out = +""
      value.format_into(out, description)
      assert_equal expected, out
    end
  end

  # <tt>formatting.rs:502</tt>, +display_pdt+.
  def test_display_pdt
    [
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0), "1970-01-01 0:00:00.0"],
      [date(1970, 1, 1).with_hms_nano(0, 0, 1, 0), "1970-01-01 0:00:01.0"],
    ].each do |value, expected|
      assert_equal expected, value.to_s
    end
  end

  # <tt>formatting.rs:556</tt>, +format_udt+.
  def test_format_udt
    [
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, "1970-01-01 00:00:00.0"],
    ].each do |value, expected|
      description = fd("[year]-[month]-[day] [hour]:[minute]:[second].[subsecond]")
      assert_equal expected, value.format(description)
    end
  end

  # <tt>formatting.rs:550</tt>, +display_odt+.
  def test_display_odt
    [
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0).assume_offset(T::UtcOffset::UTC), "1970-01-01 0:00:00.0 +00:00:00"],
    ].each do |value, expected|
      assert_equal expected, value.to_s
    end
  end

  # <tt>formatting.rs:575</tt>, +display_udt+.
  def test_display_udt
    [
      [date(1970, 1, 1).with_hms_nano(0, 0, 0, 0).as_utc, "1970-01-01 0:00:00.0 +00"],
    ].each do |value, expected|
      assert_equal expected, value.to_s
    end
  end

  # <tt>formatting.rs:580</tt>, +insufficient_type_information+. Its
  # second half formats a +First+ item, which the gem defers with the
  # format-item tree (plan 007, decision 1).
  def test_insufficient_type_information
    assert_raises(T::Error::Format::InsufficientTypeInformation) { T::Time::MIDNIGHT.format(fd("[year]")) }
  end

  # <tt>formatting.rs:759</tt>, +ignore+.
  def test_ignore
    [
      [fd("[ignore count:2]"), ""],
    ].each do |description, expected|
      assert_equal expected, T::Time::MIDNIGHT.format(description)
    end
  end

  # <tt>formatting.rs:765</tt>, +end+.
  def test_end
    [
      [fd("[end]"), ""],
    ].each do |description, expected|
      assert_equal expected, T::Time::MIDNIGHT.format(description)
    end
  end

  # <tt>formatting.rs:800</tt>, +unix_timestamp+.
  def test_unix_timestamp
    [
      [date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456789).assume_offset(T::UtcOffset::UTC), fd("[unix_timestamp]"), "1234567890"],
      [date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456789).assume_offset(T::UtcOffset::UTC), fd("[unix_timestamp sign:mandatory]"), "+1234567890"],
      [date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456789).assume_offset(T::UtcOffset::UTC), fd("[unix_timestamp precision:millisecond]"), "1234567890123"],
      [date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456789).assume_offset(T::UtcOffset::UTC), fd("[unix_timestamp precision:microsecond]"), "1234567890123456"],
      [date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456789).assume_offset(T::UtcOffset::UTC), fd("[unix_timestamp precision:nanosecond]"), "1234567890123456789"],
      [date(1969, 12, 31).with_hms_nano(23, 59, 59, 0).assume_offset(T::UtcOffset::UTC), fd("[unix_timestamp]"), "-1"],
    ].each do |value, description, expected|
      assert_equal expected, value.format(description)
    end
  end
end

#--
# SPDX-SnippetEnd
#++
