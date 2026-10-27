# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Every value the gem makes holds a value time made, is frozen, and
# compares, orders, and hashes as time's traits say (plan 007,
# decisions 3 to 6).
class TestValues < Minitest::Test
  include TimeSuite

  private def samples
    plain = datetime(2019, 1, 1, 12, 30, 45, 123_456_789)
    {
      T::Date => plain.date,
      T::Time => plain.time,
      T::PlainDateTime => plain,
      T::UtcDateTime => plain.as_utc,
      T::OffsetDateTime => plain.assume_offset(offset(-5)),
      T::UtcOffset => offset(-5),
      T::SignedDuration => Duration.seconds(5),
      T::FormatDescription::FormatDescriptionV3 => fd("[year]"),
    }
  end

  def test_every_value_is_frozen_and_held_by_its_class
    samples.each do |klass, value|
      assert_instance_of klass, value
      assert_predicate value, :frozen?, klass.name
    end
  end

  def test_ruby_cannot_allocate_one
    samples.each_key do |klass|
      assert_raises(TypeError, klass.name) { klass.allocate }
    end
    assert_raises(TypeError) { T::Date.new }
  end

  def test_copies_are_the_value_itself
    samples.each do |klass, value|
      assert_same value, value.dup, klass.name
      assert_same value, value.clone, klass.name
      error = assert_raises(ArgumentError, klass.name) { value.clone(freeze: false) }
      assert_equal "can't unfreeze #{klass.name}", error.message
    end
  end

  def test_the_aliases_are_the_same_classes
    assert_same T::PlainDateTime, T::PrimitiveDateTime
    assert_same T::SignedDuration, T::Duration
    assert_equal "Ferro::Time::PlainDateTime", T::PrimitiveDateTime.name
  end

  def test_equal_values_are_equal_eql_and_hash_alike
    samples.except(T::FormatDescription::FormatDescriptionV3).each do |klass, value|
      twin = rebuild(value)
      refute_same value, twin, klass.name
      assert_equal value, twin, klass.name
      assert value.eql?(twin), klass.name
      assert_equal value.hash, twin.hash, klass.name
      assert_equal 1, { value => 1, twin => 1 }.size, klass.name
    end
  end

  # A second value equal to +value+, built anew.
  private def rebuild(value)
    case value
    when T::Date then T::Date.from_julian_day(value.to_julian_day)
    when T::Time then T::Time.from_hms_nano(*value.as_hms_nano)
    when T::PlainDateTime then T::PlainDateTime.new(rebuild(value.date), rebuild(value.time))
    when T::UtcDateTime then T::UtcDateTime.from_unix_timestamp_nanos(value.unix_timestamp_nanos)
    when T::OffsetDateTime then T::OffsetDateTime.new_in_offset(value.date, value.time, rebuild(value.offset))
    when T::UtcOffset then T::UtcOffset.from_whole_seconds(value.whole_seconds)
    when T::SignedDuration then Duration.nanoseconds_i128(value.whole_nanoseconds)
    end
  end

  def test_values_order_by_time_s_ord
    assert_operator date(2019, 1, 1), :<, date(2019, 1, 2)
    assert_operator clock(23, 59), :>, clock(0, 0)
    assert_operator Duration.seconds(-1), :<, Duration::ZERO
    assert_operator offset(-5), :<, offset(5)
    assert_nil date(2019, 1, 1) <=> 1
    assert_raises(ArgumentError) { date(2019, 1, 1) < 1 }
    assert_equal [Month::January, Month::March], [Month::March, Month::January].sort
  end

  # OffsetDateTime compares and hashes by instant (src/offset_date_time.rs:43-82).
  def test_an_offset_date_time_compares_by_instant
    noon_utc = datetime(2019, 1, 1, 12).assume_utc
    one_pm_east = datetime(2019, 1, 1, 13).assume_offset(offset(1))
    assert_equal noon_utc, one_pm_east
    assert noon_utc.eql?(one_pm_east)
    assert_equal noon_utc.hash, one_pm_east.hash
    refute_equal noon_utc.offset, one_pm_east.offset
    assert_equal noon_utc, noon_utc.to_utc
    assert_equal 0, noon_utc.to_utc <=> one_pm_east
    refute noon_utc.eql?(noon_utc.to_utc)
  end

  def test_month_and_weekday_are_frozen_constants
    assert_predicate Month::May, :frozen?
    assert_same Month::May, Month.try_from(5)
    assert_same Weekday::Friday, Weekday.from_str("Friday")
    assert_raises(NoMethodError) { Month.new(1, :January) }
    assert_raises(NoMethodError) { Weekday.new(0, :Monday) }
    refute_respond_to Weekday::Monday, :<
    assert_equal "Ferro::Time::Month::May", Month::May.inspect
  end

  def test_inspect_is_time_s_debug_and_to_s_its_display
    assert_equal "2019-01-01", date(2019, 1, 1).inspect
    assert_equal "0:00:00.0", T::Time::MIDNIGHT.to_s
    assert_equal "+00:00:00", T::UtcOffset::UTC.to_s
    assert_equal "SignedDuration { seconds: 93784, nanoseconds: 5 }", Duration.new(93_784, 5).inspect
    assert_equal "1d2h3m4s5ns", Duration.new(93_784, 5).to_s
    assert_equal "0s", Duration::ZERO.to_s
  end

  def test_constants_are_time_s
    assert_equal [-9999, 1], T::Date::MIN.to_ordinal_date
    assert_equal [9999, 365], T::Date::MAX.to_ordinal_date
    assert_equal [23, 59, 59, 999_999_999], T::Time::MAX.as_hms_nano
    assert_equal 0, T::UtcDateTime::UNIX_EPOCH.unix_timestamp
    assert_equal 0, T::OffsetDateTime::UNIX_EPOCH.unix_timestamp
    assert_equal T::Date::MIN.midnight, T::PlainDateTime::MIN
    assert_equal Duration.weeks(1), Duration::WEEK
    assert_equal Duration::ZERO, Duration.default
    assert_equal [(2 ** 63) - 1, 999_999_999], [Duration::MAX.whole_seconds, Duration::MAX.subsec_nanoseconds]
  end

  def test_a_wrong_argument_type_raises_type_error
    assert_raises(TypeError) { T::Date.from_calendar_date(2019, 1, 1) }
    assert_raises(TypeError) { date(2019, 1, 1) + 1 }
    assert_raises(TypeError) { date(2019, 1, 1) - "x" }
    assert_raises(TypeError) { date(2019, 1, 1).with_time(1) }
    assert_raises(TypeError) { date(2019, 1, 1).format("[year]") }
    assert_raises(TypeError) { T::Date.from_iso_week_date(2019, 1, :monday) }
    assert_raises(TypeError) { T::OffsetDateTime.from(1) }
    assert_raises(RangeError) { T::Date.from_calendar_date(2 ** 40, Month::January, 1) }
    assert_raises(RangeError) { clock(256, 0) }
  end

  # A number on the left reaches time's reflexive Mul<SignedDuration> for
  # i32 and f64 through coerce, and only that: Rust has no other operator
  # with a number on the left, and Ruby's words for that stay as they were.
  def test_a_number_on_the_left_only_multiplies
    second = Duration::SECOND
    assert_equal Duration.seconds(3), 3 * second
    assert_equal Duration.milliseconds(1_500), 1.5 * second
    assert_raises(RangeError) { (2 ** 40) * second }
    assert_raises(RangeError) { 2 * Duration::MAX }
    %i[+ - / % ** div divmod fdiv modulo remainder pow].each do |operator|
      error = assert_raises(TypeError, operator.to_s) { 2.public_send(operator, second) }
      assert_equal "Ferro::Time::SignedDuration can't be coerced into Integer", error.message
    end
    error = assert_raises(TypeError) { 2.5 + second }
    assert_equal "Ferro::Time::SignedDuration can't be coerced into Float", error.message
    error = assert_raises(ArgumentError) { 2 < second }
    assert_equal "comparison of Integer with Ferro::Time::SignedDuration failed", error.message
    assert_nil 2 <=> second
    refute_equal 2, second
    assert_raises(TypeError) { Rational(1, 2) * second }
  end

  def test_month_and_weekday_numbers
    assert_equal (1..12).to_a, (1..12).map { |n| Month.try_from(n).to_i }
    assert_equal [1, 2, 0, 1], [
      Weekday::Monday.number_from_monday,
      Weekday::Monday.number_from_sunday,
      Weekday::Monday.number_days_from_monday,
      Weekday::Monday.number_days_from_sunday,
]
    assert_equal 29, Month::February.length(2024)
  end

  # time deprecates util::days_in_year_month since 0.3.37; Ruby warns in
  # the :deprecated category (plan 007, row 70).
  def test_the_deprecated_util_function_warns
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    assert_output(nil, /days_in_year_month is deprecated since time 0\.3\.37; use days_in_month/) do
      assert_equal 29, T::Util.days_in_year_month(2020, Month::February)
    end
  ensure
    Warning[:deprecated] = deprecated
  end
end
