# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Iso8601 with any Config (plan 007, decision 11). The extension's
# iso8601::tests checks the gem's composition against time's own
# formatter; these check the Ruby side: Config's setters, what each
# configuration writes, the refusals Rust's compiler would make, and the
# strings Tokra's notification plugin reads.
class TestIso8601 < Minitest::Test
  include TimeSuite

  Config = Iso8601::Config

  private def iso(config)
    Iso8601.new(config)
  end

  private def at
    datetime(2021, 1, 2, 3, 4, 5, 123_456_789).assume_offset(offset(1, 30))
  end

  def test_the_constants_format_what_time_names_them_for
    {
      Iso8601::DEFAULT => "2021-01-02T03:04:05.123456789+01:30",
      Iso8601::DATE_TIME_OFFSET => "2021-01-02T03:04:05.123456789+01:30",
      Iso8601::DATE => "2021-01-02",
      Iso8601::TIME => "03:04:05.123456789",
      Iso8601::OFFSET => "+01:30",
      Iso8601::DATE_TIME => "2021-01-02T03:04:05.123456789",
      Iso8601::TIME_OFFSET => "03:04:05.123456789+01:30",
    }.each { |format, expected| assert_equal expected, at.format(format), format.inspect }
    assert_equal at.format(Iso8601::DEFAULT), at.format(Iso8601)
  end

  def test_each_setter_changes_what_is_written
    basic = Config::DEFAULT.set_use_separators(false)
    assert_equal "20210102T030405.123456789+0130", at.format(iso(basic))
    assert_equal "+002021-01-02T03:04:05.123456789+01:30", at.format(iso(Config::DEFAULT.set_year_is_six_digits(true)))
    assert_equal "2020-W53-6T03:04:05.123456789+01:30",
      at.format(iso(Config::DEFAULT.set_date_kind(Iso8601::DateKind::Week)))
    assert_equal "2021-002T03:04:05.123456789+01:30",
      at.format(iso(Config::DEFAULT.set_date_kind(Iso8601::DateKind::Ordinal)))
    hours = Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Hour.new(decimal_digits: 3))
    assert_equal "2021-01-02T03.068+01:30", at.format(iso(hours))
    minutes = Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Minute.new(decimal_digits: nil))
    assert_equal "2021-01-02T03:04+01:30", at.format(iso(minutes))
    many = Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Second.new(decimal_digits: 12))
    assert_equal "2021-01-02T03:04:05.123456789000+01:30", at.format(iso(many))
    assert_raises(Ferro::Time::Error::Format::InvalidComponent) do
      at.format(iso(Config::DEFAULT.set_offset_precision(Iso8601::OffsetPrecision::Hour)))
    end
  end

  # A Config is a value: each setter leaves its receiver as it was.
  def test_a_config_is_frozen_and_never_changes
    config = Config::DEFAULT
    changed = config.set_use_separators(false)
    refute_same config, changed
    assert_predicate changed, :frozen?
    assert_equal Iso8601::DEFAULT, iso(config)
    refute_equal Iso8601::DEFAULT, iso(changed)
    assert_equal iso(changed), iso(Config::DEFAULT.set_use_separators(false))
    refute_equal config, Config::DEFAULT.set_use_separators(true)
  end

  # time's encoding puts each setting in a byte, most significant first
  # (src/format_description/well_known/iso8601/adt_hack.rs:51-87).
  def test_encode_is_time_s_encoding
    bytes = [5, 1, 0, 0, 2, 9, 1] + ([0] * 9)
    assert_equal bytes.reduce(0) { |sum, byte| (sum << 8) | byte }, Config::DEFAULT.encode
  end

  def test_debug_texts
    assert_equal "Config { formatted_components: DateTimeOffset, use_separators: true, year_is_six_digits: false, " \
      "date_kind: Calendar, time_precision: Second { decimal_digits: Some(9) }, offset_precision: Minute }",
      Config::DEFAULT.inspect
    assert_equal "Iso8601 { config: #{Config::DEFAULT.inspect} }", Iso8601::DEFAULT.inspect
  end

  def test_a_setting_rust_cannot_hold_is_refused
    assert_raises(TypeError) { Config::DEFAULT.set_formatted_components(1) }
    assert_raises(TypeError) { Config::DEFAULT.set_use_separators(nil) }
    assert_raises(TypeError) { Config::DEFAULT.set_time_precision(Iso8601::DateKind::Week) }
    assert_raises(RangeError) { Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Second.new(decimal_digits: 0)) }
    assert_raises(RangeError) do
      Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Second.new(decimal_digits: 256))
    end
    assert_raises(TypeError) { Iso8601.new(:default) }
  end

  # Rust refuses these when it compiles (src/formatting/formattable.rs:927-946).
  def test_what_a_type_cannot_provide_raises_type_error
    error = assert_raises(TypeError) { date(2021, 1, 2).format(Iso8601::DEFAULT) }
    assert_equal "this Iso8601 configuration formats time components, but this type cannot provide them", error.message
    error = assert_raises(TypeError) { clock(1, 2).format(Iso8601::DATE) }
    assert_equal "this Iso8601 configuration formats date components, but this type cannot provide them", error.message
    error = assert_raises(TypeError) { datetime(2021, 1, 2).format(Iso8601::DEFAULT) }
    assert_equal "this Iso8601 configuration formats offset components, but this type cannot provide them",
      error.message
    error = assert_raises(TypeError) { at.format(Iso8601::PARSING) }
    assert_equal "this Iso8601 configuration does not format any components", error.message
    assert_raises(TypeError) { date(2021, 1, 2).format(WellKnown::Rfc3339) }
    assert_raises(TypeError) { offset(1).format(WellKnown::Rfc2822) }
  end

  # format_into keeps what time wrote before it stopped (plan 007,
  # decision 11).
  def test_format_into_keeps_the_parts_written_before_a_failure
    output = +"> "
    value = datetime(2021, 1, 2, 3, 4, 5).assume_offset(offset(0, 0, 1))
    assert_raises(Ferro::Time::Error::Format::InvalidComponent) { value.format_into(output, Iso8601::DEFAULT) }
    assert_equal "> 2021-01-02T03:04:05.000000000", output
    assert_raises(FrozenError) { value.format_into("frozen", Iso8601::DATE) }
  end

  # format_into returns time's count, which leaves out the bytes of an hour
  # or minute with a decimal fraction (src/formatting/iso8601.rs:125-140)
  # and of an RFC 3339 fraction of a second;
  # the extension's tests compare every count with time's own.
  def test_format_into_returns_time_s_count
    hours = Config::DEFAULT.set_time_precision(Iso8601::TimePrecision::Hour.new(decimal_digits: 2))
    output = +""
    assert_equal 0, T::Time::MIDNIGHT.format_into(output, iso(hours.set_formatted_components(Iso8601::FormattedComponents::Time)))
    assert_equal "00.00", output
    output = +""
    assert_equal 12, T::OffsetDateTime::UNIX_EPOCH.format_into(output, iso(hours))
    assert_equal "1970-01-01T00.00Z", output
    output = +""
    assert_equal 30, T::OffsetDateTime::UNIX_EPOCH.format_into(output, Iso8601::DEFAULT)
    assert_equal 30, output.bytesize
    # RFC 3339 leaves the digits of a fraction of a second out of its count
    # (src/formatting/formattable.rs:868-875).
    output = +""
    assert_equal 21, (T::OffsetDateTime::UNIX_EPOCH + Duration::MILLISECOND).format_into(output, WellKnown::Rfc3339)
    assert_equal "1970-01-01T00:00:00.001Z", output
  end

  # Parsing reads no configuration (src/parsing/parsable.rs:894-954).
  def test_every_configuration_parses_alike
    input = "2021-W01-2T03:04:05.1-01:00"
    expected = T::OffsetDateTime.parse(input, Iso8601::DEFAULT)
    [Iso8601::PARSING, Iso8601::DATE, iso(Config::DEFAULT.set_use_separators(false))].each do |format|
      assert_equal expected, T::OffsetDateTime.parse(input, format)
    end
  end

  # What Tauri's notification plugin reads with time's ISO 8601 parser
  # (Tokra's plan 024), with time's serde configuration.
  def test_tokra_s_notification_dates
    serde = iso(Config::DEFAULT.set_year_is_six_digits(true))
    at = T::OffsetDateTime.parse("2026-10-26T12:00:00.000Z", serde)
    assert_equal 1_793_016_000, at.unix_timestamp
    assert_equal "+002026-10-26T12:00:00.000000000Z", at.format(serde)
    assert_equal at, T::OffsetDateTime.parse("+002026-10-26T12:00:00.000000000Z", serde)
    error = assert_raises(Ferro::Time::Error::Parse) { T::OffsetDateTime.parse("2026-13-01T00:00:00Z", serde) }
    assert_equal "unexpected trailing characters; the end of input was expected", error.message
    error = assert_raises(Ferro::Time::Error::Parse) { T::OffsetDateTime.parse("tomorrow", serde) }
    assert_equal "the 'year' component could not be parsed", error.message
  end
end
