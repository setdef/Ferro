# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    # Converts the gem's Ruby values to what the native layer takes, and
    # back. Private to the gem.
    module Arguments # :nodoc:
      # Nanoseconds in a second.
      NANOSECONDS = 1_000_000_000

      # The most whole seconds a std +Duration+ holds, +u64+'s maximum.
      U64_MAX = (2 ** 64) - 1

      class << self
        # The number of +month+, refusing anything but a Month as Rust's
        # type checker would.
        def month(month)
          raise TypeError, "no implicit conversion of #{month.class} into Ferro::Time::Month" unless month.is_a?(Month)

          month.to_i
        end

        # The Month numbered +number+.
        def month_of(number)
          Month.const_get(:ALL).fetch(number - 1)
        end

        # The days from Monday of +weekday+, refusing anything but a Weekday.
        def weekday(weekday)
          unless weekday.is_a?(Weekday)
            raise TypeError, "no implicit conversion of #{weekday.class} into Ferro::Time::Weekday"
          end

          weekday.__send__(:days_from_monday)
        end

        # The Weekday +days+ after Monday.
        def weekday_of(days)
          Weekday.const_get(:ALL).fetch(days)
        end

        # +duration+, refusing anything but a SignedDuration.
        def duration(duration)
          unless duration.is_a?(SignedDuration)
            raise TypeError, "no implicit conversion of #{duration.class} into Ferro::Time::SignedDuration"
          end

          duration
        end

        # The whole seconds and nanoseconds of the std +Duration+ that
        # +seconds+ names, the pair the native layer reads as a
        # <tt>std::time::Duration</tt> (ADR 001, 2026-11-05). A Float goes
        # through core's <tt>Duration::try_from_secs_f64</tt>, which rounds to
        # the nearest nanosecond, ties to even, and refuses a negative, NaN,
        # infinite, or too large count with +ArgumentError+ and core's text.
        # Any other Numeric is exact: its Rational value, rounded the same
        # way. Its seconds then cross as a +u64+, so magnus refuses with
        # +RangeError+ a count that is negative after that rounding, or too
        # large; a negative count that rounds to zero nanoseconds is zero.
        def std_duration(seconds)
          case seconds
          when Float then Native.std_from_secs_f64(seconds)
          when Numeric then (Rational(_ = seconds) * NANOSECONDS).round(half: :even).divmod(NANOSECONDS)
          else raise TypeError, "no implicit conversion of #{seconds.class} into Numeric"
          end
        end

        # The pair #std_duration gives, or +nil+ where +seconds+ is not a
        # number of seconds a std +Duration+ can hold, for the comparisons,
        # which answer rather than raise.
        def std_duration_or_nil(seconds)
          return unless seconds.is_a?(Numeric)

          whole, nanoseconds = std_duration(seconds)
          [whole, nanoseconds] if whole.between?(0, U64_MAX)
        rescue ArgumentError, RangeError
          nil
        end

        # A Rational number of seconds from a std +Duration+'s whole
        # +nanoseconds+, exact to the nanosecond (ADR 001, 2026-11-05).
        def seconds(nanoseconds)
          Rational(nanoseconds, NANOSECONDS)
        end

        # A year, month number, and day, with the month as a Month.
        def calendar_date(parts)
          year, month, day = parts
          [year, month_of(month), day]
        end

        # An ISO year, week, and weekday number, with the weekday as a
        # Weekday.
        def iso_week_date(parts)
          year, week, weekday = parts
          [year, week, weekday_of(weekday)]
        end

        # The native form of a description: a version 3 description itself,
        # a well-known format's name, an ISO 8601 configuration's settings
        # (plan 007, decision 11), or format items (plan 009, decision 10).
        def description(description)
          wk = FormatDescription::WellKnown
          case description
          when FormatDescription::BorrowedFormatItem, FormatDescription::OwnedFormatItem, Array then items_description(description)
          when FormatDescription::FormatDescriptionV3 then description
          when wk::Iso8601 then description.__send__(:config).__send__(:settings)
          else
            return :rfc2822 if description.equal?(wk::Rfc2822)
            return :rfc3339 if description.equal?(wk::Rfc3339)
            return wk::Iso8601::DEFAULT.__send__(:config).__send__(:settings) if description.equal?(wk::Iso8601)

            raise TypeError, "no implicit conversion of #{description.inspect} into a format description"
          end
        end

        # The native form of an item, or an Array of items of one family,
        # used as a description (plan 009, decision 10).
        def items_description(description)
          fd = FormatDescription
          return [:item, encode_item(description)] unless description.is_a?(Array)

          family = description.first.is_a?(fd::BorrowedFormatItem) ? fd::BorrowedFormatItem : fd::OwnedFormatItem
          [:items, items_of(family, description).map { |item| encode_item(item) }]
        end

        # +item+, refusing anything but an item of +family+ as Rust's type
        # checker would.
        def item_of(family, item)
          raise TypeError, "no implicit conversion of #{item.class} into #{family.name}" unless item.is_a?(family)

          _ = item
        end

        # A frozen copy of +items+, refusing anything but an Array of items
        # of +family+.
        def items_of(family, items)
          raise TypeError, "no implicit conversion of #{items.class} into Array" unless items.is_a?(Array)

          items.map { |item| item_of(family, item) }.freeze
        end

        # The fields a format item's +new+ keeps, each checked as Rust's
        # type checker would and frozen.
        def item_fields(item, fields)
          family = item.is_a?(FormatDescription::BorrowedFormatItem) ? FormatDescription::BorrowedFormatItem : FormatDescription::OwnedFormatItem
          # @type var checked: Hash[Symbol, Object]
          checked = {}
          fields.each do |name, value|
            checked[name] = _ = case name
              when :literal then item.is_a?(family.const_get(:LITERALS).fetch(:Literal)) ? bytes(value) : text(value)
              when :component then component(value)
              when :item then item_of(family, value)
              else items_of(family, value)
            end
          end
          checked
        end

        # +item+, refusing anything but a BorrowedFormatItem or an
        # OwnedFormatItem.
        def any_item(item)
          return _ = item if item.is_a?(FormatDescription::BorrowedFormatItem) || item.is_a?(FormatDescription::OwnedFormatItem)

          raise TypeError, "no implicit conversion of #{item.class} into a format item"
        end

        # +value+, refusing anything but +true+ or +false+, as Rust's +bool+.
        def flag(value)
          modifier_field(:bool, value)
          value
        end

        # +parsed+, refusing anything but a Parsing::Parsed.
        def parsed(parsed)
          raise TypeError, "no implicit conversion of #{parsed.class} into Ferro::Time::Parsing::Parsed" unless parsed.is_a?(Parsing::Parsed)

          parsed
        end

        # Checks +value+ against the type time gives a modifier's field:
        # one of the modifier enums, +bool+, or <tt>NonZero<u16></tt>.
        def modifier_field(kind, value)
          case kind
          when :bool
            raise TypeError, "no implicit conversion of #{value.class} into true or false" unless value == true || value == false
          when :count then nonzero_u16(value)
          else
            raise TypeError, "no implicit conversion of #{value.class} into #{kind.name}" unless value.instance_of?(kind)
          end
        end

        # Checks that +value+ is an Integer from 1 to 65,535, Rust's
        # <tt>NonZero<u16></tt>, in the words magnus uses for an Integer
        # out of a Rust type's range.
        def nonzero_u16(value)
          raise TypeError, "no implicit conversion of #{value.class} into Integer" unless value.is_a?(Integer)
          raise RangeError, "integer #{value} too small to convert into `NonZero<u16>`" if value < 1
          raise RangeError, "integer #{value} too big to convert into `NonZero<u16>`" if value > 65_535
        end

        # A modifier field as the native layer reads it: an enum as its
        # place in time's enum, anything else as is.
        def encode_field(value)
          case value
          when true, false, Integer then value
          else value.__send__(:index)
          end
        end

        # Checks that +modifier+ is the modifier of the component variant
        # +component_class+, which shares its name.
        def component_modifier(component_class, modifier)
          expected = FormatDescription::Modifier.const_get(:CLASSES).fetch(component_class.name.to_s.split("::").last.to_s.to_sym)
          return if modifier.instance_of?(expected)

          raise TypeError, "no implicit conversion of #{modifier.class} into #{expected.name}"
        end

        # +component+, refusing anything but a FormatDescription::Component.
        def component(component)
          unless component.is_a?(FormatDescription::Component)
            raise TypeError, "no implicit conversion of #{component.class} into Ferro::Time::FormatDescription::Component"
          end

          _ = component
        end

        # A frozen binary copy of the bytes of +string+.
        def bytes(string)
          raise TypeError, "no implicit conversion of #{string.class} into String" unless string.is_a?(String)

          string.b.freeze
        end

        # A frozen UTF-8 copy of +string+, refusing one that is not valid
        # UTF-8 as Rust's +str+ would.
        def text(string)
          raise TypeError, "no implicit conversion of #{string.class} into String" unless string.is_a?(String)

          utf8 = string.dup.force_encoding(Encoding::UTF_8)
          raise EncodingError, "invalid byte sequence in UTF-8" unless utf8.valid_encoding?

          utf8.freeze
        end

        # The native form of a format item: its variant's place in time's
        # enum and its contents.
        def encode_item(item)
          b = FormatDescription::BorrowedFormatItem
          o = FormatDescription::OwnedFormatItem
          case item
          when b::StringLiteral, o::StringLiteral then [1, item.literal]
          when b::Component, o::Component then [2, (_ = item.component).__send__(:encode)]
          when b::Compound, o::Compound then [3, item.compound.map { |inner| encode_item(inner) }]
          when b::Optional, o::Optional then [4, encode_item(item.item)]
          when b::First, o::First then [5, item.items.map { |inner| encode_item(inner) }]
          else [0, (_ = item).literal]
          end
        end

        # The BorrowedFormatItem the native encoding +encoded+ describes.
        def decode_borrowed(encoded)
          b = FormatDescription::BorrowedFormatItem
          raise TypeError, "malformed format item" unless encoded.is_a?(Array)

          tag, value = encoded
          case tag
          when 0 then b.const_get(:LITERALS).fetch(:Literal).new(value)
          when 1 then b::StringLiteral.new(value)
          when 2 then b::Component.new(decode_component(value))
          when 3 then b::Compound.new(value.map { |inner| decode_borrowed(inner) })
          when 4 then b::Optional.new(decode_borrowed(value))
          else b::First.new(value.map { |inner| decode_borrowed(inner) })
          end
        end

        # The OwnedFormatItem the native encoding +encoded+ describes.
        def decode_owned(encoded)
          o = FormatDescription::OwnedFormatItem
          raise TypeError, "malformed format item" unless encoded.is_a?(Array)

          tag, value = encoded
          case tag
          when 0 then o.const_get(:LITERALS).fetch(:Literal).new(value)
          when 1 then o::StringLiteral.new(value)
          when 2 then o::Component.new(decode_component(value))
          when 3 then o::Compound.new(value.map { |inner| decode_owned(inner) })
          when 4 then o::Optional.new(decode_owned(value))
          else o::First.new(value.map { |inner| decode_owned(inner) })
          end
        end

        # The component the native encoding +encoded+ describes: its
        # variant's name, then its modifier's fields in time's order.
        def decode_component(encoded)
          raise TypeError, "malformed component" unless encoded.is_a?(Array)

          name, *values = encoded
          modifier = FormatDescription::Modifier.const_get(:CLASSES).fetch(name.to_s.to_sym)
          kinds = modifier.const_get(:KINDS)
          # @type var fields: Hash[Symbol, Object]
          fields = {}
          kinds.each_with_index do |(field, kind), index|
            value = values.fetch(index)
            fields[field] = kind.is_a?(Class) ? kind.const_get(:ALL).fetch(value) : value
          end
          FormatDescription::Component.const_get(:CLASSES).fetch(name.to_s.to_sym).new(modifier.__send__(:new, **fields))
        end

        # The OwnedFormatItem time's <tt>From<&BorrowedFormatItem></tt>
        # makes of +item+ (<tt>src/format_description/owned_format_item.rs:85-107</tt>).
        def owned_item(item)
          decode_owned(encode_item(item))
        end

        # The owned items of an Array of borrowed or of owned items, as
        # time's <tt>From<Vec<_>></tt> impls for +OwnedFormatItem+ take
        # them.
        def owned_items(items)
          fd = FormatDescription
          return _ = items_of(fd::OwnedFormatItem, items) if items.all?(fd::OwnedFormatItem)

          items_of(fd::BorrowedFormatItem, items).map { |item| owned_item(item) }
        end

        # Refuses an +output+ that is not a String, or is frozen, before
        # anything is formatted.
        def sink(output)
          raise TypeError, "no implicit conversion of #{output.class} into String" unless output.is_a?(String)
          raise FrozenError.new("can't modify frozen String: #{output.inspect}", receiver: output) if output.frozen?
        end

        # The whole seconds and nanoseconds since the epoch of Ruby's
        # +time+, the parts of a +SystemTime+ (plan 007, decision 10).
        def system_time(time)
          raise TypeError, "no implicit conversion of #{time.class} into Time" unless time.is_a?(::Time)

          [time.to_i, time.nsec]
        end

        # Ruby's ::Time, in UTC, at +seconds+ and +nanoseconds+ after the
        # epoch.
        def ruby_time(parts)
          seconds, nanoseconds = parts
          ::Time.at(seconds, nanoseconds, :nsec, in: "UTC")
        end
      end
    end
  end
end
