# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Ruby side of the format-item tree (plan 009): what Rust's type
# checker and visibility give a Rust caller, the deprecated items left
# unbound, the conversions
# time's tests leave out, and the nesting limit.
class TestFormatItems < Minitest::Test
  include TimeSuite

  FD = T::FormatDescription
  M = FD::Modifier
  C = FD::Component
  B = FD::BorrowedFormatItem
  O = FD::OwnedFormatItem

  def test_modifiers_are_built_only_from_their_defaults
    assert_raises(NoMethodError) { M::Day.new(padding: M::Padding::Zero) }
    assert_raises(NoMethodError) { M::Padding.new(0, :Zero) }
    assert_equal M::Padding::Zero, M::Day.default.padding
    assert_same M::Day.default, M::Day.default
    assert_equal M::Day.default, M::Day.default.with_padding(M::Padding::Space).with_padding(M::Padding::Zero)
    refute_equal M::Day.default, M::Day.default.with_padding(M::Padding::Space)
    assert_predicate M::Day.default.with_padding(M::Padding::None), :frozen?
  end

  def test_each_enum_has_times_default
    assert_same M::Padding::Zero, M::Padding.default
    assert_same M::SubsecondDigits::OneOrMore, M::SubsecondDigits.default
    assert_same M::TrailingInput::Prohibit, M::TrailingInput.default
    assert_equal "None", M::Padding::None.debug
    assert_equal "OneOrMore", M::SubsecondDigits::OneOrMore.debug
  end

  # TrailingInput alone of the modifier enums is exhaustive, so Rust may
  # cast it (modifier.rs:1145-1152); to_i answers that cast (ADR 001,
  # 2026-11-05). The non_exhaustive ones have none.
  def test_trailing_input_answers_rusts_cast_and_the_others_none
    assert_equal [0, 1], [M::TrailingInput::Prohibit, M::TrailingInput::Discard].map(&:to_i)
    refute_respond_to M::Padding::Zero, :to_i
    refute_respond_to M::SubsecondDigits::One, :to_i
  end

  def test_fields_time_keeps_to_itself_have_private_readers
    assert_respond_to M::Day.default, :padding
    assert_respond_to M::OffsetHour.default, :sign_is_mandatory
    refute_respond_to M::MonthShort.default, :case_sensitive
    refute_respond_to M::CalendarYearFullStandardRange.default, :padding
    refute_respond_to M::End.default, :trailing_input
    assert_equal "MonthShort { case_sensitive: false }", M::MonthShort.default.with_case_sensitive(false).debug
  end

  def test_builders_check_their_arguments_types
    error = assert_raises(TypeError) { M::Day.default.with_padding(:space) }
    assert_equal "no implicit conversion of Symbol into Ferro::Time::FormatDescription::Modifier::Padding", error.message
    assert_raises(TypeError) { M::Day.default.with_padding(M::SubsecondDigits::One) }
    error = assert_raises(TypeError) { M::Period.default.with_is_uppercase(nil) }
    assert_equal "no implicit conversion of NilClass into true or false", error.message
    assert_raises(TypeError) { M::Ignore.count("2") }
    error = assert_raises(RangeError) { M::Ignore.count(0) }
    assert_equal "integer 0 too small to convert into `NonZero<u16>`", error.message
    error = assert_raises(RangeError) { M::Ignore.count(65_536) }
    assert_equal "integer 65536 too big to convert into `NonZero<u16>`", error.message
    assert_equal 65_535, M::Ignore.count(65_535).count
  end

  def test_constructors_check_their_fields_types
    day = C::Day.new(M::Day.default)
    error = assert_raises(TypeError) { C::Day.new(M::Minute.default) }
    assert_equal "no implicit conversion of Ferro::Time::FormatDescription::Modifier::Minute into " \
      "Ferro::Time::FormatDescription::Modifier::Day", error.message
    assert_raises(TypeError) { B::Component.new(M::Day.default) }
    assert_raises(TypeError) { B::StringLiteral.new(:x) }
    assert_raises(EncodingError) { B::StringLiteral.new("\xFF".b) }
    assert_raises(TypeError) { B::Compound.new([O::StringLiteral.new("x")]) }
    assert_raises(TypeError) { O::Optional.new(B::Component.new(day)) }
    assert_raises(TypeError) { B::First.new(B::StringLiteral.new("x")) }
  end

  # Every item and component variant is a tuple variant in Rust, so its one
  # field is positional: deconstruct and to_a give it, and no reader names
  # it (ADR 001, amendment of 2026-11-05; plan 007, Follow-up: the four
  # rulings).
  def test_a_variants_field_is_positional
    day = C::Day.new(M::Day.default)
    literal = B::StringLiteral.new("-")
    owned = O::StringLiteral.new("-")
    [
      [literal, "-"],
      [B::Component.new(day), day],
      [B::Compound.new([literal]), [literal]],
      [B::Optional.new(literal), literal],
      [B::First.new([literal]), [literal]],
      [owned, "-"],
      [O::Component.new(day), day],
      [O::Compound.new([]), []],
      [O::Optional.new(owned), owned],
      [O::First.new([owned]), [owned]],
      [day, M::Day.default],
    ].each do |variant, field|
      assert_equal [field], variant.deconstruct, variant.class.name
      assert_equal [field], variant.to_a, variant.class.name
      %i[literal component compound item items modifier to_h deconstruct_keys with].each do |name|
        refute_respond_to variant, name, "#{variant.class}##{name}"
      end
    end
  end

  def test_a_variant_takes_its_field_by_position_only
    assert_raises(TypeError) { B::StringLiteral.new(literal: "-") }
    assert_raises(TypeError) { C::Day.new(modifier: M::Day.default) }
    assert_raises(ArgumentError) { C::Day.new }
    assert_raises(ArgumentError) { O::First.new([], []) }
  end

  def test_a_pattern_reads_as_rusts_does
    matched = case FD.parse_owned(2, "[year]-[month]")
    in O::Compound[[O::Component[C::CalendarYearFullStandardRange[year]], O::StringLiteral["-"], *]] then year
    end
    assert_equal M::CalendarYearFullStandardRange.default, matched
  end

  def test_a_variant_is_a_frozen_value
    literal = B::StringLiteral.new("-")
    same = B::StringLiteral.new(+"-")
    assert_equal literal, same
    assert literal.eql?(same), "eql?"
    assert_equal literal.hash, same.hash
    refute_equal literal, O::StringLiteral.new("-")
    refute literal.eql?(B::Optional.new(literal)), "another variant"
    assert_equal 1, { C::Day.new(M::Day.default) => 1 }[C::Day.new(M::Day.default)]
    [literal.dup, literal.clone, literal.clone(freeze: false)].each do |copy|
      assert_predicate copy, :frozen?
      assert_equal literal, copy
    end
    assert Ractor.shareable?(B::First.new([B::Compound.new([literal])])), "deeply frozen"
  end

  def test_items_hold_frozen_shareable_copies
    text = +"abc"
    literal = B::StringLiteral.new(text)
    text << "d"
    assert_equal ["abc"], literal.to_a
    assert_predicate literal.to_a.first, :frozen?
    assert_equal Encoding::UTF_8, B::StringLiteral.new("abc".b).to_a.first.encoding
    items = [literal]
    compound = B::Compound.new(items)
    items << literal
    assert_equal 1, compound.to_a.first.length
    assert_predicate compound.to_a.first, :frozen?
    parsed = FD.parse_owned(2, "[optional [[year]-[month]]] [first [a] [[day]]]")
    assert Ractor.shareable?(parsed), "a parsed tree is deeply frozen"
    borrowed = FD.parse_borrowed(2, "[year]-[month]")
    refute_predicate borrowed, :frozen?, "the Array is the caller's, as Rust's Vec is"
    assert(borrowed.all? { |item| Ractor.shareable?(item) })
  end

  # time's deprecated items are no part of the gem's API (ADR 001,
  # amendment of 2026-11-05), so none is bound (plan 007, Follow-up: the
  # four rulings).
  def test_times_deprecated_items_are_unbound
    refute_respond_to FD, :parse
    refute_respond_to T::Util, :days_in_year_month
    refute T.const_defined?(:Convert, false), "Convert"
    refute FD.const_defined?(:FormatItem, false), "FormatItem"
    refute B.const_defined?(:Literal, false), "BorrowedFormatItem::Literal"
    refute O.const_defined?(:Literal, false), "OwnedFormatItem::Literal"
    %i[Month Weekday WeekNumber Hour UnixTimestamp Year].each do |name|
      refute C.const_defined?(name, false), "Component::#{name}"
    end
    modifiers = %i[MonthRepr Month WeekdayRepr Weekday WeekNumberRepr WeekNumber YearRepr YearRange Year Hour]
    (modifiers + %i[UnixTimestampPrecision UnixTimestamp]).each do |name|
      refute M.const_defined?(name, false), "Modifier::#{name}"
    end
  end

  # time's parsers lower the old component names to the new components
  # (format_description/parse/format_item.rs:326-604) and make
  # StringLiteral, never Literal, so nothing the gem returns needs a
  # deprecated item.
  def test_times_parsers_return_no_deprecated_item
    description = "[hour] [hour repr:12] [month] [month repr:long] [weekday] [week_number] [year] " \
      "[year repr:last_two] [unix_timestamp precision:millisecond]"
    [1, 2].each do |version|
      assert_equal "[Hour24(Hour24 { padding: Zero }),  , Hour12(Hour12 { padding: Zero }),  , " \
        "MonthNumerical(MonthNumerical { padding: Zero }),  , MonthLong(MonthLong { case_sensitive: true }),  , " \
        "WeekdayLong(WeekdayLong { case_sensitive: true }),  , WeekNumberIso(WeekNumberIso { padding: Zero }),  , " \
        "CalendarYearFullStandardRange(CalendarYearFullStandardRange { padding: Zero, sign_is_mandatory: false }),  , " \
        "CalendarYearLastTwo(CalendarYearLastTwo { padding: Zero }),  , " \
        "UnixTimestampMillisecond(UnixTimestampMillisecond { sign_is_mandatory: false })]",
        FD.parse_owned(version, description).debug, "version #{version}"
    end
    assert_equal [B::StringLiteral] * 2, FD.parse_borrowed(1, "a[day]b").values_at(0, 2).map(&:class)
    assert_equal [B::StringLiteral] * 2, FD.parse_strftime_borrowed("a%db").values_at(0, 2).map(&:class)
  end

  def test_borrowed_and_owned_items_never_compare_equal
    refute_equal B::StringLiteral.new("a"), O::StringLiteral.new("a")
    refute_equal O.from(B::StringLiteral.new("a")), B::StringLiteral.new("a")
    day = C::Day.new(M::Day.default)
    refute_equal B::Component.new(day), O::Component.new(day)
    refute_equal [B::Component.new(day)], B::Compound.new([B::Component.new(day)]), "Array#== is Ruby's"
  end

  def test_conversions_refuse_what_rust_would_not_compile
    day = C::Day.new(M::Day.default)
    assert_raises(TypeError) { B.from("x") }
    assert_raises(TypeError) { O.from(:x) }
    assert_raises(TypeError) { O.from([B::StringLiteral.new("a"), O::StringLiteral.new("b")]) }
    assert_raises(TypeError) { C.try_from(day) }
    assert_equal O::Compound.new([]), O.from([])
    assert_equal O::Compound.new([O::Component.new(day)]), O.from([B::Component.new(day)])
    nested = B::Optional.new(B::First.new([B::Compound.new([B::Component.new(day)])]))
    assert_equal O::Optional.new(O::First.new([O::Compound.new([O::Component.new(day)])])), O.from(nested)
  end

  def test_an_item_or_an_array_of_items_is_a_description
    fd = FD.parse_borrowed(2, "[year]-[month]-[day]")
    date = T::Date.from_calendar_date(2026, Month::October, 31)
    assert_equal "2026-10-31", date.format(fd)
    assert_equal date, T::Date.parse("2026-10-31", fd)
    owned = O.from(fd)
    assert_equal "2026-10-31", date.format(owned)
    assert_equal date, T::Date.parse("2026-10-31", owned)
    assert_equal date, T::Date.parse("2026-10-31", owned.to_a.first)
    assert_equal "", date.format([])
    assert_raises(TypeError) { date.format([fd.first, owned]) }
    assert_raises(TypeError) { date.format([1]) }
  end

  def test_parse_errors_with_items_are_times
    fd = FD.parse_borrowed(2, "[year]-[month]")
    error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::Date.parse("2026-13", fd) }
    assert_equal "month", error.to_a.first.to_a.first
    assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) { T::Date.parse("2026-10", fd) }
  end

  def test_a_tree_nested_past_times_parser_limit_is_refused
    item = B::StringLiteral.new("x")
    255.times { item = B::Optional.new(item) }
    assert_equal "x", T::Date::MIN.format(item)
    item = B::Optional.new(item)
    error = assert_raises(ArgumentError) { T::Date::MIN.format(item) }
    assert_equal "format items nested more than 255 levels deep", error.message
    assert_raises(ArgumentError) { item.debug }
  end

  def test_component_debug_is_times_debug
    assert_equal "Ignore(Ignore { count: 3 })", C::Ignore.new(M::Ignore.count(3)).debug
    assert_equal "[Day(Day { padding: Zero }), -, Optional(First([a, [b, c]]))]",
      O.from(
        [
          B::Component.new(C::Day.new(M::Day.default)),
          B::StringLiteral.new("-"),
          B::Optional.new(B::First.new([B::StringLiteral.new("a"), B::Compound.new([B::StringLiteral.new("b"), B::StringLiteral.new("c")])])),
        ]
      ).debug
  end
end
