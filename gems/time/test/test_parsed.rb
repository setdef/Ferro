# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Ruby side of Parsing::Parsed and parse_with_defaults (plan 009):
# mutation and copies, refusals, and what Rust's types give a Rust caller.
class TestParsed < Minitest::Test
  include TimeSuite

  Parsed = T::Parsing::Parsed
  FD = T::FormatDescription

  def test_a_setter_answers_true_or_nil
    parsed = Parsed.new
    assert_equal true, parsed.set_year(9999)
    assert_nil parsed.set_year(10_000), "past the year range time builds without large-dates"
    assert_equal 9999, parsed.year
    assert_nil parsed.set_minute(60)
    assert_nil parsed.minute
  end

  def test_a_builder_copies_and_leaves_the_original
    parsed = Parsed.new
    built = parsed.with_year(2020)
    assert_instance_of Parsed, built
    assert_nil parsed.year
    assert_equal 2020, built.year
    assert_nil parsed.with_hour_24(24)
  end

  def test_dup_copies_the_value
    parsed = Parsed.new
    parsed.set_day(3)
    copy = parsed.dup
    copy.set_day(4)
    assert_equal 3, parsed.day
    assert_equal 4, copy.day
    refute_equal parsed, copy, "time derives no equality for Parsed"
    assert_equal 3, parsed.clone.day
  end

  def test_a_frozen_parsed_refuses_change
    parsed = Parsed.new.freeze
    error = assert_raises(FrozenError) { parsed.set_year(2020) }
    assert_same parsed, error.receiver
    assert_raises(FrozenError) { parsed.parse_items("2020", FD.parse_borrowed(2, "[year]")) }
    assert_raises(FrozenError) { parsed.parse_item("2020", FD.parse_owned(2, "[year]")) }
    assert_equal 2020, parsed.with_year(2020).year
    assert_raises(Ractor::Error) { Ractor.make_shareable(Parsed.new) }
  end

  # The native layer refuses a frozen Parsed too, as the iterators' does,
  # so no path past the Ruby guard can change one (plan 009, decision 12).
  def test_the_native_layer_refuses_a_frozen_parsed
    native = T.const_get(:Native)
    arguments = T.const_get(:Arguments)
    parsed = Parsed.new.freeze
    year = [:item, arguments.encode_item(arguments.any_item(FD.parse_owned(2, "[year]")))]
    day = [:item, [2, FD::Component::Day.new(FD::Modifier::Day.default).__send__(:encode)]]
    [
      -> { native.parsed_set_year(parsed, 2020) },
      -> { native.parsed_set_day(parsed, 3) },
      -> { native.parsed_set_year_century(parsed, 20, false) },
      -> { native.parsed_parse_items(parsed, "2020", year) },
      -> { native.parsed_parse_component(parsed, "07", day) },
    ].each { |change| assert_raises(FrozenError, &change) }
    assert_nil parsed.year
    assert_nil parsed.day
    assert_nil parsed.year_century
  end

  def test_arguments_are_checked_as_rust_types_them
    parsed = Parsed.new
    error = assert_raises(RangeError) { parsed.set_day(0) }
    assert_equal "integer 0 too small to convert into `NonZero<u8>`", error.message
    assert_raises(RangeError) { parsed.with_ordinal(0) }
    assert_raises(RangeError) { parsed.set_minute(256) }
    assert_raises(TypeError) { parsed.set_month(1) }
    assert_raises(TypeError) { parsed.set_weekday(:monday) }
    assert_raises(TypeError) { parsed.set_hour_12_is_pm(1) }
    assert_raises(TypeError) { parsed.parse_item("x", "x") }
    assert_raises(TypeError) { parsed.parse_items("x", FD.parse_owned(2, "[year]")) }
    assert_raises(TypeError) { T::Date.try_from(nil) }
    assert_raises(TypeError) { T::Date.parse_with_defaults("2020", FD.parse_borrowed(2, "[year]"), {}) }
  end

  def test_month_and_weekday_cross_as_their_constants
    parsed = Parsed.new
    parsed.set_month(Month::December)
    parsed.set_weekday(Weekday::Sunday)
    assert_same Month::December, parsed.month
    assert_same Weekday::Sunday, parsed.weekday
  end

  def test_a_century_takes_its_sign_from_the_value_unless_zero
    parsed = Parsed.new
    assert parsed.set_year_century(-20, false)
    assert_equal true, parsed.year_century_is_negative
    assert parsed.set_iso_year_century(0, true)
    assert_equal true, parsed.iso_year_century_is_negative
    built = Parsed.new.with_year_century(0, true)
    assert_equal 0, built.year_century
    assert_equal true, built.year_century_is_negative
  end

  def test_a_failed_parse_items_leaves_the_parsed_unchanged
    parsed = Parsed.new
    assert_raises(T::Error::ParseFromDescription::InvalidLiteral) { parsed.parse_items("2020/", FD.parse_borrowed(2, "[year]-")) }
    assert_nil parsed.year
    assert_equal "/".b, parsed.parse_items("2020/", FD.parse_borrowed(2, "[year]"))
    assert_equal 2020, parsed.year
  end

  def test_parse_with_defaults_leaves_its_defaults_unchanged
    defaults = Parsed.new.with_year(2020)
    date = T::Date.parse_with_defaults("01-15".b, FD.parse_borrowed(2, "[month]-[day]"), defaults)
    assert_equal T::Date.from_calendar_date(2020, Month::January, 15), date
    assert_nil defaults.month
    assert_predicate date, :frozen?
  end

  def test_parse_with_defaults_takes_every_kind_of_description
    defaults = Parsed.new.with_offset_hour(0).with_offset_minute_signed(0)
    expected = T::OffsetDateTime::UNIX_EPOCH
    assert_equal expected, T::OffsetDateTime.parse_with_defaults("1970-01-01T00:00:00Z", FD::WellKnown::Rfc3339, defaults)
    assert_equal expected, T::OffsetDateTime.parse_with_defaults("1970-01-01T00:00:00Z", FD::WellKnown::Iso8601, defaults)
    assert_equal expected,
      T::OffsetDateTime.parse_with_defaults("Thu, 01 Jan 1970 00:00:00 +0000", FD::WellKnown::Rfc2822, defaults)
    v3 = FD.parse_owned(3, "[year]-[month]-[day] [hour]:[minute]:[second]")
    assert_equal expected, T::OffsetDateTime.parse_with_defaults("1970-01-01 00:00:00", v3, defaults)
  end

  def test_a_frozen_parsed_cannot_be_overwritten_by_initialize_copy
    frozen = Parsed.new.with_year(2020).freeze
    other = Parsed.new.with_year(1999)
    assert_raises(FrozenError) { frozen.__send__(:initialize_copy, other) }
    assert_equal 2020, frozen.year
    assert_equal 2020, frozen.clone.year
    assert_predicate frozen.clone, :frozen?
    assert_raises(TypeError) { Parsed.new.__send__(:initialize_copy, T::Date::MIN) }
  end

  def test_parse_literal_returns_the_rest_or_refuses
    rest = Parsed.parse_literal("T09:00", "T")
    assert_equal "09:00".b, rest
    assert_equal Encoding::BINARY, rest.encoding
    assert_equal "".b, Parsed.parse_literal("abc", "abc")
    assert_raises(T::Error::ParseFromDescription::InvalidLiteral) { Parsed.parse_literal("09:00", "T") }
  end

  # time's TryFrom<Parsed> for UtcDateTime calls the panicking to_utc
  # (src/parsing/parsed.rs:1336-1341); the gem refuses first, with
  # to_utc's message, at both ends of the range (plan 009, decision 19).
  def test_a_utc_date_time_past_the_range_is_refused_with_times_message
    fd = FD.parse_owned(3, "[year]-[month]-[day] [hour]:[minute] [offset_hour sign:mandatory]")
    [["9999-12-31 23:00 -05", 9999, 12, 31, 23, -5], ["-9999-01-01 00:00 +05", -9999, 1, 1, 0, 5]].each do |input, year, month, day, hour, offset|
      parsed = Parsed.new.with_year(year).with_month(Month.try_from(month)).with_day(day).with_hour_24(hour).with_minute(0).with_offset_hour(offset)
      [
        -> { T::UtcDateTime.try_from(parsed) },
        -> { T::UtcDateTime.parse(input, fd) },
        -> { T::UtcDateTime.parse_with_defaults(input, fd, Parsed.new) },
        -> { T::UtcDateTime.parse_with_defaults(input[0..-5], FD.parse_owned(3, "[year]-[month]-[day] [hour]:[minute]"), Parsed.new.with_offset_hour(offset)) },
      ].each do |call|
        error = assert_raises(RangeError, input) { call.call }
        assert_equal "local datetime out of valid range", error.message
      end
      assert_equal T::OffsetDateTime.try_from(parsed), T::OffsetDateTime.parse(input, fd)
    end
    rfc = FD::WellKnown::Rfc3339
    ["9999-12-31T23:00:00-05:00", "9999-12-31T23:59:60-05:00"].each do |input|
      error = assert_raises(RangeError, input) { T::UtcDateTime.parse(input, rfc) }
      assert_equal "local datetime out of valid range", error.message
    end
    assert_equal T::UtcDateTime.new(T::Date.from_calendar_date(9999, Month::December, 31), T::Time.from_hms(23, 0, 0)),
      T::UtcDateTime.parse("9999-12-31T18:00:00-05:00", rfc)
    assert_raises(T::Error::Parse::TryFromParsed::ComponentRange) { T::UtcDateTime.parse("2016-12-30T23:59:60Z", rfc) }
    assert_equal T::UtcDateTime.parse("2016-12-31T23:59:59.999999999Z", rfc), T::UtcDateTime.parse("2016-12-31T23:59:60Z", rfc)
  end

  def test_a_refused_leap_second_prints_no_panic
    _, err = capture_subprocess_io do
      assert_raises(RangeError) { T::UtcDateTime.parse("9999-12-31T23:59:60-05:00", FD::WellKnown::Rfc3339) }
    end
    assert_empty err
  end

  def test_inspect_is_times_debug
    assert_match(/\AParsed \{ year: /, Parsed.new.inspect)
  end
end
