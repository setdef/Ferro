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
    # SPDX-SnippetComment: PlainDateTime, its methods, and their docs from time 0.3.55 src/plain_date_time.rs
    #++

    # A date and a clock time with no offset: the wall-clock reading of no
    # particular place.
    #
    # A meeting at 9:00 on March 3, a birthday party, a calendar entry typed
    # by hand: until you know where it happens, it names no single instant.
    # Ruby's ::Time always carries an offset, so a time with none either
    # pretends to be in the machine's zone or in UTC, and the pretense leaks.
    #
    # A PlainDateTime is time's +PlainDateTime+ (until 0.3.54 its
    # +PrimitiveDateTime+, a name time keeps as an alias, and so does this
    # gem). Build one from a Date and a Time, read and replace its parts, add
    # a SignedDuration, and when you learn the place, attach an offset with
    # #assume_offset, #assume_utc, or #as_utc.
    #
    # A PlainDateTime is frozen and shareable between Ractors.
    #
    # Mirrors time's +PlainDateTime+ (<tt>src/plain_date_time.rs</tt>).
    #
    # === Examples
    #
    #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::March, 3)
    #   meeting = Ferro::Time::PlainDateTime.new(date, Ferro::Time::Time.from_hms(9, 0, 0))
    #   meeting.to_s # => "2019-03-03 9:00:00.0"
    #   meeting.assume_offset(Ferro::Time::UtcOffset.from_hms(1, 0, 0)).to_s
    #   # => "2019-03-03 9:00:00.0 +01:00:00"
    #
    #   Ferro::Time::PrimitiveDateTime.equal?(Ferro::Time::PlainDateTime) # => true
    class PlainDateTime
      include Comparable

      class << self
        # Creates a PlainDateTime from a Date and a Time. Mirrors time's
        # <tt>PlainDateTime::new</tt>
        # (<tt>src/plain_date_time.rs:156-169</tt>).
        #
        # [date] Date.
        # [time] Time.
        #
        # === Example
        #
        #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
        #   Ferro::Time::PlainDateTime.new(date, Ferro::Time::Time::MIDNIGHT).to_s # => "2019-01-01 0:00:00.0"
        def new(date, time)
          Native.plain_new(date, time)
        end

        # Parses a PlainDateTime from +input+ with +description+, which takes
        # the same kinds of description as #format. Raises an Error::Parse
        # variant when the input does not match. Mirrors time's
        # <tt>PlainDateTime::parse</tt>
        # (<tt>src/plain_date_time.rs:1080-1099</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   Ferro::Time::PlainDateTime.parse("2019-01-01T12:30:45", Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE_TIME).to_s # => "2019-01-01 12:30:45.0"
        def parse(input, description)
          Native.plain_parse(input, Arguments.description(description))
        end
      end

      # The smallest value that can be represented by PlainDateTime: midnight
      # on Date::MIN. Mirrors time's <tt>PlainDateTime::MIN</tt>
      # (<tt>src/plain_date_time.rs:118-122</tt>).
      MIN = Native.plain_constant(:MIN)

      # The largest value that can be represented by PlainDateTime: Time::MAX
      # on Date::MAX. Mirrors time's <tt>PlainDateTime::MAX</tt>
      # (<tt>src/plain_date_time.rs:150-154</tt>).
      MAX = Native.plain_constant(:MAX)

      # The date component. Mirrors time's <tt>PlainDateTime::date</tt>
      # (<tt>src/plain_date_time.rs:171-180</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.date.to_s # => "2019-01-01"
      def date
        Native.plain_date(self)
      end

      # The clock time component. Mirrors time's <tt>PlainDateTime::time</tt>
      # (<tt>src/plain_date_time.rs:182-191</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.time.to_s # => "12:30:45.123456789"
      def time
        Native.plain_time(self)
      end

      # The year of the date. Mirrors time's <tt>PlainDateTime::year</tt>
      # (<tt>src/plain_date_time.rs:193-204</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.year # => 2019
      def year
        Native.plain_int(self, :year)
      end

      # The month. Mirrors time's <tt>PlainDateTime::month</tt>
      # (<tt>src/plain_date_time.rs:206-217</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.month # => Ferro::Time::Month::January
      def month
        Arguments.month_of(Native.plain_int(self, :month))
      end

      # The day of the month, from 1 to 31. Mirrors time's
      # <tt>PlainDateTime::day</tt> (<tt>src/plain_date_time.rs:219-231</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.day # => 1
      def day
        Native.plain_int(self, :day)
      end

      # The day of the year, from 1 to 366 (1 to 365 in a common year).
      # Mirrors time's <tt>PlainDateTime::ordinal</tt>
      # (<tt>src/plain_date_time.rs:233-245</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.ordinal # => 1
      def ordinal
        Native.plain_int(self, :ordinal)
      end

      # The ISO week number, from 1 to 53. The first ISO week of a year is the
      # week containing its first Thursday, so a date in early January or late
      # December may belong to a week of the next or previous ISO year.
      # Mirrors time's <tt>PlainDateTime::iso_week</tt>
      # (<tt>src/plain_date_time.rs:247-262</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.iso_week # => 1
      def iso_week
        Native.plain_int(self, :iso_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Sunday
      # of the calendar year. Mirrors time's
      # <tt>PlainDateTime::sunday_based_week</tt>
      # (<tt>src/plain_date_time.rs:264-278</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.sunday_based_week # => 0
      def sunday_based_week
        Native.plain_int(self, :sunday_based_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Monday
      # of the calendar year. Mirrors time's
      # <tt>PlainDateTime::monday_based_week</tt>
      # (<tt>src/plain_date_time.rs:280-294</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.monday_based_week # => 0
      def monday_based_week
        Native.plain_int(self, :monday_based_week)
      end

      # The year, month, and day, as a three-element Array for Rust's tuple.
      # Mirrors time's <tt>PlainDateTime::to_calendar_date</tt>
      # (<tt>src/plain_date_time.rs:296-309</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.to_calendar_date # => [2019, Ferro::Time::Month::January, 1]
      def to_calendar_date
        Arguments.calendar_date(Native.plain_ints(self, :to_calendar_date))
      end

      # The year and the day of the year, as a two-element Array for Rust's
      # tuple. Mirrors time's <tt>PlainDateTime::to_ordinal_date</tt>
      # (<tt>src/plain_date_time.rs:311-320</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.to_ordinal_date # => [2019, 1]
      def to_ordinal_date
        Native.plain_ints(self, :to_ordinal_date)
      end

      # The ISO year, ISO week number, and weekday, as a three-element Array
      # for Rust's tuple. The ISO year may differ from #year near the turn of
      # a year. Mirrors time's <tt>PlainDateTime::to_iso_week_date</tt>
      # (<tt>src/plain_date_time.rs:322-351</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.to_iso_week_date # => [2019, 1, Ferro::Time::Weekday::Tuesday]
      def to_iso_week_date
        Arguments.iso_week_date(Native.plain_ints(self, :to_iso_week_date))
      end

      # The day of the week. Mirrors time's <tt>PlainDateTime::weekday</tt>
      # (<tt>src/plain_date_time.rs:353-374</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.weekday # => Ferro::Time::Weekday::Tuesday
      def weekday
        Arguments.weekday_of(Native.plain_int(self, :weekday))
      end

      # The Julian day number: the days since noon UTC on November 24 of 4714
      # BC in the proleptic Gregorian calendar, day 0. Mirrors time's
      # <tt>PlainDateTime::to_julian_day</tt>
      # (<tt>src/plain_date_time.rs:376-388</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.to_julian_day # => 2_458_485
      def to_julian_day
        Native.plain_int(self, :to_julian_day)
      end

      # The clock hour, from 0 to 23. Mirrors time's
      # <tt>PlainDateTime::hour</tt>
      # (<tt>src/plain_date_time.rs:447-459</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.hour # => 12
      def hour
        Native.plain_int(self, :hour)
      end

      # The minute within the hour, from 0 to 59. Mirrors time's
      # <tt>PlainDateTime::minute</tt>
      # (<tt>src/plain_date_time.rs:461-473</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.minute # => 30
      def minute
        Native.plain_int(self, :minute)
      end

      # The second within the minute, from 0 to 59. Mirrors time's
      # <tt>PlainDateTime::second</tt>
      # (<tt>src/plain_date_time.rs:475-487</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.second # => 45
      def second
        Native.plain_int(self, :second)
      end

      # The milliseconds within the second, from 0 to 999. Mirrors time's
      # <tt>PlainDateTime::millisecond</tt>
      # (<tt>src/plain_date_time.rs:489-501</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.millisecond # => 123
      def millisecond
        Native.plain_int(self, :millisecond)
      end

      # The microseconds within the second, from 0 to 999,999. Mirrors time's
      # <tt>PlainDateTime::microsecond</tt>
      # (<tt>src/plain_date_time.rs:503-518</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.microsecond # => 123_456
      def microsecond
        Native.plain_int(self, :microsecond)
      end

      # The nanoseconds within the second, from 0 to 999,999,999. Mirrors
      # time's <tt>PlainDateTime::nanosecond</tt>
      # (<tt>src/plain_date_time.rs:520-535</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.nanosecond # => 123_456_789
      def nanosecond
        Native.plain_int(self, :nanosecond)
      end

      # The clock hour, minute, and second. An Array for Rust's tuple. Mirrors
      # time's <tt>PlainDateTime::as_hms</tt>
      # (<tt>src/plain_date_time.rs:390-400</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.as_hms # => [12, 30, 45]
      def as_hms
        Native.plain_ints(self, :as_hms)
      end

      # The clock hour, minute, second, and millisecond. An Array for Rust's
      # tuple. Mirrors time's <tt>PlainDateTime::as_hms_milli</tt>
      # (<tt>src/plain_date_time.rs:402-415</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.as_hms_milli # => [12, 30, 45, 123]
      def as_hms_milli
        Native.plain_ints(self, :as_hms_milli)
      end

      # The clock hour, minute, second, and microsecond. An Array for Rust's
      # tuple. Mirrors time's <tt>PlainDateTime::as_hms_micro</tt>
      # (<tt>src/plain_date_time.rs:417-430</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.as_hms_micro # => [12, 30, 45, 123_456]
      def as_hms_micro
        Native.plain_ints(self, :as_hms_micro)
      end

      # The clock hour, minute, second, and nanosecond. An Array for Rust's
      # tuple. Mirrors time's <tt>PlainDateTime::as_hms_nano</tt>
      # (<tt>src/plain_date_time.rs:432-445</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.as_hms_nano # => [12, 30, 45, 123_456_789]
      def as_hms_nano
        Native.plain_ints(self, :as_hms_nano)
      end

      # Computes <tt>self + duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>PlainDateTime::checked_add</tt>
      # (<tt>src/plain_date_time.rs:593-622</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.checked_add(Ferro::Time::Duration::DAY).to_s # => "2019-01-02 12:30:45.123456789"
      #   Ferro::Time::PlainDateTime::MAX.checked_add(Ferro::Time::Duration::DAY) # => nil
      def checked_add(duration)
        Native.plain_arith(self, :checked_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>PlainDateTime::checked_sub</tt>
      # (<tt>src/plain_date_time.rs:624-653</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MIN.checked_sub(Ferro::Time::Duration::DAY) # => nil
      def checked_sub(duration)
        Native.plain_arith(self, :checked_sub, Arguments.duration(duration))
      end

      # Computes <tt>self + duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's
      # <tt>PlainDateTime::saturating_add</tt>
      # (<tt>src/plain_date_time.rs:655-684</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MAX.saturating_add(Ferro::Time::Duration::DAY) == Ferro::Time::PlainDateTime::MAX # => true
      def saturating_add(duration)
        Native.plain_arith(self, :saturating_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's
      # <tt>PlainDateTime::saturating_sub</tt>
      # (<tt>src/plain_date_time.rs:686-715</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::PlainDateTime::MIN.saturating_sub(Ferro::Time::Duration::DAY) == Ferro::Time::PlainDateTime::MIN # => true
      def saturating_sub(duration)
        Native.plain_arith(self, :saturating_sub, Arguments.duration(duration))
      end

      # Adds +duration+, as time's <tt>Add<SignedDuration></tt> does. Where
      # Rust panics because the result leaves the supported range, this raises
      # +RangeError+ with time's message, "resulting value is out of range".
      # Ruby's <tt>+=</tt> works through it. Mirrors time's
      # <tt>Add<SignedDuration> for PlainDateTime</tt>
      # (<tt>src/plain_date_time.rs:1187-1199</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   (datetime + Ferro::Time::Duration::DAY).to_s # => "2019-01-02 12:30:45.123456789"
      #   Ferro::Time::PlainDateTime::MAX + Ferro::Time::Duration::DAY # raises RangeError
      def +(duration)
        Native.plain_arith(self, :+, Arguments.duration(duration))
      end

      # This date and time in +offset+, as an OffsetDateTime: the wall-clock
      # reading stays and the offset says where. Mirrors time's
      # <tt>PlainDateTime::assume_offset</tt>
      # (<tt>src/plain_date_time.rs:537-558</tt>).
      #
      # [offset] UtcOffset.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.assume_offset(Ferro::Time::UtcOffset.from_hms(-5, 0, 0)).unix_timestamp # => 1_546_363_845
      def assume_offset(offset)
        Native.plain_assume_offset(self, offset)
      end

      # This date and time in UTC, as an OffsetDateTime. Mirrors time's
      # <tt>PlainDateTime::assume_utc</tt>
      # (<tt>src/plain_date_time.rs:560-576</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.assume_utc.unix_timestamp # => 1_546_345_845
      def assume_utc
        Native.plain_assume_utc(self)
      end

      # This date and time in UTC, as a UtcDateTime. Mirrors time's
      # <tt>PlainDateTime::as_utc</tt>
      # (<tt>src/plain_date_time.rs:578-591</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.as_utc.to_s # => "2019-01-01 12:30:45.123456789 +00"
      def as_utc
        Native.plain_as_utc(self)
      end

      # Subtracts a SignedDuration, as time's <tt>Sub<SignedDuration></tt>
      # does, raising +RangeError+ with time's message, "resulting value is
      # out of range", where Rust panics; or, given another PlainDateTime,
      # returns the span between them, as <tt>Sub for PlainDateTime</tt> does.
      # Mirrors time's <tt>Sub for PlainDateTime</tt>
      # (<tt>src/plain_date_time.rs:1247-1314</tt>).
      #
      # [other] SignedDuration or PlainDateTime.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   (datetime - Ferro::Time::Duration::DAY).to_s # => "2018-12-31 12:30:45.123456789"
      #   (datetime - datetime.date.midnight).to_s # => "12h30m45s123ms456µs789ns"
      def -(other)
        case other
        when SignedDuration then Native.plain_arith(self, :-, other)
        when PlainDateTime then Native.plain_difference(self, other)
        else raise TypeError, "no implicit conversion of #{other.class} into Ferro::Time::SignedDuration"
        end
      end

      # This date at another clock time. Mirrors time's
      # <tt>PlainDateTime::replace_time</tt>
      # (<tt>src/plain_date_time.rs:720-736</tt>).
      #
      # [time] Time.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_time(Ferro::Time::Time::MIDNIGHT).to_s # => "2019-01-01 0:00:00.0"
      def replace_time(time)
        Native.plain_replace_time(self, time)
      end

      # This clock time on another date. Mirrors time's
      # <tt>PlainDateTime::replace_date</tt>
      # (<tt>src/plain_date_time.rs:738-754</tt>).
      #
      # [date] Date.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_date(Ferro::Time::Date::MIN).to_s # => "-9999-01-01 12:30:45.123456789"
      def replace_date(date)
        Native.plain_replace_date(self, date)
      end

      # Replaces the year. The month and day are unchanged. Raises
      # Error::ComponentRange when the year is out of range, or when the date
      # is February 29 and the new year is not a leap year. Mirrors time's
      # <tt>PlainDateTime::replace_year</tt>
      # (<tt>src/plain_date_time.rs:756-774</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_year(2020).year # => 2020
      #   datetime.replace_year(10_000) # raises Ferro::Time::Error::ComponentRange
      def replace_year(year)
        Native.plain_replace(self, :replace_year, year)
      end

      # Replaces the month of the year. Raises Error::ComponentRange when the
      # day does not exist in the new month. Mirrors time's
      # <tt>PlainDateTime::replace_month</tt>
      # (<tt>src/plain_date_time.rs:776-794</tt>).
      #
      # [month] Month.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_month(Ferro::Time::Month::May).month # => Ferro::Time::Month::May
      #   datetime.replace_day(31).replace_month(Ferro::Time::Month::April) # raises Ferro::Time::Error::ComponentRange
      def replace_month(month)
        Native.plain_replace(self, :replace_month, Arguments.month(month))
      end

      # Replaces the day of the month. Raises Error::ComponentRange when the
      # day does not exist in the month. Mirrors time's
      # <tt>PlainDateTime::replace_day</tt>
      # (<tt>src/plain_date_time.rs:796-814</tt>).
      #
      # [day] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_day(31).day # => 31
      #   datetime.replace_day(32) # raises Ferro::Time::Error::ComponentRange
      def replace_day(day)
        Native.plain_replace(self, :replace_day, day)
      end

      # Replaces the day of the year. Raises Error::ComponentRange when the
      # day does not exist in the year. Mirrors time's
      # <tt>PlainDateTime::replace_ordinal</tt>
      # (<tt>src/plain_date_time.rs:816-831</tt>).
      #
      # [ordinal] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_ordinal(32).to_calendar_date # => [2019, Ferro::Time::Month::February, 1]
      #   datetime.replace_ordinal(366) # raises Ferro::Time::Error::ComponentRange
      def replace_ordinal(ordinal)
        Native.plain_replace(self, :replace_ordinal, ordinal)
      end

      # Replaces the clock hour. Raises Error::ComponentRange outside 0 to 23.
      # Mirrors time's <tt>PlainDateTime::replace_hour</tt>
      # (<tt>src/plain_date_time.rs:848-865</tt>).
      #
      # [hour] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_hour(7).hour # => 7
      #   datetime.replace_hour(24) # raises Ferro::Time::Error::ComponentRange
      def replace_hour(hour)
        Native.plain_replace(self, :replace_hour, hour)
      end

      # Replaces the minutes within the hour. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's <tt>PlainDateTime::replace_minute</tt>
      # (<tt>src/plain_date_time.rs:882-899</tt>).
      #
      # [minute] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_minute(7).minute # => 7
      #   datetime.replace_minute(60) # raises Ferro::Time::Error::ComponentRange
      def replace_minute(minute)
        Native.plain_replace(self, :replace_minute, minute)
      end

      # Replaces the seconds within the minute. Raises Error::ComponentRange
      # outside 0 to 59. Mirrors time's <tt>PlainDateTime::replace_second</tt>
      # (<tt>src/plain_date_time.rs:916-933</tt>).
      #
      # [second] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_second(7).second # => 7
      #   datetime.replace_second(60) # raises Ferro::Time::Error::ComponentRange
      def replace_second(second)
        Native.plain_replace(self, :replace_second, second)
      end

      # Replaces the milliseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999. Mirrors time's
      # <tt>PlainDateTime::replace_millisecond</tt>
      # (<tt>src/plain_date_time.rs:950-970</tt>).
      #
      # [millisecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_millisecond(7).nanosecond # => 7_000_000
      #   datetime.replace_millisecond(1_000) # raises Ferro::Time::Error::ComponentRange
      def replace_millisecond(millisecond)
        Native.plain_replace(self, :replace_millisecond, millisecond)
      end

      # Replaces the microseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999. Mirrors time's
      # <tt>PlainDateTime::replace_microsecond</tt>
      # (<tt>src/plain_date_time.rs:987-1007</tt>).
      #
      # [microsecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_microsecond(7).nanosecond # => 7_000
      #   datetime.replace_microsecond(1_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_microsecond(microsecond)
        Native.plain_replace(self, :replace_microsecond, microsecond)
      end

      # Replaces the nanoseconds within the second. Raises
      # Error::ComponentRange outside 0 to 999,999,999. Mirrors time's
      # <tt>PlainDateTime::replace_nanosecond</tt>
      # (<tt>src/plain_date_time.rs:1024-1041</tt>).
      #
      # [nanosecond] Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.replace_nanosecond(7).nanosecond # => 7
      #   datetime.replace_nanosecond(1_000_000_000) # raises Ferro::Time::Error::ComponentRange
      def replace_nanosecond(nanosecond)
        Native.plain_replace(self, :replace_nanosecond, nanosecond)
      end

      # The value with every component finer than the day set to zero. Mirrors
      # time's <tt>PlainDateTime::truncate_to_day</tt>
      # (<tt>src/plain_date_time.rs:833-846</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.truncate_to_day.as_hms_nano # => [0, 0, 0, 0]
      def truncate_to_day
        Native.plain_truncate(self, :truncate_to_day)
      end

      # The value with every component finer than the hour set to zero.
      # Mirrors time's <tt>PlainDateTime::truncate_to_hour</tt>
      # (<tt>src/plain_date_time.rs:867-880</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.truncate_to_hour.as_hms_nano # => [12, 0, 0, 0]
      def truncate_to_hour
        Native.plain_truncate(self, :truncate_to_hour)
      end

      # The value with every component finer than the minute set to zero.
      # Mirrors time's <tt>PlainDateTime::truncate_to_minute</tt>
      # (<tt>src/plain_date_time.rs:901-914</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.truncate_to_minute.as_hms_nano # => [12, 30, 0, 0]
      def truncate_to_minute
        Native.plain_truncate(self, :truncate_to_minute)
      end

      # The value with every component finer than the second set to zero.
      # Mirrors time's <tt>PlainDateTime::truncate_to_second</tt>
      # (<tt>src/plain_date_time.rs:935-948</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.truncate_to_second.as_hms_nano # => [12, 30, 45, 0]
      def truncate_to_second
        Native.plain_truncate(self, :truncate_to_second)
      end

      # The value with every component finer than the millisecond set to zero.
      # Mirrors time's <tt>PlainDateTime::truncate_to_millisecond</tt>
      # (<tt>src/plain_date_time.rs:972-985</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.truncate_to_millisecond.as_hms_nano # => [12, 30, 45, 123_000_000]
      def truncate_to_millisecond
        Native.plain_truncate(self, :truncate_to_millisecond)
      end

      # The value with every component finer than the microsecond set to zero.
      # Mirrors time's <tt>PlainDateTime::truncate_to_microsecond</tt>
      # (<tt>src/plain_date_time.rs:1009-1022</tt>).
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.truncate_to_microsecond.as_hms_nano # => [12, 30, 45, 123_456_000]
      def truncate_to_microsecond
        Native.plain_truncate(self, :truncate_to_microsecond)
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. Raises an Error::Format variant
      # when a component cannot be formatted, and +TypeError+ when a
      # well-known format needs a component this type lacks, which Rust's
      # compiler refuses. Mirrors time's <tt>PlainDateTime::format</tt>
      # (<tt>src/plain_date_time.rs:1057-1075</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.format(Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE_TIME) # => "2019-01-01T12:30:45.123456789"
      def format(description)
        Native.plain_format(self, Arguments.description(description))
      end

      # Formats the value with +description+ onto the end of +output+ and
      # returns the count time's +format_into+ returns, which is the number of
      # bytes written except where time leaves some out, as it does for the
      # digits of a fraction of a second in RFC 3339 and for an ISO 8601 hour
      # or minute with a decimal fraction. Rust writes to any
      # <tt>io::Write</tt>; here +output+ is a String, which keeps what time
      # wrote even when formatting fails partway, as Rust's writer does. A
      # frozen +output+ raises +FrozenError+ before anything is formatted.
      # Mirrors time's <tt>PlainDateTime::format_into</tt>
      # (<tt>src/plain_date_time.rs:1046-1055</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   output = +"on "
      #   datetime.format_into(output, Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE_TIME) # => 29
      #   output # => "on 2019-01-01T12:30:45.123456789"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.plain_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # Whether +other+ is the same PlainDateTime, by time's +PartialEq+.
      # +false+ for anything else.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime == Ferro::Time::PlainDateTime::MAX # => false
      #   datetime == datetime # => true
      def ==(other)
        other.is_a?(PlainDateTime) && Native.plain_eq(self, other)
      end

      # Whether +other+ is an equal PlainDateTime, as time's +Eq+ says, so
      # that equal values are the same Hash key.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.eql?(datetime) # => true
      def eql?(other)
        other.is_a?(PlainDateTime) && Native.plain_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.hash == datetime.hash # => true
      def hash
        Native.plain_hash(self)
      end

      # Compares with another PlainDateTime by time's +Ord+, so the Comparable
      # operators answer as Rust's do; +nil+ for anything else.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime <=> Ferro::Time::PlainDateTime::MAX # => -1
      def <=>(other)
        Native.plain_cmp(self, other) if other.is_a?(PlainDateTime)
      end

      # The value as time's +Display+ writes it.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.to_s # => "2019-01-01 12:30:45.123456789"
      def to_s
        Native.plain_display(self)
      end

      # The value as time's +Debug+ writes it.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
      #   datetime.inspect # => "2019-01-01 12:30:45.123456789"
      def inspect
        Native.plain_debug(self)
      end

      # The value itself. A PlainDateTime is +Copy+ in Rust and frozen here,
      # so a copy would be the same value; Ruby answers the same way for an
      # Integer.
      #
      # === Example
      #
      #   datetime = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).with_hms_nano(12, 30, 45, 123_456_789)
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
      #   datetime.clone.equal?(datetime) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::PlainDateTime" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
