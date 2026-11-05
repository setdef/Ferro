# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: Jacob Pratt et al.
    # SPDX-SnippetComment: Parsed, its methods, and their docs from time 0.3.55
    #   src/parsing/parsed.rs and src/parsing/mod.rs
    #++

    # Parsing for various types.
    #
    # Mirrors time's +parsing+ module (<tt>src/parsing/mod.rs</tt>). Its
    # sealed +Parsable+ trait is the set of descriptions +parse+ takes
    # (plan 007, decision 11); Parsed is the rest.
    module Parsing
      # All information parsed.
      #
      # This information is directly used to construct the final values.
      # Most users will not need to think about it. It is public to allow
      # for manual control over values, in the instance that the default
      # parser is insufficient.
      #
      # A description parses into a Parsed one component at a time, and a
      # date or time type is built from what it gathered. Reach for it when
      # the input lacks a part your type needs: give the missing part a
      # default with +parse_with_defaults+ (Date.parse_with_defaults and
      # the rest), or fill one in by hand with a setter and convert with
      # +try_from+ (Date.try_from and the rest).
      #
      # A Parsed is mutable, as time's setters change it in place; the
      # +with_+ builders return a changed copy instead, and +dup+ copies
      # it, as Rust's +Copy+ does. time derives no equality for it, so two
      # are equal only when they are the same object. Each getter returns
      # +nil+ for a component nothing has set. The setters return +true+
      # when time took the value and +nil+ when it refused it (Rust's
      # <tt>Option<()></tt>), so a refusal is never mistaken for success.
      # time's hidden, deprecated +offset_minute+ and +offset_second+
      # accessors (since 0.3.8) are not bound; the +_signed+ ones replace
      # them.
      #
      # Mirrors time's <tt>parsing::Parsed</tt>
      # (<tt>src/parsing/parsed.rs:126-1137</tt>), plan 009.
      #
      # === Example
      #
      #   parsed = Ferro::Time::Parsing::Parsed.new
      #   parsed.set_year(2026) # => true
      #   parsed.set_ordinal(0) # raises RangeError
      #   parsed.set_ordinal(300) # => true
      #   Ferro::Time::Date.try_from(parsed).to_s # => "2026-10-27"
      class Parsed
        # A new Parsed with no information known. Mirrors time's
        # <tt>Parsed::default</tt>, which is <tt>Parsed::new</tt>
        # (<tt>src/parsing/parsed.rs:207-218</tt>).
        #
        # === Example
        #
        #   Ferro::Time::Parsing::Parsed.default.year # => nil
        def self.default
          new
        end

        # Parse a literal byte sequence, returning the rest of +input+ as a
        # binary String, or raising Error::ParseFromDescription::InvalidLiteral
        # when +input+ does not start with +literal+. Mirrors time's
        # <tt>Parsed::parse_literal</tt> (<tt>src/parsing/parsed.rs:583-591</tt>).
        #
        # [input] String, read as bytes.
        # [literal] String, read as bytes.
        #
        # === Example
        #
        #   Ferro::Time::Parsing::Parsed.parse_literal("T09:00", "T") # => "09:00".b
        def self.parse_literal(input, literal)
          Native.parsed_parse_literal(input, literal)
        end

        # Parse a single BorrowedFormatItem or OwnedFormatItem, changing this
        # Parsed, and return the rest of +input+ as a binary String. Raises
        # an Error::ParseFromDescription variant when the item does not
        # match.
        #
        # If an Optional item is passed, parsing will not fail; the input
        # will be returned as-is if the expected format is not present.
        #
        # Mirrors time's <tt>Parsed::parse_item</tt>
        # (<tt>src/parsing/parsed.rs:548-560</tt>).
        #
        # [input] String, read as bytes.
        # [item] FormatDescription::BorrowedFormatItem or
        #        FormatDescription::OwnedFormatItem.
        #
        # === Example
        #
        #   parsed = Ferro::Time::Parsing::Parsed.new
        #   item = Ferro::Time::FormatDescription.parse_owned(2, "[year]")
        #   parsed.parse_item("2026-10", item) # => "-10".b
        #   parsed.year # => 2026
        def parse_item(input, item)
          check_frozen
          Native.parsed_parse_items(self, input, [:item, Arguments.encode_item(Arguments.any_item(_ = item))])
        end

        # Parse an Array of BorrowedFormatItem or of OwnedFormatItem,
        # changing this Parsed, and return the rest of +input+ as a binary
        # String.
        #
        # This method will fail if any of the items fail to parse, and this
        # Parsed will not be changed in that case.
        #
        # Mirrors time's <tt>Parsed::parse_items</tt>
        # (<tt>src/parsing/parsed.rs:562-581</tt>).
        #
        # [input] String, read as bytes.
        # [items] Array of FormatDescription::BorrowedFormatItem, or of
        #         FormatDescription::OwnedFormatItem.
        #
        # === Example
        #
        #   parsed = Ferro::Time::Parsing::Parsed.new
        #   items = Ferro::Time::FormatDescription.parse_borrowed(2, "[hour]:[minute]")
        #   parsed.parse_items("09:05 tail", items) # => " tail".b
        #   parsed.minute # => 5
        def parse_items(input, items)
          check_frozen
          raise TypeError, "no implicit conversion of #{items.class} into Array" unless items.is_a?(Array)

          Native.parsed_parse_items(self, input, Arguments.items_description(items))
        end

        # Parse a single component, changing this Parsed, and return the
        # rest of +input+ as a binary String. An Ignore component consumes
        # bytes without regard for UTF-8 boundaries, as it always has.
        #
        # Mirrors time's <tt>Parsed::parse_component</tt>
        # (<tt>src/parsing/parsed.rs:593-616</tt>).
        #
        # [input] String, read as bytes.
        # [component] FormatDescription::Component.
        #
        # === Example
        #
        #   fd = Ferro::Time::FormatDescription
        #   parsed = Ferro::Time::Parsing::Parsed.new
        #   parsed.parse_component("07", fd::Component::Day.new(fd::Modifier::Day.default)) # => "".b
        #   parsed.day # => 7
        def parse_component(input, component)
          check_frozen
          encoded = [2, (_ = Arguments.component(component)).__send__(:encode)]
          Native.parsed_parse_component(self, input, [:item, encoded])
        end

        # time's derived +Debug+ for Parsed, every field as time stores it.
        def debug
          Native.parsed_debug(self)
        end

        # Ruby's FrozenError for a frozen Parsed, before anything changes.
        private def check_frozen
          raise FrozenError.new("can't modify frozen #{self.class}: #{inspect}", receiver: self) if frozen?
        end

        # Obtain the +year+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::year</tt> (<tt>src/parsing/parsed.rs:622</tt>).
        def year
          Native.parsed_year(self)
        end

        # Obtain the +year_last_two+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::year_last_two</tt>
        # (<tt>src/parsing/parsed.rs:649</tt>).
        def year_last_two
          Native.parsed_year_last_two(self)
        end

        # Obtain the +iso_year+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::iso_year</tt>
        # (<tt>src/parsing/parsed.rs:655</tt>).
        def iso_year
          Native.parsed_iso_year(self)
        end

        # Obtain the +iso_year_last_two+ component, or +nil+ when it is
        # unknown. Mirrors time's <tt>Parsed::iso_year_last_two</tt>
        # (<tt>src/parsing/parsed.rs:682</tt>).
        def iso_year_last_two
          Native.parsed_iso_year_last_two(self)
        end

        # Obtain the +month+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::month</tt> (<tt>src/parsing/parsed.rs:688</tt>).
        def month
          value = Native.parsed_month(self)
          Arguments.month_of(value) if value
        end

        # Obtain the +sunday_week_number+ component, or +nil+ when it is
        # unknown. Mirrors time's <tt>Parsed::sunday_week_number</tt>
        # (<tt>src/parsing/parsed.rs:694</tt>).
        def sunday_week_number
          Native.parsed_sunday_week_number(self)
        end

        # Obtain the +monday_week_number+ component, or +nil+ when it is
        # unknown. Mirrors time's <tt>Parsed::monday_week_number</tt>
        # (<tt>src/parsing/parsed.rs:700</tt>).
        def monday_week_number
          Native.parsed_monday_week_number(self)
        end

        # Obtain the +iso_week_number+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::iso_week_number</tt>
        # (<tt>src/parsing/parsed.rs:706</tt>).
        def iso_week_number
          Native.parsed_iso_week_number(self)
        end

        # Obtain the +weekday+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::weekday</tt>
        # (<tt>src/parsing/parsed.rs:712</tt>).
        def weekday
          value = Native.parsed_weekday(self)
          Arguments.weekday_of(value) if value
        end

        # Obtain the +ordinal+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::ordinal</tt>
        # (<tt>src/parsing/parsed.rs:718</tt>).
        def ordinal
          Native.parsed_ordinal(self)
        end

        # Obtain the +day+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::day</tt> (<tt>src/parsing/parsed.rs:724</tt>).
        def day
          Native.parsed_day(self)
        end

        # Obtain the +hour_24+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::hour_24</tt>
        # (<tt>src/parsing/parsed.rs:730</tt>).
        def hour_24
          Native.parsed_hour_24(self)
        end

        # Obtain the +hour_12+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::hour_12</tt>
        # (<tt>src/parsing/parsed.rs:736</tt>).
        def hour_12
          Native.parsed_hour_12(self)
        end

        # Obtain the +hour_12_is_pm+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::hour_12_is_pm</tt>
        # (<tt>src/parsing/parsed.rs:742</tt>).
        def hour_12_is_pm
          Native.parsed_hour_12_is_pm(self)
        end

        # Obtain the +minute+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::minute</tt> (<tt>src/parsing/parsed.rs:748</tt>).
        def minute
          Native.parsed_minute(self)
        end

        # Obtain the +second+ component, or +nil+ when it is unknown. Mirrors
        # time's <tt>Parsed::second</tt> (<tt>src/parsing/parsed.rs:754</tt>).
        def second
          Native.parsed_second(self)
        end

        # Obtain the +subsecond+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::subsecond</tt>
        # (<tt>src/parsing/parsed.rs:760</tt>).
        def subsecond
          Native.parsed_subsecond(self)
        end

        # Obtain the +offset_hour+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::offset_hour</tt>
        # (<tt>src/parsing/parsed.rs:766</tt>).
        def offset_hour
          Native.parsed_offset_hour(self)
        end

        # Obtain the +offset_minute+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::offset_minute_signed</tt>
        # (<tt>src/parsing/parsed.rs:780</tt>).
        def offset_minute_signed
          Native.parsed_offset_minute_signed(self)
        end

        # Obtain the +offset_second+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::offset_second_signed</tt>
        # (<tt>src/parsing/parsed.rs:798</tt>).
        def offset_second_signed
          Native.parsed_offset_second_signed(self)
        end

        # Obtain the +unix_timestamp_nanos+ component, or +nil+ when it is
        # unknown. Mirrors time's <tt>Parsed::unix_timestamp_nanos</tt>
        # (<tt>src/parsing/parsed.rs:808</tt>).
        def unix_timestamp_nanos
          Native.parsed_unix_timestamp_nanos(self)
        end

        # Obtain the +year_century+ component, or +nil+ when it is unknown.
        # Mirrors time's <tt>Parsed::year_century</tt>
        # (<tt>src/parsing/parsed.rs:631</tt>).
        def year_century
          Native.parsed_year_century(self)
        end

        # Obtain whether the +year_century+ component is negative, or +nil+
        # when it is unknown. Mirrors time's
        # <tt>Parsed::year_century_is_negative</tt>
        # (<tt>src/parsing/parsed.rs:640</tt>).
        def year_century_is_negative
          Native.parsed_year_century_is_negative(self)
        end

        # Obtain the +iso_year_century+ component, or +nil+ when it is
        # unknown. Mirrors time's <tt>Parsed::iso_year_century</tt>
        # (<tt>src/parsing/parsed.rs:664</tt>).
        def iso_year_century
          Native.parsed_iso_year_century(self)
        end

        # Obtain whether the +iso_year_century+ component is negative, or
        # +nil+ when it is unknown. Mirrors time's
        # <tt>Parsed::iso_year_century_is_negative</tt>
        # (<tt>src/parsing/parsed.rs:673</tt>).
        def iso_year_century_is_negative
          Native.parsed_iso_year_century_is_negative(self)
        end

        # Set the +year+ component. Returns +true+ when time set it, and +nil+
        # when time refused the value, which it may do for a value out of
        # range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_year</tt>
        # (<tt>src/parsing/parsed.rs:836</tt>).
        #
        # [value] Integer.
        def set_year(value)
          check_frozen
          Native.parsed_set_year(self, value)
        end

        # Set the +year_last_two+ component. Returns +true+ when time set it,
        # and +nil+ when time refused the value, which it may do for a value
        # out of range, though time does not promise to. Raises +FrozenError+
        # on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_year_last_two</tt>
        # (<tt>src/parsing/parsed.rs:855</tt>).
        #
        # [value] Integer.
        def set_year_last_two(value)
          check_frozen
          Native.parsed_set_year_last_two(self, value)
        end

        # Set the +iso_year+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_iso_year</tt>
        # (<tt>src/parsing/parsed.rs:856</tt>).
        #
        # [value] Integer.
        def set_iso_year(value)
          check_frozen
          Native.parsed_set_iso_year(self, value)
        end

        # Set the +iso_year_last_two+ component. Returns +true+ when time set
        # it, and +nil+ when time refused the value, which it may do for a
        # value out of range, though time does not promise to. Raises
        # +FrozenError+ on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_iso_year_last_two</tt>
        # (<tt>src/parsing/parsed.rs:857</tt>).
        #
        # [value] Integer.
        def set_iso_year_last_two(value)
          check_frozen
          Native.parsed_set_iso_year_last_two(self, value)
        end

        # Set the +month+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_month</tt>
        # (<tt>src/parsing/parsed.rs:876</tt>).
        #
        # [value] Month.
        def set_month(value)
          check_frozen
          Native.parsed_set_month(self, Arguments.month(value))
        end

        # Set the +sunday_week_number+ component. Returns +true+ when time set
        # it, and +nil+ when time refused the value, which it may do for a
        # value out of range, though time does not promise to. Raises
        # +FrozenError+ on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_sunday_week_number</tt>
        # (<tt>src/parsing/parsed.rs:877</tt>).
        #
        # [value] Integer.
        def set_sunday_week_number(value)
          check_frozen
          Native.parsed_set_sunday_week_number(self, value)
        end

        # Set the +monday_week_number+ component. Returns +true+ when time set
        # it, and +nil+ when time refused the value, which it may do for a
        # value out of range, though time does not promise to. Raises
        # +FrozenError+ on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_monday_week_number</tt>
        # (<tt>src/parsing/parsed.rs:878</tt>).
        #
        # [value] Integer.
        def set_monday_week_number(value)
          check_frozen
          Native.parsed_set_monday_week_number(self, value)
        end

        # Set the +iso_week_number+ component. Returns +true+ when time set
        # it, and +nil+ when time refused the value, which it may do for a
        # value out of range, though time does not promise to. Raises
        # +FrozenError+ on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_iso_week_number</tt>
        # (<tt>src/parsing/parsed.rs:879</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u8></tt>).
        def set_iso_week_number(value)
          check_frozen
          Native.parsed_set_iso_week_number(self, value)
        end

        # Set the +weekday+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_weekday</tt>
        # (<tt>src/parsing/parsed.rs:880</tt>).
        #
        # [value] Weekday.
        def set_weekday(value)
          check_frozen
          Native.parsed_set_weekday(self, Arguments.weekday(value))
        end

        # Set the +ordinal+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_ordinal</tt>
        # (<tt>src/parsing/parsed.rs:881</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u16></tt>).
        def set_ordinal(value)
          check_frozen
          Native.parsed_set_ordinal(self, value)
        end

        # Set the +day+ component. Returns +true+ when time set it, and +nil+
        # when time refused the value, which it may do for a value out of
        # range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_day</tt>
        # (<tt>src/parsing/parsed.rs:882</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u8></tt>).
        def set_day(value)
          check_frozen
          Native.parsed_set_day(self, value)
        end

        # Set the +hour_24+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_hour_24</tt>
        # (<tt>src/parsing/parsed.rs:883</tt>).
        #
        # [value] Integer.
        def set_hour_24(value)
          check_frozen
          Native.parsed_set_hour_24(self, value)
        end

        # Set the +hour_12+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_hour_12</tt>
        # (<tt>src/parsing/parsed.rs:884</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u8></tt>).
        def set_hour_12(value)
          check_frozen
          Native.parsed_set_hour_12(self, value)
        end

        # Set the +hour_12_is_pm+ component. Returns +true+ when time set it,
        # and +nil+ when time refused the value, which it may do for a value
        # out of range, though time does not promise to. Raises +FrozenError+
        # on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_hour_12_is_pm</tt>
        # (<tt>src/parsing/parsed.rs:885</tt>).
        #
        # [value] true or false.
        def set_hour_12_is_pm(value)
          check_frozen
          Native.parsed_set_hour_12_is_pm(self, Arguments.flag(value))
        end

        # Set the +minute+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_minute</tt>
        # (<tt>src/parsing/parsed.rs:886</tt>).
        #
        # [value] Integer.
        def set_minute(value)
          check_frozen
          Native.parsed_set_minute(self, value)
        end

        # Set the +second+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_second</tt>
        # (<tt>src/parsing/parsed.rs:887</tt>).
        #
        # [value] Integer.
        def set_second(value)
          check_frozen
          Native.parsed_set_second(self, value)
        end

        # Set the +subsecond+ component. Returns +true+ when time set it, and
        # +nil+ when time refused the value, which it may do for a value out
        # of range, though time does not promise to. Raises +FrozenError+ on a
        # frozen Parsed. Mirrors time's <tt>Parsed::set_subsecond</tt>
        # (<tt>src/parsing/parsed.rs:888</tt>).
        #
        # [value] Integer, nanoseconds.
        def set_subsecond(value)
          check_frozen
          Native.parsed_set_subsecond(self, value)
        end

        # Set the +offset_hour+ component. Returns +true+ when time set it,
        # and +nil+ when time refused the value, which it may do for a value
        # out of range, though time does not promise to. Raises +FrozenError+
        # on a frozen Parsed. Mirrors time's <tt>Parsed::set_offset_hour</tt>
        # (<tt>src/parsing/parsed.rs:889</tt>).
        #
        # [value] Integer.
        def set_offset_hour(value)
          check_frozen
          Native.parsed_set_offset_hour(self, value)
        end

        # Set the +offset_minute+ component. Returns +true+ when time set it,
        # and +nil+ when time refused the value, which it may do for a value
        # out of range, though time does not promise to. Raises +FrozenError+
        # on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_offset_minute_signed</tt>
        # (<tt>src/parsing/parsed.rs:890</tt>).
        #
        # [value] Integer.
        def set_offset_minute_signed(value)
          check_frozen
          Native.parsed_set_offset_minute_signed(self, value)
        end

        # Set the +offset_second+ component. Returns +true+ when time set it,
        # and +nil+ when time refused the value, which it may do for a value
        # out of range, though time does not promise to. Raises +FrozenError+
        # on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_offset_second_signed</tt>
        # (<tt>src/parsing/parsed.rs:891</tt>).
        #
        # [value] Integer.
        def set_offset_second_signed(value)
          check_frozen
          Native.parsed_set_offset_second_signed(self, value)
        end

        # Set the +unix_timestamp_nanos+ component. Returns +true+ when time
        # set it, and +nil+ when time refused the value, which it may do for a
        # value out of range, though time does not promise to. Raises
        # +FrozenError+ on a frozen Parsed. Mirrors time's
        # <tt>Parsed::set_unix_timestamp_nanos</tt>
        # (<tt>src/parsing/parsed.rs:892</tt>).
        #
        # [value] Integer.
        def set_unix_timestamp_nanos(value)
          check_frozen
          Native.parsed_set_unix_timestamp_nanos(self, value)
        end

        # Set the +year_century+ component. If the value is zero, the sign of
        # the century is taken from +is_negative+; otherwise the sign is
        # inferred from the value. Returns +true+ when time set it and +nil+
        # when it refused. Raises +FrozenError+ on a frozen Parsed. Mirrors
        # time's <tt>Parsed::set_year_century</tt>
        # (<tt>src/parsing/parsed.rs:844</tt>).
        #
        # [value] Integer.
        # [is_negative] true or false.
        def set_year_century(value, is_negative)
          check_frozen
          Native.parsed_set_year_century(self, value, Arguments.flag(is_negative))
        end

        # Set the +iso_year_century+ component. If the value is zero, the sign
        # of the century is taken from +is_negative+; otherwise the sign is
        # inferred from the value. Returns +true+ when time set it and +nil+
        # when it refused. Raises +FrozenError+ on a frozen Parsed. Mirrors
        # time's <tt>Parsed::set_iso_year_century</tt>
        # (<tt>src/parsing/parsed.rs:865</tt>).
        #
        # [value] Integer.
        # [is_negative] true or false.
        def set_iso_year_century(value, is_negative)
          check_frozen
          Native.parsed_set_iso_year_century(self, value, Arguments.flag(is_negative))
        end

        # Set the +year+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_year</tt>
        # (<tt>src/parsing/parsed.rs:933</tt>).
        #
        # [value] Integer.
        def with_year(value)
          Native.parsed_with_year(self, value)
        end

        # Set the +year_last_two+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_year_last_two</tt>
        # (<tt>src/parsing/parsed.rs:955</tt>).
        #
        # [value] Integer.
        def with_year_last_two(value)
          Native.parsed_with_year_last_two(self, value)
        end

        # Set the +iso_year+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_iso_year</tt>
        # (<tt>src/parsing/parsed.rs:962</tt>).
        #
        # [value] Integer.
        def with_iso_year(value)
          Native.parsed_with_iso_year(self, value)
        end

        # Set the +iso_year_last_two+ component in a copy, and return the
        # copy, or +nil+ when time refused the value. This Parsed is
        # unchanged. Mirrors time's <tt>Parsed::with_iso_year_last_two</tt>
        # (<tt>src/parsing/parsed.rs:984</tt>).
        #
        # [value] Integer.
        def with_iso_year_last_two(value)
          Native.parsed_with_iso_year_last_two(self, value)
        end

        # Set the +month+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_month</tt>
        # (<tt>src/parsing/parsed.rs:991</tt>).
        #
        # [value] Month.
        def with_month(value)
          Native.parsed_with_month(self, Arguments.month(value))
        end

        # Set the +sunday_week_number+ component in a copy, and return the
        # copy, or +nil+ when time refused the value. This Parsed is
        # unchanged. Mirrors time's <tt>Parsed::with_sunday_week_number</tt>
        # (<tt>src/parsing/parsed.rs:998</tt>).
        #
        # [value] Integer.
        def with_sunday_week_number(value)
          Native.parsed_with_sunday_week_number(self, value)
        end

        # Set the +monday_week_number+ component in a copy, and return the
        # copy, or +nil+ when time refused the value. This Parsed is
        # unchanged. Mirrors time's <tt>Parsed::with_monday_week_number</tt>
        # (<tt>src/parsing/parsed.rs:1005</tt>).
        #
        # [value] Integer.
        def with_monday_week_number(value)
          Native.parsed_with_monday_week_number(self, value)
        end

        # Set the +iso_week_number+ component in a copy, and return the copy,
        # or +nil+ when time refused the value. This Parsed is unchanged.
        # Mirrors time's <tt>Parsed::with_iso_week_number</tt>
        # (<tt>src/parsing/parsed.rs:1012</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u8></tt>).
        def with_iso_week_number(value)
          Native.parsed_with_iso_week_number(self, value)
        end

        # Set the +weekday+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_weekday</tt>
        # (<tt>src/parsing/parsed.rs:1019</tt>).
        #
        # [value] Weekday.
        def with_weekday(value)
          Native.parsed_with_weekday(self, Arguments.weekday(value))
        end

        # Set the +ordinal+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_ordinal</tt>
        # (<tt>src/parsing/parsed.rs:1026</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u16></tt>).
        def with_ordinal(value)
          Native.parsed_with_ordinal(self, value)
        end

        # Set the +day+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_day</tt>
        # (<tt>src/parsing/parsed.rs:1033</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u8></tt>).
        def with_day(value)
          Native.parsed_with_day(self, value)
        end

        # Set the +hour_24+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_hour_24</tt>
        # (<tt>src/parsing/parsed.rs:1040</tt>).
        #
        # [value] Integer.
        def with_hour_24(value)
          Native.parsed_with_hour_24(self, value)
        end

        # Set the +hour_12+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_hour_12</tt>
        # (<tt>src/parsing/parsed.rs:1047</tt>).
        #
        # [value] Integer, from 1 (Rust's <tt>NonZero<u8></tt>).
        def with_hour_12(value)
          Native.parsed_with_hour_12(self, value)
        end

        # Set the +hour_12_is_pm+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_hour_12_is_pm</tt>
        # (<tt>src/parsing/parsed.rs:1054</tt>).
        #
        # [value] true or false.
        def with_hour_12_is_pm(value)
          Native.parsed_with_hour_12_is_pm(self, Arguments.flag(value))
        end

        # Set the +minute+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_minute</tt>
        # (<tt>src/parsing/parsed.rs:1061</tt>).
        #
        # [value] Integer.
        def with_minute(value)
          Native.parsed_with_minute(self, value)
        end

        # Set the +second+ component in a copy, and return the copy, or +nil+
        # when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_second</tt>
        # (<tt>src/parsing/parsed.rs:1068</tt>).
        #
        # [value] Integer.
        def with_second(value)
          Native.parsed_with_second(self, value)
        end

        # Set the +subsecond+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_subsecond</tt>
        # (<tt>src/parsing/parsed.rs:1075</tt>).
        #
        # [value] Integer, nanoseconds.
        def with_subsecond(value)
          Native.parsed_with_subsecond(self, value)
        end

        # Set the +offset_hour+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_offset_hour</tt>
        # (<tt>src/parsing/parsed.rs:1082</tt>).
        #
        # [value] Integer.
        def with_offset_hour(value)
          Native.parsed_with_offset_hour(self, value)
        end

        # Set the +offset_minute+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_offset_minute_signed</tt>
        # (<tt>src/parsing/parsed.rs:1104</tt>).
        #
        # [value] Integer.
        def with_offset_minute_signed(value)
          Native.parsed_with_offset_minute_signed(self, value)
        end

        # Set the +offset_second+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. This Parsed is unchanged. Mirrors
        # time's <tt>Parsed::with_offset_second_signed</tt>
        # (<tt>src/parsing/parsed.rs:1126</tt>).
        #
        # [value] Integer.
        def with_offset_second_signed(value)
          Native.parsed_with_offset_second_signed(self, value)
        end

        # Set the +unix_timestamp_nanos+ component in a copy, and return the
        # copy, or +nil+ when time refused the value. This Parsed is
        # unchanged. Mirrors time's <tt>Parsed::with_unix_timestamp_nanos</tt>
        # (<tt>src/parsing/parsed.rs:1133</tt>).
        #
        # [value] Integer.
        def with_unix_timestamp_nanos(value)
          Native.parsed_with_unix_timestamp_nanos(self, value)
        end

        # Set the +year_century+ component in a copy, and return the copy, or
        # +nil+ when time refused the value. If the value is zero, the sign of
        # the century is taken from +is_negative+; otherwise the sign is
        # inferred from the value. Mirrors time's
        # <tt>Parsed::with_year_century</tt>
        # (<tt>src/parsing/parsed.rs:943</tt>).
        #
        # [value] Integer.
        # [is_negative] true or false.
        def with_year_century(value, is_negative)
          Native.parsed_with_year_century(self, value, Arguments.flag(is_negative))
        end

        # Set the +iso_year_century+ component in a copy, and return the copy,
        # or +nil+ when time refused the value. If the value is zero, the sign
        # of the century is taken from +is_negative+; otherwise the sign is
        # inferred from the value. Mirrors time's
        # <tt>Parsed::with_iso_year_century</tt>
        # (<tt>src/parsing/parsed.rs:972</tt>).
        #
        # [value] Integer.
        # [is_negative] true or false.
        def with_iso_year_century(value, is_negative)
          Native.parsed_with_iso_year_century(self, value, Arguments.flag(is_negative))
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
