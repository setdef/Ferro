# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    module FormatDescription
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: Jacob Pratt et al.
      # SPDX-SnippetComment: Component, its variants, and their docs from time
      #   0.3.55 src/format_description/component.rs
      #++

      # A component of a larger format description.
      #
      # A description is literal text and components: <tt>[year]</tt>,
      # <tt>[month]</tt>, <tt>[day]</tt>, each a part of a date or time
      # that changes from value to value. When you build a description in
      # code, or read one FormatDescription.parse_borrowed returned, each
      # component is a value of its own, holding the modifier that says how
      # to write it.
      #
      # Component is a module, and each of time's variants is a frozen
      # class that includes it, holding its modifier by position, as
      # Rust's tuple variant does: #to_a gives it, and so does the pattern
      # <tt>in Component::Day[modifier]</tt>. A
      # component equals the other component of the same variant and
      # modifier, and also the BorrowedFormatItem::Component or
      # OwnedFormatItem::Component that holds it, as time's
      # <tt>PartialEq<Component></tt> impls have it. The six components
      # time deprecated in 0.3.48 (+Month+, +Weekday+, +WeekNumber+,
      # +Hour+, +UnixTimestamp+, +Year+) are not bound (ADR 001, amendment
      # of 2026-11-05); time's parsers never return one.
      #
      # Mirrors time's <tt>format_description::Component</tt>
      # (<tt>src/format_description/component.rs:9-124</tt>), plan 009.
      #
      # === Example
      #
      #   modifier = Ferro::Time::FormatDescription::Modifier
      #   component = Ferro::Time::FormatDescription::Component::Hour24.new(modifier::Hour24.default)
      #   component.debug # => "Hour24(Hour24 { padding: Zero })"
      #   Ferro::Time::Time.from_hms(7, 0, 0).format(Ferro::Time::FormatDescription::BorrowedFormatItem.from(component)) # => "07"
      module Component
        # The component +item+ holds, raising Error::DifferentVariant
        # when it holds anything else. Mirrors time's
        # <tt>TryFrom<BorrowedFormatItem></tt> and
        # <tt>TryFrom<OwnedFormatItem></tt> for +Component+
        # (<tt>src/format_description/borrowed_format_item.rs:87-97</tt>,
        # <tt>src/format_description/owned_format_item.rs:133-143</tt>).
        #
        # [item] BorrowedFormatItem or OwnedFormatItem.
        #
        # === Example
        #
        #   item = Ferro::Time::FormatDescription::BorrowedFormatItem::StringLiteral.new("-")
        #   Ferro::Time::FormatDescription::Component.try_from(item)
        #   # raises Ferro::Time::Error::DifferentVariant: value was of a different variant than required
        def self.try_from(item)
          case item
          when BorrowedFormatItem::Component, OwnedFormatItem::Component then _ = item.deconstruct.first
          when BorrowedFormatItem, OwnedFormatItem then raise Error::DifferentVariant
          else raise TypeError, "no implicit conversion of #{item.class} into a format item"
          end
        end

        include TupleVariant

        # Checks that +modifier+ is this variant's modifier, as Rust's
        # type checker would, and keeps it.
        private def check(modifier)
          Arguments.component_modifier(self.class, modifier)
          modifier
        end

        # Whether +other+ is the same component, or a format item that holds
        # it, as time's derived +PartialEq+ and its
        # <tt>PartialEq<BorrowedFormatItem></tt> and
        # <tt>PartialEq<OwnedFormatItem></tt> for +Component+ compare
        # (<tt>src/format_description/borrowed_format_item.rs:125-130</tt>,
        # <tt>src/format_description/owned_format_item.rs:171-176</tt>).
        #
        # [other] Object.
        def ==(other)
          case other
          when BorrowedFormatItem::Component, OwnedFormatItem::Component then (_ = other).deconstruct.first.eql?(self)
          else super
          end
        end

        # time's +Debug+ for the component: the variant and its modifier.
        def debug
          Native.format_item_debug(1, __send__(:encode))
        end

        # The component as the native layer reads it, which is its
        # modifier's encoding: every variant has its modifier's name.
        private def encode
          deconstruct.first.__send__(:encode)
        end

        # Day of the month.
        #
        # Mirrors time's <tt>Component::Day</tt>
        # (<tt>src/format_description/component.rs:10-11</tt>).
        class Day
          include Component
        end

        # Month of the year in the abbreviated form (e.g. "Jan").
        #
        # Mirrors time's <tt>Component::MonthShort</tt>
        # (<tt>src/format_description/component.rs:12-13</tt>).
        class MonthShort
          include Component
        end

        # Month of the year in the full form (e.g. "January").
        #
        # Mirrors time's <tt>Component::MonthLong</tt>
        # (<tt>src/format_description/component.rs:14-15</tt>).
        class MonthLong
          include Component
        end

        # Month of the year in the numerical form (e.g. "1" for January).
        #
        # Mirrors time's <tt>Component::MonthNumerical</tt>
        # (<tt>src/format_description/component.rs:16-17</tt>).
        class MonthNumerical
          include Component
        end

        # Ordinal day of the year.
        #
        # Mirrors time's <tt>Component::Ordinal</tt>
        # (<tt>src/format_description/component.rs:18-19</tt>).
        class Ordinal
          include Component
        end

        # Weekday in the abbreviated form (e.g. "Mon").
        #
        # Mirrors time's <tt>Component::WeekdayShort</tt>
        # (<tt>src/format_description/component.rs:20-21</tt>).
        class WeekdayShort
          include Component
        end

        # Weekday in the full form (e.g. "Monday").
        #
        # Mirrors time's <tt>Component::WeekdayLong</tt>
        # (<tt>src/format_description/component.rs:22-23</tt>).
        class WeekdayLong
          include Component
        end

        # Weekday number where Sunday is either 0 or 1 depending on the
        # modifier.
        #
        # Mirrors time's <tt>Component::WeekdaySunday</tt>
        # (<tt>src/format_description/component.rs:24-25</tt>).
        class WeekdaySunday
          include Component
        end

        # Weekday number where Monday is either 0 or 1 depending on the
        # modifier.
        #
        # Mirrors time's <tt>Component::WeekdayMonday</tt>
        # (<tt>src/format_description/component.rs:26-27</tt>).
        class WeekdayMonday
          include Component
        end

        # Week number of the year, where week 1 starts is the week beginning
        # on Monday that contains January 4.
        #
        # Mirrors time's <tt>Component::WeekNumberIso</tt>
        # (<tt>src/format_description/component.rs:28-30</tt>).
        class WeekNumberIso
          include Component
        end

        # Week number of the year, where week 1 starts on the first Sunday
        # of the calendar year.
        #
        # Mirrors time's <tt>Component::WeekNumberSunday</tt>
        # (<tt>src/format_description/component.rs:31-32</tt>).
        class WeekNumberSunday
          include Component
        end

        # Week number of the year, where week 1 starts on the first Monday
        # of the calendar year.
        #
        # Mirrors time's <tt>Component::WeekNumberMonday</tt>
        # (<tt>src/format_description/component.rs:33-34</tt>).
        class WeekNumberMonday
          include Component
        end

        # The calendar year. Supports the extended range.
        #
        # Mirrors time's <tt>Component::CalendarYearFullExtendedRange</tt>
        # (<tt>src/format_description/component.rs:35-36</tt>).
        class CalendarYearFullExtendedRange
          include Component
        end

        # The calendar year. Does not support the extended range.
        #
        # Mirrors time's <tt>Component::CalendarYearFullStandardRange</tt>
        # (<tt>src/format_description/component.rs:37-38</tt>).
        class CalendarYearFullStandardRange
          include Component
        end

        # The ISO week-based year. Supports the extended range.
        #
        # Mirrors time's <tt>Component::IsoYearFullExtendedRange</tt>
        # (<tt>src/format_description/component.rs:39-40</tt>).
        class IsoYearFullExtendedRange
          include Component
        end

        # The ISO week-based year. Does not support the extended range.
        #
        # Mirrors time's <tt>Component::IsoYearFullStandardRange</tt>
        # (<tt>src/format_description/component.rs:41-42</tt>).
        class IsoYearFullStandardRange
          include Component
        end

        # The century of the calendar year. Supports the extended range.
        #
        # Mirrors time's
        # <tt>Component::CalendarYearCenturyExtendedRange</tt>
        # (<tt>src/format_description/component.rs:43-44</tt>).
        class CalendarYearCenturyExtendedRange
          include Component
        end

        # The century of the calendar year. Does not support the extended
        # range.
        #
        # Mirrors time's
        # <tt>Component::CalendarYearCenturyStandardRange</tt>
        # (<tt>src/format_description/component.rs:45-46</tt>).
        class CalendarYearCenturyStandardRange
          include Component
        end

        # The century of the ISO week-based year. Supports the extended
        # range.
        #
        # Mirrors time's <tt>Component::IsoYearCenturyExtendedRange</tt>
        # (<tt>src/format_description/component.rs:47-48</tt>).
        class IsoYearCenturyExtendedRange
          include Component
        end

        # The century of the ISO week-based year. Does not support the
        # extended range.
        #
        # Mirrors time's <tt>Component::IsoYearCenturyStandardRange</tt>
        # (<tt>src/format_description/component.rs:49-50</tt>).
        class IsoYearCenturyStandardRange
          include Component
        end

        # The last two digits of the calendar year.
        #
        # Mirrors time's <tt>Component::CalendarYearLastTwo</tt>
        # (<tt>src/format_description/component.rs:51-52</tt>).
        class CalendarYearLastTwo
          include Component
        end

        # The last two digits of the ISO week-based year.
        #
        # Mirrors time's <tt>Component::IsoYearLastTwo</tt>
        # (<tt>src/format_description/component.rs:53-54</tt>).
        class IsoYearLastTwo
          include Component
        end

        # Hour of the day using the 12-hour clock.
        #
        # Mirrors time's <tt>Component::Hour12</tt>
        # (<tt>src/format_description/component.rs:55-56</tt>).
        class Hour12
          include Component
        end

        # Hour of the day using the 24-hour clock.
        #
        # Mirrors time's <tt>Component::Hour24</tt>
        # (<tt>src/format_description/component.rs:57-58</tt>).
        class Hour24
          include Component
        end

        # Minute within the hour.
        #
        # Mirrors time's <tt>Component::Minute</tt>
        # (<tt>src/format_description/component.rs:59-60</tt>).
        class Minute
          include Component
        end

        # AM/PM part of the time.
        #
        # Mirrors time's <tt>Component::Period</tt>
        # (<tt>src/format_description/component.rs:61-62</tt>).
        class Period
          include Component
        end

        # Second within the minute.
        #
        # Mirrors time's <tt>Component::Second</tt>
        # (<tt>src/format_description/component.rs:63-64</tt>).
        class Second
          include Component
        end

        # Subsecond within the second.
        #
        # Mirrors time's <tt>Component::Subsecond</tt>
        # (<tt>src/format_description/component.rs:65-66</tt>).
        class Subsecond
          include Component
        end

        # Hour of the UTC offset.
        #
        # Mirrors time's <tt>Component::OffsetHour</tt>
        # (<tt>src/format_description/component.rs:67-68</tt>).
        class OffsetHour
          include Component
        end

        # Minute within the hour of the UTC offset.
        #
        # Mirrors time's <tt>Component::OffsetMinute</tt>
        # (<tt>src/format_description/component.rs:69-70</tt>).
        class OffsetMinute
          include Component
        end

        # Second within the minute of the UTC offset.
        #
        # Mirrors time's <tt>Component::OffsetSecond</tt>
        # (<tt>src/format_description/component.rs:71-72</tt>).
        class OffsetSecond
          include Component
        end

        # A number of bytes to ignore when parsing. This has no effect on
        # formatting.
        #
        # Mirrors time's <tt>Component::Ignore</tt>
        # (<tt>src/format_description/component.rs:73-74</tt>).
        class Ignore
          include Component
        end

        # A Unix timestamp in seconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampSecond</tt>
        # (<tt>src/format_description/component.rs:75-76</tt>).
        class UnixTimestampSecond
          include Component
        end

        # A Unix timestamp in milliseconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampMillisecond</tt>
        # (<tt>src/format_description/component.rs:77-78</tt>).
        class UnixTimestampMillisecond
          include Component
        end

        # A Unix timestamp in microseconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampMicrosecond</tt>
        # (<tt>src/format_description/component.rs:79-80</tt>).
        class UnixTimestampMicrosecond
          include Component
        end

        # A Unix timestamp in nanoseconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampNanosecond</tt>
        # (<tt>src/format_description/component.rs:81-82</tt>).
        class UnixTimestampNanosecond
          include Component
        end

        # The end of input. Parsing this component will fail if there is any
        # input remaining. This component neither affects formatting nor
        # consumes any input when parsing.
        #
        # Mirrors time's <tt>Component::End</tt>
        # (<tt>src/format_description/component.rs:83-85</tt>).
        class End
          include Component
        end

        # Every variant by name, for the native encoding. Private to the gem.
        CLASSES = { Day: Day, MonthShort: MonthShort, MonthLong: MonthLong, MonthNumerical: MonthNumerical, Ordinal: Ordinal, WeekdayShort: WeekdayShort, WeekdayLong: WeekdayLong, WeekdaySunday: WeekdaySunday, WeekdayMonday: WeekdayMonday, WeekNumberIso: WeekNumberIso, WeekNumberSunday: WeekNumberSunday, WeekNumberMonday: WeekNumberMonday, CalendarYearFullExtendedRange: CalendarYearFullExtendedRange, CalendarYearFullStandardRange: CalendarYearFullStandardRange, IsoYearFullExtendedRange: IsoYearFullExtendedRange, IsoYearFullStandardRange: IsoYearFullStandardRange, CalendarYearCenturyExtendedRange: CalendarYearCenturyExtendedRange, CalendarYearCenturyStandardRange: CalendarYearCenturyStandardRange, IsoYearCenturyExtendedRange: IsoYearCenturyExtendedRange, IsoYearCenturyStandardRange: IsoYearCenturyStandardRange, CalendarYearLastTwo: CalendarYearLastTwo, IsoYearLastTwo: IsoYearLastTwo, Hour12: Hour12, Hour24: Hour24, Minute: Minute, Period: Period, Second: Second, Subsecond: Subsecond, OffsetHour: OffsetHour, OffsetMinute: OffsetMinute, OffsetSecond: OffsetSecond, Ignore: Ignore, UnixTimestampSecond: UnixTimestampSecond, UnixTimestampMillisecond: UnixTimestampMillisecond, UnixTimestampMicrosecond: UnixTimestampMicrosecond, UnixTimestampNanosecond: UnixTimestampNanosecond, End: End }.freeze
        private_constant :CLASSES
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
