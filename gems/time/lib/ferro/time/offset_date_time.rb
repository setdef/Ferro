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
    # SPDX-SnippetComment: OffsetDateTime, its methods, and their docs from time 0.3.55 src/offset_date_time.rs and src/interop
    #++

    # A date and a clock time with an offset from UTC: an instant, as a place
    # reads it.
    #
    # The string <tt>2019-01-01T12:30:45-05:00</tt> names one instant and how
    # a clock five hours behind UTC showed it. Code that schedules, logs, or
    # exchanges times with other systems needs both halves, and needs to
    # compare two such values by instant, not by their printed digits.
    #
    # An OffsetDateTime is time's +OffsetDateTime+. Build one from a
    # PlainDateTime with an offset, a Unix timestamp, OffsetDateTime.now_utc,
    # or by parsing RFC 3339, RFC 2822, ISO 8601, or your own description;
    # move it to another offset with #to_offset; read its local parts. Two
    # values compare, order, and hash by instant, as time's do, so
    # <tt>12:00 +00</tt> and <tt>13:00 +01</tt> are equal.
    #
    # An OffsetDateTime is frozen and shareable between Ractors. Ruby's own
    # ::Time converts both ways, through OffsetDateTime.from and #to_time,
    # as time's conversions with +SystemTime+ do.
    #
    # Mirrors time's +OffsetDateTime+ (<tt>src/offset_date_time.rs</tt>).
    #
    # === Examples
    #
    #   rfc3339 = Ferro::Time::FormatDescription::WellKnown::Rfc3339
    #   at = Ferro::Time::OffsetDateTime.parse("1985-04-12T23:20:50.52Z", rfc3339)
    #   at.to_offset(Ferro::Time::UtcOffset.from_hms(2, 0, 0)).format(rfc3339)
    #   # => "1985-04-13T01:20:50.52+02:00"
    #
    #   Ferro::Time::OffsetDateTime.parse("2019-13-01T00:00:00Z", rfc3339)
    #   # raises Ferro::Time::Error::Parse::TryFromParsed::ComponentRange: month was not in range
    class OffsetDateTime
      include Comparable

      class << self
        # The current date and time in UTC, from the system clock. Mirrors
        # time's <tt>OffsetDateTime::now_utc</tt>
        # (<tt>src/offset_date_time.rs:95-121</tt>).
        #
        # === Example
        #
        #   Ferro::Time::OffsetDateTime.now_utc.offset.is_utc # => true
        def now_utc
          Native.offset_date_time_now_utc
        end

        # The current date and time in the system's local offset, raising
        # Error::IndeterminateOffset when the offset cannot be determined
        # (plan 007, decision 13). Mirrors time's
        # <tt>OffsetDateTime::now_local</tt>
        # (<tt>src/offset_date_time.rs:123-137</tt>).
        #
        # === Example
        #
        #   Ferro::Time::OffsetDateTime.now_local.offset.whole_seconds # => ::Time.now.utc_offset
        def now_local
          Native.offset_date_time_now_local
        end

        # Creates an OffsetDateTime from a Date, a Time, and the UtcOffset
        # they are read in. Mirrors time's
        # <tt>OffsetDateTime::new_in_offset</tt>
        # (<tt>src/offset_date_time.rs:139-158</tt>).
        #
        # [date] Date.
        # [time] Time.
        # [offset] UtcOffset.
        #
        # === Example
        #
        #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
        #   Ferro::Time::OffsetDateTime.new_in_offset(date, Ferro::Time::Time::MIDNIGHT, Ferro::Time::UtcOffset.from_hms(1, 0, 0))
        #     .unix_timestamp # => 1_546_297_200
        def new_in_offset(date, time, offset)
          Native.offset_date_time_new_in_offset(date, time, offset)
        end

        # Creates an OffsetDateTime from a Date and a Time in UTC. Mirrors
        # time's <tt>OffsetDateTime::new_utc</tt>
        # (<tt>src/offset_date_time.rs:160-175</tt>).
        #
        # [date] Date.
        # [time] Time.
        #
        # === Example
        #
        #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
        #   Ferro::Time::OffsetDateTime.new_utc(date, Ferro::Time::Time::MIDNIGHT).unix_timestamp # => 1_546_300_800
        def new_utc(date, time)
          Native.offset_date_time_new_utc(date, time)
        end

        # Creates an OffsetDateTime in UTC from a Unix timestamp in seconds,
        # raising Error::ComponentRange when the result is outside the
        # supported range. Mirrors time's
        # <tt>OffsetDateTime::from_unix_timestamp</tt>
        # (<tt>src/offset_date_time.rs:409-471</tt>).
        #
        # [timestamp] Integer, seconds since the epoch.
        #
        # === Example
        #
        #   Ferro::Time::OffsetDateTime.from_unix_timestamp(0) == Ferro::Time::OffsetDateTime::UNIX_EPOCH # => true
        def from_unix_timestamp(timestamp)
          Native.offset_date_time_from_unix_timestamp(timestamp)
        end

        # Creates an OffsetDateTime in UTC from a Unix timestamp in
        # nanoseconds, raising Error::ComponentRange when the result is
        # outside the supported range. Mirrors time's
        # <tt>OffsetDateTime::from_unix_timestamp_nanos</tt>
        # (<tt>src/offset_date_time.rs:473-515</tt>).
        #
        # [timestamp] Integer, nanoseconds since the epoch.
        #
        # === Example
        #
        #   Ferro::Time::OffsetDateTime.from_unix_timestamp_nanos(1_546_300_800_000_000_001).nanosecond # => 1
        def from_unix_timestamp_nanos(timestamp)
          Native.offset_date_time_from_unix_timestamp_nanos(timestamp)
        end

        # Converts a UtcDateTime, as time's <tt>From<UtcDateTime></tt> does,
        # or Ruby's ::Time, as <tt>From<SystemTime></tt> does (plan 007,
        # decision 10); the result is in UTC. A ::Time keeps its seconds and
        # nanoseconds since the epoch and drops any finer fraction. Where Rust
        # panics because the result is outside the supported range, this
        # raises +RangeError+ with time's message. Mirrors time's
        # <tt>From<UtcDateTime> for OffsetDateTime</tt>
        # (<tt>src/interop/offsetdatetime_utcdatetime.rs:71-82,
        # src/interop/offsetdatetime_systemtime.rs:59-67</tt>).
        #
        # [value] UtcDateTime or ::Time.
        #
        # === Example
        #
        #   Ferro::Time::OffsetDateTime.from(::Time.at(0, in: "+09:00")) == Ferro::Time::OffsetDateTime::UNIX_EPOCH # => true
        def from(value)
          case value
          when UtcDateTime then Native.offset_date_time_from_utc(value)
          when ::Time
            seconds, nanoseconds = Arguments.system_time(value)
            Native.offset_date_time_from_system_time(seconds, nanoseconds)
          else raise TypeError, "no implicit conversion of #{value.class} into Ferro::Time::OffsetDateTime"
          end
        end

        # Parses a OffsetDateTime from +input+ with +description+, which takes
        # the same kinds of description as #format. Raises an Error::Parse
        # variant when the input does not match. Mirrors time's
        # <tt>OffsetDateTime::parse</tt>
        # (<tt>src/offset_date_time.rs:1533-1555</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   Ferro::Time::OffsetDateTime.parse("Tue, 01 Jan 2019 12:30:45 -0500", Ferro::Time::FormatDescription::WellKnown::Rfc2822).to_s # => "2019-01-01 12:30:45.0 -05:00:00"
        def parse(input, description)
          Native.offset_date_time_parse(input, Arguments.description(description))
        end
      end

      # Midnight, January 1, 1970, in UTC. Mirrors time's
      # <tt>OffsetDateTime::UNIX_EPOCH</tt>
      # (<tt>src/offset_date_time.rs:85-93</tt>).
      UNIX_EPOCH = Native.offset_date_time_constant(:UNIX_EPOCH)

      # The same instant in +offset+. Where Rust panics because the local date
      # and time leave the supported range, this raises +RangeError+ with
      # time's message, "local datetime out of valid range". Mirrors time's
      # <tt>OffsetDateTime::to_offset</tt>
      # (<tt>src/offset_date_time.rs:177-207</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_offset(Ferro::Time::UtcOffset::UTC).hour # => 17
      def to_offset(offset)
        Native.offset_date_time_to_offset(self, :to_offset, offset)
      end

      # The same instant in +offset+, or +nil+ when the local date and time
      # leave the supported range. Mirrors time's
      # <tt>OffsetDateTime::checked_to_offset</tt>
      # (<tt>src/offset_date_time.rs:209-247</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MAX.assume_utc.checked_to_offset(Ferro::Time::UtcOffset.from_hms(1, 0, 0)) # => nil
      def checked_to_offset(offset)
        Native.offset_date_time_to_offset(self, :checked_to_offset, offset)
      end

      # The same instant as a UtcDateTime. Where Rust panics because the date
      # and time in UTC leave the supported range, this raises +RangeError+
      # with time's message, "local datetime out of valid range". Mirrors
      # time's <tt>OffsetDateTime::to_utc</tt>
      # (<tt>src/offset_date_time.rs:249-270</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_utc.to_s # => "2019-01-01 17:30:45.123456789 +00"
      def to_utc
        Native.offset_date_time_to_utc(self, :to_utc)
      end

      # The same instant as a UtcDateTime, or +nil+ when it leaves the
      # supported range. Mirrors time's
      # <tt>OffsetDateTime::checked_to_utc</tt>
      # (<tt>src/offset_date_time.rs:293-313</tt>).
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MAX.assume_offset(Ferro::Time::UtcOffset.from_hms(-1, 0, 0)).checked_to_utc # => nil
      def checked_to_utc
        Native.offset_date_time_to_utc(self, :checked_to_utc)
      end

      # The offset from UTC. Mirrors time's <tt>OffsetDateTime::offset</tt>
      # (<tt>src/offset_date_time.rs:517-527</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.offset.to_s # => "-05:00:00"
      def offset
        Native.offset_date_time_offset(self)
      end

      # The Unix timestamp: whole seconds since the epoch. Mirrors time's
      # <tt>OffsetDateTime::unix_timestamp</tt>
      # (<tt>src/offset_date_time.rs:529-545</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.unix_timestamp # => 1_546_363_845
      def unix_timestamp
        Native.offset_date_time_int(self, :unix_timestamp)
      end

      # The Unix timestamp in nanoseconds. Mirrors time's
      # <tt>OffsetDateTime::unix_timestamp_nanos</tt>
      # (<tt>src/offset_date_time.rs:547-561</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.unix_timestamp_nanos # => 1_546_363_845_123_456_789
      def unix_timestamp_nanos
        Native.offset_date_time_int(self, :unix_timestamp_nanos)
      end

      # The date component. Mirrors time's <tt>OffsetDateTime::date</tt>
      # (<tt>src/offset_date_time.rs:569-584</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.date.to_s # => "2019-01-01"
      def date
        Native.offset_date_time_date(self)
      end

      # The clock time component. Mirrors time's <tt>OffsetDateTime::time</tt>
      # (<tt>src/offset_date_time.rs:586-601</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.time.to_s # => "12:30:45.123456789"
      def time
        Native.offset_date_time_time(self)
      end

      # The year of the date. Mirrors time's <tt>OffsetDateTime::year</tt>
      # (<tt>src/offset_date_time.rs:603-619</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.year # => 2019
      def year
        Native.offset_date_time_int(self, :year)
      end

      # The month. Mirrors time's <tt>OffsetDateTime::month</tt>
      # (<tt>src/offset_date_time.rs:621-637</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.month # => Ferro::Time::Month::January
      def month
        Arguments.month_of(Native.offset_date_time_int(self, :month))
      end

      # The day of the month, from 1 to 31. Mirrors time's
      # <tt>OffsetDateTime::day</tt>
      # (<tt>src/offset_date_time.rs:639-656</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.day # => 1
      def day
        Native.offset_date_time_int(self, :day)
      end

      # The day of the year, from 1 to 366 (1 to 365 in a common year).
      # Mirrors time's <tt>OffsetDateTime::ordinal</tt>
      # (<tt>src/offset_date_time.rs:658-675</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.ordinal # => 1
      def ordinal
        Native.offset_date_time_int(self, :ordinal)
      end

      # The ISO week number, from 1 to 53. The first ISO week of a year is the
      # week containing its first Thursday, so a date in early January or late
      # December may belong to a week of the next or previous ISO year.
      # Mirrors time's <tt>OffsetDateTime::iso_week</tt>
      # (<tt>src/offset_date_time.rs:677-691</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.iso_week # => 1
      def iso_week
        Native.offset_date_time_int(self, :iso_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Sunday
      # of the calendar year. Mirrors time's
      # <tt>OffsetDateTime::sunday_based_week</tt>
      # (<tt>src/offset_date_time.rs:693-707</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.sunday_based_week # => 0
      def sunday_based_week
        Native.offset_date_time_int(self, :sunday_based_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Monday
      # of the calendar year. Mirrors time's
      # <tt>OffsetDateTime::monday_based_week</tt>
      # (<tt>src/offset_date_time.rs:709-723</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.monday_based_week # => 0
      def monday_based_week
        Native.offset_date_time_int(self, :monday_based_week)
      end

      # The year, month, and day, as a three-element Array for Rust's tuple.
      # Mirrors time's <tt>OffsetDateTime::to_calendar_date</tt>
      # (<tt>src/offset_date_time.rs:725-738</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_calendar_date # => [2019, Ferro::Time::Month::January, 1]
      def to_calendar_date
        Arguments.calendar_date(Native.offset_date_time_ints(self, :to_calendar_date))
      end

      # The year and the day of the year, as a two-element Array for Rust's
      # tuple. Mirrors time's <tt>OffsetDateTime::to_ordinal_date</tt>
      # (<tt>src/offset_date_time.rs:740-752</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_ordinal_date # => [2019, 1]
      def to_ordinal_date
        Native.offset_date_time_ints(self, :to_ordinal_date)
      end

      # The ISO year, ISO week number, and weekday, as a three-element Array
      # for Rust's tuple. The ISO year may differ from #year near the turn of
      # a year. Mirrors time's <tt>OffsetDateTime::to_iso_week_date</tt>
      # (<tt>src/offset_date_time.rs:754-783</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_iso_week_date # => [2019, 1, Ferro::Time::Weekday::Tuesday]
      def to_iso_week_date
        Arguments.iso_week_date(Native.offset_date_time_ints(self, :to_iso_week_date))
      end

      # The day of the week. Mirrors time's <tt>OffsetDateTime::weekday</tt>
      # (<tt>src/offset_date_time.rs:785-797</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.weekday # => Ferro::Time::Weekday::Tuesday
      def weekday
        Arguments.weekday_of(Native.offset_date_time_int(self, :weekday))
      end

      # The Julian day number: the days since noon UTC on November 24 of 4714
      # BC in the proleptic Gregorian calendar, day 0. Mirrors time's
      # <tt>OffsetDateTime::to_julian_day</tt>
      # (<tt>src/offset_date_time.rs:799-811</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_julian_day # => 2_458_485
      def to_julian_day
        Native.offset_date_time_int(self, :to_julian_day)
      end

      # The clock hour, from 0 to 23. Mirrors time's
      # <tt>OffsetDateTime::hour</tt>
      # (<tt>src/offset_date_time.rs:879-896</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.hour # => 12
      def hour
        Native.offset_date_time_int(self, :hour)
      end

      # The minute within the hour, from 0 to 59. Mirrors time's
      # <tt>OffsetDateTime::minute</tt>
      # (<tt>src/offset_date_time.rs:898-915</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.minute # => 30
      def minute
        Native.offset_date_time_int(self, :minute)
      end

      # The second within the minute, from 0 to 59. Mirrors time's
      # <tt>OffsetDateTime::second</tt>
      # (<tt>src/offset_date_time.rs:917-934</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.second # => 45
      def second
        Native.offset_date_time_int(self, :second)
      end

      # The milliseconds within the second, from 0 to 999. Mirrors time's
      # <tt>OffsetDateTime::millisecond</tt>
      # (<tt>src/offset_date_time.rs:939-951</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.millisecond # => 123
      def millisecond
        Native.offset_date_time_int(self, :millisecond)
      end

      # The microseconds within the second, from 0 to 999,999. Mirrors time's
      # <tt>OffsetDateTime::microsecond</tt>
      # (<tt>src/offset_date_time.rs:953-968</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.microsecond # => 123_456
      def microsecond
        Native.offset_date_time_int(self, :microsecond)
      end

      # The nanoseconds within the second, from 0 to 999,999,999. Mirrors
      # time's <tt>OffsetDateTime::nanosecond</tt>
      # (<tt>src/offset_date_time.rs:970-985</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.nanosecond # => 123_456_789
      def nanosecond
        Native.offset_date_time_int(self, :nanosecond)
      end

      # The clock hour, minute, and second. An Array for Rust's tuple. Mirrors
      # time's <tt>OffsetDateTime::to_hms</tt>
      # (<tt>src/offset_date_time.rs:813-823</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_hms # => [12, 30, 45]
      def to_hms
        Native.offset_date_time_ints(self, :to_hms)
      end

      # The clock hour, minute, second, and millisecond. An Array for Rust's
      # tuple. Mirrors time's <tt>OffsetDateTime::to_hms_milli</tt>
      # (<tt>src/offset_date_time.rs:825-841</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_hms_milli # => [12, 30, 45, 123]
      def to_hms_milli
        Native.offset_date_time_ints(self, :to_hms_milli)
      end

      # The clock hour, minute, second, and microsecond. An Array for Rust's
      # tuple. Mirrors time's <tt>OffsetDateTime::to_hms_micro</tt>
      # (<tt>src/offset_date_time.rs:843-859</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_hms_micro # => [12, 30, 45, 123_456]
      def to_hms_micro
        Native.offset_date_time_ints(self, :to_hms_micro)
      end

      # The clock hour, minute, second, and nanosecond. An Array for Rust's
      # tuple. Mirrors time's <tt>OffsetDateTime::to_hms_nano</tt>
      # (<tt>src/offset_date_time.rs:861-877</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_hms_nano # => [12, 30, 45, 123_456_789]
      def to_hms_nano
        Native.offset_date_time_ints(self, :to_hms_nano)
      end

      # Computes <tt>self + duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>OffsetDateTime::checked_add</tt>
      # (<tt>src/offset_date_time.rs:987-1006</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.checked_add(Ferro::Time::Duration::DAY).to_s # => "2019-01-02 12:30:45.123456789 -05:00:00"
      #   Ferro::Time::PlainDateTime::MAX.assume_utc.checked_add(Ferro::Time::Duration::DAY) # => nil
      def checked_add(duration)
        Native.offset_date_time_arith(self, :checked_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>OffsetDateTime::checked_sub</tt>
      # (<tt>src/offset_date_time.rs:1008-1027</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MIN.assume_utc.checked_sub(Ferro::Time::Duration::DAY) # => nil
      def checked_sub(duration)
        Native.offset_date_time_arith(self, :checked_sub, Arguments.duration(duration))
      end

      # Computes <tt>self + duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's
      # <tt>OffsetDateTime::saturating_add</tt>
      # (<tt>src/offset_date_time.rs:1067-1083</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MAX.assume_utc.saturating_add(Ferro::Time::Duration::DAY) == Ferro::Time::PlainDateTime::MAX.assume_utc # => true
      def saturating_add(duration)
        Native.offset_date_time_arith(self, :saturating_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's
      # <tt>OffsetDateTime::saturating_sub</tt>
      # (<tt>src/offset_date_time.rs:1123-1139</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MIN.assume_utc.saturating_sub(Ferro::Time::Duration::DAY) == Ferro::Time::PlainDateTime::MIN.assume_utc # => true
      def saturating_sub(duration)
        Native.offset_date_time_arith(self, :saturating_sub, Arguments.duration(duration))
      end

      # Adds +duration+, as time's <tt>Add<SignedDuration></tt> does. Where
      # Rust panics because the result leaves the supported range, this raises
      # +RangeError+ with time's message, "resulting value is out of range".
      # Ruby's <tt>+=</tt> works through it. Mirrors time's
      # <tt>Add<SignedDuration> for OffsetDateTime</tt>
      # (<tt>src/offset_date_time.rs:1672-1684</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   (datetime + Ferro::Time::Duration::DAY).to_s # => "2019-01-02 12:30:45.123456789 -05:00:00"
      #   Ferro::Time::PlainDateTime::MAX.assume_utc + Ferro::Time::Duration::DAY # raises RangeError
      def +(duration)
        Native.offset_date_time_arith(self, :+, Arguments.duration(duration))
      end

      # This date at another clock time, in the same offset. Mirrors time's
      # <tt>OffsetDateTime::replace_time</tt>
      # (<tt>src/offset_date_time.rs:1144-1166</tt>).
      #
      # [time] Time.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_time(Ferro::Time::Time::MIDNIGHT).hour # => 0
      def replace_time(time)
        Native.offset_date_time_replace_time(self, time)
      end

      # This clock time on another date, in the same offset. Mirrors time's
      # <tt>OffsetDateTime::replace_date</tt>
      # (<tt>src/offset_date_time.rs:1168-1186</tt>).
      #
      # [date] Date.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_date(Ferro::Time::Date.from_ordinal_date(2019, 2)).day # => 2
      def replace_date(date)
        Native.offset_date_time_replace_date(self, date)
      end

      # Another date and time, in the same offset. Mirrors time's
      # <tt>OffsetDateTime::replace_date_time</tt>
      # (<tt>src/offset_date_time.rs:1188-1206</tt>).
      #
      # [date_time] PlainDateTime.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_date_time(Ferro::Time::PlainDateTime::MIN).year # => -9999
      def replace_date_time(date_time)
        Native.offset_date_time_replace_date_time(self, date_time)
      end

      # The same date and time read in another offset: a different instant,
      # unlike #to_offset. Mirrors time's
      # <tt>OffsetDateTime::replace_offset</tt>
      # (<tt>src/offset_date_time.rs:1208-1221</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_offset(Ferro::Time::UtcOffset::UTC).unix_timestamp # => 1_546_345_845
      def replace_offset(offset)
        Native.offset_date_time_replace_offset(self, offset)
      end

      # Replaces the year. The month and day are unchanged. Raises
      # Error::ComponentRange when the year is out of range, or when the date
      # is February 29 and the new year is not a leap year. Mirrors time's
      # <tt>OffsetDateTime::replace_year</tt>
      # (<tt>src/offset_date_time.rs:1223-1238</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_year(2020).year # => 2020
      #   datetime.replace_year(10_000) # raises Ferro::Time::Error::ComponentRange
      def replace_year(year)
        Native.offset_date_time_replace(self, :replace_year, year)
      end

      # Replaces the month of the year. Raises Error::ComponentRange when the
      # day does not exist in the new month. Mirrors time's
      # <tt>OffsetDateTime::replace_month</tt>
      # (<tt>src/offset_date_time.rs:1240-1255</tt>).
      #
      # [month] Month.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_month(Ferro::Time::Month::May).month # => Ferro::Time::Month::May
      #   datetime.replace_day(31).replace_month(Ferro::Time::Month::April) # raises Ferro::Time::Error::ComponentRange
      def replace_month(month)
        Native.offset_date_time_replace(self, :replace_month, Arguments.month(month))
      end

      # Replaces the day of the month. Raises Error::ComponentRange when the
      # day does not exist in the month. Mirrors time's
      # <tt>OffsetDateTime::replace_day</tt>
      # (<tt>src/offset_date_time.rs:1257-1272</tt>).
      #
      # [day] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_day(31).day # => 31
      #   datetime.replace_day(32) # raises Ferro::Time::Error::ComponentRange
      def replace_day(day)
        Native.offset_date_time_replace(self, :replace_day, day)
      end

      # Replaces the day of the year. Raises Error::ComponentRange when the
      # day does not exist in the year. Mirrors time's
      # <tt>OffsetDateTime::replace_ordinal</tt>
      # (<tt>src/offset_date_time.rs:1274-1286</tt>).
      #
      # [ordinal] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_ordinal(32).to_calendar_date # => [2019, Ferro::Time::Month::February, 1]
      #   datetime.replace_ordinal(366) # raises Ferro::Time::Error::ComponentRange
      def replace_ordinal(ordinal)
        Native.offset_date_time_replace(self, :replace_ordinal, ordinal)
      end

      # Replaces the clock hour. Raises Error::ComponentRange outside 0 to 23.
      # Mirrors time's <tt>OffsetDateTime::replace_hour</tt>
      # (<tt>src/offset_date_time.rs:1304-1318</tt>).
      #
      # [hour] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_hour(7).hour # => 7
      #   datetime.replace_hour(24) # raises Ferro::Time::Error::ComponentRange
      def replace_hour(hour)
        Native.offset_date_time_replace(self, :replace_hour, hour)
      end

      # Replaces the minutes within the hour. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's
      # <tt>OffsetDateTime::replace_minute</tt>
      # (<tt>src/offset_date_time.rs:1336-1350</tt>).
      #
      # [minute] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_minute(7).minute # => 7
      #   datetime.replace_minute(60) # raises Ferro::Time::Error::ComponentRange
      def replace_minute(minute)
        Native.offset_date_time_replace(self, :replace_minute, minute)
      end

      # Replaces the seconds within the minute. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's
      # <tt>OffsetDateTime::replace_second</tt>
      # (<tt>src/offset_date_time.rs:1368-1382</tt>).
      #
      # [second] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_second(7).second # => 7
      #   datetime.replace_second(60) # raises Ferro::Time::Error::ComponentRange
      def replace_second(second)
        Native.offset_date_time_replace(self, :replace_second, second)
      end

      # Replaces the milliseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999. Mirrors time's
      # <tt>OffsetDateTime::replace_millisecond</tt>
      # (<tt>src/offset_date_time.rs:1400-1420</tt>).
      #
      # [millisecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_millisecond(7).nanosecond # => 7_000_000
      #   datetime.replace_millisecond(1_000) # raises Ferro::Time::Error::ComponentRange
      def replace_millisecond(millisecond)
        Native.offset_date_time_replace(self, :replace_millisecond, millisecond)
      end

      # Replaces the microseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999. Mirrors time's
      # <tt>OffsetDateTime::replace_microsecond</tt>
      # (<tt>src/offset_date_time.rs:1438-1458</tt>).
      #
      # [microsecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_microsecond(7).nanosecond # => 7_000
      #   datetime.replace_microsecond(1_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_microsecond(microsecond)
        Native.offset_date_time_replace(self, :replace_microsecond, microsecond)
      end

      # Replaces the nanoseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999,999. Mirrors time's
      # <tt>OffsetDateTime::replace_nanosecond</tt>
      # (<tt>src/offset_date_time.rs:1476-1493</tt>).
      #
      # [nanosecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.replace_nanosecond(7).nanosecond # => 7
      #   datetime.replace_nanosecond(1_000_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_nanosecond(nanosecond)
        Native.offset_date_time_replace(self, :replace_nanosecond, nanosecond)
      end

      # The value with every component finer than the day set to zero. Mirrors
      # time's <tt>OffsetDateTime::truncate_to_day</tt>
      # (<tt>src/offset_date_time.rs:1288-1302</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.truncate_to_day.to_hms_nano # => [0, 0, 0, 0]
      def truncate_to_day
        Native.offset_date_time_truncate(self, :truncate_to_day)
      end

      # The value with every component finer than the hour set to zero.
      # Mirrors time's <tt>OffsetDateTime::truncate_to_hour</tt>
      # (<tt>src/offset_date_time.rs:1320-1334</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.truncate_to_hour.to_hms_nano # => [12, 0, 0, 0]
      def truncate_to_hour
        Native.offset_date_time_truncate(self, :truncate_to_hour)
      end

      # The value with every component finer than the minute set to zero.
      # Mirrors time's <tt>OffsetDateTime::truncate_to_minute</tt>
      # (<tt>src/offset_date_time.rs:1352-1366</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.truncate_to_minute.to_hms_nano # => [12, 30, 0, 0]
      def truncate_to_minute
        Native.offset_date_time_truncate(self, :truncate_to_minute)
      end

      # The value with every component finer than the second set to zero.
      # Mirrors time's <tt>OffsetDateTime::truncate_to_second</tt>
      # (<tt>src/offset_date_time.rs:1384-1398</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.truncate_to_second.to_hms_nano # => [12, 30, 45, 0]
      def truncate_to_second
        Native.offset_date_time_truncate(self, :truncate_to_second)
      end

      # The value with every component finer than the millisecond set to zero.
      # Mirrors time's <tt>OffsetDateTime::truncate_to_millisecond</tt>
      # (<tt>src/offset_date_time.rs:1422-1436</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.truncate_to_millisecond.to_hms_nano # => [12, 30, 45, 123_000_000]
      def truncate_to_millisecond
        Native.offset_date_time_truncate(self, :truncate_to_millisecond)
      end

      # The value with every component finer than the microsecond set to zero.
      # Mirrors time's <tt>OffsetDateTime::truncate_to_microsecond</tt>
      # (<tt>src/offset_date_time.rs:1460-1474</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.truncate_to_microsecond.to_hms_nano # => [12, 30, 45, 123_456_000]
      def truncate_to_microsecond
        Native.offset_date_time_truncate(self, :truncate_to_microsecond)
      end

      # Subtracts a SignedDuration, raising +RangeError+ with time's message,
      # "resulting value is out of range", where Rust panics; or returns the
      # span from +other+ to this instant, given a OffsetDateTime, a
      # UtcDateTime, or Ruby's ::Time, as time's <tt>Sub</tt> impls do. Ruby's
      # own <tt>::Time#-</tt> is unchanged, so <tt>time - datetime</tt> stays
      # Ruby's. Mirrors time's <tt>Sub for OffsetDateTime</tt>
      # (<tt>src/interop/offsetdatetime_utcdatetime.rs,
      # src/interop/offsetdatetime_systemtime.rs</tt>).
      #
      # [other] SignedDuration, OffsetDateTime, UtcDateTime, or ::Time.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   (datetime - Ferro::Time::Duration::HOUR).hour # => 11
      #   (datetime - datetime.replace_time(Ferro::Time::Time::MIDNIGHT)).to_s # => "12h30m45s123ms456µs789ns"
      def -(other)
        case other
        when SignedDuration then Native.offset_date_time_arith(self, :-, other)
        when OffsetDateTime then Native.offset_date_time_difference(self, other)
        when UtcDateTime then Native.offset_date_time_difference_utc(self, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.offset_date_time_with_system_time(self, :-, seconds, nanoseconds)
        else raise TypeError, "no implicit conversion of #{other.class} into Ferro::Time::SignedDuration"
        end
      end

      # Whether +other+ is the same instant: a OffsetDateTime, a UtcDateTime,
      # or Ruby's ::Time, by time's +PartialEq+ impls. +false+ for anything
      # else. Ruby's own <tt>::Time#<=></tt> asks the other value when it is
      # not a ::Time (<tt>time.c:3987</tt> at Ruby v4.0.9), so <tt>time ==
      # datetime</tt> answers through this method too, as time's impls with
      # +SystemTime+ on the left do. Mirrors time's <tt>PartialEq for
      # OffsetDateTime</tt> (<tt>src/interop/offsetdatetime_utcdatetime.rs,
      # src/interop/offsetdatetime_systemtime.rs</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_700)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime == datetime.to_time # => true
      #   datetime == datetime.date # => false
      def ==(other)
        case other
        when OffsetDateTime then Native.offset_date_time_eq(self, other)
        when UtcDateTime then Native.offset_date_time_eq_utc(self, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.offset_date_time_with_system_time(self, :==, seconds, nanoseconds)
        else false
        end
      end

      # Whether +other+ is an equal OffsetDateTime, as time's +Eq+ says, so
      # equal values are the same Hash key. Unlike #==, a value of another
      # type is never +eql?+.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.eql?(datetime) # => true
      #   datetime.eql?(datetime.to_time) # => false
      def eql?(other)
        other.is_a?(OffsetDateTime) && Native.offset_date_time_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.hash == datetime.hash # => true
      def hash
        Native.offset_date_time_hash(self)
      end

      # Orders by instant against a OffsetDateTime, a UtcDateTime, or Ruby's
      # ::Time, by time's +Ord+ and +PartialOrd+ impls, so the Comparable
      # operators answer as Rust's do; +nil+ for anything else. Ruby's
      # <tt>::Time#<=></tt> asks this method in turn, so <tt>time <
      # datetime</tt> works too. Mirrors time's <tt>PartialOrd for
      # OffsetDateTime</tt> (<tt>src/interop/offsetdatetime_utcdatetime.rs,
      # src/interop/offsetdatetime_systemtime.rs</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime <=> Ferro::Time::OffsetDateTime::UNIX_EPOCH # => 1
      def <=>(other)
        case other
        when OffsetDateTime then Native.offset_date_time_cmp(self, other)
        when UtcDateTime then Native.offset_date_time_cmp_utc(self, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.offset_date_time_with_system_time(self, :<=>, seconds, nanoseconds)
        end
      end

      # This instant as Ruby's ::Time, in UTC: time's <tt>From<OffsetDateTime>
      # for SystemTime</tt>, with Ruby's ::Time standing for +SystemTime+,
      # which has no offset. Where std panics because the instant is outside
      # +SystemTime+'s range (narrower on Windows), this raises +RangeError+
      # with std's message. Mirrors time's <tt>From<OffsetDateTime> for
      # SystemTime</tt>
      # (<tt>src/interop/offsetdatetime_systemtime.rs:69-82</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_time.to_i # => 1_546_363_845
      #   datetime.to_time.utc? # => true
      def to_time
        Arguments.ruby_time(Native.offset_date_time_to_system_time(self))
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. Raises an Error::Format variant
      # when a component cannot be formatted, and +TypeError+ when a
      # well-known format needs a component this type lacks, which Rust's
      # compiler refuses. Mirrors time's <tt>OffsetDateTime::format</tt>
      # (<tt>src/offset_date_time.rs:1509-1528</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.format(Ferro::Time::FormatDescription::WellKnown::Rfc2822) # => "Tue, 01 Jan 2019 12:30:45 -0500"
      def format(description)
        Native.offset_date_time_format(self, Arguments.description(description))
      end

      # Formats the value with +description+ onto the end of +output+ and
      # returns the count time's +format_into+ returns, which is the number of
      # bytes written except where time leaves some out, as it does for the
      # digits of a fraction of a second in RFC 3339 and for an ISO 8601 hour
      # or minute with a decimal fraction. Rust writes to any
      # <tt>io::Write</tt>; here +output+ is a String, which keeps what time
      # wrote even when formatting fails partway, as Rust's writer does. A
      # frozen +output+ raises +FrozenError+ before anything is formatted.
      # Mirrors time's <tt>OffsetDateTime::format_into</tt>
      # (<tt>src/offset_date_time.rs:1498-1507</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   output = +"on "
      #   datetime.format_into(output, Ferro::Time::FormatDescription::WellKnown::Rfc2822) # => 31
      #   output # => "on Tue, 01 Jan 2019 12:30:45 -0500"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.offset_date_time_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # The value as time's +Display+ writes it.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.to_s # => "2019-01-01 12:30:45.123456789 -05:00:00"
      def to_s
        Native.offset_date_time_display(self)
      end

      # The value as time's +Debug+ writes it.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.inspect # => "2019-01-01 12:30:45.123456789 -05:00:00"
      def inspect
        Native.offset_date_time_debug(self)
      end

      # The value itself. A OffsetDateTime is +Copy+ in Rust and frozen here,
      # so a copy would be the same value; Ruby answers the same way for an
      # Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.dup.equal?(datetime) # => true
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
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #     .assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0))
      #   datetime.clone.equal?(datetime) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::OffsetDateTime" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
