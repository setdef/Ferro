# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Every error time raises is a class under Ferro::Time::Error, nested as
# Rust nests its enums, with time's Display text as the message and time's
# fields as readers (plan 007, decision 14). The texts are time's own;
# failure::tests in the extension pins each against the crate.
class TestErrors < Minitest::Test
  include TimeSuite

  E = Ferro::Time::Error

  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: MIT OR Apache-2.0
  # SPDX-SnippetCopyrightText: Jacob Pratt et al.
  # SPDX-SnippetComment: the failures time 0.3.55's tests/integration/error.rs
  #   builds, and the Display texts of src/error/*.rs
  #++

  def test_a_component_out_of_range
    error = assert_raises(E::ComponentRange) { T::Date.from_ordinal_date(0, 367) }
    assert_equal "ordinal was not in range", error.message
    assert_equal "ordinal", error.name
    assert error.is_conditional
    error = assert_raises(E::ComponentRange) { T::Time.from_hms(24, 0, 0) }
    assert_equal ["hour", false], [error.name, error.is_conditional]
  end

  def test_insufficient_type_information
    error = assert_raises(E::Format::InsufficientTypeInformation) { T::Time::MIDNIGHT.format(fd("[year]")) }
    assert_equal "The type being formatted does not contain sufficient information to format a component.",
      error.message
  end

  def test_unexpected_trailing_characters
    error = assert_raises(E::Parse::ParseFromDescription::UnexpectedTrailingCharacters) do
      T::Time.parse("a", fd(""))
    end
    assert_equal "unexpected trailing characters; the end of input was expected", error.message
  end

  def test_an_invalid_format_description
    error = assert_raises(E::InvalidFormatDescription::MissingComponentName) do
      T::FormatDescription.parse_borrowed(3, "[")
    end
    assert_equal "missing component name at byte index 0", error.message
    assert_equal 0, error.index
  end

  def test_an_invalid_literal
    error = assert_raises(E::Parse::ParseFromDescription::InvalidLiteral) { T::Time.parse("12x30", fd("[hour]:[minute]")) }
    assert_equal "a character literal was not valid", error.message
  end

  def test_an_invalid_component
    error = assert_raises(E::Parse::ParseFromDescription::InvalidComponent) do
      T::OffsetDateTime.parse("x", WellKnown::Rfc3339)
    end
    assert_equal ["year", "the 'year' component could not be parsed"], [error.name, error.message]
  end

  def test_insufficient_information
    error = assert_raises(E::Parse::TryFromParsed::InsufficientInformation) { T::Date.parse("2020", fd("[year]")) }
    assert_equal "the `Parsed` struct did not include enough information to construct the type", error.message
  end

  def test_a_component_out_of_range_while_parsing
    error = assert_raises(E::Parse::TryFromParsed::ComponentRange) do
      T::Date.parse("2019-02-30", Iso8601::DATE)
    end
    assert_equal ["day", true, "day was not in range"], [error.name, error.is_conditional, error.message]
  end

  def test_an_invalid_variant
    error = assert_raises(E::InvalidVariant) { Month.from_str("Smarch") }
    assert_equal "value was not a valid variant", error.message
  end

  def test_an_invalid_component_while_formatting
    error = assert_raises(E::Format::InvalidComponent) { T::OffsetDateTime::UNIX_EPOCH.replace_year(1800).format(WellKnown::Rfc2822) }
    assert_equal ["year", "The year component cannot be formatted into the requested format."],
      [error.component, error.message]
  end

  def test_each_messages_default_is_times_text
    assert_equal "Source value is out of range for the target type", E::ConversionRange.new.message
    assert_equal "The system's UTC offset could not be determined", E::IndeterminateOffset.new.message
    assert_equal "value was of a different variant than required", E::DifferentVariant.new.message
    assert_equal "day was not in range", E::Format::ComponentRange.new("day", true).message
    assert_equal "hour was not in range", E::TryFromParsed::ComponentRange.new("hour", false).message
    assert_equal "a character literal was not valid", E::ParseFromDescription::InvalidLiteral.new.message
    assert_equal "the 'x' component could not be parsed", E::ParseFromDescription::InvalidComponent.new("x").message
    assert_equal "unexpected trailing characters; the end of input was expected",
      E::ParseFromDescription::UnexpectedTrailingCharacters.new.message
    assert_equal "the `Parsed` struct did not include enough information to construct the type",
      E::TryFromParsed::InsufficientInformation.new.message
  end

  # time's InvalidFormatDescription Display (src/error/invalid_format_description.rs:105-161),
  # by variant, through version 3 descriptions and time's own error-display
  # cases (tests/integration/parse_format_description.rs:931-945).
  def test_each_invalid_format_description
    [
      [
        "[foo",
        E::InvalidFormatDescription::UnclosedOpeningBracket,
        "unclosed opening bracket at byte index 0",
        { index: 0 },
],
      [
        "[foo]",
        E::InvalidFormatDescription::InvalidComponentName,
        "invalid component name `foo` at byte index 1",
        { name: "foo", index: 1 },
],
      [
        "[day bar]",
        E::InvalidFormatDescription::InvalidModifier,
        "invalid modifier `bar` at byte index 5",
        { value: "bar", index: 5 },
],
      [
        "[]",
        E::InvalidFormatDescription::MissingComponentName,
        "missing component name at byte index 0",
        { index: 0 },
],
      [
        "[ignore]",
        E::InvalidFormatDescription::MissingRequiredModifier,
        "missing required modifier `count` for component at byte index 1",
        { name: "count", index: 1 },
],
      [
        "[optional]",
        E::InvalidFormatDescription::Expected,
        "expected nested format description at byte index 9",
        { what: "nested format description", index: 9 },
],
      [
        "[day padding:zero padding:zero]",
        E::InvalidFormatDescription::DuplicateModifier,
        "duplicate modifier `padding` at byte index 18",
        { name: "padding", index: 18 },
],
      [
        "[month repr:numerical case_sensitive:false]",
        E::InvalidFormatDescription::InvalidModifierCombination,
        "the `case_sensitive` modifier is not valid at byte index 22 for numerical month",
        { modifier: "case_sensitive", context: "for numerical month", index: 22 },
],
    ].each do |description, klass, message, fields|
      error = assert_raises(klass, description) { T::FormatDescription.parse_owned(3, description) }
      assert_equal message, error.message, description
      fields.each { |name, value| assert_equal value, error.public_send(name), "#{description} #{name}" }
    end
  end

  # NotSupported has no version 3 input that raises it; its Display has two
  # forms.
  def test_not_supported_reads_as_time_writes_it
    assert_equal "x is not supported at byte index 0",
      E::InvalidFormatDescription::NotSupported.new("x", "", 0).message
    assert_equal "x is not supported in y at byte index 3",
      E::InvalidFormatDescription::NotSupported.new("x", "y", 3).message
  end

  #--
  # SPDX-SnippetEnd
  #++

  # rescue Error catches all of them, and each variant is a subclass of
  # the enum it sits in, as Rust's matches! on the outer enum would match.
  def test_the_classes_nest_as_rust_nests_the_enums
    leaves = [
      E::Parse::ParseFromDescription::InvalidLiteral,
      E::Parse::ParseFromDescription::InvalidComponent,
      E::Parse::ParseFromDescription::UnexpectedTrailingCharacters,
      E::Parse::TryFromParsed::InsufficientInformation,
      E::Parse::TryFromParsed::ComponentRange,
    ]
    leaves.each do |leaf|
      assert_operator leaf, :<, E::Parse
      assert_operator leaf, :<, E
    end
    assert_operator E::Parse::TryFromParsed::ComponentRange, :<, E::Parse::TryFromParsed
    assert_operator E::Format::ComponentRange, :<, E::Format
    assert_operator E, :<, StandardError
    refute_operator E::Parse::TryFromParsed::ComponentRange, :<, E::ComponentRange
  end

  def test_a_wrong_version_is_refused
    error = assert_raises(ArgumentError) { T::FormatDescription.parse_owned(1, "[year]") }
    assert_includes error.message, "plan 007"
    assert_raises(ArgumentError) { T::FormatDescription.parse_borrowed(2, "[year]") }
    error = assert_raises(TypeError) { T::FormatDescription.parse_owned(4, "[year]") }
    assert_equal "invalid version provided", error.message
  end
end
