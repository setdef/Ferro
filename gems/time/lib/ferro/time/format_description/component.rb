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
      # Component is a module, and each of time's variants is a +Data+
      # class that includes it, holding its modifier as +modifier+. A
      # component equals the other component of the same variant and
      # modifier, and also the BorrowedFormatItem::Component or
      # OwnedFormatItem::Component that holds it, as time's
      # <tt>PartialEq<Component></tt> impls have it. The six components
      # time deprecated in 0.3.48 (Month, Weekday, WeekNumber, Hour,
      # UnixTimestamp, Year) still format and parse, as time keeps them
      # working, and naming one warns.
      #
      # Mirrors time's <tt>format_description::Component</tt>
      # (<tt>src/format_description/component.rs:9-124</tt>), plan 009.
      #
      # === Example
      #
      #   modifier = Ferro::Time::FormatDescription::Modifier
      #   component = Ferro::Time::FormatDescription::Component::Hour24.new(modifier::Hour24.default)
      #   component.inspect # => "Hour24(Hour24 { padding: Zero })"
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
          when BorrowedFormatItem::Component, OwnedFormatItem::Component then item.component
          when BorrowedFormatItem, OwnedFormatItem then raise Error::DifferentVariant
          else raise TypeError, "no implicit conversion of #{item.class} into a format item"
          end
        end

        # Checks that +modifier+ is this variant's modifier, as Rust's
        # type checker would.
        #
        # [modifier] The modifier of the same name.
        def initialize(modifier:)
          Arguments.component_modifier(self.class, modifier)
          super
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
          when BorrowedFormatItem::Component, OwnedFormatItem::Component then (_ = other).component.eql?(self)
          else super
          end
        end

        # time's +Debug+ for the component: the variant and its modifier.
        def inspect
          Native.format_item_debug(1, __send__(:encode))
        end

        # The component as the native layer reads it, which is its
        # modifier's encoding: every variant has its modifier's name.
        private def encode
          (_ = self).modifier.__send__(:encode)
        end

        # Day of the month.
        #
        # Mirrors time's <tt>Component::Day</tt>
        # (<tt>src/format_description/component.rs:10-11</tt>).
        class Day < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Day that says how to format and parse it.
        end

        # Month of the year in the abbreviated form (e.g. "Jan").
        #
        # Mirrors time's <tt>Component::MonthShort</tt>
        # (<tt>src/format_description/component.rs:12-13</tt>).
        class MonthShort < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::MonthShort that says how to format and parse it.
        end

        # Month of the year in the full form (e.g. "January").
        #
        # Mirrors time's <tt>Component::MonthLong</tt>
        # (<tt>src/format_description/component.rs:14-15</tt>).
        class MonthLong < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::MonthLong that says how to format and parse it.
        end

        # Month of the year in the numerical form (e.g. "1" for January).
        #
        # Mirrors time's <tt>Component::MonthNumerical</tt>
        # (<tt>src/format_description/component.rs:16-17</tt>).
        class MonthNumerical < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::MonthNumerical that says how to format and parse it.
        end

        # Ordinal day of the year.
        #
        # Mirrors time's <tt>Component::Ordinal</tt>
        # (<tt>src/format_description/component.rs:18-19</tt>).
        class Ordinal < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Ordinal that says how to format and parse it.
        end

        # Weekday in the abbreviated form (e.g. "Mon").
        #
        # Mirrors time's <tt>Component::WeekdayShort</tt>
        # (<tt>src/format_description/component.rs:20-21</tt>).
        class WeekdayShort < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekdayShort that says how to format and parse it.
        end

        # Weekday in the full form (e.g. "Monday").
        #
        # Mirrors time's <tt>Component::WeekdayLong</tt>
        # (<tt>src/format_description/component.rs:22-23</tt>).
        class WeekdayLong < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekdayLong that says how to format and parse it.
        end

        # Weekday number where Sunday is either 0 or 1 depending on the
        # modifier.
        #
        # Mirrors time's <tt>Component::WeekdaySunday</tt>
        # (<tt>src/format_description/component.rs:24-25</tt>).
        class WeekdaySunday < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekdaySunday that says how to format and parse it.
        end

        # Weekday number where Monday is either 0 or 1 depending on the
        # modifier.
        #
        # Mirrors time's <tt>Component::WeekdayMonday</tt>
        # (<tt>src/format_description/component.rs:26-27</tt>).
        class WeekdayMonday < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekdayMonday that says how to format and parse it.
        end

        # Week number of the year, where week 1 starts is the week beginning
        # on Monday that contains January 4.
        #
        # Mirrors time's <tt>Component::WeekNumberIso</tt>
        # (<tt>src/format_description/component.rs:28-30</tt>).
        class WeekNumberIso < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekNumberIso that says how to format and parse it.
        end

        # Week number of the year, where week 1 starts on the first Sunday
        # of the calendar year.
        #
        # Mirrors time's <tt>Component::WeekNumberSunday</tt>
        # (<tt>src/format_description/component.rs:31-32</tt>).
        class WeekNumberSunday < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekNumberSunday that says how to format and parse it.
        end

        # Week number of the year, where week 1 starts on the first Monday
        # of the calendar year.
        #
        # Mirrors time's <tt>Component::WeekNumberMonday</tt>
        # (<tt>src/format_description/component.rs:33-34</tt>).
        class WeekNumberMonday < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekNumberMonday that says how to format and parse it.
        end

        # The calendar year. Supports the extended range.
        #
        # Mirrors time's <tt>Component::CalendarYearFullExtendedRange</tt>
        # (<tt>src/format_description/component.rs:35-36</tt>).
        class CalendarYearFullExtendedRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::CalendarYearFullExtendedRange that says how to format and parse it.
        end

        # The calendar year. Does not support the extended range.
        #
        # Mirrors time's <tt>Component::CalendarYearFullStandardRange</tt>
        # (<tt>src/format_description/component.rs:37-38</tt>).
        class CalendarYearFullStandardRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::CalendarYearFullStandardRange that says how to format and parse it.
        end

        # The ISO week-based year. Supports the extended range.
        #
        # Mirrors time's <tt>Component::IsoYearFullExtendedRange</tt>
        # (<tt>src/format_description/component.rs:39-40</tt>).
        class IsoYearFullExtendedRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::IsoYearFullExtendedRange that says how to format and parse it.
        end

        # The ISO week-based year. Does not support the extended range.
        #
        # Mirrors time's <tt>Component::IsoYearFullStandardRange</tt>
        # (<tt>src/format_description/component.rs:41-42</tt>).
        class IsoYearFullStandardRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::IsoYearFullStandardRange that says how to format and parse it.
        end

        # The century of the calendar year. Supports the extended range.
        #
        # Mirrors time's
        # <tt>Component::CalendarYearCenturyExtendedRange</tt>
        # (<tt>src/format_description/component.rs:43-44</tt>).
        class CalendarYearCenturyExtendedRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::CalendarYearCenturyExtendedRange that says how to format and parse it.
        end

        # The century of the calendar year. Does not support the extended
        # range.
        #
        # Mirrors time's
        # <tt>Component::CalendarYearCenturyStandardRange</tt>
        # (<tt>src/format_description/component.rs:45-46</tt>).
        class CalendarYearCenturyStandardRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::CalendarYearCenturyStandardRange that says how to format and parse it.
        end

        # The century of the ISO week-based year. Supports the extended
        # range.
        #
        # Mirrors time's <tt>Component::IsoYearCenturyExtendedRange</tt>
        # (<tt>src/format_description/component.rs:47-48</tt>).
        class IsoYearCenturyExtendedRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::IsoYearCenturyExtendedRange that says how to format and parse it.
        end

        # The century of the ISO week-based year. Does not support the
        # extended range.
        #
        # Mirrors time's <tt>Component::IsoYearCenturyStandardRange</tt>
        # (<tt>src/format_description/component.rs:49-50</tt>).
        class IsoYearCenturyStandardRange < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::IsoYearCenturyStandardRange that says how to format and parse it.
        end

        # The last two digits of the calendar year.
        #
        # Mirrors time's <tt>Component::CalendarYearLastTwo</tt>
        # (<tt>src/format_description/component.rs:51-52</tt>).
        class CalendarYearLastTwo < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::CalendarYearLastTwo that says how to format and parse it.
        end

        # The last two digits of the ISO week-based year.
        #
        # Mirrors time's <tt>Component::IsoYearLastTwo</tt>
        # (<tt>src/format_description/component.rs:53-54</tt>).
        class IsoYearLastTwo < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::IsoYearLastTwo that says how to format and parse it.
        end

        # Hour of the day using the 12-hour clock.
        #
        # Mirrors time's <tt>Component::Hour12</tt>
        # (<tt>src/format_description/component.rs:55-56</tt>).
        class Hour12 < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Hour12 that says how to format and parse it.
        end

        # Hour of the day using the 24-hour clock.
        #
        # Mirrors time's <tt>Component::Hour24</tt>
        # (<tt>src/format_description/component.rs:57-58</tt>).
        class Hour24 < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Hour24 that says how to format and parse it.
        end

        # Minute within the hour.
        #
        # Mirrors time's <tt>Component::Minute</tt>
        # (<tt>src/format_description/component.rs:59-60</tt>).
        class Minute < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Minute that says how to format and parse it.
        end

        # AM/PM part of the time.
        #
        # Mirrors time's <tt>Component::Period</tt>
        # (<tt>src/format_description/component.rs:61-62</tt>).
        class Period < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Period that says how to format and parse it.
        end

        # Second within the minute.
        #
        # Mirrors time's <tt>Component::Second</tt>
        # (<tt>src/format_description/component.rs:63-64</tt>).
        class Second < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Second that says how to format and parse it.
        end

        # Subsecond within the second.
        #
        # Mirrors time's <tt>Component::Subsecond</tt>
        # (<tt>src/format_description/component.rs:65-66</tt>).
        class Subsecond < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Subsecond that says how to format and parse it.
        end

        # Hour of the UTC offset.
        #
        # Mirrors time's <tt>Component::OffsetHour</tt>
        # (<tt>src/format_description/component.rs:67-68</tt>).
        class OffsetHour < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::OffsetHour that says how to format and parse it.
        end

        # Minute within the hour of the UTC offset.
        #
        # Mirrors time's <tt>Component::OffsetMinute</tt>
        # (<tt>src/format_description/component.rs:69-70</tt>).
        class OffsetMinute < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::OffsetMinute that says how to format and parse it.
        end

        # Second within the minute of the UTC offset.
        #
        # Mirrors time's <tt>Component::OffsetSecond</tt>
        # (<tt>src/format_description/component.rs:71-72</tt>).
        class OffsetSecond < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::OffsetSecond that says how to format and parse it.
        end

        # A number of bytes to ignore when parsing. This has no effect on
        # formatting.
        #
        # Mirrors time's <tt>Component::Ignore</tt>
        # (<tt>src/format_description/component.rs:73-74</tt>).
        class Ignore < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Ignore that says how to format and parse it.
        end

        # A Unix timestamp in seconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampSecond</tt>
        # (<tt>src/format_description/component.rs:75-76</tt>).
        class UnixTimestampSecond < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::UnixTimestampSecond that says how to format and parse it.
        end

        # A Unix timestamp in milliseconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampMillisecond</tt>
        # (<tt>src/format_description/component.rs:77-78</tt>).
        class UnixTimestampMillisecond < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::UnixTimestampMillisecond that says how to format and parse it.
        end

        # A Unix timestamp in microseconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampMicrosecond</tt>
        # (<tt>src/format_description/component.rs:79-80</tt>).
        class UnixTimestampMicrosecond < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::UnixTimestampMicrosecond that says how to format and parse it.
        end

        # A Unix timestamp in nanoseconds.
        #
        # Mirrors time's <tt>Component::UnixTimestampNanosecond</tt>
        # (<tt>src/format_description/component.rs:81-82</tt>).
        class UnixTimestampNanosecond < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::UnixTimestampNanosecond that says how to format and parse it.
        end

        # The end of input. Parsing this component will fail if there is any
        # input remaining. This component neither affects formatting nor
        # consumes any input when parsing.
        #
        # Mirrors time's <tt>Component::End</tt>
        # (<tt>src/format_description/component.rs:83-85</tt>).
        class End < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::End that says how to format and parse it.
        end

        # Month of the year.
        #
        # Deprecated since time 0.3.48: use +MonthShort+, +MonthLong+, or
        # +MonthNumeric+ instead. Naming it warns, in the :deprecated
        # category, as rustc warns where Rust code names it.
        #
        # Mirrors time's <tt>Component::Month</tt>
        # (<tt>src/format_description/component.rs:90-95</tt>).
        class Month < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Month that says how to format and parse it.
        end

        # Day of the week.
        #
        # Deprecated since time 0.3.48: use +WeekdayShort+, +WeekdayLong+,
        # or +WeekdaySunday+, or +WeekdayMonday+ instead. Naming it warns,
        # in the :deprecated category, as rustc warns where Rust code names
        # it.
        #
        # Mirrors time's <tt>Component::Weekday</tt>
        # (<tt>src/format_description/component.rs:96-101</tt>).
        class Weekday < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Weekday that says how to format and parse it.
        end

        # Week within the year.
        #
        # Deprecated since time 0.3.48: use +WeekNumberIso+,
        # +WeekNumberSunday+, or +WeekNumberMonday+ instead. Naming it
        # warns, in the :deprecated category, as rustc warns where Rust code
        # names it.
        #
        # Mirrors time's <tt>Component::WeekNumber</tt>
        # (<tt>src/format_description/component.rs:102-107</tt>).
        class WeekNumber < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::WeekNumber that says how to format and parse it.
        end

        # Hour of the day.
        #
        # Deprecated since time 0.3.48: use +Hour12+ or +Hour24+ instead.
        # Naming it warns, in the :deprecated category, as rustc warns where
        # Rust code names it.
        #
        # Mirrors time's <tt>Component::Hour</tt>
        # (<tt>src/format_description/component.rs:108-110</tt>).
        class Hour < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Hour that says how to format and parse it.
        end

        # A Unix timestamp.
        #
        # Deprecated since time 0.3.48: use +UnixTimestampSeconds+,
        # +UnixTimestampMilliseconds+, +UnixTimestampMicroseconds+, or
        # +UnixTimestampNanoseconds+ instead. Naming it warns, in the
        # :deprecated category, as rustc warns where Rust code names it.
        #
        # Mirrors time's <tt>Component::UnixTimestamp</tt>
        # (<tt>src/format_description/component.rs:111-117</tt>).
        class UnixTimestamp < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::UnixTimestamp that says how to format and parse it.
        end

        # Year of the date.
        #
        # Deprecated since time 0.3.48: use one of the various
        # <tt>Year*</tt> components instead. Naming it warns, in the
        # :deprecated category, as rustc warns where Rust code names it.
        #
        # Mirrors time's <tt>Component::Year</tt>
        # (<tt>src/format_description/component.rs:118-123</tt>).
        class Year < Data.define(:modifier)
          include Component

          ##
          # :attr_reader: modifier
          # The Modifier::Year that says how to format and parse it.
        end

        # Every variant by name, deprecated ones included, so the gem reaches
        # them without warning. Private to the gem.
        CLASSES = { Day: Day, MonthShort: MonthShort, MonthLong: MonthLong, MonthNumerical: MonthNumerical, Ordinal: Ordinal, WeekdayShort: WeekdayShort, WeekdayLong: WeekdayLong, WeekdaySunday: WeekdaySunday, WeekdayMonday: WeekdayMonday, WeekNumberIso: WeekNumberIso, WeekNumberSunday: WeekNumberSunday, WeekNumberMonday: WeekNumberMonday, CalendarYearFullExtendedRange: CalendarYearFullExtendedRange, CalendarYearFullStandardRange: CalendarYearFullStandardRange, IsoYearFullExtendedRange: IsoYearFullExtendedRange, IsoYearFullStandardRange: IsoYearFullStandardRange, CalendarYearCenturyExtendedRange: CalendarYearCenturyExtendedRange, CalendarYearCenturyStandardRange: CalendarYearCenturyStandardRange, IsoYearCenturyExtendedRange: IsoYearCenturyExtendedRange, IsoYearCenturyStandardRange: IsoYearCenturyStandardRange, CalendarYearLastTwo: CalendarYearLastTwo, IsoYearLastTwo: IsoYearLastTwo, Hour12: Hour12, Hour24: Hour24, Minute: Minute, Period: Period, Second: Second, Subsecond: Subsecond, OffsetHour: OffsetHour, OffsetMinute: OffsetMinute, OffsetSecond: OffsetSecond, Ignore: Ignore, UnixTimestampSecond: UnixTimestampSecond, UnixTimestampMillisecond: UnixTimestampMillisecond, UnixTimestampMicrosecond: UnixTimestampMicrosecond, UnixTimestampNanosecond: UnixTimestampNanosecond, End: End, Month: Month, Weekday: Weekday, WeekNumber: WeekNumber, Hour: Hour, UnixTimestamp: UnixTimestamp, Year: Year }.freeze
        private_constant :CLASSES

        deprecate_constant :Month, :Weekday, :WeekNumber, :Hour, :UnixTimestamp, :Year
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
