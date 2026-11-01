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
# SPDX-SnippetComment: the test cases of time 0.3.55
#   tests/integration/parse_format_description.rs
#++

# time's own tests in <tt>tests/integration/parse_format_description.rs</tt>,
# ported: each method is the Rust test of the same name, and each
# component test runs every modifier value of rstest's +modifiers+
# template (<tt>parse_format_description.rs:23-80</tt>). time's
# <tt>format_description!</tt> macro, version 1 by default, is
# FormatDescription.parse_borrowed(1, ...) here.
#
# time's tests run with every feature, +large-dates+ included; this gem
# builds without it (plan 007, decision 2), and then time's parser builds
# the standard-range year for <tt>[year]</tt> and for
# <tt>range:extended</tt> alike (<tt>src/format_description/parse/format_item.rs:496-600</tt>).
# Those cases expect the standard-range twin, which +STANDARD+ names.
class TestPortParseFormatDescription < Minitest::Test
  include TimeSuite

  FD = T::FormatDescription
  M = FD::Modifier
  C = FD::Component
  B = FD::BorrowedFormatItem
  O = FD::OwnedFormatItem
  IFD = T::Error::InvalidFormatDescription

  PADDING = [[M::Padding::Space, "padding:space"], [M::Padding::Zero, "padding:zero"], [M::Padding::None, "padding:none"]].freeze
  PERIOD_IS_UPPERCASE = [[true, "case:upper"], [false, "case:lower"]].freeze
  SUBSECOND_DIGITS = [
    [M::SubsecondDigits::One, "digits:1"],
    [M::SubsecondDigits::Two, "digits:2"],
    [M::SubsecondDigits::Three, "digits:3"],
    [M::SubsecondDigits::Four, "digits:4"],
    [M::SubsecondDigits::Five, "digits:5"],
    [M::SubsecondDigits::Six, "digits:6"],
    [M::SubsecondDigits::Seven, "digits:7"],
    [M::SubsecondDigits::Eight, "digits:8"],
    [M::SubsecondDigits::Nine, "digits:9"],
    [M::SubsecondDigits::OneOrMore, "digits:1+"],
  ].freeze
  SIGN_IS_MANDATORY = [[false, "sign:automatic"], [true, "sign:mandatory"]].freeze
  WEEKDAY_IS_ONE_INDEXED = [[true, "one_indexed:true"], [false, "one_indexed:false"]].freeze
  CASE_SENSITIVE = [[true, "case_sensitive:true"], [false, "case_sensitive:false"]].freeze
  IGNORE_COUNT = [1, 2, 3, 10, 100, 1_000].map { |count| [count, "count:#{count}"] }.freeze
  TRAILING_INPUT = [[M::TrailingInput::Prohibit, "trailing_input:prohibit"], [M::TrailingInput::Discard, "trailing_input:discard"]].freeze

  # The year component time's parser builds without +large-dates+ for
  # each extended-range one.
  STANDARD = {
    "CalendarYearFullExtendedRange" => "CalendarYearFullStandardRange",
    "IsoYearFullExtendedRange" => "IsoYearFullStandardRange",
    "CalendarYearCenturyExtendedRange" => "CalendarYearCenturyStandardRange",
    "IsoYearCenturyExtendedRange" => "IsoYearCenturyStandardRange",
  }.freeze

  # Rust's +parse_with_modifiers!+ (<tt>parse_format_description.rs:176-190</tt>):
  # asserts that every combination of +axes+, written after +name+,
  # parses with version 2 into the one component the block builds.
  private def assert_modifiers(name, *axes)
    combinations = axes.first.product(*axes.drop(1))
    combinations.each do |combination|
      description = "[#{name}#{combination.map { |(_, text)| " #{text}" }.join}]"
      expected = [B::Component.new(yield(*combination.map(&:first)))]
      assert_equal expected, FD.parse_borrowed(2, description), description
    end
  end

  # <tt>parse_format_description.rs:82</tt>, +empty+.
  def test_empty
    assert_equal [], FD.parse_borrowed(2, "")
    assert_equal O::Compound.new([]), FD.parse_owned(2, "")
  end

  # <tt>parse_format_description.rs:91</tt>, +only_literal+.
  def test_only_literal
    [
      ["foo bar", ["foo bar"]],
      ["  leading spaces", ["  leading spaces"]],
      ["trailing spaces  ", ["trailing spaces  "]],
      ["     ", ["     "]],
      ["[[", ["["]],
      ["foo[[bar", ["foo", "[", "bar"]],
    ].each do |description, expected|
      assert_equal expected.map { |text| B::StringLiteral.new(text) }, FD.parse_borrowed(1, description), description
    end
  end

  # <tt>parse_format_description.rs:108</tt>, +simple_component+.
  def test_simple_component
    [
      ["[day]", C::Day.new(M::Day.default)],
      ["[end]", C::End.new(M::End.default)],
      ["[hour]", C::Hour24.new(M::Hour24.default)],
      ["[minute]", C::Minute.new(M::Minute.default)],
      ["[month]", C::MonthNumerical.new(M::MonthNumerical.default)],
      ["[offset_hour]", C::OffsetHour.new(M::OffsetHour.default)],
      ["[offset_minute]", C::OffsetMinute.new(M::OffsetMinute.default)],
      ["[offset_second]", C::OffsetSecond.new(M::OffsetSecond.default)],
      ["[ordinal]", C::Ordinal.new(M::Ordinal.default)],
      ["[period]", C::Period.new(M::Period.default)],
      ["[second]", C::Second.new(M::Second.default)],
      ["[subsecond]", C::Subsecond.new(M::Subsecond.default)],
      ["[unix_timestamp]", C::UnixTimestampSecond.new(M::UnixTimestampSecond.default)],
      ["[weekday]", C::WeekdayLong.new(M::WeekdayLong.default)],
      ["[week_number]", C::WeekNumberIso.new(M::WeekNumberIso.default)],
      # Rust: CalendarYearFullExtendedRange, with large-dates.
      ["[year]", C::CalendarYearFullStandardRange.new(M::CalendarYearFullStandardRange.default)],
    ].each do |description, component|
      assert_equal [B::Component.new(component)], FD.parse_borrowed(2, description), description
    end
  end

  # <tt>parse_format_description.rs:138</tt>, +errors+, with version 3,
  # through both parsers.
  def test_errors
    [
      ["[ invalid ]", IFD::InvalidComponentName, { name: "invalid", index: 2 }],
      ["[", IFD::MissingComponentName, { index: 0 }],
      ["[ ", IFD::MissingComponentName, { index: 1 }],
      ["[]", IFD::MissingComponentName, { index: 0 }],
      ["[day sign:mandatory]", IFD::InvalidModifier, { value: "sign", index: 5 }],
      ["[day sign:]", IFD::InvalidModifier, { value: "", index: 9 }],
      ["[day :mandatory]", IFD::InvalidModifier, { value: "", index: 5 }],
      ["[day sign:mandatory", IFD::UnclosedOpeningBracket, { index: 0 }],
      ["[day padding:invalid]", IFD::InvalidModifier, { value: "invalid", index: 13 }],
      ["[ignore]", IFD::MissingRequiredModifier, { name: "count", index: 1 }],
      ["[ignore count:70000]", IFD::InvalidModifier, { value: "70000", index: 14 }],
    ].each do |description, klass, fields|
      %i[parse_borrowed parse_owned].each do |parser|
        error = assert_raises(klass, description) { FD.public_send(parser, 3, description) }
        fields.each { |name, value| assert_equal value, error.public_send(name), "#{description} #{name}" }
      end
    end
  end

  # <tt>parse_format_description.rs:192</tt>, +day_component+.
  def test_day_component
    assert_modifiers("day", PADDING) { |padding| C::Day.new(M::Day.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:202</tt>, +end_component+.
  def test_end_component
    assert_modifiers("end", TRAILING_INPUT) { |input| C::End.new(M::End.default.with_trailing_input(input)) }
  end

  # <tt>parse_format_description.rs:212</tt>, +minute_component+.
  def test_minute_component
    assert_modifiers("minute", PADDING) { |padding| C::Minute.new(M::Minute.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:222</tt>, +offset_minute_component+.
  def test_offset_minute_component
    assert_modifiers("offset_minute", PADDING) { |padding| C::OffsetMinute.new(M::OffsetMinute.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:232</tt>, +offset_second_component+.
  def test_offset_second_component
    assert_modifiers("offset_second", PADDING) { |padding| C::OffsetSecond.new(M::OffsetSecond.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:242</tt>, +ordinal_component+.
  def test_ordinal_component
    assert_modifiers("ordinal", PADDING) { |padding| C::Ordinal.new(M::Ordinal.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:252</tt>, +second_component+.
  def test_second_component
    assert_modifiers("second", PADDING) { |padding| C::Second.new(M::Second.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:262</tt>, +hour_12_component+.
  def test_hour_12_component
    assert_modifiers("hour repr:12", PADDING) { |padding| C::Hour12.new(M::Hour12.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:272</tt>, +hour_24_component+.
  def test_hour_24_component
    assert_modifiers("hour repr:24", PADDING) { |padding| C::Hour24.new(M::Hour24.default.with_padding(padding)) }
  end

  # <tt>parse_format_description.rs:282</tt>, +month_numerical_component+.
  def test_month_numerical_component
    assert_modifiers("month repr:numerical", PADDING) do |padding|
      C::MonthNumerical.new(M::MonthNumerical.default.with_padding(padding))
    end
  end

  # <tt>parse_format_description.rs:292</tt>, +month_short_component+.
  def test_month_short_component
    assert_modifiers("month repr:short", CASE_SENSITIVE) do |sensitive|
      C::MonthShort.new(M::MonthShort.default.with_case_sensitive(sensitive))
    end
  end

  # <tt>parse_format_description.rs:302</tt>, +month_long_component+.
  def test_month_long_component
    assert_modifiers("month repr:long", CASE_SENSITIVE) do |sensitive|
      C::MonthLong.new(M::MonthLong.default.with_case_sensitive(sensitive))
    end
  end

  # <tt>parse_format_description.rs:312</tt>, +period_component+.
  def test_period_component
    assert_modifiers("period", PERIOD_IS_UPPERCASE, CASE_SENSITIVE) do |uppercase, sensitive|
      C::Period.new(M::Period.default.with_is_uppercase(uppercase).with_case_sensitive(sensitive))
    end
  end

  # <tt>parse_format_description.rs:324</tt>, +weekday_short_component+.
  def test_weekday_short_component
    assert_modifiers("weekday repr:short", CASE_SENSITIVE) do |sensitive|
      C::WeekdayShort.new(M::WeekdayShort.default.with_case_sensitive(sensitive))
    end
  end

  # <tt>parse_format_description.rs:334</tt>, +weekday_long_component+.
  def test_weekday_long_component
    assert_modifiers("weekday repr:long", CASE_SENSITIVE) do |sensitive|
      C::WeekdayLong.new(M::WeekdayLong.default.with_case_sensitive(sensitive))
    end
  end

  # <tt>parse_format_description.rs:344</tt>, +weekday_sunday_component+.
  def test_weekday_sunday_component
    assert_modifiers("weekday repr:sunday", WEEKDAY_IS_ONE_INDEXED) do |one|
      C::WeekdaySunday.new(M::WeekdaySunday.default.with_one_indexed(one))
    end
  end

  # <tt>parse_format_description.rs:356</tt>, +weekday_monday_component+.
  def test_weekday_monday_component
    assert_modifiers("weekday repr:monday", WEEKDAY_IS_ONE_INDEXED) do |one|
      C::WeekdayMonday.new(M::WeekdayMonday.default.with_one_indexed(one))
    end
  end

  # <tt>parse_format_description.rs:368</tt>, +week_number_iso_component+.
  def test_week_number_iso_component
    assert_modifiers("week_number repr:iso", PADDING) do |padding|
      C::WeekNumberIso.new(M::WeekNumberIso.default.with_padding(padding))
    end
  end

  # <tt>parse_format_description.rs:378</tt>, +week_number_sunday_component+.
  def test_week_number_sunday_component
    assert_modifiers("week_number repr:sunday", PADDING) do |padding|
      C::WeekNumberSunday.new(M::WeekNumberSunday.default.with_padding(padding))
    end
  end

  # <tt>parse_format_description.rs:388</tt>, +week_number_monday_component+.
  def test_week_number_monday_component
    assert_modifiers("week_number repr:monday", PADDING) do |padding|
      C::WeekNumberMonday.new(M::WeekNumberMonday.default.with_padding(padding))
    end
  end

  # <tt>parse_format_description.rs:398</tt>, +offset_hour_component+.
  def test_offset_hour_component
    assert_modifiers("offset_hour", PADDING, SIGN_IS_MANDATORY) do |padding, sign|
      C::OffsetHour.new(M::OffsetHour.default.with_padding(padding).with_sign_is_mandatory(sign))
    end
  end

  # The eight year components with a sign (<tt>parse_format_description.rs:410-553</tt>).
  {
    calendar_year_full_extended_range: "year base:calendar repr:full range:extended",
    calendar_year_full_standard_range: "year base:calendar repr:full range:standard",
    iso_year_full_extended_range: "year base:iso_week repr:full range:extended",
    iso_year_full_standard_range: "year base:iso_week repr:full range:standard",
    calendar_year_century_extended_range: "year base:calendar repr:century range:extended",
    calendar_year_century_standard_range: "year base:calendar repr:century range:standard",
    iso_year_century_extended_range: "year base:iso_week repr:century range:extended",
    iso_year_century_standard_range: "year base:iso_week repr:century range:standard",
  }.each do |test, description|
    name = test.to_s.split("_").map(&:capitalize).join
    name = STANDARD.fetch(name, name)
    define_method(:"test_#{test}_component") do
      assert_modifiers(description, PADDING, SIGN_IS_MANDATORY) do |padding, sign|
        C.const_get(name).new(M.const_get(name).default.with_padding(padding).with_sign_is_mandatory(sign))
      end
    end
  end

  # <tt>parse_format_description.rs:554</tt>, +calendar_year_last_two_component+.
  def test_calendar_year_last_two_component
    assert_modifiers("year base:calendar repr:last_two", PADDING) do |padding|
      C::CalendarYearLastTwo.new(M::CalendarYearLastTwo.default.with_padding(padding))
    end
  end

  # <tt>parse_format_description.rs:564</tt>, +iso_year_last_two_component+.
  def test_iso_year_last_two_component
    assert_modifiers("year base:iso_week repr:last_two", PADDING) do |padding|
      C::IsoYearLastTwo.new(M::IsoYearLastTwo.default.with_padding(padding))
    end
  end

  # The four Unix timestamp components (<tt>parse_format_description.rs:574-621</tt>).
  %w[second millisecond microsecond nanosecond].each do |precision|
    name = "UnixTimestamp#{precision.capitalize}"
    define_method(:"test_unix_timestamp_#{precision}_component") do
      assert_modifiers("unix_timestamp precision:#{precision}", SIGN_IS_MANDATORY) do |sign|
        C.const_get(name).new(M.const_get(name).default.with_sign_is_mandatory(sign))
      end
    end
  end

  # <tt>parse_format_description.rs:622</tt>, +subsecond_component+.
  def test_subsecond_component
    assert_modifiers("subsecond", SUBSECOND_DIGITS) { |digits| C::Subsecond.new(M::Subsecond.default.with_digits(digits)) }
  end

  # <tt>parse_format_description.rs:632</tt>, +ignore_component+.
  def test_ignore_component
    assert_modifiers("ignore", IGNORE_COUNT) { |count| C::Ignore.new(M::Ignore.count(count)) }
  end

  private def year
    # Rust: CalendarYearFullExtendedRange, with large-dates.
    O::Component.new(C::CalendarYearFullStandardRange.new(M::CalendarYearFullStandardRange.default))
  end

  # <tt>parse_format_description.rs:642</tt>, +optional+.
  def test_optional
    [
      ["[optional [:[year]]]", O::Optional.new(O::Compound.new([O::StringLiteral.new(":"), year]))],
      ["[optional [[year]]]", O::Optional.new(year)],
      ['[optional [\[]]', O::Optional.new(O::StringLiteral.new("["))],
      ['[optional [ \[ ]]', O::Optional.new(O::Compound.new([" ", "[", " "].map { |text| O::StringLiteral.new(text) }))],
    ].each do |description, expected|
      assert_equal expected, FD.parse_owned(2, description), description
    end
  end

  private def period(uppercase)
    O::Component.new(C::Period.new(M::Period.default.with_is_uppercase(uppercase).with_case_sensitive(true)))
  end

  # <tt>parse_format_description.rs:681</tt>, +first+.
  def test_first
    literal = -> (text) { O::StringLiteral.new(text) }
    [
      ["[first [a]]", O::First.new([literal["a"]])],
      ["[first [a] [b]]", O::First.new([literal["a"], literal["b"]])],
      ["[first [a] [b] ]", O::First.new([literal["a"], literal["b"]])],
      ['[first [a][\[]]', O::First.new([literal["a"], literal["["]])],
      ['[first [a][\[\[]]', O::First.new([literal["a"], O::Compound.new([literal["["], literal["["]])])],
      ["[first [[period case:upper]] [[period case:lower]] ]", O::First.new([period(true), period(false)])],
    ].each do |description, expected|
      assert_equal expected, FD.parse_owned(2, description), description
    end
  end

  # <tt>parse_format_description.rs:741</tt>, +first_v1+.
  def test_first_v1
    assert_equal O::First.new([period(true), period(false)]),
      FD.parse_owned(1, "[first [[period case:upper]] [[period case:lower]] ]")
  end

  # <tt>parse_format_description.rs:764</tt>, +backslash_escape+.
  def test_backslash_escape
    assert_equal O::Optional.new(O::StringLiteral.new("]")), FD.parse_owned(2, '[optional [\]]]')
    assert_equal O::Optional.new(O::StringLiteral.new("[")), FD.parse_owned(2, '[optional [\[]]')
    assert_equal O::Optional.new(O::StringLiteral.new("\\")), FD.parse_owned(2, '[optional [\\\\]]')
    assert_equal O::StringLiteral.new("\\"), FD.parse_owned(2, "\\\\")
    assert_equal O::StringLiteral.new("["), FD.parse_owned(2, '\[')
    assert_equal O::StringLiteral.new("]"), FD.parse_owned(2, '\]')
    assert_equal O::Compound.new([O::StringLiteral.new("foo"), O::StringLiteral.new("\\")]), FD.parse_owned(2, "foo\\\\")
    assert_equal [B::StringLiteral.new("\\")], FD.parse_borrowed(2, "\\\\")
    assert_equal [B::StringLiteral.new("[")], FD.parse_borrowed(2, '\[')
    assert_equal [B::StringLiteral.new("]")], FD.parse_borrowed(2, '\]')
    assert_equal [B::StringLiteral.new("foo"), B::StringLiteral.new("\\")], FD.parse_borrowed(2, "foo\\\\")
  end

  # <tt>parse_format_description.rs:824</tt>, +backslash_escape_error+.
  def test_backslash_escape_error
    [['\a', 1], ["\\", 0]].each do |description, index|
      %i[parse_owned parse_borrowed].each do |parser|
        error = assert_raises(IFD::Expected) { FD.public_send(parser, 2, description) }
        assert_equal "valid escape sequence", error.what
        assert_equal index, error.index
      end
    end
  end

  # <tt>parse_format_description.rs:846</tt>, +nested_v2_error_missing_component_name+.
  def test_nested_v2_error_missing_component_name
    [["[]", 0], ["[   ]", 1]].each do |description, index|
      error = assert_raises(IFD::MissingComponentName) { FD.parse_owned(2, description) }
      assert_equal index, error.index
    end
  end

  # <tt>parse_format_description.rs:859</tt>, +nested_v2_error_unclosed+.
  def test_nested_v2_error_unclosed
    ["[first [a][[[]]", "[optional []", "[first []", "[optional [", "[optional [[year", "[a[", "[hour["].each do |description|
      error = assert_raises(IFD::UnclosedOpeningBracket, description) { FD.parse_owned(2, description) }
      assert_equal 0, error.index
    end
  end

  # <tt>parse_format_description.rs:878</tt>, +nested_v1_error_not_supported+.
  def test_nested_v1_error_not_supported
    [["[optional []]", "optional item"], ["[first []]", "'first' item"]].each do |description, what|
      error = assert_raises(IFD::NotSupported) { FD.parse_borrowed(1, description) }
      assert_equal what, error.what
      assert_equal "runtime-parsed format descriptions", error.context
      assert_equal 0, error.index
    end
  end

  # <tt>parse_format_description.rs:901</tt>, +nested_v2_error_invalid_modifier+.
  def test_nested_v2_error_invalid_modifier
    error = assert_raises(IFD::InvalidModifier) { FD.parse_owned(2, "[year foo]") }
    assert_equal "foo", error.value
    assert_equal 6, error.index
  end

  # <tt>parse_format_description.rs:915</tt>, +nested_v2_error_expected+.
  def test_nested_v2_error_expected
    [
      ["[optional[]]", "whitespace before nested format description", 9],
      ["[first[]]", "whitespace before nested format description", 6],
      ["[optional]", "nested format description", 9],
    ].each do |description, what, index|
      error = assert_raises(IFD::Expected) { FD.parse_owned(2, description) }
      assert_equal what, error.what
      assert_equal index, error.index
    end
  end

  # <tt>parse_format_description.rs:931</tt>, +error_display+.
  def test_error_display
    [
      ["[", "missing component name at byte index 0"],
      ["[foo", "unclosed opening bracket at byte index 0"],
      ["[foo]", "invalid component name `foo` at byte index 1"],
      ["[day bar]", "invalid modifier `bar` at byte index 5"],
      ["[]", "missing component name at byte index 0"],
      ["[optional []]", "optional item is not supported in runtime-parsed format descriptions at byte index 0"],
      ["[ignore]", "missing required modifier `count` for component at byte index 1"],
    ].each do |description, message|
      error = assert_raises(IFD) { FD.parse_borrowed(1, description) }
      assert_equal message, error.message
    end
  end

  # <tt>parse_format_description.rs:960</tt>, +error_display_owned+.
  def test_error_display_owned
    error = assert_raises(IFD) { FD.parse_owned(2, "[optional ") }
    assert_equal "unclosed opening bracket at byte index 0", error.message
  end

  # <tt>parse_format_description.rs:977</tt>, +rfc_3339+.
  def test_rfc_3339
    component = -> (component) { B::Component.new(component) }
    literal = -> (text) { B::StringLiteral.new(text) }
    expected = [
      # Rust: CalendarYearFullExtendedRange, with large-dates.
      component[C::CalendarYearFullStandardRange.new(M::CalendarYearFullStandardRange.default.with_padding(M::Padding::Zero).with_sign_is_mandatory(false))],
      literal["-"],
      component[C::MonthNumerical.new(M::MonthNumerical.default.with_padding(M::Padding::Zero))],
      literal["-"],
      component[C::Day.new(M::Day.default.with_padding(M::Padding::Zero))],
      literal["T"],
      component[C::Hour24.new(M::Hour24.default.with_padding(M::Padding::Zero))],
      literal[":"],
      component[C::Minute.new(M::Minute.default.with_padding(M::Padding::Zero))],
      literal[":"],
      component[C::Second.new(M::Second.default.with_padding(M::Padding::Zero))],
      literal["."],
      component[C::Subsecond.new(M::Subsecond.default.with_digits(M::SubsecondDigits::OneOrMore))],
      component[C::OffsetHour.new(M::OffsetHour.default.with_padding(M::Padding::Zero).with_sign_is_mandatory(true))],
      literal[":"],
      component[C::OffsetMinute.new(M::OffsetMinute.default.with_padding(M::Padding::Zero))],
    ]
    assert_equal expected, FD.parse_borrowed(2, "[year]-[month repr:numerical]-[day]T[hour]:[minute]:[second].[subsecond][offset_hour sign:mandatory]:[offset_minute]")
  end

  # <tt>parse_format_description.rs:1027</tt>, +strftime_equivalence+.
  def test_strftime_equivalence
    [
      ["foo", "foo"],
      ["%a", "[weekday repr:short]"],
      ["%A", "[weekday]"],
      ["%b", "[month repr:short]"],
      ["%B", "[month repr:long]"],
      ["%C", "[year repr:century]"],
      ["%d", "[day]"],
      ["%e", "[day padding:space]"],
      ["%g", "[year repr:last_two base:iso_week]"],
      ["%G", "[year base:iso_week]"],
      ["%h", "[month repr:short]"],
      ["%H", "[hour]"],
      ["%I", "[hour repr:12]"],
      ["%j", "[ordinal]"],
      ["%k", "[hour padding:space]"],
      ["%l", "[hour repr:12 padding:space]"],
      ["%m", "[month]"],
      ["%M", "[minute]"],
      ["%n", "\n"],
      ["%p", "[period]"],
      ["%P", "[period case:lower]"],
      ["%s", "[unix_timestamp]"],
      ["%S", "[second]"],
      ["%t", "\t"],
      ["%u", "[weekday repr:monday]"],
      ["%U", "[week_number repr:sunday]"],
      ["%V", "[week_number]"],
      ["%w", "[weekday repr:sunday]"],
      ["%W", "[week_number repr:monday]"],
      ["%y", "[year repr:last_two]"],
      ["%Y", "[year]"],
      ["%%", "%"],
    ].each do |strftime, custom|
      custom = FD.parse_borrowed(1, custom)
      assert_equal custom, FD.parse_strftime_borrowed(strftime), strftime
      assert_equal O.from(custom), FD.parse_strftime_owned(strftime), strftime
    end
  end

  # <tt>parse_format_description.rs:1073</tt>, +strftime_compound_equivalence+.
  def test_strftime_compound_equivalence
    [
      ["%c", "[weekday repr:short] [month repr:short] [day padding:space] [hour]:[minute]:[second] [year]"],
      ["%D", "[month]/[day]/[year repr:last_two]"],
      ["%F", "[year]-[month repr:numerical]-[day]"],
      ["%r", "[hour repr:12]:[minute]:[second] [period]"],
      ["%R", "[hour]:[minute]"],
      ["%T", "[hour]:[minute]:[second]"],
      ["%x", "[month]/[day]/[year repr:last_two]"],
      ["%X", "[hour]:[minute]:[second]"],
      ["%z", "[offset_hour sign:mandatory][offset_minute]"],
    ].each do |strftime, custom|
      custom = [B::Compound.new(FD.parse_borrowed(2, custom))]
      assert_equal custom, FD.parse_strftime_borrowed(strftime), strftime
      assert_equal O.from(custom), FD.parse_strftime_owned(strftime), strftime
    end
  end

  # <tt>parse_format_description.rs:1101</tt>, +strftime_padding_missing_component+.
  def test_strftime_padding_missing_component
    ["%_", "%-", "%0"].each do |strftime|
      error = assert_raises(IFD::Expected, strftime) { FD.parse_strftime_borrowed(strftime) }
      assert_equal "valid escape sequence", error.what
      assert_equal 2, error.index
    end
  end
end

#--
# SPDX-SnippetEnd
#++
