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
    # SPDX-SnippetComment: Month, its methods, and their docs from time 0.3.55
    #   src/month.rs
    #++

    # Months of the year.
    #
    # A month is more than a number from 1 to 12: it has a length that
    # depends on the year, a name, and neighbors that wrap from December to
    # January. Passing bare Integers around invites off-by-one months and
    # thirteenth months.
    #
    # Month has twelve frozen instances, Month::January to Month::December.
    # Each knows its length in a year, steps forward and back, and prints
    # its English name. Months compare in calendar order, as time's derived
    # +Ord+ does, which assumes the months are in the same year.
    #
    # Mirrors time's +Month+ (<tt>src/month.rs:13-292</tt>). Its +iter_from+
    # and the +MonthIter+ it returns are deferred with the +iter+ module
    # (plan 007, decision 1); step with #next and #previous.
    #
    # === Examples
    #
    #   Ferro::Time::Month::February.length(2020) # => 29
    #   Ferro::Time::Month::December.next # => Ferro::Time::Month::January
    #   Ferro::Time::Month.from_str("March").to_i # => 3
    class Month
      include Comparable

      private_class_method :new

      class << self
        # Parses a month from its English name, exactly as time's +Display+
        # writes it, raising Error::InvalidVariant for anything else.
        # Mirrors time's <tt>FromStr for Month</tt> (<tt>src/month.rs:252-273</tt>).
        #
        # [text] String.
        #
        # === Example
        #
        #   Ferro::Time::Month.from_str("January") # => Ferro::Time::Month::January
        #   Ferro::Time::Month.from_str("january") # raises Ferro::Time::Error::InvalidVariant
        def from_str(text)
          Arguments.month_of(Native.month_from_str(text))
        end

        # The month numbered +value+, from 1 for January to 12 for December,
        # raising Error::ComponentRange for any other number. Mirrors time's
        # <tt>TryFrom<u8> for Month</tt> (<tt>src/month.rs:282-292</tt>).
        #
        # [value] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Month.try_from(12) # => Ferro::Time::Month::December
        #   Ferro::Time::Month.try_from(13) # raises Ferro::Time::Error::ComponentRange
        def try_from(value)
          Arguments.month_of(Native.month_try_from(value))
        end
      end

      # Creates the month numbered +number+. The constants are the only
      # instances.
      #
      # [number] Integer, from 1 to 12.
      # [name] Symbol, the variant's name.
      def initialize(number, name)
        @number = number
        @name = name
        freeze
      end

      # The number of days in the month of +year+.
      #
      # Mirrors time's <tt>Month::length</tt> (<tt>src/month.rs:64-73</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Month::February.length(2020) # => 29
      #   Ferro::Time::Month::February.length(2021) # => 28
      def length(year)
        Native.month_length(@number, year)
      end

      # The previous month. Mirrors time's <tt>Month::previous</tt>
      # (<tt>src/month.rs:75-97</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Month::January.previous # => Ferro::Time::Month::December
      def previous
        Arguments.month_of(Native.month_step(@number, :previous, 0))
      end

      # The next month. Mirrors time's <tt>Month::next</tt>
      # (<tt>src/month.rs:99-121</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Month::January.next # => Ferro::Time::Month::February
      def next
        Arguments.month_of(Native.month_step(@number, :next, 0))
      end

      # The month +n+ months after this one, wrapping around the year.
      # Mirrors time's <tt>Month::nth_next</tt> (<tt>src/month.rs:123-149</tt>).
      #
      # [n] Integer, from 0 to 255.
      #
      # === Example
      #
      #   Ferro::Time::Month::January.nth_next(4) # => Ferro::Time::Month::May
      #   Ferro::Time::Month::July.nth_next(9) # => Ferro::Time::Month::April
      def nth_next(n)
        Arguments.month_of(Native.month_step(@number, :nth_next, n))
      end

      # The month +n+ months before this one, wrapping around the year.
      # Mirrors time's <tt>Month::nth_prev</tt> (<tt>src/month.rs:151-177</tt>).
      #
      # [n] Integer, from 0 to 255.
      #
      # === Example
      #
      #   Ferro::Time::Month::January.nth_prev(4) # => Ferro::Time::Month::September
      #   Ferro::Time::Month::July.nth_prev(9) # => Ferro::Time::Month::October
      def nth_prev(n)
        Arguments.month_of(Native.month_step(@number, :nth_prev, n))
      end

      # The month's number, from 1 for January to 12 for December. Mirrors
      # time's <tt>From<Month> for u8</tt> (<tt>src/month.rs:275-280</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Month::March.to_i # => 3
      def to_i
        @number
      end

      # Compares months in calendar order, as time's derived +Ord+ does;
      # +nil+ for anything but a Month.
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::Time::Month::March < Ferro::Time::Month::April # => true
      def <=>(other)
        @number <=> other.to_i if other.is_a?(Month)
      end

      # The month's English name, as time's +Display+ writes it
      # (<tt>src/month.rs:205-250</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Month::March.to_s # => "March"
      def to_s
        Native.month_display(@number)
      end

      # The constant that holds this month.
      #
      # === Example
      #
      #   Ferro::Time::Month::March.inspect # => "Ferro::Time::Month::March"
      def inspect
        "Ferro::Time::Month::#{@name}"
      end

      # January.
      January = new(1, :January)
      # February.
      February = new(2, :February)
      # March.
      March = new(3, :March)
      # April.
      April = new(4, :April)
      # May.
      May = new(5, :May)
      # June.
      June = new(6, :June)
      # July.
      July = new(7, :July)
      # August.
      August = new(8, :August)
      # September.
      September = new(9, :September)
      # October.
      October = new(10, :October)
      # November.
      November = new(11, :November)
      # December.
      December = new(12, :December)

      # Every month, in calendar order, for the gem to find a month by
      # number.
      ALL = [January, February, March, April, May, June, July, August, September, October, November, December].freeze
      private_constant :ALL
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
