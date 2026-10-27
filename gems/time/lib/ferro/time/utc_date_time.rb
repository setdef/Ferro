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
    # SPDX-SnippetComment: UtcDateTime, its methods, and their docs from time 0.3.55 src/utc_date_time.rs and src/interop
    #++

    # A date and a clock time in UTC: an instant, with no offset to carry.
    #
    # Logs, database rows, and wire formats usually store instants in UTC,
    # and code that reads them should not have to remember an offset that is
    # always zero. Ruby's ::Time can be in UTC, but nothing keeps it there:
    # one call to +localtime+ and the same value prints differently.
    #
    # A UtcDateTime is time's +UtcDateTime+, the same instant an
    # OffsetDateTime in UTC names, held without the offset. Build one from a
    # Date and a Time, a Unix timestamp, or UtcDateTime.now; convert it with
    # #to_offset; compare and subtract it with OffsetDateTime and Ruby's own
    # ::Time.
    #
    # A UtcDateTime is frozen and shareable between Ractors.
    #
    # Mirrors time's +UtcDateTime+ (<tt>src/utc_date_time.rs</tt>).
    #
    # === Examples
    #
    #   at = Ferro::Time::UtcDateTime.from_unix_timestamp(1_546_300_800)
    #   at.to_s # => "2019-01-01 0:00:00.0 +00"
    #   at.to_offset(Ferro::Time::UtcOffset.from_hms(9, 0, 0)).hour # => 9
    #
    #   at == Ferro::Time::OffsetDateTime.from_unix_timestamp(1_546_300_800) # => true
    class UtcDateTime
      include Comparable

      class << self
        # The current date and time in UTC, from the system clock. Mirrors
        # time's <tt>UtcDateTime::now</tt>
        # (<tt>src/utc_date_time.rs:111-135</tt>).
        #
        # === Example
        #
        #   Ferro::Time::UtcDateTime.now.year >= 2019 # => true
        def now
          Native.utc_now
        end

        # Creates a UtcDateTime from a Date and a Time. Mirrors time's
        # <tt>UtcDateTime::new</tt> (<tt>src/utc_date_time.rs:137-152</tt>).
        #
        # [date] Date.
        # [time] Time.
        #
        # === Example
        #
        #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
        #   Ferro::Time::UtcDateTime.new(date, Ferro::Time::Time::MIDNIGHT).unix_timestamp # => 1_546_300_800
        def new(date, time)
          Native.utc_new(date, time)
        end

        # Creates a UtcDateTime from a Unix timestamp in seconds, raising
        # Error::ComponentRange when the result is outside the supported
        # range. Mirrors time's <tt>UtcDateTime::from_unix_timestamp</tt>
        # (<tt>src/utc_date_time.rs:167-221</tt>).
        #
        # [timestamp] Integer, seconds since the epoch.
        #
        # === Example
        #
        #   Ferro::Time::UtcDateTime.from_unix_timestamp(0) == Ferro::Time::UtcDateTime::UNIX_EPOCH # => true
        def from_unix_timestamp(timestamp)
          Native.utc_from_unix_timestamp(timestamp)
        end

        # Creates a UtcDateTime from a Unix timestamp in nanoseconds, raising
        # Error::ComponentRange when the result is outside the supported
        # range. Mirrors time's
        # <tt>UtcDateTime::from_unix_timestamp_nanos</tt>
        # (<tt>src/utc_date_time.rs:223-263</tt>).
        #
        # [timestamp] Integer, nanoseconds since the epoch.
        #
        # === Example
        #
        #   Ferro::Time::UtcDateTime.from_unix_timestamp_nanos(1_546_300_800_000_000_001).nanosecond # => 1
        def from_unix_timestamp_nanos(timestamp)
          Native.utc_from_unix_timestamp_nanos(timestamp)
        end

        # Converts an OffsetDateTime, as time's <tt>From<OffsetDateTime></tt>
        # does, or Ruby's ::Time, as <tt>From<SystemTime></tt> does (plan 007,
        # decision 10). A ::Time keeps its seconds and nanoseconds since the
        # epoch and drops any finer fraction. Where Rust panics because the
        # result is outside the supported range, this raises +RangeError+ with
        # time's message. Mirrors time's <tt>From<OffsetDateTime> for
        # UtcDateTime</tt>
        # (<tt>src/interop/offsetdatetime_utcdatetime.rs:60-69,
        # src/interop/utcdatetime_systemtime.rs:61-69</tt>).
        #
        # [value] OffsetDateTime or ::Time.
        #
        # === Example
        #
        #   Ferro::Time::UtcDateTime.from(::Time.at(0)) == Ferro::Time::UtcDateTime::UNIX_EPOCH # => true
        def from(value)
          case value
          when OffsetDateTime then Native.utc_from_offset(value)
          when ::Time
            seconds, nanoseconds = Arguments.system_time(value)
            Native.utc_from_system_time(seconds, nanoseconds)
          else raise TypeError, "no implicit conversion of #{value.class} into Ferro::Time::UtcDateTime"
          end
        end

        # Parses a UtcDateTime from +input+ with +description+, which takes
        # the same kinds of description as #format. Raises an Error::Parse
        # variant when the input does not match. Mirrors time's
        # <tt>UtcDateTime::parse</tt>
        # (<tt>src/utc_date_time.rs:1199-1219</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   Ferro::Time::UtcDateTime.parse("2019-01-01T12:30:45Z", Ferro::Time::FormatDescription::WellKnown::Rfc3339).to_s # => "2019-01-01 12:30:45.0 +00"
        def parse(input, description)
          Native.utc_parse(input, Arguments.description(description))
        end
      end

      # Midnight, January 1, 1970. Mirrors time's
      # <tt>UtcDateTime::UNIX_EPOCH</tt>
      # (<tt>src/utc_date_time.rs:44-51</tt>).
      UNIX_EPOCH = Native.utc_constant(:UNIX_EPOCH)

      # The smallest value that can be represented by UtcDateTime. Mirrors
      # time's <tt>UtcDateTime::MIN</tt>
      # (<tt>src/utc_date_time.rs:79-80</tt>).
      MIN = Native.utc_constant(:MIN)

      # The largest value that can be represented by UtcDateTime. Mirrors
      # time's <tt>UtcDateTime::MAX</tt>
      # (<tt>src/utc_date_time.rs:108-109</tt>).
      MAX = Native.utc_constant(:MAX)

      # The date component. Mirrors time's <tt>UtcDateTime::date</tt>
      # (<tt>src/utc_date_time.rs:407-416</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.date.to_s # => "2019-01-01"
      def date
        Native.utc_date(self)
      end

      # The clock time component. Mirrors time's <tt>UtcDateTime::time</tt>
      # (<tt>src/utc_date_time.rs:418-427</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.time.to_s # => "12:30:45.123456789"
      def time
        Native.utc_time(self)
      end

      # The year of the date. Mirrors time's <tt>UtcDateTime::year</tt>
      # (<tt>src/utc_date_time.rs:429-440</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.year # => 2019
      def year
        Native.utc_int(self, :year)
      end

      # The month. Mirrors time's <tt>UtcDateTime::month</tt>
      # (<tt>src/utc_date_time.rs:442-453</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.month # => Ferro::Time::Month::January
      def month
        Arguments.month_of(Native.utc_int(self, :month))
      end

      # The day of the month, from 1 to 31. Mirrors time's
      # <tt>UtcDateTime::day</tt> (<tt>src/utc_date_time.rs:455-467</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.day # => 1
      def day
        Native.utc_int(self, :day)
      end

      # The day of the year, from 1 to 366 (1 to 365 in a common year).
      # Mirrors time's <tt>UtcDateTime::ordinal</tt>
      # (<tt>src/utc_date_time.rs:469-481</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.ordinal # => 1
      def ordinal
        Native.utc_int(self, :ordinal)
      end

      # The ISO week number, from 1 to 53. The first ISO week of a year is the
      # week containing its first Thursday, so a date in early January or late
      # December may belong to a week of the next or previous ISO year.
      # Mirrors time's <tt>UtcDateTime::iso_week</tt>
      # (<tt>src/utc_date_time.rs:483-498</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.iso_week # => 1
      def iso_week
        Native.utc_int(self, :iso_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Sunday
      # of the calendar year. Mirrors time's
      # <tt>UtcDateTime::sunday_based_week</tt>
      # (<tt>src/utc_date_time.rs:500-514</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.sunday_based_week # => 0
      def sunday_based_week
        Native.utc_int(self, :sunday_based_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Monday
      # of the calendar year. Mirrors time's
      # <tt>UtcDateTime::monday_based_week</tt>
      # (<tt>src/utc_date_time.rs:516-530</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.monday_based_week # => 0
      def monday_based_week
        Native.utc_int(self, :monday_based_week)
      end

      # The year, month, and day, as a three-element Array for Rust's tuple.
      # Mirrors time's <tt>UtcDateTime::to_calendar_date</tt>
      # (<tt>src/utc_date_time.rs:532-545</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_calendar_date # => [2019, Ferro::Time::Month::January, 1]
      def to_calendar_date
        Arguments.calendar_date(Native.utc_ints(self, :to_calendar_date))
      end

      # The year and the day of the year, as a two-element Array for Rust's
      # tuple. Mirrors time's <tt>UtcDateTime::to_ordinal_date</tt>
      # (<tt>src/utc_date_time.rs:547-556</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_ordinal_date # => [2019, 1]
      def to_ordinal_date
        Native.utc_ints(self, :to_ordinal_date)
      end

      # The ISO year, ISO week number, and weekday, as a three-element Array
      # for Rust's tuple. The ISO year may differ from #year near the turn of
      # a year. Mirrors time's <tt>UtcDateTime::to_iso_week_date</tt>
      # (<tt>src/utc_date_time.rs:558-587</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_iso_week_date # => [2019, 1, Ferro::Time::Weekday::Tuesday]
      def to_iso_week_date
        Arguments.iso_week_date(Native.utc_ints(self, :to_iso_week_date))
      end

      # The day of the week. Mirrors time's <tt>UtcDateTime::weekday</tt>
      # (<tt>src/utc_date_time.rs:589-610</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.weekday # => Ferro::Time::Weekday::Tuesday
      def weekday
        Arguments.weekday_of(Native.utc_int(self, :weekday))
      end

      # The Julian day number: the days since noon UTC on November 24 of 4714
      # BC in the proleptic Gregorian calendar, day 0. Mirrors time's
      # <tt>UtcDateTime::to_julian_day</tt>
      # (<tt>src/utc_date_time.rs:612-624</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_julian_day # => 2_458_485
      def to_julian_day
        Native.utc_int(self, :to_julian_day)
      end

      # The clock hour, from 0 to 23. Mirrors time's
      # <tt>UtcDateTime::hour</tt> (<tt>src/utc_date_time.rs:683-695</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.hour # => 12
      def hour
        Native.utc_int(self, :hour)
      end

      # The minute within the hour, from 0 to 59. Mirrors time's
      # <tt>UtcDateTime::minute</tt> (<tt>src/utc_date_time.rs:697-709</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.minute # => 30
      def minute
        Native.utc_int(self, :minute)
      end

      # The second within the minute, from 0 to 59. Mirrors time's
      # <tt>UtcDateTime::second</tt> (<tt>src/utc_date_time.rs:711-723</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.second # => 45
      def second
        Native.utc_int(self, :second)
      end

      # The milliseconds within the second, from 0 to 999. Mirrors time's
      # <tt>UtcDateTime::millisecond</tt>
      # (<tt>src/utc_date_time.rs:725-737</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.millisecond # => 123
      def millisecond
        Native.utc_int(self, :millisecond)
      end

      # The microseconds within the second, from 0 to 999,999. Mirrors time's
      # <tt>UtcDateTime::microsecond</tt>
      # (<tt>src/utc_date_time.rs:739-754</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.microsecond # => 123_456
      def microsecond
        Native.utc_int(self, :microsecond)
      end

      # The nanoseconds within the second, from 0 to 999,999,999. Mirrors
      # time's <tt>UtcDateTime::nanosecond</tt>
      # (<tt>src/utc_date_time.rs:756-771</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.nanosecond # => 123_456_789
      def nanosecond
        Native.utc_int(self, :nanosecond)
      end

      # The clock hour, minute, and second. An Array for Rust's tuple. Mirrors
      # time's <tt>UtcDateTime::as_hms</tt>
      # (<tt>src/utc_date_time.rs:626-636</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.as_hms # => [12, 30, 45]
      def as_hms
        Native.utc_ints(self, :as_hms)
      end

      # The clock hour, minute, second, and millisecond. An Array for Rust's
      # tuple. Mirrors time's <tt>UtcDateTime::as_hms_milli</tt>
      # (<tt>src/utc_date_time.rs:638-651</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.as_hms_milli # => [12, 30, 45, 123]
      def as_hms_milli
        Native.utc_ints(self, :as_hms_milli)
      end

      # The clock hour, minute, second, and microsecond. An Array for Rust's
      # tuple. Mirrors time's <tt>UtcDateTime::as_hms_micro</tt>
      # (<tt>src/utc_date_time.rs:653-666</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.as_hms_micro # => [12, 30, 45, 123_456]
      def as_hms_micro
        Native.utc_ints(self, :as_hms_micro)
      end

      # The clock hour, minute, second, and nanosecond. An Array for Rust's
      # tuple. Mirrors time's <tt>UtcDateTime::as_hms_nano</tt>
      # (<tt>src/utc_date_time.rs:668-681</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.as_hms_nano # => [12, 30, 45, 123_456_789]
      def as_hms_nano
        Native.utc_ints(self, :as_hms_nano)
      end

      # Computes <tt>self + duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>UtcDateTime::checked_add</tt>
      # (<tt>src/utc_date_time.rs:773-790</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.checked_add(Ferro::Time::Duration::DAY).to_s # => "2019-01-02 12:30:45.123456789 +00"
      #   Ferro::Time::UtcDateTime::MAX.checked_add(Ferro::Time::Duration::DAY) # => nil
      def checked_add(duration)
        Native.utc_arith(self, :checked_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>UtcDateTime::checked_sub</tt>
      # (<tt>src/utc_date_time.rs:792-809</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::UtcDateTime::MIN.checked_sub(Ferro::Time::Duration::DAY) # => nil
      def checked_sub(duration)
        Native.utc_arith(self, :checked_sub, Arguments.duration(duration))
      end

      # Computes <tt>self + duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's
      # <tt>UtcDateTime::saturating_add</tt>
      # (<tt>src/utc_date_time.rs:811-832</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::UtcDateTime::MAX.saturating_add(Ferro::Time::Duration::DAY) == Ferro::Time::UtcDateTime::MAX # => true
      def saturating_add(duration)
        Native.utc_arith(self, :saturating_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's
      # <tt>UtcDateTime::saturating_sub</tt>
      # (<tt>src/utc_date_time.rs:834-855</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::UtcDateTime::MIN.saturating_sub(Ferro::Time::Duration::DAY) == Ferro::Time::UtcDateTime::MIN # => true
      def saturating_sub(duration)
        Native.utc_arith(self, :saturating_sub, Arguments.duration(duration))
      end

      # Adds +duration+, as time's <tt>Add<SignedDuration></tt> does. Where
      # Rust panics because the result leaves the supported range, this raises
      # +RangeError+ with time's message, "resulting value is out of range".
      # Ruby's <tt>+=</tt> works through it. Mirrors time's
      # <tt>Add<SignedDuration> for UtcDateTime</tt>
      # (<tt>src/utc_date_time.rs:1322-1333</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   (datetime + Ferro::Time::Duration::DAY).to_s # => "2019-01-02 12:30:45.123456789 +00"
      #   Ferro::Time::UtcDateTime::MAX + Ferro::Time::Duration::DAY # raises RangeError
      def +(duration)
        Native.utc_arith(self, :+, Arguments.duration(duration))
      end

      # The same instant in +offset+. Where Rust panics because the local date
      # and time leave the supported range, this raises +RangeError+ with
      # time's message, "local datetime out of valid range". Mirrors time's
      # <tt>UtcDateTime::to_offset</tt>
      # (<tt>src/utc_date_time.rs:265-294</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0)).hour # => 7
      def to_offset(offset)
        Native.utc_to_offset(self, :to_offset, offset)
      end

      # The same instant in +offset+, or +nil+ when the local date and time
      # leave the supported range. Mirrors time's
      # <tt>UtcDateTime::checked_to_offset</tt>
      # (<tt>src/utc_date_time.rs:296-334</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   Ferro::Time::UtcDateTime::MAX.checked_to_offset(Ferro::Time::UtcOffset.from_hms(1, 0, 0)) # => nil
      def checked_to_offset(offset)
        Native.utc_to_offset(self, :checked_to_offset, offset)
      end

      # The Unix timestamp: whole seconds since the epoch. Mirrors time's
      # <tt>UtcDateTime::unix_timestamp</tt>
      # (<tt>src/utc_date_time.rs:374-389</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.unix_timestamp # => 1_546_345_845
      def unix_timestamp
        Native.utc_int(self, :unix_timestamp)
      end

      # The Unix timestamp in nanoseconds. Mirrors time's
      # <tt>UtcDateTime::unix_timestamp_nanos</tt>
      # (<tt>src/utc_date_time.rs:391-405</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.unix_timestamp_nanos # => 1_546_345_845_123_456_789
      def unix_timestamp_nanos
        Native.utc_int(self, :unix_timestamp_nanos)
      end

      # This date at another clock time. Mirrors time's
      # <tt>UtcDateTime::replace_time</tt>
      # (<tt>src/utc_date_time.rs:860-873</tt>).
      #
      # [time] Time.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_time(Ferro::Time::Time::MIDNIGHT).unix_timestamp # => 1_546_300_800
      def replace_time(time)
        Native.utc_replace_time(self, time)
      end

      # This clock time on another date. Mirrors time's
      # <tt>UtcDateTime::replace_date</tt>
      # (<tt>src/utc_date_time.rs:875-888</tt>).
      #
      # [date] Date.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_date(Ferro::Time::Date.from_ordinal_date(2019, 2)).day # => 2
      def replace_date(date)
        Native.utc_replace_date(self, date)
      end

      # Replaces the year. The month and day are unchanged. Raises
      # Error::ComponentRange when the year is out of range, or when the date
      # is February 29 and the new year is not a leap year. Mirrors time's
      # <tt>UtcDateTime::replace_year</tt>
      # (<tt>src/utc_date_time.rs:890-905</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_year(2020).year # => 2020
      #   datetime.replace_year(10_000) # raises Ferro::Time::Error::ComponentRange
      def replace_year(year)
        Native.utc_replace(self, :replace_year, year)
      end

      # Replaces the month of the year. Raises Error::ComponentRange when the
      # day does not exist in the new month. Mirrors time's
      # <tt>UtcDateTime::replace_month</tt>
      # (<tt>src/utc_date_time.rs:907-924</tt>).
      #
      # [month] Month.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_month(Ferro::Time::Month::May).month # => Ferro::Time::Month::May
      #   datetime.replace_day(31).replace_month(Ferro::Time::Month::April) # raises Ferro::Time::Error::ComponentRange
      def replace_month(month)
        Native.utc_replace(self, :replace_month, Arguments.month(month))
      end

      # Replaces the day of the month. Raises Error::ComponentRange when the
      # day does not exist in the month. Mirrors time's
      # <tt>UtcDateTime::replace_day</tt>
      # (<tt>src/utc_date_time.rs:926-941</tt>).
      #
      # [day] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_day(31).day # => 31
      #   datetime.replace_day(32) # raises Ferro::Time::Error::ComponentRange
      def replace_day(day)
        Native.utc_replace(self, :replace_day, day)
      end

      # Replaces the day of the year. Raises Error::ComponentRange when the
      # day does not exist in the year. Mirrors time's
      # <tt>UtcDateTime::replace_ordinal</tt>
      # (<tt>src/utc_date_time.rs:943-957</tt>).
      #
      # [ordinal] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_ordinal(32).to_calendar_date # => [2019, Ferro::Time::Month::February, 1]
      #   datetime.replace_ordinal(366) # raises Ferro::Time::Error::ComponentRange
      def replace_ordinal(ordinal)
        Native.utc_replace(self, :replace_ordinal, ordinal)
      end

      # Replaces the clock hour. Raises Error::ComponentRange outside 0 to 23.
      # Mirrors time's <tt>UtcDateTime::replace_hour</tt>
      # (<tt>src/utc_date_time.rs:974-988</tt>).
      #
      # [hour] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_hour(7).hour # => 7
      #   datetime.replace_hour(24) # raises Ferro::Time::Error::ComponentRange
      def replace_hour(hour)
        Native.utc_replace(self, :replace_hour, hour)
      end

      # Replaces the minutes within the hour. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's <tt>UtcDateTime::replace_minute</tt>
      # (<tt>src/utc_date_time.rs:1005-1021</tt>).
      #
      # [minute] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_minute(7).minute # => 7
      #   datetime.replace_minute(60) # raises Ferro::Time::Error::ComponentRange
      def replace_minute(minute)
        Native.utc_replace(self, :replace_minute, minute)
      end

      # Replaces the seconds within the minute. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's <tt>UtcDateTime::replace_second</tt>
      # (<tt>src/utc_date_time.rs:1038-1054</tt>).
      #
      # [second] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_second(7).second # => 7
      #   datetime.replace_second(60) # raises Ferro::Time::Error::ComponentRange
      def replace_second(second)
        Native.utc_replace(self, :replace_second, second)
      end

      # Replaces the milliseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999. Mirrors time's
      # <tt>UtcDateTime::replace_millisecond</tt>
      # (<tt>src/utc_date_time.rs:1071-1090</tt>).
      #
      # [millisecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_millisecond(7).nanosecond # => 7_000_000
      #   datetime.replace_millisecond(1_000) # raises Ferro::Time::Error::ComponentRange
      def replace_millisecond(millisecond)
        Native.utc_replace(self, :replace_millisecond, millisecond)
      end

      # Replaces the microseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999. Mirrors time's
      # <tt>UtcDateTime::replace_microsecond</tt>
      # (<tt>src/utc_date_time.rs:1107-1126</tt>).
      #
      # [microsecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_microsecond(7).nanosecond # => 7_000
      #   datetime.replace_microsecond(1_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_microsecond(microsecond)
        Native.utc_replace(self, :replace_microsecond, microsecond)
      end

      # Replaces the nanoseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999,999. Mirrors time's
      # <tt>UtcDateTime::replace_nanosecond</tt>
      # (<tt>src/utc_date_time.rs:1143-1159</tt>).
      #
      # [nanosecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.replace_nanosecond(7).nanosecond # => 7
      #   datetime.replace_nanosecond(1_000_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_nanosecond(nanosecond)
        Native.utc_replace(self, :replace_nanosecond, nanosecond)
      end

      # The value with every component finer than the day set to zero. Mirrors
      # time's <tt>UtcDateTime::truncate_to_day</tt>
      # (<tt>src/utc_date_time.rs:959-972</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.truncate_to_day.as_hms_nano # => [0, 0, 0, 0]
      def truncate_to_day
        Native.utc_truncate(self, :truncate_to_day)
      end

      # The value with every component finer than the hour set to zero.
      # Mirrors time's <tt>UtcDateTime::truncate_to_hour</tt>
      # (<tt>src/utc_date_time.rs:990-1003</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.truncate_to_hour.as_hms_nano # => [12, 0, 0, 0]
      def truncate_to_hour
        Native.utc_truncate(self, :truncate_to_hour)
      end

      # The value with every component finer than the minute set to zero.
      # Mirrors time's <tt>UtcDateTime::truncate_to_minute</tt>
      # (<tt>src/utc_date_time.rs:1023-1036</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.truncate_to_minute.as_hms_nano # => [12, 30, 0, 0]
      def truncate_to_minute
        Native.utc_truncate(self, :truncate_to_minute)
      end

      # The value with every component finer than the second set to zero.
      # Mirrors time's <tt>UtcDateTime::truncate_to_second</tt>
      # (<tt>src/utc_date_time.rs:1056-1069</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.truncate_to_second.as_hms_nano # => [12, 30, 45, 0]
      def truncate_to_second
        Native.utc_truncate(self, :truncate_to_second)
      end

      # The value with every component finer than the millisecond set to zero.
      # Mirrors time's <tt>UtcDateTime::truncate_to_millisecond</tt>
      # (<tt>src/utc_date_time.rs:1092-1105</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.truncate_to_millisecond.as_hms_nano # => [12, 30, 45, 123_000_000]
      def truncate_to_millisecond
        Native.utc_truncate(self, :truncate_to_millisecond)
      end

      # The value with every component finer than the microsecond set to zero.
      # Mirrors time's <tt>UtcDateTime::truncate_to_microsecond</tt>
      # (<tt>src/utc_date_time.rs:1128-1141</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.truncate_to_microsecond.as_hms_nano # => [12, 30, 45, 123_456_000]
      def truncate_to_microsecond
        Native.utc_truncate(self, :truncate_to_microsecond)
      end

      # Subtracts a SignedDuration, raising +RangeError+ with time's message,
      # "resulting value is out of range", where Rust panics; or returns the
      # span from +other+ to this instant, given a UtcDateTime, a
      # OffsetDateTime, or Ruby's ::Time, as time's <tt>Sub</tt> impls do.
      # Ruby's own <tt>::Time#-</tt> is unchanged, so <tt>time - datetime</tt>
      # stays Ruby's. Mirrors time's <tt>Sub for UtcDateTime</tt>
      # (<tt>src/interop/offsetdatetime_utcdatetime.rs,
      # src/interop/utcdatetime_systemtime.rs</tt>).
      #
      # [other] SignedDuration, UtcDateTime, OffsetDateTime, or ::Time.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   (datetime - Ferro::Time::Duration::HOUR).hour # => 11
      #   (datetime - datetime.replace_time(Ferro::Time::Time::MIDNIGHT)).to_s # => "12h30m45s123ms456µs789ns"
      def -(other)
        case other
        when SignedDuration then Native.utc_arith(self, :-, other)
        when UtcDateTime then Native.utc_difference(self, other)
        when OffsetDateTime then Native.utc_difference_offset(self, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.utc_with_system_time(self, :-, seconds, nanoseconds)
        else raise TypeError, "no implicit conversion of #{other.class} into Ferro::Time::SignedDuration"
        end
      end

      # Whether +other+ is the same instant: a UtcDateTime, a OffsetDateTime,
      # or Ruby's ::Time, by time's +PartialEq+ impls. +false+ for anything
      # else. Ruby's own <tt>::Time#<=></tt> asks the other value when it is
      # not a ::Time (<tt>time.c:3987</tt> at Ruby v4.0.9), so <tt>time ==
      # datetime</tt> answers through this method too, as time's impls with
      # +SystemTime+ on the left do. Mirrors time's <tt>PartialEq for
      # UtcDateTime</tt> (<tt>src/interop/offsetdatetime_utcdatetime.rs,
      # src/interop/utcdatetime_systemtime.rs</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_700).as_utc
      #   datetime == datetime.to_time # => true
      #   datetime == datetime.date # => false
      def ==(other)
        case other
        when UtcDateTime then Native.utc_eq(self, other)
        when OffsetDateTime then Native.utc_eq_offset(self, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.utc_with_system_time(self, :==, seconds, nanoseconds)
        else false
        end
      end

      # Whether +other+ is an equal UtcDateTime, as time's +Eq+ says, so equal
      # values are the same Hash key. Unlike #==, a value of another type is
      # never +eql?+.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.eql?(datetime) # => true
      #   datetime.eql?(datetime.to_time) # => false
      def eql?(other)
        other.is_a?(UtcDateTime) && Native.utc_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.hash == datetime.hash # => true
      def hash
        Native.utc_hash(self)
      end

      # Orders by instant against a UtcDateTime, a OffsetDateTime, or Ruby's
      # ::Time, by time's +Ord+ and +PartialOrd+ impls, so the Comparable
      # operators answer as Rust's do; +nil+ for anything else. Ruby's
      # <tt>::Time#<=></tt> asks this method in turn, so <tt>time <
      # datetime</tt> works too. Mirrors time's <tt>PartialOrd for
      # UtcDateTime</tt> (<tt>src/interop/offsetdatetime_utcdatetime.rs,
      # src/interop/utcdatetime_systemtime.rs</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime <=> Ferro::Time::UtcDateTime::MAX # => -1
      def <=>(other)
        case other
        when UtcDateTime then Native.utc_cmp(self, other)
        when OffsetDateTime then Native.utc_cmp_offset(self, other)
        when ::Time
          seconds, nanoseconds = Arguments.system_time(other)
          Native.utc_with_system_time(self, :<=>, seconds, nanoseconds)
        end
      end

      # This instant as Ruby's ::Time, in UTC: time's <tt>From<UtcDateTime>
      # for SystemTime</tt>, with Ruby's ::Time standing for +SystemTime+,
      # which has no offset. Where std panics because the instant is outside
      # +SystemTime+'s range (narrower on Windows), this raises +RangeError+
      # with std's message. Mirrors time's <tt>From<UtcDateTime> for
      # SystemTime</tt>
      # (<tt>src/interop/utcdatetime_systemtime.rs:71-84</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_time.to_i # => 1_546_345_845
      #   datetime.to_time.utc? # => true
      def to_time
        Arguments.ruby_time(Native.utc_to_system_time(self))
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. Raises an Error::Format variant
      # when a component cannot be formatted, and +TypeError+ when a
      # well-known format needs a component this type lacks, which Rust's
      # compiler refuses. Mirrors time's <tt>UtcDateTime::format</tt>
      # (<tt>src/utc_date_time.rs:1175-1194</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.format(Ferro::Time::FormatDescription::WellKnown::Rfc3339) # => "2019-01-01T12:30:45.123456789Z"
      def format(description)
        Native.utc_format(self, Arguments.description(description))
      end

      # Formats the value with +description+ onto the end of +output+ and
      # returns the count time's +format_into+ returns, which is the number of
      # bytes written except where time leaves some out, as it does for the
      # digits of a fraction of a second in RFC 3339 and for an ISO 8601 hour
      # or minute with a decimal fraction. Rust writes to any
      # <tt>io::Write</tt>; here +output+ is a String, which keeps what time
      # wrote even when formatting fails partway, as Rust's writer does. A
      # frozen +output+ raises +FrozenError+ before anything is formatted.
      # Mirrors time's <tt>UtcDateTime::format_into</tt>
      # (<tt>src/utc_date_time.rs:1164-1173</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   output = +"on "
      #   datetime.format_into(output, Ferro::Time::FormatDescription::WellKnown::Rfc3339) # => 21
      #   output # => "on 2019-01-01T12:30:45.123456789Z"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.utc_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # The value as time's +Display+ writes it.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.to_s # => "2019-01-01 12:30:45.123456789 +00"
      def to_s
        Native.utc_display(self)
      end

      # The value as time's +Debug+ writes it.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.inspect # => "2019-01-01 12:30:45.123456789 +00"
      def inspect
        Native.utc_debug(self)
      end

      # The value itself. A UtcDateTime is +Copy+ in Rust and frozen here, so
      # a copy would be the same value; Ruby answers the same way for an
      # Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
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
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789).as_utc
      #   datetime.clone.equal?(datetime) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::UtcDateTime" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
