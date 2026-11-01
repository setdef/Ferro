# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Ruby side of the format-item tree (plan 009): what Rust's type
# checker and visibility give a Rust caller, deprecations, the conversions
# time's tests leave out, and the nesting limit.
class TestFormatItems < Minitest::Test
  include TimeSuite

  FD = T::FormatDescription
  M = FD::Modifier
  C = FD::Component
  B = FD::BorrowedFormatItem
  O = FD::OwnedFormatItem

  # The warnings +block+ prints with Ruby's deprecation warnings on.
  private def deprecation_warnings(&)
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    _, err = capture_io(&)
    err
  ensure
    Warning[:deprecated] = deprecated
  end

  # The block's value, with Ruby's deprecation warnings off.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

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
    assert_equal "Ferro::Time::FormatDescription::Modifier::Padding::None", M::Padding::None.inspect
  end

  def test_fields_time_keeps_to_itself_have_private_readers
    assert_respond_to M::Day.default, :padding
    assert_respond_to M::OffsetHour.default, :sign_is_mandatory
    refute_respond_to M::MonthShort.default, :case_sensitive
    refute_respond_to M::CalendarYearFullStandardRange.default, :padding
    refute_respond_to M::End.default, :trailing_input
    assert_equal "MonthShort { case_sensitive: false }", M::MonthShort.default.with_case_sensitive(false).inspect
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
    assert_raises(TypeError) { B::Component.new(day).with(component: 1) }
  end

  def test_items_hold_frozen_shareable_copies
    text = +"abc"
    literal = B::StringLiteral.new(text)
    text << "d"
    assert_equal "abc", literal.literal
    assert_predicate literal.literal, :frozen?
    assert_equal Encoding::UTF_8, B::StringLiteral.new("abc".b).literal.encoding
    items = [literal]
    compound = B::Compound.new(items)
    items << literal
    assert_equal 1, compound.compound.length
    assert_predicate compound.compound, :frozen?
    parsed = FD.parse_owned(2, "[optional [[year]-[month]]] [first [a] [[day]]]")
    assert Ractor.shareable?(parsed), "a parsed tree is deeply frozen"
    borrowed = FD.parse_borrowed(2, "[year]-[month]")
    refute_predicate borrowed, :frozen?, "the Array is the caller's, as Rust's Vec is"
    assert(borrowed.all? { |item| Ractor.shareable?(item) })
  end

  def test_deprecated_types_warn_where_they_are_named
    assert_match(/constant Ferro::Time::FormatDescription::Modifier::Month is deprecated/, deprecation_warnings { M::Month })
    assert_match(/Modifier::YearRepr is deprecated/, deprecation_warnings { M::YearRepr })
    assert_match(/Component::Hour is deprecated/, deprecation_warnings { C::Hour })
    assert_match(/BorrowedFormatItem::Literal is deprecated/, deprecation_warnings { B::Literal })
    assert_match(/OwnedFormatItem::Literal is deprecated/, deprecation_warnings { O::Literal })
    assert_match(/FormatDescription::FormatItem is deprecated/, deprecation_warnings { FD::FormatItem })
    assert_match(/FormatDescription.parse is deprecated since time 0.3.48/, deprecation_warnings { FD.parse("[day]") })
    assert_empty deprecation_warnings { M::Day.default.with_padding(M::Padding::Space) }
    assert_empty deprecation_warnings { FD.parse_owned(1, "[year] [month repr:short]").inspect }
  end

  def test_the_deprecated_parse_is_version_1
    assert_equal FD.parse_borrowed(1, "[[[day]"), quietly { FD.parse("[[[day]") }
  end

  def test_deprecated_components_format_as_time_converts_them
    date = T::Date.from_calendar_date(2021, Month::February, 3)
    quietly do
      month = C::Month.new(M::Month.default.with_repr(M::MonthRepr::Long))
      assert_equal "February", date.format(B::Component.new(month))
      year = C::Year.new(M::Year.default.with_repr(M::YearRepr::LastTwo).with_iso_week_based(true))
      assert_equal "21", date.format(O::Component.new(year))
      weekday = C::Weekday.new(M::Weekday.default.with_repr(M::WeekdayRepr::Monday).with_one_indexed(false))
      assert_equal "2", date.format(B::Component.new(weekday))
      hour = C::Hour.new(M::Hour.default.with_is_12_hour_clock(true).with_padding(M::Padding::None))
      assert_equal "1", T::Time.from_hms(13, 0, 0).format(B::Component.new(hour))
      stamp = C::UnixTimestamp.new(M::UnixTimestamp.default.with_precision(M::UnixTimestampPrecision::Millisecond))
      assert_equal "1000", T::OffsetDateTime::UNIX_EPOCH.replace_second(1).format(B::Component.new(stamp))
      week = C::WeekNumber.new(M::WeekNumber.default.with_repr(M::WeekNumberRepr::Sunday))
      assert_equal "05", date.format(B::Component.new(week))
      assert_equal "Year(Year { padding: Zero, repr: LastTwo, range: Extended, iso_week_based: true, sign_is_mandatory: false })",
        year.inspect
    end
  end

  def test_a_literal_of_bytes_equals_the_text_of_the_same_bytes
    quietly do
      assert_equal B::StringLiteral.new("ab"), B::Literal.new("ab")
      assert_equal B::Literal.new("ab"), B::StringLiteral.new("ab")
      assert_equal O::Literal.new("é"), O::StringLiteral.new("é")
      refute_equal B::Literal.new("ab"), O::StringLiteral.new("ab")
      refute B::Literal.new("ab").eql?(B::StringLiteral.new("ab")), "eql? stays strict"
      assert_equal Encoding::BINARY, B::Literal.new("ab").literal.encoding
    end
  end

  def test_a_literal_that_is_not_utf8_formats_as_time_replaces_it
    quietly do
      literal = O::Literal.new("a\xFFb".b)
      assert_equal "a\u{FFFD}b", T::Date::MIN.format(literal)
      assert_equal "a\u{FFFD}b", literal.inspect
      out = +""
      T::Date::MIN.format_into(out, literal)
      assert_equal "a\xFFb".b, out.b
      assert_equal O::Literal.new("a\xFFb".b), O.from(B::Literal.new("a\xFFb".b))
    end
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
    assert_equal date, T::Date.parse("2026-10-31", owned.compound)
    assert_equal "", date.format([])
    assert_raises(TypeError) { date.format([fd.first, owned]) }
    assert_raises(TypeError) { date.format([1]) }
  end

  def test_parse_errors_with_items_are_times
    fd = FD.parse_borrowed(2, "[year]-[month]")
    error = assert_raises(T::Error::Parse::ParseFromDescription::InvalidComponent) { T::Date.parse("2026-13", fd) }
    assert_equal "month", error.name
    assert_raises(T::Error::Parse::TryFromParsed::InsufficientInformation) { T::Date.parse("2026-10", fd) }
  end

  def test_a_tree_nested_past_times_parser_limit_is_refused
    item = B::StringLiteral.new("x")
    255.times { item = B::Optional.new(item) }
    assert_equal "x", T::Date::MIN.format(item)
    item = B::Optional.new(item)
    error = assert_raises(ArgumentError) { T::Date::MIN.format(item) }
    assert_equal "format items nested more than 255 levels deep", error.message
    assert_raises(ArgumentError) { item.inspect }
  end

  def test_component_inspect_is_times_debug
    assert_equal "Ignore(Ignore { count: 3 })", C::Ignore.new(M::Ignore.count(3)).inspect
    assert_equal "[Day(Day { padding: Zero }), -, Optional(First([a, [b, c]]))]",
      O.from(
        [
          B::Component.new(C::Day.new(M::Day.default)),
          B::StringLiteral.new("-"),
          B::Optional.new(B::First.new([B::StringLiteral.new("a"), B::Compound.new([B::StringLiteral.new("b"), B::StringLiteral.new("c")])])),
        ]
      ).inspect
  end
end
