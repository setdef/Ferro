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
    # SPDX-SnippetComment: Timestamp, its methods, and their docs from time 0.3.55 src/timestamp.rs and src/interop
    #++

    # An instant: seconds and nanoseconds since the Unix epoch, in UTC.
    #
    # A Timestamp is the cheapest instant time offers. It holds two numbers
    # and works out the date and clock time only when asked, so code that
    # stores, orders, and subtracts instants, and rarely names their dates,
    # does less work than with a UtcDateTime. It ranges over the same
    # instants as UtcDateTime, from <tt>-9999-01-01 0:00</tt> to
    # <tt>9999-12-31 23:59:59.999999999</tt>.
    #
    # Build one with Timestamp.new, a <tt>from_*</tt> constructor,
    # Timestamp.now, or Timestamp.from a UtcDateTime, an OffsetDateTime, or
    # Ruby's ::Time. Convert it with #to_utc, #to_offset, or #to_time, and
    # compare and subtract it with those types, as time's impls between
    # them do.
    #
    # A Timestamp is frozen and shareable between Ractors.
    #
    # Mirrors time's +Timestamp+ (<tt>src/timestamp.rs</tt>). time's
    # <tt>timestamp!</tt> macro checks its input when Rust compiles; its
    # run-time counterparts are Timestamp.new and Timestamp.from a
    # UtcDateTime (plan 007, decision 15).
    #
    # === Examples
    #
    #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
    #   at.to_s # => "1546398245.006007008"
    #   at.to_utc.to_s # => "2019-01-02 3:04:05.006007008 +00"
    #   at.weekday # => Ferro::Time::Weekday::Wednesday
    #
    #   at == Ferro::Time::UtcDateTime.from_unix_timestamp_nanos(1_546_398_245_006_007_008) # => true
    class Timestamp
      include Comparable

      class << self
        # The current instant, from the system clock. Where Rust panics
        # because the clock is past the supported range, this raises
        # +RangeError+ with time's message. Mirrors time's
        # <tt>Timestamp::now</tt> (<tt>src/timestamp.rs:136</tt>).
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.now.year >= 2019 # => true
        def now
          Native.timestamp_now
        end

        # Creates a Timestamp from whole Unix seconds and the nanoseconds
        # after them, raising Error::ComponentRange when either is out of
        # range. The nanoseconds count forward from the seconds, so half a
        # second before the epoch is <tt>new(-1, 500_000_000)</tt>. Mirrors
        # time's <tt>Timestamp::new</tt> (<tt>src/timestamp.rs:179</tt>).
        #
        # [seconds] Integer, seconds since the epoch.
        # [nanoseconds] Integer, 0 to 999,999,999.
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.new(1, 5).as_nanoseconds # => 1_000_000_005
        #   Ferro::Time::Timestamp.new(-1, 500_000_000).as_nanoseconds # => -500_000_000
        def new(seconds, nanoseconds)
          Native.timestamp_new(seconds, nanoseconds)
        end

        # Creates a Timestamp from whole Unix seconds, raising
        # Error::ComponentRange when they are out of range. Mirrors time's
        # <tt>Timestamp::from_seconds</tt> (<tt>src/timestamp.rs:195</tt>).
        #
        # [seconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.from_seconds(-1).as_seconds # => -1
        def from_seconds(seconds)
          Native.timestamp_from_seconds(seconds)
        end

        # Creates a Timestamp from Unix milliseconds, raising
        # Error::ComponentRange when they are out of range. Mirrors time's
        # <tt>Timestamp::from_milliseconds</tt> (<tt>src/timestamp.rs:211</tt>).
        #
        # [milliseconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.from_milliseconds(-500).as_nanoseconds # => -500_000_000
        def from_milliseconds(milliseconds)
          Native.timestamp_from_milliseconds(milliseconds)
        end

        # Creates a Timestamp from Unix microseconds, raising
        # Error::ComponentRange when they are out of range. Mirrors time's
        # <tt>Timestamp::from_microseconds</tt> (<tt>src/timestamp.rs:240</tt>).
        #
        # [microseconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.from_microseconds(1_500_000).as_nanoseconds # => 1_500_000_000
        def from_microseconds(microseconds)
          Native.timestamp_from_microseconds(microseconds)
        end

        # Creates a Timestamp from Unix nanoseconds, raising
        # Error::ComponentRange when they are out of range. Mirrors time's
        # <tt>Timestamp::from_nanoseconds</tt> (<tt>src/timestamp.rs:269</tt>).
        #
        # [nanoseconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.from_nanoseconds(-1).as_nanoseconds # => -1
        def from_nanoseconds(nanoseconds)
          Native.timestamp_from_nanoseconds(nanoseconds)
        end

        # Converts a UtcDateTime or an OffsetDateTime, as time's +From+
        # impls do, or Ruby's ::Time, as <tt>From<SystemTime></tt> does (plan
        # 007, decision 10). A ::Time keeps its seconds and nanoseconds since
        # the epoch and drops any finer fraction; on Windows, where a
        # SystemTime counts whole 100 ns intervals, it keeps only those (plan
        # 007, decision 10). Where Rust panics because
        # the result is outside the supported range (an OffsetDateTime whose
        # offset puts its instant past the range, or a ::Time past it), this
        # raises +RangeError+ with time's message. Mirrors time's
        # <tt>From<UtcDateTime> for Timestamp</tt>, <tt>From<OffsetDateTime>
        # for Timestamp</tt>, and <tt>From<SystemTime> for Timestamp</tt>
        # (<tt>src/interop/timestamp_utcdatetime.rs:60-72,
        # src/interop/offsetdatetime_timestamp.rs:63-78,
        # src/interop/systemdatetime_timestamp.rs:67-86</tt>).
        #
        # [value] UtcDateTime, OffsetDateTime, or ::Time.
        #
        # === Example
        #
        #   Ferro::Time::Timestamp.from(::Time.at(1_546_398_245)).as_seconds # => 1_546_398_245
        #   Ferro::Time::Timestamp.from(Ferro::Time::UtcDateTime::UNIX_EPOCH) == Ferro::Time::Timestamp::UNIX_EPOCH # => true
        def from(value)
          case value
          when UtcDateTime then Native.timestamp_from_utc(value)
          when OffsetDateTime then Native.timestamp_from_offset_date_time(value)
          when ::Time
            seconds, nanoseconds = Arguments.system_time(value)
            Native.timestamp_from_system_time(seconds, nanoseconds)
          else raise TypeError, "no implicit conversion of #{value.class} into Ferro::Time::Timestamp"
          end
        end

        # Parses a Timestamp from +input+ with +description+, which takes
        # the same kinds of description as #format. Raises an Error::Parse
        # variant when the input does not match. Where Rust panics because
        # the date, time, and offset the input names leave the supported
        # range, this raises +RangeError+ with time's message. Mirrors
        # time's <tt>Timestamp::parse</tt> (<tt>src/timestamp.rs:1340</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   unix = Ferro::Time::FormatDescription.parse_owned(3, "[unix_timestamp]")
        #   Ferro::Time::Timestamp.parse("1546398245", unix).as_seconds # => 1_546_398_245
        def parse(input, description)
          Native.timestamp_parse(input, Arguments.description(description))
        end

        # Parses a Timestamp from +input+ with +description+, as parse does,
        # but starting from +defaults+ rather than from nothing: a component
        # the input lacks keeps the value +defaults+ gives it. +defaults+ is
        # not changed. Mirrors time's <tt>Timestamp::parse_with_defaults</tt>
        # (<tt>src/timestamp.rs:1363</tt>).
        #
        # [input] String, read as bytes, as Rust's <tt>&[u8]</tt>.
        # [description] A format description.
        # [defaults] Parsing::Parsed.
        #
        # === Example
        #
        #   defaults = Ferro::Time::Parsing::Parsed.new
        #   defaults.set_year(2019)
        #   defaults.set_ordinal(2)
        #   defaults.set_hour_24(3)
        #   defaults.set_minute(4)
        #   defaults.set_second(5)
        #   description = Ferro::Time::FormatDescription.parse_owned(3, "[subsecond]")
        #   Ferro::Time::Timestamp.parse_with_defaults("5", description, defaults).as_nanoseconds # => 1_546_398_245_500_000_000
        def parse_with_defaults(input, description, defaults)
          Native.timestamp_parse_with_defaults(input, Arguments.description(description), Arguments.parsed(defaults))
        end

        # The Timestamp that +parsed+ describes, raising an
        # Error::TryFromParsed variant when it lacks a component the
        # Timestamp needs or holds one out of range. A Unix timestamp in
        # +parsed+ is the answer; without one, the date, time, and offset
        # give a UtcDateTime, and the Timestamp is its instant. Where Rust
        # panics because that UtcDateTime leaves the supported range, this
        # raises +RangeError+ with time's message. Mirrors time's
        # <tt>TryFrom<Parsed> for Timestamp</tt>
        # (<tt>src/parsing/parsed.rs:1395-1410</tt>).
        #
        # [parsed] Parsing::Parsed.
        #
        # === Example
        #
        #   parsed = Ferro::Time::Parsing::Parsed.new
        #   parsed.set_unix_timestamp_nanos(1_546_398_245_006_007_008)
        #   Ferro::Time::Timestamp.try_from(parsed).as_nanoseconds # => 1_546_398_245_006_007_008
        def try_from(parsed)
          Native.timestamp_try_from_parsed(Arguments.parsed(parsed))
        end
      end

      # The Unix epoch, midnight on January 1, 1970 UTC. Mirrors time's
      # <tt>Timestamp::UNIX_EPOCH</tt> (<tt>src/timestamp.rs:113</tt>).
      UNIX_EPOCH = Native.timestamp_constant(:UNIX_EPOCH)

      # The smallest value that can be represented by Timestamp, the same
      # instant as UtcDateTime::MIN. Mirrors time's <tt>Timestamp::MIN</tt>
      # (<tt>src/timestamp.rs:120</tt>).
      MIN = Native.timestamp_constant(:MIN)

      # The largest value that can be represented by Timestamp, the same
      # instant as UtcDateTime::MAX. Mirrors time's <tt>Timestamp::MAX</tt>
      # (<tt>src/timestamp.rs:126</tt>).
      MAX = Native.timestamp_constant(:MAX)

      # The same instant in +offset+. Where Rust panics because the local
      # date and time leave the supported range, this raises +RangeError+
      # with time's message, "local datetime out of valid range". Mirrors
      # time's <tt>Timestamp::to_offset</tt> (<tt>src/timestamp.rs:302</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 0)
      #   at.to_offset(Ferro::Time::UtcOffset.from_hms(1, 0, 0)).hour # => 4
      def to_offset(offset)
        Native.timestamp_to_offset(self, :to_offset, offset)
      end

      # The same instant in +offset+, or +nil+ when the local date and time
      # leave the supported range. Mirrors time's
      # <tt>Timestamp::checked_to_offset</tt>
      # (<tt>src/timestamp.rs:318</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp::MAX.checked_to_offset(Ferro::Time::UtcOffset.from_hms(1, 0, 0)) # => nil
      def checked_to_offset(offset)
        Native.timestamp_to_offset(self, :checked_to_offset, offset)
      end

      # The same instant as a UtcDateTime. Mirrors time's
      # <tt>Timestamp::to_utc</tt> (<tt>src/timestamp.rs:329</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).to_utc.to_s # => "2019-01-02 3:04:05.0 +00"
      def to_utc
        Native.timestamp_to_utc(self)
      end

      # The UTC date component. Mirrors time's <tt>Timestamp::date</tt>
      # (<tt>src/timestamp.rs:417</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).date.to_s # => "2019-01-02"
      def date
        Native.timestamp_date(self)
      end

      # The UTC clock time component. Mirrors time's <tt>Timestamp::time</tt>
      # (<tt>src/timestamp.rs:428</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).time.to_s # => "3:04:05.0"
      def time
        Native.timestamp_time(self)
      end

      # The whole seconds since the epoch. Mirrors time's
      # <tt>Timestamp::as_seconds</tt> (<tt>src/timestamp.rs:355</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_seconds # => 1_546_398_245
      def as_seconds
        Native.timestamp_int(self, :as_seconds)
      end

      # The whole milliseconds since the epoch, dropping any finer fraction. Mirrors time's
      # <tt>Timestamp::as_milliseconds</tt> (<tt>src/timestamp.rs:371</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_milliseconds # => 1_546_398_245_006
      def as_milliseconds
        Native.timestamp_int(self, :as_milliseconds)
      end

      # The whole microseconds since the epoch, dropping any finer fraction. Mirrors time's
      # <tt>Timestamp::as_microseconds</tt> (<tt>src/timestamp.rs:388</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_microseconds # => 1_546_398_245_006_007
      def as_microseconds
        Native.timestamp_int(self, :as_microseconds)
      end

      # The nanoseconds since the epoch. Mirrors time's
      # <tt>Timestamp::as_nanoseconds</tt> (<tt>src/timestamp.rs:405</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_nanoseconds # => 1_546_398_245_006_007_008
      def as_nanoseconds
        Native.timestamp_int(self, :as_nanoseconds)
      end

      # The year of the UTC date. Mirrors time's
      # <tt>Timestamp::year</tt> (<tt>src/timestamp.rs:489</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.year # => 2019
      def year
        Native.timestamp_int(self, :year)
      end

      # The month of the UTC date, as a Month. Mirrors time's
      # <tt>Timestamp::month</tt> (<tt>src/timestamp.rs:501</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.month # => Ferro::Time::Month::January
      def month
        Arguments.month_of(Native.timestamp_int(self, :month))
      end

      # The day of the month of the UTC date. Mirrors time's
      # <tt>Timestamp::day</tt> (<tt>src/timestamp.rs:515</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.day # => 2
      def day
        Native.timestamp_int(self, :day)
      end

      # The day of the year of the UTC date. Mirrors time's
      # <tt>Timestamp::ordinal</tt> (<tt>src/timestamp.rs:529</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.ordinal # => 2
      def ordinal
        Native.timestamp_int(self, :ordinal)
      end

      # The ISO week number of the UTC date. Mirrors time's
      # <tt>Timestamp::iso_week</tt> (<tt>src/timestamp.rs:542</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.iso_week # => 1
      def iso_week
        Native.timestamp_int(self, :iso_week)
      end

      # The week number of the UTC date, counting weeks from Sunday. Mirrors time's
      # <tt>Timestamp::sunday_based_week</tt> (<tt>src/timestamp.rs:555</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.sunday_based_week # => 0
      def sunday_based_week
        Native.timestamp_int(self, :sunday_based_week)
      end

      # The week number of the UTC date, counting weeks from Monday. Mirrors time's
      # <tt>Timestamp::monday_based_week</tt> (<tt>src/timestamp.rs:568</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.monday_based_week # => 0
      def monday_based_week
        Native.timestamp_int(self, :monday_based_week)
      end

      # The year, month, and day of the UTC date, as an Array with the month as a Month. Mirrors time's
      # <tt>Timestamp::to_calendar_date</tt> (<tt>src/timestamp.rs:583</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.to_calendar_date # => [2019, Ferro::Time::Month::January, 2]
      def to_calendar_date
        Arguments.calendar_date(Native.timestamp_ints(self, :to_calendar_date))
      end

      # The year and day of the year of the UTC date, as an Array. Mirrors time's
      # <tt>Timestamp::to_ordinal_date</tt> (<tt>src/timestamp.rs:596</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.to_ordinal_date # => [2019, 2]
      def to_ordinal_date
        Native.timestamp_ints(self, :to_ordinal_date)
      end

      # The ISO year, ISO week, and weekday of the UTC date, as an Array with the weekday as a Weekday. Mirrors time's
      # <tt>Timestamp::to_iso_week_date</tt> (<tt>src/timestamp.rs:612</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.to_iso_week_date # => [2019, 1, Ferro::Time::Weekday::Wednesday]
      def to_iso_week_date
        Arguments.iso_week_date(Native.timestamp_ints(self, :to_iso_week_date))
      end

      # The day of the week of the UTC date, as a Weekday. Mirrors time's
      # <tt>Timestamp::weekday</tt> (<tt>src/timestamp.rs:624</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.weekday # => Ferro::Time::Weekday::Wednesday
      def weekday
        Arguments.weekday_of(Native.timestamp_int(self, :weekday))
      end

      # The Julian day of the UTC date. Mirrors time's
      # <tt>Timestamp::to_julian_day</tt> (<tt>src/timestamp.rs:649</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.to_julian_day # => 2_458_486
      def to_julian_day
        Native.timestamp_int(self, :to_julian_day)
      end

      # The hour, minute, and second of the UTC clock time, as an Array. Mirrors time's
      # <tt>Timestamp::as_hms</tt> (<tt>src/timestamp.rs:661</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_hms # => [3, 4, 5]
      def as_hms
        Native.timestamp_ints(self, :as_hms)
      end

      # The hour, minute, second, and millisecond of the UTC clock time, as an Array. Mirrors time's
      # <tt>Timestamp::as_hms_milli</tt> (<tt>src/timestamp.rs:672</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_hms_milli # => [3, 4, 5, 6]
      def as_hms_milli
        Native.timestamp_ints(self, :as_hms_milli)
      end

      # The hour, minute, second, and microsecond of the UTC clock time, as an Array. Mirrors time's
      # <tt>Timestamp::as_hms_micro</tt> (<tt>src/timestamp.rs:686</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_hms_micro # => [3, 4, 5, 6_007]
      def as_hms_micro
        Native.timestamp_ints(self, :as_hms_micro)
      end

      # The hour, minute, second, and nanosecond of the UTC clock time, as an Array. Mirrors time's
      # <tt>Timestamp::as_hms_nano</tt> (<tt>src/timestamp.rs:700</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.as_hms_nano # => [3, 4, 5, 6_007_008]
      def as_hms_nano
        Native.timestamp_ints(self, :as_hms_nano)
      end

      # The hour of the UTC clock time. Mirrors time's
      # <tt>Timestamp::hour</tt> (<tt>src/timestamp.rs:711</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.hour # => 3
      def hour
        Native.timestamp_int(self, :hour)
      end

      # The minute of the UTC clock time. Mirrors time's
      # <tt>Timestamp::minute</tt> (<tt>src/timestamp.rs:722</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.minute # => 4
      def minute
        Native.timestamp_int(self, :minute)
      end

      # The second of the UTC clock time. Mirrors time's
      # <tt>Timestamp::second</tt> (<tt>src/timestamp.rs:734</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.second # => 5
      def second
        Native.timestamp_int(self, :second)
      end

      # The millisecond of the UTC clock time. Mirrors time's
      # <tt>Timestamp::millisecond</tt> (<tt>src/timestamp.rs:745</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.millisecond # => 6
      def millisecond
        Native.timestamp_int(self, :millisecond)
      end

      # The microsecond of the UTC clock time. Mirrors time's
      # <tt>Timestamp::microsecond</tt> (<tt>src/timestamp.rs:756</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.microsecond # => 6_007
      def microsecond
        Native.timestamp_int(self, :microsecond)
      end

      # The nanosecond of the UTC clock time. Mirrors time's
      # <tt>Timestamp::nanosecond</tt> (<tt>src/timestamp.rs:770</tt>).
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008)
      #   at.nanosecond # => 6_007_008
      def nanosecond
        Native.timestamp_int(self, :nanosecond)
      end

      # Adds a SignedDuration, or returns +nil+ when the result is out of
      # range. Mirrors time's <tt>Timestamp::checked_add</tt>
      # (<tt>src/timestamp.rs:930</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp::MAX.checked_add(Ferro::Time::Duration::NANOSECOND) # => nil
      def checked_add(duration)
        Native.timestamp_arith(self, :checked_add, Arguments.duration(duration))
      end

      # Subtracts a SignedDuration, or returns +nil+ when the result is out
      # of range. Mirrors time's <tt>Timestamp::checked_sub</tt>
      # (<tt>src/timestamp.rs:952</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp::MIN.checked_sub(Ferro::Time::Duration::NANOSECOND) # => nil
      def checked_sub(duration)
        Native.timestamp_arith(self, :checked_sub, Arguments.duration(duration))
      end

      # Adds a SignedDuration, stopping at MIN or MAX. Mirrors time's
      # <tt>Timestamp::saturating_add</tt> (<tt>src/timestamp.rs:975</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp::MAX.saturating_add(Ferro::Time::Duration::DAY) == Ferro::Time::Timestamp::MAX # => true
      def saturating_add(duration)
        Native.timestamp_arith(self, :saturating_add, Arguments.duration(duration))
      end

      # Subtracts a SignedDuration, stopping at MIN or MAX. Mirrors time's
      # <tt>Timestamp::saturating_sub</tt> (<tt>src/timestamp.rs:999</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp::MIN.saturating_sub(Ferro::Time::Duration::DAY) == Ferro::Time::Timestamp::MIN # => true
      def saturating_sub(duration)
        Native.timestamp_arith(self, :saturating_sub, Arguments.duration(duration))
      end

      # Replaces the UTC clock time, keeping the date. Mirrors time's
      # <tt>Timestamp::replace_time</tt> (<tt>src/timestamp.rs:1021</tt>).
      #
      # [time] Time.
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(-1, 0)
      #   at.replace_time(Ferro::Time::Time::MIDNIGHT).as_seconds # => -86_400
      def replace_time(time)
        Native.timestamp_replace_time(self, time)
      end

      # Replaces the UTC date, keeping the clock time. Mirrors time's
      # <tt>Timestamp::replace_date</tt> (<tt>src/timestamp.rs:1045</tt>).
      #
      # [date] Date.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2020, Ferro::Time::Month::January, 2)
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_date(date).as_seconds # => 1_577_934_245
      def replace_date(date)
        Native.timestamp_replace_date(self, date)
      end

      # Replaces the year, raising Error::ComponentRange when it is out of
      # range or the date does not exist in it. Mirrors time's
      # <tt>Timestamp::replace_year</tt> (<tt>src/timestamp.rs:1071</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_year(2020).as_seconds # => 1_577_934_245
      def replace_year(year)
        Native.timestamp_replace(self, :replace_year, year)
      end

      # Replaces the month, raising Error::ComponentRange when the date
      # does not exist in it. Mirrors time's <tt>Timestamp::replace_month</tt>
      # (<tt>src/timestamp.rs:1094</tt>).
      #
      # [month] Month.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_month(Ferro::Time::Month::February).as_seconds # => 1_549_076_645
      def replace_month(month)
        Native.timestamp_replace(self, :replace_month, Arguments.month(month))
      end

      # Replaces the day of the month, raising Error::ComponentRange when it
      # is out of range for the month. Mirrors time's
      # <tt>Timestamp::replace_day</tt> (<tt>src/timestamp.rs:1112</tt>).
      #
      # [day] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_day(1).as_seconds # => 1_546_311_845
      def replace_day(day)
        Native.timestamp_replace(self, :replace_day, day)
      end

      # Replaces the day of the year, raising Error::ComponentRange when it
      # is out of range for the year. Mirrors time's
      # <tt>Timestamp::replace_ordinal</tt> (<tt>src/timestamp.rs:1130</tt>).
      #
      # [ordinal] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_ordinal(1).as_seconds # => 1_546_311_845
      def replace_ordinal(ordinal)
        Native.timestamp_replace(self, :replace_ordinal, ordinal)
      end

      # Replaces the hour, raising Error::ComponentRange when it is not 0
      # to 23. Mirrors time's <tt>Timestamp::replace_hour</tt>
      # (<tt>src/timestamp.rs:1147</tt>).
      #
      # [hour] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_hour(0).as_seconds # => 1_546_387_445
      def replace_hour(hour)
        Native.timestamp_replace(self, :replace_hour, hour)
      end

      # Replaces the minute, raising Error::ComponentRange when it is not 0
      # to 59. Mirrors time's <tt>Timestamp::replace_minute</tt>
      # (<tt>src/timestamp.rs:1171</tt>).
      #
      # [minute] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_minute(0).as_seconds # => 1_546_398_005
      def replace_minute(minute)
        Native.timestamp_replace(self, :replace_minute, minute)
      end

      # Replaces the second, raising Error::ComponentRange when it is not 0
      # to 59. Mirrors time's <tt>Timestamp::replace_second</tt>
      # (<tt>src/timestamp.rs:1194</tt>).
      #
      # [second] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_second(0).as_seconds # => 1_546_398_240
      def replace_second(second)
        Native.timestamp_replace(self, :replace_second, second)
      end

      # Replaces the millisecond, raising Error::ComponentRange when it is
      # not 0 to 999. Mirrors time's <tt>Timestamp::replace_millisecond</tt>
      # (<tt>src/timestamp.rs:1220</tt>).
      #
      # Before the epoch, an instant with a fraction has the fraction
      # replaced as its decimal text writes it (-1.5 with 400 ms is -1.4);
      # a whole second or an instant after the epoch is replaced as a clock
      # is.
      #
      # [millisecond] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 6_000_000).replace_millisecond(7).as_nanoseconds # => 1_546_398_245_007_000_000
      def replace_millisecond(millisecond)
        Native.timestamp_replace(self, :replace_millisecond, millisecond)
      end

      # Replaces the microsecond, raising Error::ComponentRange when it is
      # not 0 to 999,999. Mirrors time's <tt>Timestamp::replace_microsecond</tt>
      # (<tt>src/timestamp.rs:1245</tt>).
      #
      # Before the epoch, an instant with a fraction has the fraction
      # replaced as its decimal text writes it (-1.5 with 400 ms is -1.4);
      # a whole second or an instant after the epoch is replaced as a clock
      # is.
      #
      # [microsecond] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_microsecond(123_456).as_nanoseconds # => 1_546_398_245_123_456_000
      def replace_microsecond(microsecond)
        Native.timestamp_replace(self, :replace_microsecond, microsecond)
      end

      # Replaces the nanosecond, raising Error::ComponentRange when it is
      # not 0 to 999,999,999. Mirrors time's <tt>Timestamp::replace_nanosecond</tt>
      # (<tt>src/timestamp.rs:1270</tt>).
      #
      # Before the epoch, an instant with a fraction has the fraction
      # replaced as its decimal text writes it (-1.5 with 400 ms is -1.4);
      # a whole second or an instant after the epoch is replaced as a clock
      # is.
      #
      # [nanosecond] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).replace_nanosecond(5).as_nanoseconds # => 1_546_398_245_000_000_005
      def replace_nanosecond(nanosecond)
        Native.timestamp_replace(self, :replace_nanosecond, nanosecond)
      end

      # Adds a SignedDuration, raising +RangeError+ with time's message,
      # "resulting value is out of range", where Rust panics. Mirrors time's
      # <tt>Add<SignedDuration> for Timestamp</tt>
      # (<tt>src/timestamp.rs:1450-1462</tt>); the <tt>AddAssign</tt> impls
      # are Ruby's <tt>+=</tt>, and std's +Duration+ waits with the rest of
      # its operations (plan 010, decision 16).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   (Ferro::Time::Timestamp::UNIX_EPOCH + Ferro::Time::Duration::DAY).as_seconds # => 86_400
      def +(duration)
        Native.timestamp_arith(self, :+, Arguments.duration(duration))
      end

      # Subtracts a SignedDuration, raising +RangeError+ with time's message,
      # "resulting value is out of range", where Rust panics; or returns the
      # span from +other+ to this instant, given a Timestamp, a UtcDateTime,
      # an OffsetDateTime, or Ruby's ::Time, as time's <tt>Sub</tt> impls do.
      # Ruby's own <tt>::Time#-</tt> is unchanged, so <tt>time - timestamp</tt>
      # stays Ruby's. Where Rust panics because a ::Time lies so far from the
      # epoch that the span leaves a SignedDuration, this raises
      # +RangeError+ with time's message. Mirrors time's <tt>Sub</tt> impls
      # for Timestamp (<tt>src/timestamp.rs:1499-1561,
      # src/interop/timestamp_utcdatetime.rs:6-16,
      # src/interop/offsetdatetime_timestamp.rs:9-19,
      # src/interop/systemdatetime_timestamp.rs:12-23</tt>).
      #
      # [other] SignedDuration, Timestamp, UtcDateTime, OffsetDateTime, or ::Time.
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1_546_398_245, 0)
      #   (at - Ferro::Time::Duration::DAY).as_seconds # => 1_546_311_845
      #   (at - Ferro::Time::Timestamp.new(1_546_311_845, 0)).to_s # => "1d"
      def -(other)
        case other
        when SignedDuration then Native.timestamp_arith(self, :-, other)
        when Timestamp then Native.timestamp_difference(self, other)
        when UtcDateTime then Native.timestamp_with_utc(self, :-, other)
        when OffsetDateTime then Native.timestamp_with_offset_date_time(self, :-, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.timestamp_with_system_time(self, :-, seconds, nanoseconds)
        else raise TypeError, "no implicit conversion of #{other.class} into Ferro::Time::SignedDuration"
        end
      end

      # Whether +other+ is the same instant: a Timestamp, a UtcDateTime, an
      # OffsetDateTime, or Ruby's ::Time, by time's +PartialEq+ impls.
      # +false+ for anything else. Ruby's own <tt>::Time#<=></tt> asks the
      # other value when it is not a ::Time (<tt>time.c:3987</tt> at Ruby
      # v4.0.9), so <tt>time == timestamp</tt> answers through this method
      # too, as time's impls with +SystemTime+ on the left do. Mirrors time's
      # <tt>PartialEq for Timestamp</tt> (<tt>src/timestamp.rs:82,
      # src/interop/timestamp_utcdatetime.rs, src/interop/offsetdatetime_timestamp.rs,
      # src/interop/systemdatetime_timestamp.rs</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(0, 0)
      #   at == Ferro::Time::UtcDateTime::UNIX_EPOCH # => true
      #   at == ::Time.at(0) # => true
      #   at == 0 # => false
      def ==(other)
        case other
        when Timestamp then Native.timestamp_eq(self, other)
        when UtcDateTime then Native.timestamp_with_utc(self, :==, other)
        when OffsetDateTime then Native.timestamp_with_offset_date_time(self, :==, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.timestamp_with_system_time(self, :==, seconds, nanoseconds)
        else false
        end
      end

      # Whether +other+ is an equal Timestamp, as time's +Eq+ says, so equal
      # values are the same Hash key. Unlike #==, a value of another type is
      # never +eql?+.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp::UNIX_EPOCH.eql?(Ferro::Time::Timestamp.new(0, 0)) # => true
      #   Ferro::Time::Timestamp::UNIX_EPOCH.eql?(Ferro::Time::UtcDateTime::UNIX_EPOCH) # => false
      def eql?(other)
        other.is_a?(Timestamp) && Native.timestamp_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1, 2).hash == Ferro::Time::Timestamp.new(1, 2).hash # => true
      def hash
        Native.timestamp_hash(self)
      end

      # Orders by instant against a Timestamp, a UtcDateTime, an
      # OffsetDateTime, or Ruby's ::Time, by time's +Ord+ and +PartialOrd+
      # impls, so the Comparable operators answer as Rust's do; +nil+ for
      # anything else. Ruby's <tt>::Time#<=></tt> asks this method in turn,
      # so <tt>time < timestamp</tt> works too. Mirrors time's
      # <tt>PartialOrd for Timestamp</tt> (<tt>src/timestamp.rs:89-101,
      # src/interop/timestamp_utcdatetime.rs, src/interop/offsetdatetime_timestamp.rs,
      # src/interop/systemdatetime_timestamp.rs</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1, 0) <=> Ferro::Time::Timestamp::UNIX_EPOCH # => 1
      #   Ferro::Time::Timestamp::UNIX_EPOCH < ::Time.at(1) # => true
      def <=>(other)
        case other
        when Timestamp then Native.timestamp_cmp(self, other)
        when UtcDateTime then Native.timestamp_with_utc(self, :<=>, other)
        when OffsetDateTime then Native.timestamp_with_offset_date_time(self, :<=>, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.timestamp_with_system_time(self, :<=>, seconds, nanoseconds)
        end
      end

      # The same instant as Ruby's ::Time, in UTC, as time's
      # <tt>From<Timestamp> for SystemTime</tt> does (plan 007, decision 10).
      # Where std panics because a SystemTime cannot hold the instant (on
      # Windows, before 1601), this raises +RangeError+ with std's message.
      # On Windows the ::Time keeps only whole 100 ns intervals of the
      # nanoseconds, as a SystemTime does (plan 007, decision 10). Mirrors
      # time's <tt>From<Timestamp> for SystemTime</tt>
      # (<tt>src/interop/systemdatetime_timestamp.rs:88-97</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).to_time.to_i # => 1_546_398_245
      def to_time
        Arguments.ruby_time(Native.timestamp_to_system_time(self))
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. A Timestamp supplies a date, a
      # clock time, an offset of UTC, and a Unix timestamp. Raises an
      # Error::Format variant when a component cannot be formatted. Mirrors
      # time's <tt>Timestamp::format</tt> (<tt>src/timestamp.rs:1319</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).format(Ferro::Time::FormatDescription::WellKnown::Rfc3339) # => "2019-01-02T03:04:05Z"
      def format(description)
        Native.timestamp_format(self, Arguments.description(description))
      end

      # Formats the value into +output+, appending to it, and returns the
      # number of bytes written. What time wrote before a failure stays in
      # +output+, as it does in Rust's writer, and the failure is raised.
      # Mirrors time's <tt>Timestamp::format_into</tt>
      # (<tt>src/timestamp.rs:1302</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   output = +"at "
      #   unix = Ferro::Time::FormatDescription.parse_owned(3, "[unix_timestamp]")
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).format_into(output, unix) # => 10
      #   output # => "at 1546398245"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.timestamp_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # The value as time's +Display+ writes it: the seconds, then the
      # nanoseconds as a fraction without trailing zeros.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 6_007_008).to_s # => "1546398245.006007008"
      #   Ferro::Time::Timestamp.new(-1, 500_000_000).to_s # => "-0.5"
      def to_s
        Native.timestamp_display(self)
      end

      # The value as time's +Debug+ writes it, which is its +Display+.
      #
      # === Example
      #
      #   Ferro::Time::Timestamp.new(1_546_398_245, 0).inspect # => "1546398245"
      def inspect
        Native.timestamp_debug(self)
      end

      # The value itself. A Timestamp is +Copy+ in Rust and frozen here, so
      # a copy would be the same value; Ruby answers the same way for an
      # Integer.
      #
      # === Example
      #
      #   at = Ferro::Time::Timestamp.new(1, 0)
      #   at.dup.equal?(at) # => true
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
      #   at = Ferro::Time::Timestamp.new(1, 0)
      #   at.clone.equal?(at) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::Timestamp" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
