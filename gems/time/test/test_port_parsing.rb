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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/parsing.rs
#++

# time's own tests in <tt>tests/integration/parsing.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortParsing < Minitest::Test
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

  # <tt>parsing.rs:30</tt>, +rfc_2822_odt+.
  def test_rfc_2822_odt
    [
      ["Sat, 02 Jan 2021 03:04:05 GMT", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["Sat, 02 Jan 2021 03:04:05 UT", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["Sat, 02 Jan 2021 03:04:05 +0000", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["Sat, 02 Jan 2021 03:04:05 +0607", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(6, 7, 0))],
      ["Sat, 02 Jan 2021 03:04:05 -0607", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(-6, -7, 0))],
      ["Fri, 31 Dec 2021 23:59:60 Z", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC)],
      ["Fri, 31 Dec 2021 23:59:60 z", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC)],
      ["Fri, 31 Dec 2021 23:59:60 a", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC)],
      ["Fri, 31 Dec 2021 23:59:60 A", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC)],
      ["Fri, 31 Dec 2021 17:52:60 -0607", date(2021, 12, 31).with_hms_nano(17, 52, 59, 999999999).assume_offset(offset(-6, -7, 0))],
      ["Sat, 01 Jan 2022 06:06:60 +0607", date(2022, 1, 1).with_hms_nano(6, 6, 59, 999999999).assume_offset(offset(6, 7, 0))],
    ].each do |input, expected|
      assert_case expected, T::OffsetDateTime.parse(input, WellKnown::Rfc2822)
    end
  end

  # <tt>parsing.rs:52</tt>, +rfc_2822_udt+.
  def test_rfc_2822_udt
    [
      ["Sat, 02 Jan 2021 03:04:05 GMT", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).as_utc],
      ["Sat, 02 Jan 2021 03:04:05 UT", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).as_utc],
      ["Sat, 02 Jan 2021 03:04:05 +0000", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).as_utc],
      ["Sat, 02 Jan 2021 03:04:05 +0607", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(6, 7, 0)).to_utc],
      ["Sat, 02 Jan 2021 03:04:05 -0607", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(-6, -7, 0)).to_utc],
      ["Fri, 31 Dec 2021 23:59:60 Z", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).as_utc],
      ["Fri, 31 Dec 2021 23:59:60 z", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).as_utc],
      ["Fri, 31 Dec 2021 23:59:60 a", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).as_utc],
      ["Fri, 31 Dec 2021 23:59:60 A", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).as_utc],
      ["Fri, 31 Dec 2021 17:52:60 -0607", date(2021, 12, 31).with_hms_nano(17, 52, 59, 999999999).assume_offset(offset(-6, -7, 0)).to_utc],
      ["Sat, 01 Jan 2022 06:06:60 +0607", date(2022, 1, 1).with_hms_nano(6, 6, 59, 999999999).assume_offset(offset(6, 7, 0)).to_utc],
    ].each do |input, expected|
      assert_case expected, T::UtcDateTime.parse(input, WellKnown::Rfc2822)
    end
  end

  # <tt>parsing.rs:62</tt>, +rfc_2822_date+.
  def test_rfc_2822_date
    [
      ["Sat, 02 Jan 2021 03:04:05 GMT", date(2021, 1, 2)],
      ["Sat, 02 Jan 2021 03:04:05 +0607", date(2021, 1, 2)],
      ["Sat, 02 Jan 2021 03:04:05 -0607", date(2021, 1, 2)],
      ["Sat, 02 Jan 21 03:04:05 -0607", date(2021, 1, 2)],
      ["Sat, 02 Jan 71 03:04:05 -0607", date(1971, 1, 2)],
    ].each do |input, expected|
      assert_case expected, T::Date.parse(input, WellKnown::Rfc2822)
    end
  end

  # <tt>parsing.rs:67</tt>, +rfc_2822_time+: Rust's string continuations
  # become Ruby's concatenation, with the same escapes.
  def test_rfc_2822_time
    input = "  \t Sat,\r\n " \
      "(\tfoo012FOO!)" \
      "(\u{1}\u{b}\u{e}\u{7f})" \
      "(\\\u{0})" \
      "(\\\u{1}\\\u{9}\\\u{28}\\\u{29}\\\\u{5c}\\\u{7f})" \
      "(\\\n\\\u{b})" \
      "02 \r\n  \r\n Jan 2021 03:04:05 GMT"
    assert_case clock(3, 4, 5), ok { T::Time.parse(input, WellKnown::Rfc2822) }
  end

  # <tt>parsing.rs:86</tt>, +issue_661_odt+.
  def test_issue_661_odt
    [
      ["02 Jan 2021 03:04:05 +0607", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(6, 7, 0))],
    ].each do |input, expected|
      assert_case expected, T::OffsetDateTime.parse(input, WellKnown::Rfc2822)
    end
  end

  # <tt>parsing.rs:92</tt>, +issue_661_date+.
  def test_issue_661_date
    [
      ["02 Jan 2021 03:04:05 +0607", date(2021, 1, 2)],
    ].each do |input, expected|
      assert_case expected, T::Date.parse(input, WellKnown::Rfc2822)
    end
  end

  # <tt>parsing.rs:107</tt>, +rfc_2822_err_invalid_component+.
  def test_rfc_2822_err_invalid_component
    [
      [" \r\nM", "day"],
      ["Mon, o2", "day"],
      ["Mon, 02 jxn", "month"],
      ["Mon, 02 Jan abcd", "year"],
      ["Mon, 02 Jan 1899", "year"],
      ["Mon, 02 Jan 2021 ab", "hour"],
      ["Mon, 02 Jan 2021 03:04:ab", "second"],
      ["Mon, 02 Jan 2021 03:04 6", "offset hour"],
      ["Mon, 02 Jan 2021 03:04:05 -6", "offset hour"],
      ["Mon, 02 Jan 2021 03:04:05 -060", "offset minute"],
    ].each do |input, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::OffsetDateTime.parse(input, WellKnown::Rfc2822) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:125</tt>, +rfc_2822_err_invalid_literal+.
  def test_rfc_2822_err_invalid_literal
    [
      "Mon:",
      "Mon, 02_",
      "Mon, 02 Jan_",
      "Mon, 02 Jan 2021_",
      "Mon, 02 Jan 21_",
      "Mon, 02 Jan 2021 03_",
      "Mon, 02 Jan 2021 03:04_",
      "Mon, 02 Jan 2021 03:04:05_",
      "Mon, 02 Jan 2021 03:04:05:ab",
    ].each do |input|
      assert_raises(T::Error::Parse::ParseFromDescription::InvalidLiteral) { T::OffsetDateTime.parse(input, WellKnown::Rfc2822) }
    end
  end

  # <tt>parsing.rs:138</tt>, +rfc_2822_err_component_range+.
  def test_rfc_2822_err_component_range
    [
      ["Fri, 31 Dec 2021 23:59:61 Z", false],
      ["Fri, 31 Dec 2021 03:04:60 Z", true],
      ["Fri, 30 Dec 2021 23:59:60 Z", true],
    ].each do |input, conditional|
      error = assert_raises(T::Error::Parse::TryFromParsed::ComponentRange) { T::OffsetDateTime.parse(input, WellKnown::Rfc2822) }
      assert_equal ["second", conditional], [error.name, error.is_conditional]
    end
  end

  # <tt>parsing.rs:164</tt>, +rfc_3339_odt+.
  def test_rfc_3339_odt
    [
      ["2021-01-02T03:04:05Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["2021-12-31T23:59:60Z", date(2021, 12, 31).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC)],
      ["2015-07-01T00:59:60+01:00", date(2015, 6, 30).with_hms_nano(23, 59, 59, 999999999).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.1Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 100000000).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.12Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 120000000).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.123Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123000000).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.1234Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123400000).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.12345Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123450000).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.123456Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456000).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.1234567Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456700).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.12345678Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456780).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.123456789Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456789).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02T03:04:05.123456789-01:02", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456789).assume_offset(offset(-1, -2, 0))],
      ["2021-01-02T03:04:05.123456789+01:02", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123456789).assume_offset(offset(1, 2, 0))],
      ["2021-01-02T03:04:05.123-00:01", date(2021, 1, 2).with_hms_nano(3, 4, 5, 123000000).assume_offset(offset(0, -1, 0))],
      ["2021-01-02 03:04:05Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["2021-01-02$03:04:05Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, expected|
      assert_case expected, T::OffsetDateTime.parse(input, WellKnown::Rfc3339)
    end
  end

  # <tt>parsing.rs:172</tt>, +rfc_3339_date+.
  def test_rfc_3339_date
    [
      ["2021-01-02T03:04:05Z", date(2021, 1, 2)],
      ["2021-01-02T03:04:05.123+01:02", date(2021, 1, 2)],
      ["2021-01-02T03:04:05.123-01:02", date(2021, 1, 2)],
    ].each do |input, expected|
      assert_case expected, T::Date.parse(input, WellKnown::Rfc3339)
    end
  end

  # <tt>parsing.rs:181</tt>, +rfc_3339_utc_offset+.
  def test_rfc_3339_utc_offset
    [
      ["2021-01-02T03:04:05Z", T::UtcOffset::UTC],
      ["2021-01-02T03:04:05.123+01:02", offset(1, 2, 0)],
      ["2021-01-02T03:04:05.123-01:02", offset(-1, -2, 0)],
      ["2021-01-02T03:04:05.123-00:01", offset(0, -1, 0)],
    ].each do |input, expected|
      assert_case expected, T::UtcOffset.parse(input, WellKnown::Rfc3339)
    end
  end

  # <tt>parsing.rs:199</tt>, +rfc_3339_err_invalid_component+.
  def test_rfc_3339_err_invalid_component
    [
      ["x", "year"],
      ["2021-x", "month"],
      ["2021-0", "month"],
      ["2021-01-0", "day"],
      ["2021-01-01", "separator"],
      ["2021-01-01T0", "hour"],
      ["2021-01-01T00:0", "minute"],
      ["2021-01-01T00:00:0", "second"],
      ["2021-01-01T00:00:00.x", "subsecond"],
      ["2021-01-01T00:00:00x", "offset hour"],
      ["2021-01-01T00:00:00+0", "offset hour"],
      ["2021-01-01T00:00:00+00:0", "offset minute"],
      ["2021-01-01T00:00:00+24:00", "offset hour"],
    ].each do |input, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::OffsetDateTime.parse(input, WellKnown::Rfc3339) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:214</tt>, +rfc_3339_err_invalid_literal+.
  def test_rfc_3339_err_invalid_literal
    [
      "2021x",
      "2021-01x",
      "2021-01-01T00x",
      "2021-01-01T00:00x",
      "2021-01-01T00:00:00+00x",
    ].each do |input|
      assert_raises(T::Error::Parse::ParseFromDescription::InvalidLiteral) { T::OffsetDateTime.parse(input, WellKnown::Rfc3339) }
    end
  end

  # <tt>parsing.rs:230</tt>, +rfc_3339_err_component_range+.
  def test_rfc_3339_err_component_range
    [
      ["2021-13-01T00:00:00Z", "month", false],
      ["2021-12-31T23:59:61Z", "second", false],
      ["2021-01-02T23:59:60Z", "second", true],
      ["2021-12-31T03:04:60Z", "second", true],
      ["2021-12-31T23:59:60+01:00", "second", true],
      ["2021-01-01T00:00:00+00:60", "offset minute", false],
    ].each do |input, name, conditional|
      error = assert_raises(T::Error::Parse::TryFromParsed::ComponentRange) { T::OffsetDateTime.parse(input, WellKnown::Rfc3339) }
      assert_equal [name, conditional], [error.name, error.is_conditional]
    end
  end

  # <tt>parsing.rs:244</tt>, +rfc_3339_err_unexpected_trailing_offset+.
  def test_rfc_3339_err_unexpected_trailing_offset
    [
      "2021-01-02T03:04:05Z ",
    ].each do |input|
      assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) { T::OffsetDateTime.parse(input, WellKnown::Rfc3339) }
    end
  end

  # <tt>parsing.rs:255</tt>, +rfc_3339_err_component_range_pdt+.
  def test_rfc_3339_err_component_range_pdt
    [
      ["2021-01-02T03:04:60Z", "second", false],
    ].each do |input, name, conditional|
      error = assert_raises(T::Error::Parse::TryFromParsed::ComponentRange) { T::PlainDateTime.parse(input, WellKnown::Rfc3339) }
      assert_equal [name, conditional], [error.name, error.is_conditional]
    end
  end

  # <tt>parsing.rs:273</tt>, +rfc_3339_err_invalid_literal_pdt+.
  def test_rfc_3339_err_invalid_literal_pdt
    [
      "2021x",
      "2021-01x",
      "2021-01-01T00x",
      "2021-01-01T00:00x",
      "2021-01-01T00:00:00+00x",
    ].each do |input|
      assert_raises(T::Error::Parse::ParseFromDescription::InvalidLiteral) { T::PlainDateTime.parse(input, WellKnown::Rfc3339) }
    end
  end

  # <tt>parsing.rs:297</tt>, +rfc_3339_err_invalid_component_pdt+.
  def test_rfc_3339_err_invalid_component_pdt
    [
      ["x", "year"],
      ["2021-x", "month"],
      ["2021-0", "month"],
      ["2021-13-01T00:00:00Z", "month"],
      ["2021-01-0", "day"],
      ["2021-01-01", "separator"],
      ["2021-01-01T0", "hour"],
      ["2021-01-01T00:0", "minute"],
      ["2021-01-01T00:00:0", "second"],
      ["2021-01-01T00:00:00.x", "subsecond"],
      ["2021-01-01T00:00:00x", "offset hour"],
      ["2021-01-01T00:00:00+0", "offset hour"],
      ["2021-01-01T00:00:00+00:0", "offset minute"],
      ["2021-01-01T00:00:00+24:00", "offset hour"],
    ].each do |input, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::PlainDateTime.parse(input, WellKnown::Rfc3339) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:308</tt>, +rfc_3339_err_component_range_time+.
  def test_rfc_3339_err_component_range_time
    [
      ["2022-01-01T00:59:60+01:00", false],
      ["2021-12-31T23:04:60Z", false],
    ].each do |input, conditional|
      error = assert_raises(T::Error::Parse::TryFromParsed::ComponentRange) { T::Time.parse(input, WellKnown::Rfc3339) }
      assert_equal ["second", conditional], [error.name, error.is_conditional]
    end
  end

  # <tt>parsing.rs:326</tt>, +iso_8601_odt+.
  def test_iso_8601_odt
    [
      ["2021-01-02T03:04:05Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["2021-002T03:04:05Z", T::Date.from_ordinal_date(2021, 2).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["2021-W01-2T03:04:05Z", T::Date.from_iso_week_date(2021, 1, Weekday::Monday.nth_next(1)).with_hms_nano(3, 4, 5, 0).assume_offset(T::UtcOffset::UTC)],
      ["-002021-01-02T03:04:05+01:00", date(-2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(1, 0, 0))],
      ["20210102T03.1Z", date(2021, 1, 2).with_hms_nano(3, 6, 0, 0).assume_offset(T::UtcOffset::UTC)],
      ["2021002T0304.1Z", T::Date.from_ordinal_date(2021, 2).with_hms_nano(3, 4, 6, 0).assume_offset(T::UtcOffset::UTC)],
      ["2021W012T030405.1-0100", T::Date.from_iso_week_date(2021, 1, Weekday::Monday.nth_next(1)).with_hms_nano(3, 4, 5, 100000000).assume_offset(offset(-1, 0, 0))],
      ["20210102T03Z", date(2021, 1, 2).with_hms_nano(3, 0, 0, 0).assume_offset(T::UtcOffset::UTC)],
      ["20210102T0304Z", date(2021, 1, 2).with_hms_nano(3, 4, 0, 0).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, expected|
      assert_case expected, T::OffsetDateTime.parse(input, Iso8601::DEFAULT)
    end
  end

  # <tt>parsing.rs:343</tt>, +iso_8601_udt+.
  def test_iso_8601_udt
    [
      ["2021-01-02T03:04:05Z", date(2021, 1, 2).with_hms_nano(3, 4, 5, 0).as_utc],
      ["2021-002T03:04:05Z", T::Date.from_ordinal_date(2021, 2).with_hms_nano(3, 4, 5, 0).as_utc],
      ["2021-W01-2T03:04:05Z", T::Date.from_iso_week_date(2021, 1, Weekday::Monday.nth_next(1)).with_hms_nano(3, 4, 5, 0).as_utc],
      ["-002021-01-02T03:04:05+01:00", date(-2021, 1, 2).with_hms_nano(3, 4, 5, 0).assume_offset(offset(1, 0, 0)).to_utc],
      ["20210102T03.1Z", date(2021, 1, 2).with_hms_nano(3, 6, 0, 0).as_utc],
      ["2021002T0304.1Z", T::Date.from_ordinal_date(2021, 2).with_hms_nano(3, 4, 6, 0).as_utc],
      ["2021W012T030405.1-0100", T::Date.from_iso_week_date(2021, 1, Weekday::Monday.nth_next(1)).with_hms_nano(3, 4, 5, 100000000).assume_offset(offset(-1, 0, 0)).to_utc],
      ["20210102T03Z", date(2021, 1, 2).with_hms_nano(3, 0, 0, 0).as_utc],
      ["20210102T0304Z", date(2021, 1, 2).with_hms_nano(3, 4, 0, 0).as_utc],
    ].each do |input, expected|
      assert_case expected, T::UtcDateTime.parse(input, Iso8601::DEFAULT)
    end
  end

  # <tt>parsing.rs:353</tt>, +iso_8601_offset+.
  def test_iso_8601_offset
    [
      ["+07", offset(7, 0, 0)],
      ["+0304", offset(3, 4, 0)],
    ].each do |input, expected|
      assert_case expected, T::UtcOffset.parse(input, Iso8601::DEFAULT)
    end
  end

  # <tt>parsing.rs:362</tt>, +iso_8601_pdt+.
  def test_iso_8601_pdt
    [
      ["2022-07-22T12:52:50.349409", date(2022, 7, 22).with_hms_nano(12, 52, 50, 349409000)],
    ].each do |input, expected|
      assert_case expected, T::PlainDateTime.parse(input, Iso8601::DEFAULT)
    end
  end

  # <tt>parsing.rs:371</tt>, +iso_8601_time+.
  def test_iso_8601_time
    [
      ["T01:02:03.123456789", clock(1, 2, 3, 123456789)],
    ].each do |input, expected|
      assert_case expected, T::Time.parse(input, Iso8601::DEFAULT)
    end
  end

  # <tt>parsing.rs:386</tt>, +iso_8601_unexpected_trailing_odt+.
  def test_iso_8601_unexpected_trailing_odt
    [
      "20210102T03:04Z",
      "20210102T03.",
      "2021-0102",
      "2021-01-x",
      "2021-Wx",
      "2021-W012",
      "2021-W01-x",
      "2021-01-02T03:x",
      "2021-01-02T03:04x",
      "2021-01-02T03:04:",
    ].each do |input|
      assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) { T::OffsetDateTime.parse(input, Iso8601::DEFAULT) }
    end
  end

  # <tt>parsing.rs:406</tt>, +iso_8601_unexpected_trailing_udt+.
  def test_iso_8601_unexpected_trailing_udt
    [
      "20210102T03:04Z",
      "20210102T03.",
      "2021-0102",
      "2021-01-x",
      "2021-Wx",
      "2021-W012",
      "2021-W01-x",
      "2021-01-02T03:x",
      "2021-01-02T03:04x",
      "2021-01-02T03:04:",
    ].each do |input|
      assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) { T::UtcDateTime.parse(input, Iso8601::DEFAULT) }
    end
  end

  # <tt>parsing.rs:416</tt>, +iso_8601_error_insufficient_type_information+.
  def test_iso_8601_error_insufficient_type_information
    assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) do
      T::UtcDateTime.parse("01:02", Iso8601::DEFAULT)
    end
  end

  # <tt>parsing.rs:435</tt>, +parse_time+.
  def test_parse_time
    [
      [fd("[hour repr:12] [period]"), "01 PM", clock(13, 0, 0, 0)],
      [fd("[hour]"), "12", clock(12, 0, 0, 0)],
      [fd("[hour]:[minute]:[second]"), "13:02:03", clock(13, 2, 3, 0)],
      [fd("[hour repr:12]:[minute] [period]"), "01:02 PM", clock(13, 2, 0, 0)],
      [fd("[hour]:[minute]"), "01:02", clock(1, 2, 0, 0)],
      [fd("[hour repr:12]:[minute] [period]"), "01:02 AM", clock(1, 2, 0, 0)],
      [fd("[hour]:[minute]"), "01:02", clock(1, 2, 0, 0)],
      [fd("[hour repr:12] [period]"), "12 AM", clock(0, 0, 0, 0)],
      [fd("[hour repr:12] [period]"), "12 PM", clock(12, 0, 0, 0)],
    ].each do |description, input, expected|
      assert_case expected, T::Time.parse(input, description)
    end
  end

  # <tt>parsing.rs:467</tt>, +parse_time_insufficient_information+.
  def test_parse_time_insufficient_information
    [
      ["", fd("")],
      ["12:34", fd("[hour]:[second]")],
      ["12:34", fd("[hour]:[subsecond]")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) { T::Time.parse(input, description) }
    end
  end

  # <tt>parsing.rs:478</tt>, +parse_time_unexpected_trailing_characters+.
  def test_parse_time_unexpected_trailing_characters
    [
      [" ", fd("")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) { T::Time.parse(input, description) }
    end
  end

  # <tt>parsing.rs:501</tt>, +parse_time_invalid_component+.
  def test_parse_time_invalid_component
    [
      ["13 PM", fd("[hour repr:12] [period]"), "hour"],
      ["a", fd("[subsecond digits:1]"), "subsecond"],
      ["1a", fd("[subsecond digits:2]"), "subsecond"],
      ["12a", fd("[subsecond digits:3]"), "subsecond"],
      ["123a", fd("[subsecond digits:4]"), "subsecond"],
      ["1234a", fd("[subsecond digits:5]"), "subsecond"],
      ["12345a", fd("[subsecond digits:6]"), "subsecond"],
      ["123456a", fd("[subsecond digits:7]"), "subsecond"],
      ["1234567a", fd("[subsecond digits:8]"), "subsecond"],
      ["12345678a", fd("[subsecond digits:9]"), "subsecond"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::Time.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:572</tt>, +parse_date+.
  def test_parse_date
    [
      [fd("[year]-[month]-[day]"), "2021-01-02", date(2021, 1, 2)],
      [fd("[year]-[ordinal]"), "2021-002", T::Date.from_ordinal_date(2021, 2)],
      [fd("[year base:iso_week]-W[week_number]-[weekday repr:monday]"), "2020-W53-6", date(2021, 1, 2)],
      [fd("[year]-W[week_number repr:monday]-[weekday repr:monday]"), "2021-W00-6", date(2021, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2021-W00-6", date(2021, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2023-W01-1", date(2023, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2022-W00-7", date(2022, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2026-W00-5", date(2026, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2025-W00-4", date(2025, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2019-W00-3", date(2019, 1, 2)],
      [fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "2018-W01-2", date(2018, 1, 2)],
      [fd("[year padding:space]-W[week_number repr:sunday padding:none]-[weekday repr:sunday]"), " 201-W01-2", date(201, 1, 6)],
      # left out: large-dates range modifier
    ].each do |description, input, expected|
      assert_case expected, T::Date.parse(input, description)
    end
  end

  # <tt>parsing.rs:594</tt>, +parse_date_insufficient_information+.
  def test_parse_date_insufficient_information
    [
      ["", fd("")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) { T::Date.parse(input, description) }
    end
  end

  # <tt>parsing.rs:617</tt>, +parse_date_invalid_component+.
  def test_parse_date_invalid_component
    [
      ["a", fd("[year]"), "year"],
      ["0001", fd("[year sign:mandatory]"), "year"],
      ["0a", fd("[year repr:last_two]"), "year"],
      ["2021-12-32", fd("[year]-[month]-[day]"), "day"],
      ["2021-W54-1", fd("[year base:iso_week]-W[week_number]-[weekday repr:monday]"), "week number"],
      ["2021-W54-1", fd("[year]-W[week_number repr:monday]-[weekday repr:monday]"), "week number"],
      ["2021-W54-1", fd("[year]-W[week_number repr:sunday]-[weekday repr:sunday]"), "week number"],
      ["Ja", fd("[month repr:short]"), "month"],
      ["  2a21", fd("[year padding:space]"), "year"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::Date.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:636</tt>, +parse_date_component_range+.
  def test_parse_date_component_range
    [
      ["2021-366", fd("[year]-[ordinal]"), "ordinal"],
      ["2021-02-30", fd("[year]-[month]-[day]"), "day"],
      ["2019-W53-1", fd("[year base:iso_week]-W[week_number]-[weekday repr:monday]"), "week"],
      ["2019-W53-1", fd("[year]-W[week_number repr:sunday]-[weekday repr:monday]"), "ordinal"],
      ["2019-W53-1", fd("[year]-W[week_number repr:monday]-[weekday repr:monday]"), "ordinal"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::TryFromParsed::ComponentRange) { T::Date.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:656</tt>, +parse_offset+.
  def test_parse_offset
    [
      ["-00:01", fd("[offset_hour sign:mandatory]:[offset_minute]"), offset(0, -1, 0)],
      ["-00:00:01", fd("[offset_hour sign:mandatory]:[offset_minute]:[offset_second]"), offset(0, 0, -1)],
    ].each do |input, description, expected|
      assert_case expected, T::UtcOffset.parse(input, description)
    end
  end

  # <tt>parsing.rs:684</tt>, +parse_offset_invalid_component+.
  def test_parse_offset_invalid_component
    [
      ["01", fd("[offset_hour sign:mandatory]"), "offset hour"],
      ["26", fd("[offset_hour]"), "offset hour"],
      ["00:60", fd("[offset_hour]:[offset_minute]"), "offset minute"],
      ["00:00:60", fd("[offset_hour]:[offset_minute]:[offset_second]"), "offset second"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::UtcOffset.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:699</tt>, +parse_plain_date_time+.
  def test_parse_plain_date_time
    [
      ["2023-07-27 23", fd("[year]-[month]-[day] [hour]"), date(2023, 7, 27).with_hms_nano(23, 0, 0, 0)],
    ].each do |input, description, expected|
      assert_case expected, T::PlainDateTime.parse(input, description)
    end
  end

  # <tt>parsing.rs:724</tt>, +parse_plain_date_time_invalid_component+.
  def test_parse_plain_date_time_invalid_component
    [
      ["2021-001 13 PM", fd("[year]-[ordinal] [hour repr:12] [period]"), "hour"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::PlainDateTime.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:739</tt>, +parse_plain_date_time_unexpected_trailing_characters+.
  def test_parse_plain_date_time_unexpected_trailing_characters
    [
      ["2023-07-27 23:30", fd("[year]-[month]-[day] [hour]")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) { T::PlainDateTime.parse(input, description) }
    end
  end

  # <tt>parsing.rs:761</tt>, +parse_offset_date_time_insufficient_information+.
  def test_parse_offset_date_time_insufficient_information
    [
      ["", fd("")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) { T::OffsetDateTime.parse(input, description) }
    end
  end

  # <tt>parsing.rs:780</tt>, +parse_offset_date_time_invalid_component+.
  def test_parse_offset_date_time_invalid_component
    [
      ["x", fd("[year]"), "year"],
      ["2021-001 12 PM +26", fd("[year]-[ordinal] [hour repr:12] [period] [offset_hour sign:mandatory]"), "offset hour"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::OffsetDateTime.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:795</tt>, +parse_utc_date_time+.
  def test_parse_utc_date_time
    [
      ["2023-07-27 23", fd("[year]-[month]-[day] [hour]"), date(2023, 7, 27).with_hms_nano(23, 0, 0, 0).as_utc],
    ].each do |input, description, expected|
      assert_case expected, T::UtcDateTime.parse(input, description)
    end
  end

  # <tt>parsing.rs:820</tt>, +parse_utc_date_time_insufficient_information+.
  def test_parse_utc_date_time_insufficient_information
    [
      ["", fd("")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) { T::UtcDateTime.parse(input, description) }
    end
  end

  # <tt>parsing.rs:840</tt>, +parse_utc_date_time_invalid_component+.
  def test_parse_utc_date_time_invalid_component
    [
      ["2021 001 13 PM", fd("[year] [ordinal] [hour repr:12] [period]"), "hour"],
      ["x", fd("[year]"), "year"],
      ["2021-001 12 PM +26", fd("[year]-[ordinal] [hour repr:12] [period] [offset_hour sign:mandatory]"), "offset hour"],
    ].each do |input, description, name|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::UtcDateTime.parse(input, description) }
      assert_equal name, error.name
    end
  end

  # <tt>parsing.rs:854</tt>,
  # +parse_utc_date_time_unexpected_trailing_characters+.
  def test_parse_utc_date_time_unexpected_trailing_characters
    assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) do
      T::UtcDateTime.parse("2023-07-27 23:30", fd("[year]-[month]-[day] [hour]"))
    end
  end

  # <tt>parsing.rs:1235</tt>, +parse_ignore_component_v3_not_utf8_boundary+.
  def test_parse_ignore_component_v3_not_utf8_boundary
    [
      ["£", fd("[ignore count:1]")],
      ["€", fd("[ignore count:1]")],
      ["€", fd("[ignore count:2]")],
      ["🦀", fd("[ignore count:1]")],
      ["🦀", fd("[ignore count:2]")],
      ["🦀", fd("[ignore count:3]")],
    ].each do |input, description|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::Date.parse(input, description) }
      assert_equal "ignore", error.name
    end
  end

  # <tt>parsing.rs:1265</tt>, +year_default_modifier_by_version_runtime+:
  # its version 3 half; version 2 is deferred (plan 007, decision 1).
  def test_year_default_modifier_by_version_runtime
    input = "+10000-01-01"
    fd_v3 = T::FormatDescription.parse_borrowed(3, "[year]-[month]-[day]")
    assert_raises(T::Error::Parse::ParseFromDescription::InvalidLiteral) { T::Date.parse(input, fd_v3) }
  end

  # <tt>parsing.rs:1407</tt>, +parse_unix_timestamp+.
  def test_parse_unix_timestamp
    [
      ["1234567890", fd("[unix_timestamp]"), date(2009, 2, 13).with_hms_nano(23, 31, 30, 0).assume_offset(T::UtcOffset::UTC)],
      ["1234567890123", fd("[unix_timestamp precision:millisecond]"), date(2009, 2, 13).with_hms_nano(23, 31, 30, 123000000).assume_offset(T::UtcOffset::UTC)],
      ["1234567890123456", fd("[unix_timestamp precision:microsecond]"), date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456000).assume_offset(T::UtcOffset::UTC)],
      ["1234567890123456789", fd("[unix_timestamp precision:nanosecond]"), date(2009, 2, 13).with_hms_nano(23, 31, 30, 123456789).assume_offset(T::UtcOffset::UTC)],
    ].each do |input, description, expected|
      assert_case expected, T::OffsetDateTime.parse(input, description)
    end
  end

  # <tt>parsing.rs:1428</tt>, +parse_unix_timestamp_err+.
  def test_parse_unix_timestamp_err
    [
      ["1234567890", fd("[unix_timestamp sign:mandatory]")],
      ["a", fd("[unix_timestamp precision:second]")],
      ["a", fd("[unix_timestamp precision:millisecond]")],
      ["a", fd("[unix_timestamp precision:microsecond]")],
      ["a", fd("[unix_timestamp precision:nanosecond]")],
    ].each do |input, description|
      error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::OffsetDateTime.parse(input, description) }
      assert_equal "unix_timestamp", error.name
    end
  end

  # <tt>parsing.rs:1441</tt>, +issue_601+: time's version 1 description,
  # which version 3 reads the same way.
  def test_issue_601
    date = T::OffsetDateTime.parse("1234567890.123", fd("[unix_timestamp].[subsecond digits:3]"))
    assert_equal odt(2009, 2, 13, 23, 31, 30, 123_000_000, T::UtcOffset::UTC), date
  end

  # <tt>parsing.rs:1455</tt>, +end+.
  def test_end
    [
      ["00:00", fd("[hour]:[minute][end]"), clock(0, 0, 0, 0)],
      ["00:00abcdef", fd("[hour]:[minute][end trailing_input:discard]"), clock(0, 0, 0, 0)],
      # left out: untranslated fd!(version = 2, "[hour]:[minute][optional [[end]]]:[second]"), a version 2 description
    ].each do |input, description, expected|
      assert_case expected, T::Time.parse(input, description)
    end
  end

  # <tt>parsing.rs:1469</tt>, +end_err_unexpected_trailing+.
  def test_end_err_unexpected_trailing
    [
      ["00:00:00", fd("[hour]:[minute][end]:[second]")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters) { T::Time.parse(input, description) }
    end
  end

  # <tt>parsing.rs:1483</tt>, +end_err_invalid_literal+.
  def test_end_err_invalid_literal
    [
      ["00:00:00", fd("[hour]:[minute][end trailing_input:discard]:[second]")],
    ].each do |input, description|
      assert_raises(T::Error::Parse::ParseFromDescription::InvalidLiteral) { T::Time.parse(input, description) }
    end
  end
end

#--
# SPDX-SnippetEnd
#++
