# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# time converts between its error types with From and TryFrom, and an
# error that holds another names it as its source (src/error/*.rs). The
# Ruby classes nest as Rust's enums do, so the same error reaches Ruby
# under more than one class: a ComponentRange inside a parse is
# Error::Parse::TryFromParsed::ComponentRange, not Error::ComponentRange.
# These conversions relate them as the crate's do (plan 007, decision 14).
class TestErrorConversions < Minitest::Test
  include TimeSuite

  E = Ferro::Time::Error

  private def parse_error
    assert_raises(E::Parse::TryFromParsed::ComponentRange) do
      T::Date.parse("2021-02-30", fd("[year]-[month]-[day]"))
    end
  end

  private def assert_different_variant(&)
    error = assert_raises(E::DifferentVariant, &)
    assert_equal "value was of a different variant than required", error.message
  end

  # From a failed parse to the ComponentRange inside it, in the two steps
  # Rust takes: TryFrom<Parse> for TryFromParsed (src/error/parse.rs:60-70),
  # then TryFrom<TryFromParsed> for ComponentRange
  # (src/error/try_from_parsed.rs:38-48).
  def test_a_parse_error_reaches_its_component_range
    parsed = E::TryFromParsed.try_from(parse_error)
    assert_instance_of E::TryFromParsed::ComponentRange, parsed
    assert_equal ["day", true], [parsed.source.name, parsed.source.is_conditional]

    range = E::ComponentRange.try_from(parsed)
    assert_instance_of E::ComponentRange, range
    assert_equal "day was not in range", range.message
    assert_equal ["day", true], [range.name, range.is_conditional]
  end

  # TryFrom<crate::Error>, TryFrom<Format>, and TryFrom<TryFromParsed> for
  # ComponentRange (src/error/component_range.rs:66-76, format.rs:58-68,
  # try_from_parsed.rs:38-48).
  def test_component_range_try_from
    direct = assert_raises(E::ComponentRange) { T::Time.from_hms(24, 0, 0) }
    assert_same direct, E::ComponentRange.try_from(direct)

    range = E::ComponentRange.try_from(E::Format::ComponentRange.new("year", false))
    assert_instance_of E::ComponentRange, range
    assert_equal ["year", false], [range.name, range.is_conditional]

    parsed = T::Parsing::Parsed.new
    parsed.set_year(2021)
    parsed.set_month(Month::February)
    parsed.set_day(30)
    from_parsed = assert_raises(E::TryFromParsed::ComponentRange) { T::Date.try_from(parsed) }
    range = E::ComponentRange.try_from(from_parsed)
    assert_instance_of E::ComponentRange, range
    assert_equal ["day", true], [range.name, range.is_conditional]
  end

  def test_component_range_try_from_another_variant
    assert_different_variant { E::ComponentRange.try_from(E::TryFromParsed::InsufficientInformation.new) }
    assert_different_variant { E::ComponentRange.try_from(E::Format::InsufficientTypeInformation.new) }
    assert_different_variant { E::ComponentRange.try_from(E::InvalidVariant.new) }
    assert_different_variant { E::ComponentRange.try_from(parse_error) }
    error = assert_raises(TypeError) { E::ComponentRange.try_from("day") }
    assert_equal "no implicit conversion of String into Ferro::Time::Error", error.message
  end

  # TryFrom<crate::Error> and TryFrom<Parse> for TryFromParsed
  # (src/error/try_from_parsed.rs:67-77, parse.rs:60-70).
  def test_try_from_parsed_try_from
    insufficient = assert_raises(E::Parse::TryFromParsed::InsufficientInformation) do
      T::Date.parse("2020", fd("[year]"))
    end
    converted = E::TryFromParsed.try_from(insufficient)
    assert_instance_of E::TryFromParsed::InsufficientInformation, converted
    assert_equal insufficient.message, converted.message

    own = E::TryFromParsed::InsufficientInformation.new
    assert_same own, E::TryFromParsed.try_from(own)

    assert_different_variant { E::TryFromParsed.try_from(E::Parse::ParseFromDescription::InvalidLiteral.new) }
    assert_different_variant { E::TryFromParsed.try_from(E::ComponentRange.new("day", true)) }
    assert_raises(TypeError) { E::TryFromParsed.try_from(nil) }
  end

  # TryFrom<crate::Error> and TryFrom<Parse> for ParseFromDescription
  # (src/error/parse_from_description.rs:45-55, parse.rs:79-89).
  def test_parse_from_description_try_from
    invalid = assert_raises(E::Parse::ParseFromDescription::InvalidComponent) do
      T::OffsetDateTime.parse("x", WellKnown::Rfc3339)
    end
    converted = E::ParseFromDescription.try_from(invalid)
    assert_instance_of E::ParseFromDescription::InvalidComponent, converted
    assert_equal ["year", "the 'year' component could not be parsed"], [converted.to_a.first, converted.message]

    literal = E::ParseFromDescription.try_from(E::Parse::ParseFromDescription::InvalidLiteral.new)
    assert_instance_of E::ParseFromDescription::InvalidLiteral, literal
    trailing = E::ParseFromDescription.try_from(E::Parse::ParseFromDescription::UnexpectedTrailingCharacters.new)
    assert_instance_of E::ParseFromDescription::UnexpectedTrailingCharacters, trailing

    own = E::ParseFromDescription::InvalidLiteral.new
    assert_same own, E::ParseFromDescription.try_from(own)

    assert_different_variant { E::ParseFromDescription.try_from(parse_error) }
    assert_raises(TypeError) { E::ParseFromDescription.try_from(StandardError.new) }
  end

  # From<TryFromParsed> and From<ParseFromDescription> for Parse
  # (src/error/parse.rs:53-58, :72-77), as Parsed's errors join a parse's.
  def test_parse_from
    range = E::Parse.from(E::TryFromParsed::ComponentRange.new("day", true))
    assert_instance_of E::Parse::TryFromParsed::ComponentRange, range
    assert_equal ["day", true, "day was not in range"], [range.source.source.name, range.source.source.is_conditional, range.message]
    assert_instance_of E::Parse::TryFromParsed::InsufficientInformation,
      E::Parse.from(E::TryFromParsed::InsufficientInformation.new)
    component = E::Parse.from(E::ParseFromDescription::InvalidComponent.new("hour"))
    assert_instance_of E::Parse::ParseFromDescription::InvalidComponent, component
    assert_equal "hour", component.to_a.first.to_a.first
    assert_instance_of E::Parse::ParseFromDescription::InvalidLiteral,
      E::Parse.from(E::ParseFromDescription::InvalidLiteral.new)
    assert_instance_of E::Parse::ParseFromDescription::UnexpectedTrailingCharacters,
      E::Parse.from(E::ParseFromDescription::UnexpectedTrailingCharacters.new)

    error = assert_raises(TypeError) { E::Parse.from(E::ComponentRange.new("day", true)) }
    assert_equal "no implicit conversion of Ferro::Time::Error::ComponentRange into Ferro::Time::Error::Parse",
      error.message
  end

  # From<ComponentRange> for Format and for TryFromParsed
  # (src/error/format.rs:44-49, try_from_parsed.rs:31-36).
  def test_format_and_try_from_parsed_from_a_component_range
    direct = E::ComponentRange.new("hour", false)
    format = E::Format.from(direct)
    assert_instance_of E::Format::ComponentRange, format
    assert_equal ["hour", false, "hour was not in range"], [format.source.name, format.source.is_conditional, format.message]
    parsed = E::TryFromParsed.from(direct)
    assert_instance_of E::TryFromParsed::ComponentRange, parsed
    assert_equal ["hour", false], [parsed.source.name, parsed.source.is_conditional]

    assert_raises(TypeError) { E::Format.from(E::TryFromParsed::ComponentRange.new("hour", false)) }
    assert_raises(TypeError) { E::TryFromParsed.from(E::Format::ComponentRange.new("hour", false)) }
  end

  # Error::source: what each error holds (src/error/format.rs:82-91,
  # parse.rs:41-51, try_from_parsed.rs:50-58), as its own top-level class.
  def test_source
    source = parse_error.source
    assert_instance_of E::TryFromParsed::ComponentRange, source
    assert_equal ["day", true], [source.source.name, source.source.is_conditional]
    assert_instance_of E::ComponentRange, source.source
    assert_nil source.source.source

    insufficient = E::Parse::TryFromParsed::InsufficientInformation.new.source
    assert_instance_of E::TryFromParsed::InsufficientInformation, insufficient
    assert_nil insufficient.source

    component = E::Parse::ParseFromDescription::InvalidComponent.new("year").source
    assert_instance_of E::ParseFromDescription::InvalidComponent, component
    assert_equal "year", component.to_a.first
    assert_nil component.source
    assert_instance_of E::ParseFromDescription::InvalidLiteral,
      E::Parse::ParseFromDescription::InvalidLiteral.new.source

    format = E::Format::ComponentRange.new("year", false).source
    assert_instance_of E::ComponentRange, format
    assert_equal ["year", false], [format.name, format.is_conditional]

    [
      E::Format::InsufficientTypeInformation.new,
      E::Format::InvalidComponent.new("year"),
      E::ComponentRange.new("day", true),
      E::InvalidVariant.new,
      E::DifferentVariant.new,
      E::ConversionRange.new,
      E::IndeterminateOffset.new,
      E::InvalidFormatDescription::MissingComponentName.new(0),
    ].each { |error| assert_nil error.source, error.class.name }
  end

  # Rust's conversions are on the enum, not on a variant (src/error/*.rs),
  # so a variant class refuses them as Ruby refuses any missing class method.
  def test_a_variant_class_has_no_conversion
    range = E::ComponentRange.new("hour", false)
    [
      [E::Format::InsufficientTypeInformation, :from, range],
      [E::Format::ComponentRange, :from, range],
      [E::TryFromParsed::InsufficientInformation, :try_from, parse_error],
      [E::TryFromParsed::ComponentRange, :from, range],
      [E::ParseFromDescription::InvalidLiteral, :try_from, E::Parse::ParseFromDescription::InvalidLiteral.new],
      [E::Parse::TryFromParsed, :from, E::TryFromParsed::ComponentRange.new("day", true)],
      [E::Parse::ParseFromDescription::InvalidLiteral, :from, E::ParseFromDescription::InvalidLiteral.new],
    ].each do |klass, name, argument|
      error = assert_raises(NoMethodError) { klass.public_send(name, argument) }
      assert_equal "undefined method '#{name}' for class '#{klass}'", error.message
      assert_equal name, error.name
      assert_same klass, error.receiver
    end
  end

  # Rust's blanket <tt>From<T> for T</tt>: a Parse converts to itself.
  def test_parse_from_a_parse_is_that_parse
    parse = parse_error
    assert_same parse, E::Parse.from(parse)
    literal = E::Parse::ParseFromDescription::InvalidLiteral.new
    assert_same literal, E::Parse.from(literal)
  end
end
