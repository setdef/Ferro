# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "date"

# Ruby's ::Time stands for Rust's SystemTime, and OffsetDateTime and
# UtcDateTime convert to and from it and compare with it through time's
# own impls (plan 007, decision 10). Ferro::Time is not ::Time, and code
# in the Ferro namespace names Ruby's with ::Time.
class TestSystemTime < Minitest::Test
  include TimeSuite

  # What a SystemTime keeps of +nanoseconds+: all of them on Unix, and
  # whole 100 ns intervals on Windows, which counts in them from 1601
  # (std's sys/pal/windows/time.rs).
  private def kept(nanoseconds)
    Gem.win_platform? ? nanoseconds - (nanoseconds % 100) : nanoseconds
  end

  def test_from_reads_the_instant_in_utc
    ruby = ::Time.at(1_546_345_845, 123_456_789, :nsec, in: "-05:00")
    [T::OffsetDateTime, T::UtcDateTime].each do |klass|
      value = klass.from(ruby)
      assert_equal 1_546_345_845_000_000_000 + kept(123_456_789), value.unix_timestamp_nanos, klass.name
      assert_equal 12, value.hour, klass.name
    end
    assert_predicate T::OffsetDateTime.from(ruby).offset, :is_utc
  end

  def test_to_time_is_a_utc_ruby_time_at_the_same_instant
    value = datetime(2019, 1, 1, 12, 30, 45, 123_456_700).assume_offset(offset(-5))
    ruby = value.to_time
    assert_instance_of ::Time, ruby
    assert_predicate ruby, :utc?
    assert_equal [1_546_363_845, 123_456_700], [ruby.to_i, ruby.nsec]
    assert_equal value, T::OffsetDateTime.from(ruby)
    assert_equal value.to_utc, T::UtcDateTime.from(value.to_utc.to_time)
  end

  # A SystemTime keeps a nanosecond on Unix and 100 ns on Windows; the
  # instant written back is what it kept.
  def test_a_system_time_keeps_its_platform_s_precision
    value = datetime(2019, 1, 1, 12, 30, 45, 123_456_789).as_utc
    assert_equal kept(123_456_789), value.to_time.nsec
    assert_equal kept(123_456_789), T::UtcDateTime.from(::Time.at(0, 123_456_789, :nsec)).nanosecond
  end

  def test_instants_before_the_epoch_round_trip
    # 1601-01-01, the earliest a Windows SystemTime holds, and later.
    [-1, -86_401, -11_644_473_600].each do |seconds|
      [0, 100, 999_999_900].each do |nanoseconds|
        ruby = ::Time.at(seconds, nanoseconds, :nsec, in: "UTC")
        value = T::OffsetDateTime.from(ruby)
        assert_equal (seconds * 1_000_000_000) + nanoseconds, value.unix_timestamp_nanos
        assert_equal ruby, value.to_time
      end
    end
  end

  # A Ruby Time can hold a finer fraction than a SystemTime; it is dropped,
  # as a SystemTime cannot hold it.
  def test_a_fraction_finer_than_a_nanosecond_is_dropped
    ruby = ::Time.at(Rational(1, 3))
    assert_equal kept(333_333_333), T::OffsetDateTime.from(ruby).nanosecond
  end

  # Year 1 is a SystemTime on Unix and not on Windows, where std refuses to
  # build one before 1601, with its own panic message.
  def test_an_instant_before_1601_is_a_system_time_only_on_unix
    year_one = T::OffsetDateTime.from_unix_timestamp(-62_135_596_800)
    if Gem.win_platform?
      error = assert_raises(RangeError) { T::OffsetDateTime.from(::Time.at(-62_135_596_800)) }
      assert_equal "overflow when subtracting duration from `SystemTime`", error.message
      error = assert_raises(RangeError) { year_one.to_time }
      assert_equal "overflow when subtracting duration from `SystemTime`", error.message
    else
      assert_equal year_one, T::OffsetDateTime.from(::Time.at(-62_135_596_800))
      assert_equal(-62_135_596_800, year_one.to_time.to_i)
    end
  end

  def test_the_comparisons_take_a_ruby_time_on_the_right
    value = T::OffsetDateTime.from_unix_timestamp(100)
    assert_equal value, ::Time.at(100)
    refute_equal value, ::Time.at(101)
    assert_equal(-1, value <=> ::Time.at(101))
    assert_operator value, :<, ::Time.at(101)
    assert_equal Duration.seconds(-1), value - ::Time.at(101)
    utc = T::UtcDateTime.from_unix_timestamp(100)
    assert_equal utc, ::Time.at(100)
    assert_equal Duration::SECOND, utc - ::Time.at(99)
    # Ruby's own ::Time#<=> asks the other value when it is not a Time
    # (time.c:3987 at v4.0.9), so the comparisons work from Ruby's side too,
    # as time's impls with SystemTime on the left do; Time#- does not.
    assert_equal ::Time.at(100), value
    assert_operator ::Time.at(99), :<, value
    assert_raises(TypeError) { ::Time.at(100) - value }
  end

  def test_offset_and_utc_date_times_convert_and_compare_with_each_other
    odt = datetime(2019, 1, 1, 13).assume_offset(offset(1))
    utc = datetime(2019, 1, 1, 12).as_utc
    assert_equal utc, odt
    assert_equal odt, utc
    assert_equal utc, T::UtcDateTime.from(odt)
    assert_equal odt, T::OffsetDateTime.from(utc)
    assert_equal Duration.hours(1), (odt + Duration.hours(1)) - utc
    assert_equal Duration.hours(-1), utc - (odt + Duration.hours(1))
    assert_equal 0, utc <=> odt
  end

  # time's From<SystemTime> panics past its range; the gem refuses first
  # with time's message.
  def test_a_ruby_time_past_time_s_years_raises_range_error
    error = assert_raises(RangeError) { T::OffsetDateTime.from(::Time.at(400_000_000_000)) }
    assert_equal "overflow adding duration to date", error.message
    error = assert_raises(RangeError) { T::UtcDateTime.from(::Time.at(-400_000_000_000)) }
    # Before 1601 std refuses first on Windows (see above).
    expected = Gem.win_platform? ? "overflow when subtracting duration from `SystemTime`" : "overflow subtracting duration from date"
    assert_equal expected, error.message
    assert_raises(RangeError) { T::OffsetDateTime::UNIX_EPOCH == ::Time.at(400_000_000_000) }
    assert_raises(TypeError) { T::OffsetDateTime.from(1_546_345_845) }
  end

  # Inside module Ferro a bare Time names Ferro::Time once ferro-time is
  # loaded (see the README), so the gems write ::Time for Ruby's.
  def test_a_bare_time_inside_ferro_names_this_module
    assert_same Ferro::Time, Ferro.module_eval("Time")
    assert_same ::Time, Ferro.module_eval("::Time")
    refute_same ::Time, Ferro::Time::Time
    refute_same ::Date, Ferro::Time::Date
  end
end
