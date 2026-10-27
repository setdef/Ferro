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
    # SPDX-SnippetComment: Time, its methods, and their docs from time 0.3.55 src/time.rs
    #++

    # A clock time within a day, to the nanosecond, with no date and no
    # offset.
    #
    # Opening hours, an alarm, a train that leaves at 9:15 every morning: some
    # times belong to no particular day. Ruby's ::Time always carries a date
    # and a zone, so a time of day alone ends up as a String or a count of
    # seconds, and the arithmetic that wraps past midnight is yours to write.
    #
    # A Time is time's +Time+, a value from 0:00 to 23:59:59.999999999. Build
    # one with Time.from_hms and its finer siblings, read its parts, and add
    # or subtract a SignedDuration: the result wraps around midnight, as
    # time's does, and never fails.
    #
    # A Time is frozen and shareable between Ractors. It is not Ruby's
    # ::Time; inside the Ferro namespace, write <tt>::Time</tt> for Ruby's.
    #
    # Mirrors time's +Time+ (<tt>src/time.rs</tt>).
    #
    # === Examples
    #
    #   time = Ferro::Time::Time.from_hms(23, 30, 0)
    #   (time + Ferro::Time::Duration.hours(1)).to_s # => "0:30:00.0"
    #   time.duration_until(Ferro::Time::Time::MIDNIGHT).to_s # => "30m"
    #
    #   Ferro::Time::Time.from_hms(24, 0, 0)
    #   # raises Ferro::Time::Error::ComponentRange: hour was not in range
    class Time
      include Comparable

      class << self
        # Creates a Time from the hour, minute, and second, raising
        # Error::ComponentRange when one is out of range. Mirrors time's
        # <tt>Time::from_hms</tt> (<tt>src/time.rs:179-200</tt>).
        #
        # [hour] Integer, from 0 to 23.
        # [minute] Integer, from 0 to 59.
        # [second] Integer, from 0 to 59.
        #
        # === Example
        #
        #   Ferro::Time::Time.from_hms(1, 2, 3).to_s # => "1:02:03.0"
        def from_hms(hour, minute, second)
          Native.time_from_hms(hour, minute, second)
        end

        # Creates a Time from the hour, minute, second, and millisecond,
        # raising Error::ComponentRange when one is out of range. Mirrors
        # time's <tt>Time::from_hms_milli</tt> (<tt>src/time.rs:219-246</tt>).
        #
        # [hour] Integer, from 0 to 23.
        # [minute] Integer, from 0 to 59.
        # [second] Integer, from 0 to 59.
        # [millisecond] Integer, from 0 to 999.
        #
        # === Example
        #
        #   Ferro::Time::Time.from_hms_milli(1, 2, 3, 4).to_s # => "1:02:03.004"
        def from_hms_milli(hour, minute, second, millisecond)
          Native.time_from_hms_milli(hour, minute, second, millisecond)
        end

        # Creates a Time from the hour, minute, second, and microsecond,
        # raising Error::ComponentRange when one is out of range. Mirrors
        # time's <tt>Time::from_hms_micro</tt> (<tt>src/time.rs:248-275</tt>).
        #
        # [hour] Integer, from 0 to 23.
        # [minute] Integer, from 0 to 59.
        # [second] Integer, from 0 to 59.
        # [microsecond] Integer, from 0 to 999,999.
        #
        # === Example
        #
        #   Ferro::Time::Time.from_hms_micro(1, 2, 3, 4).to_s # => "1:02:03.000004"
        def from_hms_micro(hour, minute, second, microsecond)
          Native.time_from_hms_micro(hour, minute, second, microsecond)
        end

        # Creates a Time from the hour, minute, second, and nanosecond,
        # raising Error::ComponentRange when one is out of range. Mirrors
        # time's <tt>Time::from_hms_nano</tt> (<tt>src/time.rs:277-304</tt>).
        #
        # [hour] Integer, from 0 to 23.
        # [minute] Integer, from 0 to 59.
        # [second] Integer, from 0 to 59.
        # [nanosecond] Integer, from 0 to 999,999,999.
        #
        # === Example
        #
        #   Ferro::Time::Time.from_hms_nano(1, 2, 3, 4).to_s # => "1:02:03.000000004"
        def from_hms_nano(hour, minute, second, nanosecond)
          Native.time_from_hms_nano(hour, minute, second, nanosecond)
        end

        # Parses a Time from +input+ with +description+, which takes the same
        # kinds of description as #format. Raises an Error::Parse variant when
        # the input does not match. Mirrors time's <tt>Time::parse</tt>
        # (<tt>src/time.rs:926-942</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   Ferro::Time::Time.parse("12:30:45", Ferro::Time::FormatDescription::WellKnown::Iso8601::TIME).to_s # => "12:30:45.0"
        def parse(input, description)
          Native.time_parse(input, Arguments.description(description))
        end
      end

      # The Time that is exactly midnight, 0:00. Mirrors time's
      # <tt>Time::MIDNIGHT</tt> (<tt>src/time.rs:129-138</tt>).
      MIDNIGHT = Native.time_constant(:MIDNIGHT)

      # The Time one nanosecond before midnight, 23:59:59.999999999. Mirrors
      # time's <tt>Time::MAX</tt> (<tt>src/time.rs:140-149</tt>).
      MAX = Native.time_constant(:MAX)

      # The clock hour, from 0 to 23. Mirrors time's <tt>Time::hour</tt>
      # (<tt>src/time.rs:382-394</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.hour # => 12
      def hour
        Native.time_int(self, :hour)
      end

      # The minute within the hour, from 0 to 59. Mirrors time's
      # <tt>Time::minute</tt> (<tt>src/time.rs:396-408</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.minute # => 30
      def minute
        Native.time_int(self, :minute)
      end

      # The second within the minute, from 0 to 59. Mirrors time's
      # <tt>Time::second</tt> (<tt>src/time.rs:410-422</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.second # => 45
      def second
        Native.time_int(self, :second)
      end

      # The milliseconds within the second, from 0 to 999. Mirrors time's
      # <tt>Time::millisecond</tt> (<tt>src/time.rs:424-436</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.millisecond # => 123
      def millisecond
        Native.time_int(self, :millisecond)
      end

      # The microseconds within the second, from 0 to 999,999. Mirrors time's
      # <tt>Time::microsecond</tt> (<tt>src/time.rs:438-450</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.microsecond # => 123_456
      def microsecond
        Native.time_int(self, :microsecond)
      end

      # The nanoseconds within the second, from 0 to 999,999,999. Mirrors
      # time's <tt>Time::nanosecond</tt> (<tt>src/time.rs:452-464</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.nanosecond # => 123_456_789
      def nanosecond
        Native.time_int(self, :nanosecond)
      end

      # The clock hour, minute, and second. An Array for Rust's tuple. Mirrors
      # time's <tt>Time::as_hms</tt> (<tt>src/time.rs:306-316</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.as_hms # => [12, 30, 45]
      def as_hms
        Native.time_ints(self, :as_hms)
      end

      # The clock hour, minute, second, and millisecond. An Array for Rust's
      # tuple. Mirrors time's <tt>Time::as_hms_milli</tt>
      # (<tt>src/time.rs:318-333</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.as_hms_milli # => [12, 30, 45, 123]
      def as_hms_milli
        Native.time_ints(self, :as_hms_milli)
      end

      # The clock hour, minute, second, and microsecond. An Array for Rust's
      # tuple. Mirrors time's <tt>Time::as_hms_micro</tt>
      # (<tt>src/time.rs:335-353</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.as_hms_micro # => [12, 30, 45, 123_456]
      def as_hms_micro
        Native.time_ints(self, :as_hms_micro)
      end

      # The clock hour, minute, second, and nanosecond. An Array for Rust's
      # tuple. Mirrors time's <tt>Time::as_hms_nano</tt>
      # (<tt>src/time.rs:355-373</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.as_hms_nano # => [12, 30, 45, 123_456_789]
      def as_hms_nano
        Native.time_ints(self, :as_hms_nano)
      end

      # The span from this time forward to +other+, always from zero up to one
      # day, wrapping past midnight when +other+ is earlier in the day.
      # Mirrors time's <tt>Time::duration_until</tt>
      # (<tt>src/time.rs:466-526</tt>).
      #
      # [other] Time.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.duration_until(Ferro::Time::Time.from_hms(13, 0, 0)).to_s # => "29m14s876ms543µs211ns"
      def duration_until(other)
        Native.time_between(self, :duration_until, other)
      end

      # The span from +other+ forward to this time, always from zero up to one
      # day, wrapping past midnight when +other+ is later in the day. Mirrors
      # time's <tt>Time::duration_since</tt> (<tt>src/time.rs:528-540</tt>).
      #
      # [other] Time.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.duration_since(Ferro::Time::Time.from_hms(12, 0, 0)).to_s # => "30m45s123ms456µs789ns"
      def duration_since(other)
        Native.time_between(self, :duration_since, other)
      end

      # Replaces the clock hour. Raises Error::ComponentRange outside 0 to 23.
      # Mirrors time's <tt>Time::replace_hour</tt>
      # (<tt>src/time.rs:684-699</tt>).
      #
      # [hour] Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.replace_hour(7).hour # => 7
      #   time.replace_hour(24) # raises Ferro::Time::Error::ComponentRange
      def replace_hour(hour)
        Native.time_replace(self, :replace_hour, hour)
      end

      # Replaces the minutes within the hour. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's <tt>Time::replace_minute</tt>
      # (<tt>src/time.rs:716-731</tt>).
      #
      # [minute] Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.replace_minute(7).minute # => 7
      #   time.replace_minute(60) # raises Ferro::Time::Error::ComponentRange
      def replace_minute(minute)
        Native.time_replace(self, :replace_minute, minute)
      end

      # Replaces the seconds within the minute. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's <tt>Time::replace_second</tt>
      # (<tt>src/time.rs:750-765</tt>).
      #
      # [second] Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.replace_second(7).second # => 7
      #   time.replace_second(60) # raises Ferro::Time::Error::ComponentRange
      def replace_second(second)
        Native.time_replace(self, :replace_second, second)
      end

      # Replaces the milliseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999. Mirrors time's
      # <tt>Time::replace_millisecond</tt> (<tt>src/time.rs:783-806</tt>).
      #
      # [millisecond] Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.replace_millisecond(7).nanosecond # => 7_000_000
      #   time.replace_millisecond(1_000) # raises Ferro::Time::Error::ComponentRange
      def replace_millisecond(millisecond)
        Native.time_replace(self, :replace_millisecond, millisecond)
      end

      # Replaces the microseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999. Mirrors time's
      # <tt>Time::replace_microsecond</tt> (<tt>src/time.rs:828-851</tt>).
      #
      # [microsecond] Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.replace_microsecond(7).nanosecond # => 7_000
      #   time.replace_microsecond(1_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_microsecond(microsecond)
        Native.time_replace(self, :replace_microsecond, microsecond)
      end

      # Replaces the nanoseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999,999. Mirrors time's
      # <tt>Time::replace_nanosecond</tt> (<tt>src/time.rs:872-894</tt>).
      #
      # [nanosecond] Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.replace_nanosecond(7).nanosecond # => 7
      #   time.replace_nanosecond(1_000_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_nanosecond(nanosecond)
        Native.time_replace(self, :replace_nanosecond, nanosecond)
      end

      # The value with every component finer than the hour set to zero.
      # Mirrors time's <tt>Time::truncate_to_hour</tt>
      # (<tt>src/time.rs:701-714</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.truncate_to_hour.as_hms_nano # => [12, 0, 0, 0]
      def truncate_to_hour
        Native.time_truncate(self, :truncate_to_hour)
      end

      # The value with every component finer than the minute set to zero.
      # Mirrors time's <tt>Time::truncate_to_minute</tt>
      # (<tt>src/time.rs:733-748</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.truncate_to_minute.as_hms_nano # => [12, 30, 0, 0]
      def truncate_to_minute
        Native.time_truncate(self, :truncate_to_minute)
      end

      # The value with every component finer than the second set to zero.
      # Mirrors time's <tt>Time::truncate_to_second</tt>
      # (<tt>src/time.rs:767-781</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.truncate_to_second.as_hms_nano # => [12, 30, 45, 0]
      def truncate_to_second
        Native.time_truncate(self, :truncate_to_second)
      end

      # The value with every component finer than the millisecond set to zero.
      # Mirrors time's <tt>Time::truncate_to_millisecond</tt>
      # (<tt>src/time.rs:808-826</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.truncate_to_millisecond.as_hms_nano # => [12, 30, 45, 123_000_000]
      def truncate_to_millisecond
        Native.time_truncate(self, :truncate_to_millisecond)
      end

      # The value with every component finer than the microsecond set to zero.
      # Mirrors time's <tt>Time::truncate_to_microsecond</tt>
      # (<tt>src/time.rs:853-870</tt>).
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.truncate_to_microsecond.as_hms_nano # => [12, 30, 45, 123_456_000]
      def truncate_to_microsecond
        Native.time_truncate(self, :truncate_to_microsecond)
      end

      # Adds the part of +duration+ shorter than a day, wrapping past
      # midnight, as time's <tt>Add<SignedDuration></tt> does. It never fails.
      # Ruby's <tt>+=</tt> works through it. Mirrors time's
      # <tt>Add<SignedDuration> for Time</tt>
      # (<tt>src/time.rs:1086-1101</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   (Ferro::Time::Time.from_hms(12, 0, 0) + Ferro::Time::Duration.hours(2)).to_s # => "14:00:00.0"
      #   (Ferro::Time::Time.from_hms(0, 0, 1) + Ferro::Time::Duration.seconds(-2)).to_s # => "23:59:59.0"
      def +(duration)
        Native.time_arith(self, :+, Arguments.duration(duration))
      end

      # Subtracts the part of a SignedDuration shorter than a day, wrapping
      # past midnight, as time's <tt>Sub<SignedDuration></tt> does; or, given
      # another Time, returns the signed span between the two within one day,
      # as <tt>Sub for Time</tt> does. Mirrors time's <tt>Sub for Time</tt>
      # (<tt>src/time.rs:1134-1225</tt>).
      #
      # [other] SignedDuration or Time.
      #
      # === Example
      #
      #   (Ferro::Time::Time.from_hms(1, 0, 0) - Ferro::Time::Duration.hours(2)).to_s # => "23:00:00.0"
      #   (Ferro::Time::Time.from_hms(0, 0, 0) - Ferro::Time::Time.from_hms(1, 0, 0)).to_s # => "-1h"
      def -(other)
        case other
        when SignedDuration then Native.time_arith(self, :-, other)
        when Time then Native.time_between(self, :-, other)
        else raise TypeError, "no implicit conversion of #{other.class} into Ferro::Time::SignedDuration"
        end
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. Raises an Error::Format variant
      # when a component cannot be formatted, and +TypeError+ when a
      # well-known format needs a component this type lacks, which Rust's
      # compiler refuses. Mirrors time's <tt>Time::format</tt>
      # (<tt>src/time.rs:909-921</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.format(Ferro::Time::FormatDescription::WellKnown::Iso8601::TIME) # => "12:30:45.123456789"
      def format(description)
        Native.time_format(self, Arguments.description(description))
      end

      # Formats the value with +description+ onto the end of +output+ and
      # returns the count time's +format_into+ returns, which is the number of
      # bytes written except where time leaves some out, as it does for the
      # digits of a fraction of a second in RFC 3339 and for an ISO 8601 hour
      # or minute with a decimal fraction. Rust writes to any
      # <tt>io::Write</tt>; here +output+ is a String, which keeps what time
      # wrote even when formatting fails partway, as Rust's writer does. A
      # frozen +output+ raises +FrozenError+ before anything is formatted.
      # Mirrors time's <tt>Time::format_into</tt>
      # (<tt>src/time.rs:899-907</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   output = +"on "
      #   time.format_into(output, Ferro::Time::FormatDescription::WellKnown::Iso8601::TIME) # => 18
      #   output # => "on 12:30:45.123456789"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.time_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # Whether +other+ is the same Time, by time's +PartialEq+. +false+ for
      # anything else.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time == Ferro::Time::Time::MAX # => false
      #   time == time # => true
      def ==(other)
        other.is_a?(Time) && Native.time_eq(self, other)
      end

      # Whether +other+ is an equal Time, as time's +Eq+ says, so that equal
      # values are the same Hash key.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.eql?(time) # => true
      def eql?(other)
        other.is_a?(Time) && Native.time_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.hash == time.hash # => true
      def hash
        Native.time_hash(self)
      end

      # Compares with another Time by time's +Ord+, so the Comparable
      # operators answer as Rust's do; +nil+ for anything else.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time <=> Ferro::Time::Time::MAX # => -1
      def <=>(other)
        Native.time_cmp(self, other) if other.is_a?(Time)
      end

      # The value as time's +Display+ writes it.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.to_s # => "12:30:45.123456789"
      def to_s
        Native.time_display(self)
      end

      # The value as time's +Debug+ writes it.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.inspect # => "12:30:45.123456789"
      def inspect
        Native.time_debug(self)
      end

      # The value itself. A Time is +Copy+ in Rust and frozen here, so a copy
      # would be the same value; Ruby answers the same way for an Integer.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.dup.equal?(time) # => true
      def dup
        self
      end

      # The value itself, as #dup is. Asking for an unfrozen clone raises
      # +ArgumentError+, as it does for an Integer, since every value is
      # frozen.
      #
      # [freeze] +true+, +false+, or +nil+, as Object#clone takes it.
      #
      # === Example
      #
      #   time = Ferro::Time::Time.from_hms_nano(12, 30, 45, 123_456_789)
      #   time.clone.equal?(time) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::Time" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
