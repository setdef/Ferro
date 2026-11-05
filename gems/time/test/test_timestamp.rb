# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "open3"

# What Timestamp promises beyond time's own tests (test_port_timestamp.rb):
# its Ruby contracts, its interop with UtcDateTime, OffsetDateTime, and
# Ruby's ::Time (plan 009, "Timestamp"), the same results as UtcDateTime
# for formatting and parsing, and the refusal of every input time would
# panic on (plan 007, decision 7).
class TestTimestamp < Minitest::Test
  include TimeSuite

  # A Timestamp at +seconds+ and +nanoseconds+.
  private def ts(seconds, nanoseconds = 0)
    T::Timestamp.new(seconds, nanoseconds)
  end

  private def assert_refused(message, &)
    error = assert_raises(RangeError, &)
    assert_equal message, error.message
  end

  # What a SystemTime keeps of +nanoseconds+: all of them on Unix, and
  # whole 100 ns intervals on Windows, which counts in them from 1601
  # (std's sys/pal/windows/time.rs).
  private def kept(nanoseconds)
    Gem.win_platform? ? nanoseconds - (nanoseconds % 100) : nanoseconds
  end

  def test_the_range_is_the_range_of_a_utc_date_time
    assert_equal T::UtcDateTime::MIN.unix_timestamp_nanos, T::Timestamp::MIN.as_nanoseconds
    assert_equal T::UtcDateTime::MAX.unix_timestamp_nanos, T::Timestamp::MAX.as_nanoseconds
    assert_equal T::Timestamp::MAX, T::Timestamp.from(T::UtcDateTime::MAX)
    assert_equal T::UtcDateTime::MIN, T::Timestamp::MIN.to_utc
    assert_equal ts(0), T::Timestamp::UNIX_EPOCH
  end

  def test_a_negative_instant_is_the_seconds_below_it_and_a_positive_fraction
    half_before = ts(-1, 500_000_000)
    assert_equal(-500_000_000, half_before.as_nanoseconds)
    assert_equal(-1, half_before.as_seconds)
    assert_equal 500_000_000, half_before.nanosecond
    assert_equal "-0.5", half_before.to_s
    assert_equal half_before, T::Timestamp.from_nanoseconds(-500_000_000)
  end

  def test_arguments_are_checked_as_the_other_types_check_theirs
    assert_raises(TypeError) { ts("1") }
    assert_raises(RangeError) { ts(0, -1) }
    assert_raises(RangeError) { ts(2 ** 70) }
    assert_raises(T::Error::ComponentRange) { ts(2 ** 62) }
    assert_raises(T::Error::ComponentRange) { ts(0, 1_000_000_000) }
    assert_raises(TypeError) { T::Timestamp.from(1) }
    assert_raises(TypeError) { T::Timestamp.from(nil) }
    assert_raises(TypeError) { ts(0) + :one }
    assert_raises(TypeError) { ts(0) - "1" }
    assert_raises(TypeError) { ts(0).checked_add(1) }
    assert_raises(TypeError) { ts(0).replace_month(1) }
    assert_raises(TypeError) { ts(0).replace_time(1) }
    assert_raises(TypeError) { ts(0).replace_date(1) }
    assert_raises(TypeError) { ts(0).to_offset(0) }
    assert_raises(TypeError) { ts(0).format(1) }
    assert_raises(TypeError) { T::Timestamp.try_from(1) }
    assert_raises(TypeError) { T::Timestamp.parse_with_defaults("", fd("[year]"), 1) }
    assert_raises(FrozenError) { ts(0).format_into("", fd("[year]")) }
    refute_equal ts(0), 0
    assert_nil ts(0) <=> 0
    assert_raises(ArgumentError) { ts(0) < 0 }
  end

  def test_eql_is_for_timestamps_only_and_equal_values_are_one_hash_key
    assert ts(1, 2).eql?(ts(1, 2))
    refute ts(1, 2).eql?(T::UtcDateTime.from_unix_timestamp_nanos(1_000_000_002))
    assert_equal ts(1, 2), T::UtcDateTime.from_unix_timestamp_nanos(1_000_000_002)
    assert_equal 1, { ts(1, 2) => 1, ts(1, 2) => 2 }.size
    assert_equal [ts(-1), ts(0), ts(0, 1), ts(5)], [ts(5), ts(0, 1), ts(-1), ts(0)].sort
    assert_equal ts(0), ts(5).clamp(ts(-3), ts(0))
    assert ts(2).between?(ts(1), ts(3))
  end

  def test_conversions_with_utc_date_time_and_offset_date_time
    at = ts(1_546_398_245, 6_007_008)
    utc = T::UtcDateTime.from_unix_timestamp_nanos(at.as_nanoseconds)
    odt = T::OffsetDateTime.from_unix_timestamp_nanos(at.as_nanoseconds).to_offset(offset(-5))
    assert_equal utc, at.to_utc
    assert_equal at, T::Timestamp.from(utc)
    assert_equal at, T::Timestamp.from(odt)
    assert_equal odt, at.to_offset(offset(-5))
    assert_equal utc, T::UtcDateTime.from(at)
    assert_equal odt, T::OffsetDateTime.from(at).to_offset(offset(-5))
    assert_equal offset(0), T::OffsetDateTime.from(at).offset
    [utc, odt].each do |other|
      assert_equal at, other
      assert_equal other, at
      assert_equal 0, at <=> other
      assert_equal 0, other <=> at
      assert_equal T::SignedDuration::ZERO, at - other
      assert_equal T::SignedDuration::ZERO, other - at
      later = other + Duration.nanoseconds(1)
      assert_operator at, :<, later
      assert_operator later, :>, at
      assert_equal Duration.nanoseconds(-1), at - later
      assert_equal Duration.nanoseconds(1), later - at
    end
  end

  def test_comparisons_and_differences_with_ruby_s_time
    at = ts(5, 100)
    other = ::Time.at(5, 100, :nsec)
    assert_equal at, other
    assert_equal other, at
    assert_equal 0, at <=> other
    # A ::Time crosses as a SystemTime, which keeps only whole 100 ns
    # intervals on Windows, so these differ from +at+ by a whole interval.
    assert_operator ::Time.at(5, 0, :nsec), :<, at
    assert_operator ::Time.at(5, 200, :nsec), :>, at
    assert_equal T::SignedDuration::ZERO, at - other
    assert_equal Duration.new(5, 100), at - ::Time.at(0)
    assert_equal Duration.seconds(-5), ts(0) - ::Time.at(5)
    assert_raises(TypeError) { ::Time.at(0) - ts(0) }
    refute_equal at, ::Time.at(6)
  end

  def test_from_and_to_time_round_trip_in_utc
    at = ts(1_546_398_245, 123_456_789)
    ruby = at.to_time
    assert_instance_of ::Time, ruby
    assert_predicate ruby, :utc?
    assert_equal [1_546_398_245, kept(123_456_789)], [ruby.to_i, ruby.nsec]
    assert_equal ts(1_546_398_245, kept(123_456_789)), T::Timestamp.from(at.to_time)
    before = ::Time.at(-1, 999_999_999, :nsec)
    assert_equal ts(-1, kept(999_999_999)), T::Timestamp.from(before)
    assert_equal T::Timestamp.from_seconds(1_546_398_245), T::Timestamp.from(::Time.at(1_546_398_245, in: "+09:00"))
  end

  def test_each_input_time_panics_on_is_refused_with_its_message
    out_of_range = "resulting value is out of range"
    assert_refused(out_of_range) { T::Timestamp::MAX + Duration.nanoseconds(1) }
    assert_refused(out_of_range) { T::Timestamp::MIN - Duration.nanoseconds(1) }
    assert_refused(out_of_range) { T::Timestamp::MAX + Duration::MAX }
    assert_refused("local datetime out of valid range") { T::Timestamp::MAX.to_offset(offset(1)) }
    assert_refused("local datetime out of valid range") { T::Timestamp::MIN.to_offset(offset(-1)) }
    west = T::PlainDateTime::MAX.assume_offset(offset(-1))
    error = assert_raises(RangeError) { T::Timestamp.from(west) }
    assert_equal "local datetime out of valid range for `Timestamp`: ComponentRange { name: \"seconds\", is_conditional: false }", error.message
    error = assert_raises(RangeError) { T::Timestamp.from(::Time.at(400_000_000_000)) }
    assert_equal "SystemTime value is out of valid range: ComponentRange { name: \"seconds\", is_conditional: false }", error.message
    assert_raises(RangeError) { T::Timestamp.from(::Time.at(-(2 ** 63), 5, :nsec)) }
    converting = "overflow converting `std::time::Duration` to `time::SignedDuration`: ConversionRange"
    assert_refused(converting) { T::Timestamp::MIN - ::Time.at(-(2 ** 63)) } unless Gem.win_platform?
    assert_refused("overflow when subtracting durations") { T::Timestamp::MIN - ::Time.at((2 ** 63) - 1) } unless Gem.win_platform?
    assert_refused("overflow when adding durations") { T::Timestamp::MAX - ::Time.at(-(2 ** 63) + 1) } unless Gem.win_platform?
  end

  def test_what_does_not_panic_answers
    assert_nil T::Timestamp::MAX.checked_to_offset(offset(1))
    assert_nil T::Timestamp::MIN.checked_to_offset(offset(-1))
    assert_nil T::Timestamp::MAX.checked_add(Duration.nanoseconds(1))
    assert_equal T::Timestamp::MAX, T::Timestamp::MAX.saturating_add(Duration::MAX)
    assert_equal T::Timestamp::MIN, T::Timestamp::MIN.saturating_sub(Duration::MAX)
    assert_equal Duration.nanoseconds(1), ts(1, 1) - ts(1)
    assert_equal T::Timestamp::MAX.as_nanoseconds - T::Timestamp::MIN.as_nanoseconds, (T::Timestamp::MAX - T::Timestamp::MIN).whole_nanoseconds
    assert_operator T::Timestamp.from(::Time.at(0, in: "-12:00")), :==, T::Timestamp::UNIX_EPOCH
  end

  def test_a_timestamp_is_a_before_the_epoch_clock_time_like_a_utc_date_time
    [-1, -86_400, -86_401, -(2 ** 36), T::Timestamp::MIN.as_seconds, T::Timestamp::MAX.as_seconds].each do |seconds|
      [0, 1, 999_999_999].each do |nanoseconds|
        stamp = ts(seconds, nanoseconds)
        utc = stamp.to_utc
        %i[
          year
          month
          day
          ordinal
          iso_week
          sunday_based_week
          monday_based_week
          weekday
          to_julian_day
          hour
          minute
          second
          millisecond
          microsecond
          nanosecond
          to_calendar_date
          to_ordinal_date
          to_iso_week_date
          as_hms
          as_hms_milli
          as_hms_micro
          as_hms_nano
          date
          time
].each do |reader|
          assert_equal utc.public_send(reader), stamp.public_send(reader), "#{reader} of #{stamp}"
        end
        assert_equal utc.unix_timestamp, stamp.as_seconds
        assert_equal utc.unix_timestamp_nanos, stamp.as_nanoseconds
      end
    end
  end

  def test_replace_methods_answer_as_a_utc_date_time_does
    [ts(1_546_398_245, 6_007_008), ts(-1, 400_000_000), ts(-86_401, 999_999_999), T::Timestamp::MIN].each do |stamp|
      utc = stamp.to_utc
      {
        replace_hour: [0, 12, 23, 24],
        replace_minute: [0, 59, 60],
        replace_second: [0, 59, 60],
        replace_millisecond: [0, 7, 999, 1_000],
        replace_microsecond: [0, 7, 999_999, 1_000_000],
        replace_nanosecond: [0, 7, 999_999_999, 1_000_000_000],
        replace_day: [1, 28, 31, 32],
        replace_ordinal: [1, 365, 366, 367],
        replace_year: [-9999, 2000, 9999, 10_000],
      }.each do |name, values|
        values.each do |value|
          expected = begin
            utc.public_send(name, value)
          rescue T::Error => e
            e.class
          end
          actual = begin
            stamp.public_send(name, value).to_utc
          rescue T::Error => e
            e.class
          end
          # A Timestamp replaces the fraction as its decimal text writes it:
          # before the epoch, <tt>-1.5</tt> is seconds -2 and half a second,
          # and replacing the fraction with 0 gives -1. A UtcDateTime
          # replaces the clock's nanosecond and gives -2. They agree for an
          # instant at or after the epoch and for a whole second
          # (src/timestamp.rs:1275-1295); the ported tests pin the rest.
          next if name.to_s.match?(/(milli|micro|nano)second/) && stamp.as_seconds.negative? && stamp.nanosecond != 0

          assert_equal expected, actual, "#{name}(#{value}) on #{stamp}"
        end
      end
      assert_equal stamp.replace_month(Month::March).to_utc, utc.replace_month(Month::March) if stamp.to_utc.day <= 28
    end
  end

  def test_formatting_is_a_utc_date_time_s
    descriptions = [
      fd("[year]-[month]-[day] [hour]:[minute]:[second].[subsecond] [offset_hour sign:mandatory]:[offset_minute]"),
      fd("[unix_timestamp precision:nanosecond] [weekday] [week_number] [ordinal]"),
      WellKnown::Rfc2822,
      WellKnown::Rfc3339,
      Iso8601::DEFAULT,
      Iso8601::DATE,
      Iso8601::TIME_OFFSET,
    ]
    [ts(1_546_398_245, 6_007_008), ts(-1, 400_000_000), T::Timestamp::MIN, T::Timestamp::MAX].each do |stamp|
      descriptions.each do |description|
        expected = capture { stamp.to_utc.format(description) }
        assert_equal expected, capture { stamp.format(description) }, "#{stamp} #{description.inspect}"
        output = +""
        count = capture { stamp.format_into(output, description) }
        utc_output = +""
        utc_count = capture { stamp.to_utc.format_into(utc_output, description) }
        assert_equal utc_output, output
        assert_equal utc_count, count
      end
    end
  end

  # The answer of the block, or the class of the error it raises.
  private def capture
    yield
  rescue T::Error, RangeError, TypeError => e
    [e.class, e.message]
  end

  def test_parsing_is_a_utc_date_time_s
    inputs = [
      ["2019-01-02T03:04:05.006007008Z", WellKnown::Rfc3339],
      ["2019-01-02T03:04:05+09:30", WellKnown::Rfc3339],
      ["2016-12-31T23:59:60Z", WellKnown::Rfc3339],
      ["2016-12-30T23:59:60Z", WellKnown::Rfc3339],
      ["9999-12-31T23:59:60-05:00", WellKnown::Rfc3339],
      ["9999-12-31T23:00:00-05:00", WellKnown::Rfc3339],
      ["-9999-01-01T00:00:00+05:00", WellKnown::Rfc3339],
      ["Wed, 02 Jan 2019 03:04:05 +0000", WellKnown::Rfc2822],
      ["2019-01-02T03:04:05Z", Iso8601::DEFAULT],
      ["1546398245", fd("[unix_timestamp]")],
      ["2019-01-02", fd("[year]-[month]-[day]")],
      ["03:04", fd("[hour]:[minute]")],
    ]
    inputs.each do |input, description|
      expected = capture { T::Timestamp.from(T::UtcDateTime.parse(input, description)) }
      # time's TryFrom<Parsed> for Timestamp answers any failure of the
      # UtcDateTime it falls back to with InsufficientInformation
      # (src/parsing/parsed.rs:1395-1410).
      if expected.is_a?(Array) && expected.first < T::Error::Parse::TryFromParsed
        expected = [T::Error::Parse::TryFromParsed::InsufficientInformation, T::Error::Parse::TryFromParsed::InsufficientInformation.new.message]
      end
      actual = capture { T::Timestamp.parse(input, description) }
      assert_equal expected, actual, input
      assert_equal expected, capture { T::Timestamp.parse_with_defaults(input, description, T::Parsing::Parsed.new) }, input
    end
    assert_equal ts(1_546_398_245), T::Timestamp.parse("1546398245", fd("[unix_timestamp]"))
  end

  def test_try_from_takes_a_unix_timestamp_first
    parsed = T::Parsing::Parsed.new
    parsed.set_unix_timestamp_nanos(1_546_398_245_006_007_008)
    parsed.set_year(1999)
    assert_equal ts(1_546_398_245, 6_007_008), T::Timestamp.try_from(parsed)
    edge = T::Parsing::Parsed.new
    assert edge.set_unix_timestamp_nanos(T::Timestamp::MAX.as_nanoseconds)
    assert_equal T::Timestamp::MAX, T::Timestamp.try_from(edge)
    refute edge.set_unix_timestamp_nanos(T::Timestamp::MAX.as_nanoseconds + 1)
    assert_raises(T::Error::TryFromParsed::InsufficientInformation) { T::Timestamp.try_from(T::Parsing::Parsed.new) }
  end

  def test_try_from_refuses_a_local_date_time_whose_instant_leaves_the_range
    parsed = T::Parsing::Parsed.new
    parsed.set_year(9999)
    parsed.set_month(Month::December)
    parsed.set_day(31)
    parsed.set_hour_24(23)
    parsed.set_minute(0)
    parsed.set_offset_hour(-5)
    assert_refused("local datetime out of valid range") { T::Timestamp.try_from(parsed) }
    assert_refused("local datetime out of valid range") { T::UtcDateTime.try_from(parsed) }
    parsed.set_hour_24(18)
    assert_equal T::Timestamp.from(T::UtcDateTime.try_from(parsed)), T::Timestamp.try_from(parsed)
  end

  def test_the_flags_of_a_signed_duration_apply
    at = ts(10)
    assert_equal ts(7), at - Duration.seconds(3)
    assert_equal ts(13), at + Duration.seconds(3)
    assert_equal ts(9, 500_000_000), at - Duration.milliseconds(500)
    assert_equal ts(10, 500_000_000), at + Duration.milliseconds(500)
    assert_equal Duration.milliseconds(-500), at - ts(10, 500_000_000)
  end

  # Prints nothing and raises nothing near the ends of the range: no input
  # reaches a Rust panic (plan 007, decision 7; plan 009, decisions 17 to
  # 19). The child prints each unexpected failure, and Rust's panic hook
  # would write to its standard error.
  FUZZ = <<~'RUBY'
    t = Ferro::Time
    rng = Random.new(Integer(ENV.fetch("FUZZ_SEED", "7")))
    count = Integer(ENV.fetch("FUZZ_COUNT", "3000"))
    min = t::Timestamp::MIN.as_seconds
    max = t::Timestamp::MAX.as_seconds
    ends = [min, max, min, max, 2**63 - 1, -(2**63), 2**62, -(2**62)]
    known = [
      "resulting value is out of range", "local datetime out of valid range",
      "overflow when adding durations", "overflow when subtracting durations",
      "overflow when adding duration to `SystemTime`", "overflow when subtracting duration from `SystemTime`",
    ]
    problems = []
    tally = Hash.new(0)
    expect = lambda do |label, &block|
      block.call
      tally[:ok] += 1
    rescue t::Error => e
      if e.message.start_with?("time panicked")
        problems << "#{label}: #{e.class} #{e.message}"
      else
        tally[:error] += 1
      end
    rescue RangeError, TypeError, ArgumentError => e
      known_message = known.include?(e.message) || e.message.start_with?("local datetime out of valid range for", "SystemTime value is out of valid range", "overflow converting") ||
        e.message.match?(/bignum|too big|too small|negative integer|out of range/)
      problems << "#{label}: #{e.class} #{e.message}" unless known_message
      tally[:refused] += 1
    end
    nearest = lambda do
      base = ends.sample(random: rng)
      base.abs > 2**40 ? base : base + rng.rand(-200_000..200_000)
    end
    count.times do |i|
      seconds = nearest.call
      nanos = rng.rand(0..999_999_999)
      offset_seconds = rng.rand(-93_599..93_599)
      offset = t::UtcOffset.from_whole_seconds(offset_seconds)
      duration = t::Duration.new(ends.sample(random: rng), rng.rand(-999_999_999..999_999_999)) rescue t::Duration::SECOND
      stamp = t::Timestamp.new(seconds.clamp(min, max), nanos)
      ruby_time = ::Time.at(seconds, nanos, :nsec)
      expect.call("new #{seconds} #{nanos}") { t::Timestamp.new(seconds, nanos) }
      expect.call("from_seconds #{seconds}") { t::Timestamp.from_seconds(seconds) }
      expect.call("from_nanoseconds") { t::Timestamp.from_nanoseconds(seconds * 1_000_000_000 + nanos) }
      expect.call("+ #{stamp} #{duration}") { stamp + duration }
      expect.call("- #{stamp} #{duration}") { stamp - duration }
      expect.call("from_milliseconds") { t::Timestamp.from_milliseconds(seconds * 1_000 + nanos / 1_000_000) }
      expect.call("from_microseconds") { t::Timestamp.from_microseconds(seconds * 1_000_000 + nanos / 1_000) }
      expect.call("checked_add") { stamp.checked_add(duration) }
      expect.call("checked_sub") { stamp.checked_sub(duration) }
      expect.call("saturating_add") { stamp.saturating_add(duration) }
      expect.call("saturating_sub") { stamp.saturating_sub(duration) }
      utc_other = t::UtcDateTime.from(stamp)
      odt_other = t::OffsetDateTime.from(stamp).to_offset(offset) rescue t::OffsetDateTime.from(stamp)
      [utc_other, odt_other].each do |other|
        expect.call("- #{other}") { stamp - other }
        expect.call("== #{other}") { stamp == other }
        expect.call("<=> #{other}") { stamp <=> other }
        expect.call("rev - #{other}") { other - stamp }
        expect.call("rev <=> #{other}") { other <=> stamp }
      end
      expect.call("to_offset #{stamp} #{offset}") { stamp.to_offset(offset) }
      expect.call("from odt") do
        local = t::PlainDateTime.new(t::Date.from_julian_day(rng.rand(t::Date::MIN.to_julian_day..t::Date::MAX.to_julian_day)), t::Time::MAX).assume_offset(offset)
        t::Timestamp.from(local)
      end
      expect.call("from near-end odt") do
        edge = [t::Date::MIN, t::Date::MAX].sample(random: rng)
        t::Timestamp.from(t::PlainDateTime.new(edge, t::Time.from_hms_nano(rng.rand(0..23), rng.rand(0..59), rng.rand(0..59), nanos)).assume_offset(offset))
      end
      expect.call("from time #{seconds}") { t::Timestamp.from(ruby_time) }
      expect.call("- time") { stamp - ruby_time }
      expect.call("== time") { stamp == ruby_time }
      expect.call("<=> time") { stamp <=> ruby_time }
      expect.call("to_time") { stamp.to_time }
      expect.call("replace_date") { stamp.replace_date(t::Date.from_julian_day(rng.rand(t::Date::MIN.to_julian_day..t::Date::MAX.to_julian_day))) }
      expect.call("replace_year") { stamp.replace_year(rng.rand(-10_000..10_000)) }
      expect.call("replace_ms") { stamp.replace_millisecond(rng.rand(0..65_535)) }
      expect.call("replace_us") { stamp.replace_microsecond(rng.rand(0..4_294_967_295)) }
      year = [-9999, 9999, rng.rand(-9999..9999)].sample(random: rng)
      second = [59, 60, rng.rand(0..60)].sample(random: rng)
      sign = rng.rand(2).zero? ? "-" : "+"
      text = format("%s%04d-%02d-%02dT%02d:%02d:%02d%s%02d:%02d", year.negative? ? "-" : "", year.abs, [1, 12, rng.rand(1..12)].sample(random: rng),
        [1, 28, 31, rng.rand(1..28)].sample(random: rng), rng.rand(0..23), rng.rand(0..59), second, sign, rng.rand(0..25), rng.rand(0..59))
      [t::FormatDescription::WellKnown::Rfc3339, t::FormatDescription::WellKnown::Iso8601::DEFAULT].each do |description|
        expect.call("parse #{text}") { t::Timestamp.parse(text, description) }
        expect.call("parse_with_defaults #{text}") { t::Timestamp.parse_with_defaults(text, description, t::Parsing::Parsed.new) }
        expect.call("utc parity #{text}") do
          expected = begin
            t::Timestamp.from(t::UtcDateTime.parse(text, description))
          rescue t::Error, RangeError => e
            e.class
          end
          actual = begin
            t::Timestamp.parse(text, description)
          rescue t::Error, RangeError => e
            e.class
          end
          expected = t::Error::Parse::TryFromParsed::InsufficientInformation if expected.is_a?(Class) && expected < t::Error::Parse::TryFromParsed
          problems << "parity #{text}: #{expected.inspect} #{actual.inspect}" unless expected == actual
        end
      end
      parsed = t::Parsing::Parsed.new
      parsed.set_year(year)
      parsed.set_month(t::Month.try_from(rng.rand(1..12)))
      parsed.set_day(rng.rand(1..28))
      parsed.set_hour_24(rng.rand(0..23))
      parsed.set_minute(rng.rand(0..59))
      parsed.set_offset_hour(rng.rand(-25..25))
      parsed.set_unix_timestamp_nanos(seconds * 1_000_000_000 + nanos) if rng.rand(4).zero?
      expect.call("try_from") { t::Timestamp.try_from(parsed) }
    end
    puts Marshal.dump([problems.first(20), tally]).unpack1("H*")
  RUBY

  # Runs the fuzz script in a fresh Ruby, and returns its problems, its
  # tally, and everything it wrote to standard error.
  private def fuzz(count:, seed:)
    env = UNBUNDLED.merge("FUZZ_COUNT" => count.to_s, "FUZZ_SEED" => seed.to_s)
    out, err, status = Open3.capture3(env, RbConfig.ruby, "-I", LIB, "-e", "require 'ferro/time'; Warning[:experimental] = false; #{FUZZ}")
    flunk "the fuzz child failed: #{err}\n#{out}" unless status.success?
    problems, tally = Marshal.load([out.lines.last.strip].pack("H*"))
    [problems, tally, err]
  end

  def test_no_input_near_the_ends_of_the_range_panics
    problems, tally, err = fuzz(count: 3_000, seed: 20_261_101)
    assert_empty problems
    assert_empty err, "Rust wrote to standard error"
    assert_operator tally[:ok], :>, 10_000
    assert_operator tally[:refused], :>, 100
  end
end
