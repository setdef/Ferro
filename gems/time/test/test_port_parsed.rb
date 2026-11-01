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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/parsed.rs
#++

# time's own tests in <tt>tests/integration/parsed.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. The cases of
# the hidden, deprecated +offset_minute+ and +offset_second+ accessors,
# all of +getters_setters_fail+ and +builder_methods_fail+ among them, are
# left out: the gem does not bind those accessors (plan 009).
class TestPortParsed < Minitest::Test
  include TimeSuite

  Parsed = T::Parsing::Parsed
  FD = T::FormatDescription
  C = FD::Component
  M = FD::Modifier

  CASES = [
    [:year, 5],
    [:year_last_two, 5],
    [:iso_year, 5],
    [:iso_year_last_two, 5],
    [:month, Month::May],
    [:sunday_week_number, 5],
    [:monday_week_number, 5],
    [:iso_week_number, 5],
    [:weekday, Weekday::Monday],
    [:ordinal, 5],
    [:day, 5],
    [:hour_24, 5],
    [:hour_12, 5],
    [:hour_12_is_pm, true],
    [:minute, 5],
    [:second, 5],
    [:subsecond, 5],
    [:offset_hour, 5],
    [:offset_minute_signed, -5],
    [:offset_second_signed, -5],
  ].freeze

  # <tt>parsed.rs:9</tt>, +getters_setters+.
  def test_getters_setters
    CASES.each do |name, value|
      parsed = Parsed.new
      assert parsed.public_send(:"set_#{name}", value), name
      assert_equal value, parsed.public_send(name), name
    end
  end

  # <tt>parsed.rs:62</tt>, +builder_methods+.
  def test_builder_methods
    CASES.each do |name, value|
      parsed = Parsed.new.public_send(:"with_#{name}", value)
      refute_nil parsed, name
      assert_equal value, parsed.public_send(name), name
    end
  end

  # <tt>parsed.rs:111</tt>, +single_item_parse+.
  def test_single_item_parse
    %w[a b].each do |input|
      assert_raises(T::Error::Parse) { T::Time.parse(input, FD::BorrowedFormatItem::StringLiteral.new("a")) }
    end
  end

  # <tt>parsed.rs:118</tt>, +component_err+, with the year as time's
  # parser builds it without +large-dates+, which this test does not
  # depend on.
  def test_component_err
    [
      ["day", C::Day.new(M::Day.default), ""],
      ["month", C::MonthNumerical.new(M::MonthNumerical.default), ""],
      ["ordinal", C::Ordinal.new(M::Ordinal.default), ""],
      ["weekday", C::WeekdayLong.new(M::WeekdayLong.default), ""],
      ["week number", C::WeekNumberIso.new(M::WeekNumberIso.default), ""],
      ["year", C::CalendarYearFullExtendedRange.new(M::CalendarYearFullExtendedRange.default), ""],
      ["minute", C::Minute.new(M::Minute.default), ""],
      ["period", C::Period.new(M::Period.default), ""],
      ["second", C::Second.new(M::Second.default), ""],
      ["subsecond", C::Subsecond.new(M::Subsecond.default), ""],
      ["offset hour", C::OffsetHour.new(M::OffsetHour.default), ""],
      ["offset minute", C::OffsetMinute.new(M::OffsetMinute.default), ""],
      ["offset second", C::OffsetSecond.new(M::OffsetSecond.default), ""],
      ["unix_timestamp", C::UnixTimestampSecond.new(M::UnixTimestampSecond.default), ""],
      ["week number", C::WeekNumberIso.new(M::WeekNumberIso.default), "00"],
      ["hour", C::Hour12.new(M::Hour12.default), "00"],
    ].each do |name, component, input|
      error = assert_raises(T::Error::ParseFromDescription::InvalidComponent) { Parsed.new.parse_component(input, component) }
      assert_equal name, error.name
    end
  end
end

#--
# SPDX-SnippetEnd
#++
