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
    # SPDX-SnippetComment: Weekday, its methods, and their docs from time 0.3.55
    #   src/weekday.rs
    #++

    # Days of the week.
    #
    # Whether Sunday is day 0, day 1, or day 7 depends on who is counting,
    # and code that passes weekdays around as Integers mixes the counts up.
    #
    # Weekday has seven frozen instances, Weekday::Monday to
    # Weekday::Sunday, which step forward and back and give each of time's
    # four numberings by name. As order is dependent on context (Sunday
    # could be either two days after or five days before Friday), Weekday
    # does not compare with <tt><</tt> or <tt>></tt>, as time derives no
    # +Ord+ for it.
    #
    # Mirrors time's +Weekday+ (<tt>src/weekday.rs:12-247</tt>). Step with
    # #next and #previous, or cycle through the week with Weekday.iter_from.
    #
    # === Examples
    #
    #   Ferro::Time::Weekday::Sunday.next # => Ferro::Time::Weekday::Monday
    #   Ferro::Time::Weekday::Sunday.number_days_from_sunday # => 0
    #   Ferro::Time::Weekday::Sunday.number_from_monday # => 7
    class Weekday
      private_class_method :new

      # Parses a weekday from its English name, exactly as time's +Display+
      # writes it, raising Error::InvalidVariant for anything else. Mirrors
      # time's <tt>FromStr for Weekday</tt> (<tt>src/weekday.rs:231-247</tt>).
      #
      # [text] String.
      #
      # === Example
      #
      #   Ferro::Time::Weekday.from_str("Monday") # => Ferro::Time::Weekday::Monday
      #   Ferro::Time::Weekday.from_str("Mon") # raises Ferro::Time::Error::InvalidVariant
      def self.from_str(text)
        Arguments.weekday_of(Native.weekday_from_str(text))
      end

      # Create an infinite iterator starting at +start+, an
      # Iter::WeekdayIter. Mirrors time's <tt>Weekday::iter_from</tt>
      # (<tt>src/weekday.rs:172-192</tt>).
      #
      # [start] Weekday.
      #
      # === Example
      #
      #   iter = Ferro::Time::Weekday.iter_from(Ferro::Time::Weekday::Monday)
      #   iter.first(8).last # => Ferro::Time::Weekday::Monday
      #   iter.next # => Ferro::Time::Weekday::Monday
      #   iter.next # => Ferro::Time::Weekday::Tuesday
      #   # ... continuing forever
      def self.iter_from(start)
        Iter::WeekdayIter.new(start)
      end

      # Creates the weekday +days_from_monday+ days after Monday. The
      # constants are the only instances.
      #
      # [days_from_monday] Integer, from 0 to 6.
      # [name] Symbol, the variant's name.
      def initialize(days_from_monday, name)
        @days_from_monday = days_from_monday
        @name = name
        freeze
      end

      # The previous weekday. Mirrors time's <tt>Weekday::previous</tt>
      # (<tt>src/weekday.rs:36-53</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.previous # => Ferro::Time::Weekday::Sunday
      def previous
        Arguments.weekday_of(Native.weekday_step(@days_from_monday, :previous, 0))
      end

      # The next weekday. Mirrors time's <tt>Weekday::next</tt>
      # (<tt>src/weekday.rs:55-72</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Sunday.next # => Ferro::Time::Weekday::Monday
      def next
        Arguments.weekday_of(Native.weekday_step(@days_from_monday, :next, 0))
      end

      # The weekday +n+ days after this one, wrapping around the week.
      # Mirrors time's <tt>Weekday::nth_next</tt> (<tt>src/weekday.rs:74-95</tt>).
      #
      # [n] Integer, from 0 to 255.
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.nth_next(1) # => Ferro::Time::Weekday::Tuesday
      #   Ferro::Time::Weekday::Sunday.nth_next(10) # => Ferro::Time::Weekday::Wednesday
      def nth_next(n)
        Arguments.weekday_of(Native.weekday_step(@days_from_monday, :nth_next, n))
      end

      # The weekday +n+ days before this one, wrapping around the week.
      # Mirrors time's <tt>Weekday::nth_prev</tt> (<tt>src/weekday.rs:97-118</tt>).
      #
      # [n] Integer, from 0 to 255.
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.nth_prev(1) # => Ferro::Time::Weekday::Sunday
      #   Ferro::Time::Weekday::Sunday.nth_prev(10) # => Ferro::Time::Weekday::Thursday
      def nth_prev(n)
        Arguments.weekday_of(Native.weekday_step(@days_from_monday, :nth_prev, n))
      end

      # The one-indexed number of days from Monday: Monday is 1. Mirrors
      # time's <tt>Weekday::number_from_monday</tt>
      # (<tt>src/weekday.rs:120-130</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.number_from_monday # => 1
      def number_from_monday
        Native.weekday_number(@days_from_monday, :number_from_monday)
      end

      # The one-indexed number of days from Sunday: Sunday is 1. Mirrors
      # time's <tt>Weekday::number_from_sunday</tt>
      # (<tt>src/weekday.rs:132-141</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.number_from_sunday # => 2
      def number_from_sunday
        Native.weekday_number(@days_from_monday, :number_from_sunday)
      end

      # The weekday's integer value, Rust's <tt>weekday as u8</tt>: Weekday is
      # <tt>#[repr(u8)]</tt> and fieldless, so Monday is 0 and Sunday 6, and
      # Ruby's own conversion to an Integer stands in for Rust's +as+, which
      # has no name to keep (ADR 001, 2026-11-05). Mirrors time's
      # <tt>Weekday</tt> (<tt>src/weekday.rs:16-33</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Sunday.to_i # => 6
      def to_i
        Native.weekday_to_i(@days_from_monday)
      end

      # The zero-indexed number of days from Monday: Monday is 0. Mirrors
      # time's <tt>Weekday::number_days_from_monday</tt>
      # (<tt>src/weekday.rs:143-152</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.number_days_from_monday # => 0
      def number_days_from_monday
        Native.weekday_number(@days_from_monday, :number_days_from_monday)
      end

      # The zero-indexed number of days from Sunday: Sunday is 0. Mirrors
      # time's <tt>Weekday::number_days_from_sunday</tt>
      # (<tt>src/weekday.rs:154-171</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Monday.number_days_from_sunday # => 1
      def number_days_from_sunday
        Native.weekday_number(@days_from_monday, :number_days_from_sunday)
      end

      # The weekday's English name, as time's +Display+ writes it
      # (<tt>src/weekday.rs:194-229</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Friday.to_s # => "Friday"
      def to_s
        Native.weekday_display(@days_from_monday)
      end

      # time's derived +Debug+ text for this weekday, formatted by Rust:
      # the variant's name. +inspect+ stays Ruby's (ADR 001, 2026-11-05). Mirrors time's derived +Debug+
      # for +Weekday+ (<tt>src/weekday.rs:12</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Weekday::Friday.debug # => "Friday"
      def debug
        Native.weekday_debug(@days_from_monday)
      end

      # The days from Monday, for the native layer.
      private attr_reader :days_from_monday

      # Monday.
      Monday = new(0, :Monday)
      # Tuesday.
      Tuesday = new(1, :Tuesday)
      # Wednesday.
      Wednesday = new(2, :Wednesday)
      # Thursday.
      Thursday = new(3, :Thursday)
      # Friday.
      Friday = new(4, :Friday)
      # Saturday.
      Saturday = new(5, :Saturday)
      # Sunday.
      Sunday = new(6, :Sunday)

      # Every weekday from Monday, for the gem to find one by its days from
      # Monday.
      ALL = [Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday].freeze
      private_constant :ALL
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
