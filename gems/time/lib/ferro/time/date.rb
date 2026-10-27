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
    # SPDX-SnippetComment: Date, its methods, and their docs from time 0.3.55 src/date.rs
    #++

    # A date in the proleptic Gregorian calendar: a year, a month, and a day.
    #
    # Ruby's own ::Date reckons in the Julian calendar before 1582 by default,
    # carries a calendar reform setting, and accepts dates far outside the
    # range a Rust service will read back. A date you hand to a Rust program,
    # or read from one, follows time's rules instead: years from -9999 to
    # 9999, every day in the proleptic Gregorian calendar, and errors that
    # name the component out of range.
    #
    # A Date is time's +Date+, made and checked by time itself. Build one with
    # Date.from_calendar_date, Date.from_ordinal_date, Date.from_iso_week_date,
    # or Date.from_julian_day, read its parts, step through days and weeks,
    # and add or subtract a SignedDuration. Dates compare, order, and hash as
    # time's do.
    #
    # A Date is frozen and shareable between Ractors. It is not Ruby's
    # ::Date, and ferro-time converts between the two nowhere, because time
    # has no such conversion. Ruby's has its own uses; reach for this one when
    # the answer must match time's.
    #
    # Mirrors time's +Date+ (<tt>src/date.rs</tt>). time's +large-dates+
    # feature is off (plan 007, decision 2), so years run from -9999 to 9999.
    #
    # === Examples
    #
    #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
    #   date.weekday # => Ferro::Time::Weekday::Tuesday
    #   (date + Ferro::Time::Duration.days(30)).to_s # => "2019-01-31"
    #
    #   Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::February, 29)
    #   # raises Ferro::Time::Error::ComponentRange: day was not in range
    class Date
      include Comparable

      class << self
        # Creates a Date from the year, month, and day, raising
        # Error::ComponentRange when one is out of range or the day does not
        # exist in that month. Mirrors time's
        # <tt>Date::from_calendar_date</tt> (<tt>src/date.rs:130-174</tt>).
        #
        # [year] Integer.
        # [month] Month.
        # [day] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1).to_s # => "2019-01-01"
        #   Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::December, 31).to_s # => "2019-12-31"
        def from_calendar_date(year, month, day)
          Native.date_from_calendar_date(year, Arguments.month(month), day)
        end

        # Creates a Date from the year and the day of the year, raising
        # Error::ComponentRange when one is out of range. Mirrors time's
        # <tt>Date::from_ordinal_date</tt> (<tt>src/date.rs:176-204</tt>).
        #
        # [year] Integer.
        # [ordinal] Integer, from 1.
        #
        # === Example
        #
        #   Ferro::Time::Date.from_ordinal_date(2019, 1).to_s # => "2019-01-01"
        #   Ferro::Time::Date.from_ordinal_date(2019, 365).to_s # => "2019-12-31"
        def from_ordinal_date(year, ordinal)
          Native.date_from_ordinal_date(year, ordinal)
        end

        # Creates a Date from the ISO year, ISO week number, and weekday,
        # raising Error::ComponentRange when one is out of range. Mirrors
        # time's <tt>Date::from_iso_week_date</tt>
        # (<tt>src/date.rs:206-274</tt>).
        #
        # [year] Integer, the ISO year.
        # [week] Integer, from 1.
        # [weekday] Weekday.
        #
        # === Example
        #
        #   Ferro::Time::Date.from_iso_week_date(2019, 1, Ferro::Time::Weekday::Monday).to_s # => "2018-12-31"
        #   Ferro::Time::Date.from_iso_week_date(2020, 53, Ferro::Time::Weekday::Friday).to_s # => "2021-01-01"
        def from_iso_week_date(year, week, weekday)
          Native.date_from_iso_week_date(year, week, Arguments.weekday(weekday))
        end

        # Creates a Date from its Julian day number, raising
        # Error::ComponentRange outside <tt>Date::MIN.to_julian_day</tt> to
        # <tt>Date::MAX.to_julian_day</tt>. Mirrors time's
        # <tt>Date::from_julian_day</tt> (<tt>src/date.rs:276-293</tt>).
        #
        # [julian_day] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Date.from_julian_day(0).to_s # => "-4713-11-24"
        #   Ferro::Time::Date.from_julian_day(2_451_545).to_s # => "2000-01-01"
        def from_julian_day(julian_day)
          Native.date_from_julian_day(julian_day)
        end

        # Parses a Date from +input+ with +description+, which takes the same
        # kinds of description as #format. Raises an Error::Parse variant when
        # the input does not match. Mirrors time's <tt>Date::parse</tt>
        # (<tt>src/date.rs:1493-1509</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   Ferro::Time::Date.parse("2020-01-02", Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE).to_s # => "2020-01-02"
        def parse(input, description)
          Native.date_parse(input, Arguments.description(description))
        end
      end

      # The minimum valid Date, January 1 of -9999. Mirrors time's
      # <tt>Date::MIN</tt> (<tt>src/date.rs:80-80</tt>).
      MIN = Native.date_constant(:MIN)

      # The maximum valid Date, December 31 of 9999. Mirrors time's
      # <tt>Date::MAX</tt> (<tt>src/date.rs:86-88</tt>).
      MAX = Native.date_constant(:MAX)

      # The year of the date. Mirrors time's <tt>Date::year</tt>
      # (<tt>src/date.rs:344-355</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.year # => 2019
      def year
        Native.date_int(self, :year)
      end

      # The month. Mirrors time's <tt>Date::month</tt>
      # (<tt>src/date.rs:357-386</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.month # => Ferro::Time::Month::January
      def month
        Arguments.month_of(Native.date_int(self, :month))
      end

      # The day of the month, from 1 to 31. Mirrors time's <tt>Date::day</tt>
      # (<tt>src/date.rs:388-412</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.day # => 1
      def day
        Native.date_int(self, :day)
      end

      # The day of the year, from 1 to 366 (1 to 365 in a common year).
      # Mirrors time's <tt>Date::ordinal</tt> (<tt>src/date.rs:414-426</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.ordinal # => 1
      def ordinal
        Native.date_int(self, :ordinal)
      end

      # The ISO week number, from 1 to 53. The first ISO week of a year is the
      # week containing its first Thursday, so a date in early January or late
      # December may belong to a week of the next or previous ISO year.
      # Mirrors time's <tt>Date::iso_week</tt> (<tt>src/date.rs:440-455</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.iso_week # => 1
      def iso_week
        Native.date_int(self, :iso_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Sunday
      # of the calendar year. Mirrors time's <tt>Date::sunday_based_week</tt>
      # (<tt>src/date.rs:457-472</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.sunday_based_week # => 0
      def sunday_based_week
        Native.date_int(self, :sunday_based_week)
      end

      # The week number, from 0 to 53, where week 1 begins on the first Monday
      # of the calendar year. Mirrors time's <tt>Date::monday_based_week</tt>
      # (<tt>src/date.rs:474-489</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.monday_based_week # => 0
      def monday_based_week
        Native.date_int(self, :monday_based_week)
      end

      # The year, month, and day, as a three-element Array for Rust's tuple.
      # Mirrors time's <tt>Date::to_calendar_date</tt>
      # (<tt>src/date.rs:491-530</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.to_calendar_date # => [2019, Ferro::Time::Month::January, 1]
      def to_calendar_date
        Arguments.calendar_date(Native.date_ints(self, :to_calendar_date))
      end

      # The year and the day of the year, as a two-element Array for Rust's
      # tuple. Mirrors time's <tt>Date::to_ordinal_date</tt>
      # (<tt>src/date.rs:532-541</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.to_ordinal_date # => [2019, 1]
      def to_ordinal_date
        Native.date_ints(self, :to_ordinal_date)
      end

      # The ISO year, ISO week number, and weekday, as a three-element Array
      # for Rust's tuple. The ISO year may differ from #year near the turn of
      # a year. Mirrors time's <tt>Date::to_iso_week_date</tt>
      # (<tt>src/date.rs:543-564</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.to_iso_week_date # => [2019, 1, Ferro::Time::Weekday::Tuesday]
      def to_iso_week_date
        Arguments.iso_week_date(Native.date_ints(self, :to_iso_week_date))
      end

      # The day of the week. Mirrors time's <tt>Date::weekday</tt>
      # (<tt>src/date.rs:566-598</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.weekday # => Ferro::Time::Weekday::Tuesday
      def weekday
        Arguments.weekday_of(Native.date_int(self, :weekday))
      end

      # The Julian day number: the days since noon UTC on November 24 of 4714
      # BC in the proleptic Gregorian calendar, day 0. Mirrors time's
      # <tt>Date::to_julian_day</tt> (<tt>src/date.rs:767-787</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.to_julian_day # => 2_458_485
      def to_julian_day
        Native.date_int(self, :to_julian_day)
      end

      # The next calendar date, or +nil+ after Date::MAX. Mirrors time's
      # <tt>Date::next_day</tt> (<tt>src/date.rs:600-624</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.next_day.to_s # => "2019-01-02"
      #   Ferro::Time::Date::MAX.next_day # => nil
      def next_day
        Native.date_option(self, :next_day)
      end

      # The previous calendar date, or +nil+ before Date::MIN. Mirrors time's
      # <tt>Date::previous_day</tt> (<tt>src/date.rs:626-650</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.previous_day.to_s # => "2018-12-31"
      #   Ferro::Time::Date::MIN.previous_day # => nil
      def previous_day
        Native.date_option(self, :previous_day)
      end

      # The first date on +weekday+ strictly later than this one. Where Rust
      # panics because that date is past Date::MAX, this raises +RangeError+
      # with time's message. Mirrors time's <tt>Date::next_occurrence</tt>
      # (<tt>src/date.rs:652-675</tt>).
      #
      # [weekday] Weekday.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.next_occurrence(Ferro::Time::Weekday::Monday).to_s # => "2019-01-07"
      def next_occurrence(weekday)
        Native.date_occurrence(self, :next_occurrence, Arguments.weekday(weekday), 1)
      end

      # The last date on +weekday+ strictly earlier than this one. Where Rust
      # panics because that date is before Date::MIN, this raises +RangeError+
      # with time's message. Mirrors time's <tt>Date::prev_occurrence</tt>
      # (<tt>src/date.rs:677-700</tt>).
      #
      # [weekday] Weekday.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.prev_occurrence(Ferro::Time::Weekday::Monday).to_s # => "2018-12-31"
      def prev_occurrence(weekday)
        Native.date_occurrence(self, :prev_occurrence, Arguments.weekday(weekday), 1)
      end

      # The +n+th date on +weekday+ strictly later than this one. Where Rust
      # panics, because that date is past Date::MAX or because +n+ is zero,
      # this raises +RangeError+ with time's message. Mirrors time's
      # <tt>Date::nth_next_occurrence</tt> (<tt>src/date.rs:702-725</tt>).
      #
      # [weekday] Weekday.
      # [n] Integer, from 1.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.nth_next_occurrence(Ferro::Time::Weekday::Monday, 2).to_s # => "2019-01-14"
      def nth_next_occurrence(weekday, n)
        Native.date_occurrence(self, :nth_next_occurrence, Arguments.weekday(weekday), n)
      end

      # The +n+th date on +weekday+ strictly earlier than this one. Where Rust
      # panics, because that date is before Date::MIN or because +n+ is zero,
      # this raises +RangeError+ with time's message. Mirrors time's
      # <tt>Date::nth_prev_occurrence</tt> (<tt>src/date.rs:727-750</tt>).
      #
      # [weekday] Weekday.
      # [n] Integer, from 1.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.nth_prev_occurrence(Ferro::Time::Weekday::Monday, 2).to_s # => "2018-12-24"
      def nth_prev_occurrence(weekday, n)
        Native.date_occurrence(self, :nth_prev_occurrence, Arguments.weekday(weekday), n)
      end

      # Computes <tt>self + duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>Date::checked_add</tt>
      # (<tt>src/date.rs:802-862</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.checked_add(Ferro::Time::Duration::DAY).to_s # => "2019-01-02"
      #   Ferro::Time::Date::MAX.checked_add(Ferro::Time::Duration::DAY) # => nil
      def checked_add(duration)
        Native.date_arith(self, :checked_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, returning +nil+ if an overflow
      # occurred. Mirrors time's <tt>Date::checked_sub</tt>
      # (<tt>src/date.rs:924-984</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Date::MIN.checked_sub(Ferro::Time::Duration::DAY) # => nil
      def checked_sub(duration)
        Native.date_arith(self, :checked_sub, Arguments.duration(duration))
      end

      # Computes <tt>self + duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's <tt>Date::saturating_add</tt>
      # (<tt>src/date.rs:1110-1149</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Date::MAX.saturating_add(Ferro::Time::Duration::DAY) == Ferro::Time::Date::MAX # => true
      def saturating_add(duration)
        Native.date_arith(self, :saturating_add, Arguments.duration(duration))
      end

      # Computes <tt>self - duration</tt>, saturating at the earliest or
      # latest value on overflow. Mirrors time's <tt>Date::saturating_sub</tt>
      # (<tt>src/date.rs:1151-1190</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Date::MIN.saturating_sub(Ferro::Time::Duration::DAY) == Ferro::Time::Date::MIN # => true
      def saturating_sub(duration)
        Native.date_arith(self, :saturating_sub, Arguments.duration(duration))
      end

      # Adds +duration+, as time's <tt>Add<SignedDuration></tt> does. Where
      # Rust panics because the result leaves the supported range, this raises
      # +RangeError+ with time's message, "overflow adding duration to date".
      # Ruby's <tt>+=</tt> works through it. Mirrors time's
      # <tt>Add<SignedDuration> for Date</tt>
      # (<tt>src/date.rs:1661-1672</tt>).
      #
      # [duration] SignedDuration.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   (date + Ferro::Time::Duration::DAY).to_s # => "2019-01-02"
      #   Ferro::Time::Date::MAX + Ferro::Time::Duration::DAY # raises RangeError
      def +(duration)
        Native.date_arith(self, :+, Arguments.duration(duration))
      end

      # Subtracts a SignedDuration, as time's <tt>Sub<SignedDuration></tt>
      # does, raising +RangeError+ with time's message, "overflow subtracting
      # duration from date", where Rust panics; or, given another Date,
      # returns the whole days between them as a SignedDuration, as <tt>Sub
      # for Date</tt> does. Mirrors time's <tt>Sub for Date</tt>
      # (<tt>src/date.rs:1711-1768</tt>).
      #
      # [other] SignedDuration or Date.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   (date - Ferro::Time::Duration::DAY).to_s # => "2018-12-31"
      #   (date - Ferro::Time::Date.from_ordinal_date(2018, 365)).to_s # => "1d"
      def -(other)
        case other
        when SignedDuration then Native.date_arith(self, :-, other)
        when Date then Native.date_difference(self, other)
        else raise TypeError, "no implicit conversion of #{other.class} into Ferro::Time::SignedDuration"
        end
      end

      # Replaces the year. The month and day are unchanged. Raises
      # Error::ComponentRange when the year is out of range, or when the date
      # is February 29 and the new year is not a leap year. Mirrors time's
      # <tt>Date::replace_year</tt> (<tt>src/date.rs:1192-1238</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.replace_year(2020).year # => 2020
      #   date.replace_year(10_000) # raises Ferro::Time::Error::ComponentRange
      def replace_year(year)
        Native.date_replace(self, :replace_year, year)
      end

      # Replaces the month of the year. Raises Error::ComponentRange when the
      # day does not exist in the new month. Mirrors time's
      # <tt>Date::replace_month</tt> (<tt>src/date.rs:1240-1291</tt>).
      #
      # [month] Month.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.replace_month(Ferro::Time::Month::May).month # => Ferro::Time::Month::May
      #   date.replace_day(31).replace_month(Ferro::Time::Month::April) # raises Ferro::Time::Error::ComponentRange
      def replace_month(month)
        Native.date_replace(self, :replace_month, Arguments.month(month))
      end

      # Replaces the day of the month. Raises Error::ComponentRange when the
      # day does not exist in the month. Mirrors time's
      # <tt>Date::replace_day</tt> (<tt>src/date.rs:1293-1324</tt>).
      #
      # [day] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.replace_day(31).day # => 31
      #   date.replace_day(32) # raises Ferro::Time::Error::ComponentRange
      def replace_day(day)
        Native.date_replace(self, :replace_day, day)
      end

      # Replaces the day of the year. Raises Error::ComponentRange when the
      # day does not exist in the year. Mirrors time's
      # <tt>Date::replace_ordinal</tt> (<tt>src/date.rs:1326-1349</tt>).
      #
      # [ordinal] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.replace_ordinal(32).to_calendar_date # => [2019, Ferro::Time::Month::February, 1]
      #   date.replace_ordinal(366) # raises Ferro::Time::Error::ComponentRange
      def replace_ordinal(ordinal)
        Native.date_replace(self, :replace_ordinal, ordinal)
      end

      # This date at midnight, a PlainDateTime. Mirrors time's
      # <tt>Date::midnight</tt> (<tt>src/date.rs:1354-1364</tt>).
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.midnight.to_s # => "2019-01-01 0:00:00.0"
      def midnight
        Native.date_midnight(self)
      end

      # This date at +time+, a PlainDateTime. Mirrors time's
      # <tt>Date::with_time</tt> (<tt>src/date.rs:1366-1378</tt>).
      #
      # [time] Time.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.with_time(Ferro::Time::Time.from_hms(12, 30, 0)).to_s # => "2019-01-01 12:30:00.0"
      def with_time(time)
        Native.date_with_time(self, time)
      end

      # This date at the given clock time, raising Error::ComponentRange when
      # a component is out of range. Mirrors time's <tt>Date::with_hms</tt>
      # (<tt>src/date.rs:1380-1398</tt>).
      #
      # [hour] Integer.
      # [minute] Integer.
      # [second] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.with_hms(12, 30, 45).to_s # => "2019-01-01 12:30:45.0"
      #   date.with_hms(24, 0, 0) # raises Ferro::Time::Error::ComponentRange
      def with_hms(hour, minute, second)
        Native.date_with_hms(self, hour, minute, second)
      end

      # This date at the given clock time and millisecond, raising
      # Error::ComponentRange when a component is out of range. Mirrors time's
      # <tt>Date::with_hms_milli</tt> (<tt>src/date.rs:1400-1419</tt>).
      #
      # [hour] Integer.
      # [minute] Integer.
      # [second] Integer.
      # [millisecond] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.with_hms_milli(12, 30, 45, 123).to_s # => "2019-01-01 12:30:45.123"
      def with_hms_milli(hour, minute, second, millisecond)
        Native.date_with_hms_milli(self, hour, minute, second, millisecond)
      end

      # This date at the given clock time and microsecond, raising
      # Error::ComponentRange when a component is out of range. Mirrors time's
      # <tt>Date::with_hms_micro</tt> (<tt>src/date.rs:1421-1440</tt>).
      #
      # [hour] Integer.
      # [minute] Integer.
      # [second] Integer.
      # [microsecond] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.with_hms_micro(12, 30, 45, 123_456).to_s # => "2019-01-01 12:30:45.123456"
      def with_hms_micro(hour, minute, second, microsecond)
        Native.date_with_hms_micro(self, hour, minute, second, microsecond)
      end

      # This date at the given clock time and nanosecond, raising
      # Error::ComponentRange when a component is out of range. Mirrors time's
      # <tt>Date::with_hms_nano</tt> (<tt>src/date.rs:1442-1461</tt>).
      #
      # [hour] Integer.
      # [minute] Integer.
      # [second] Integer.
      # [nanosecond] Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.with_hms_nano(12, 30, 45, 123_456_789).to_s # => "2019-01-01 12:30:45.123456789"
      def with_hms_nano(hour, minute, second, nanosecond)
        Native.date_with_hms_nano(self, hour, minute, second, nanosecond)
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. Raises an Error::Format variant
      # when a component cannot be formatted, and +TypeError+ when a
      # well-known format needs a component this type lacks, which Rust's
      # compiler refuses. Mirrors time's <tt>Date::format</tt>
      # (<tt>src/date.rs:1476-1488</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.format(Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE) # => "2019-01-01"
      def format(description)
        Native.date_format(self, Arguments.description(description))
      end

      # Formats the value with +description+ onto the end of +output+ and
      # returns the count time's +format_into+ returns, which is the number of
      # bytes written except where time leaves some out, as it does for the
      # digits of a fraction of a second in RFC 3339 and for an ISO 8601 hour
      # or minute with a decimal fraction. Rust writes to any
      # <tt>io::Write</tt>; here +output+ is a String, which keeps what time
      # wrote even when formatting fails partway, as Rust's writer does. A
      # frozen +output+ raises +FrozenError+ before anything is formatted.
      # Mirrors time's <tt>Date::format_into</tt>
      # (<tt>src/date.rs:1466-1474</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   output = +"on "
      #   date.format_into(output, Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE) # => 10
      #   output # => "on 2019-01-01"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.date_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # Whether +other+ is the same Date, by time's +PartialEq+. +false+ for
      # anything else.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date == Ferro::Time::Date::MAX # => false
      #   date == date # => true
      def ==(other)
        other.is_a?(Date) && Native.date_eq(self, other)
      end

      # Whether +other+ is an equal Date, as time's +Eq+ says, so that equal
      # values are the same Hash key.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.eql?(date) # => true
      def eql?(other)
        other.is_a?(Date) && Native.date_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.hash == date.hash # => true
      def hash
        Native.date_hash(self)
      end

      # Compares with another Date by time's +Ord+, so the Comparable
      # operators answer as Rust's do; +nil+ for anything else.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date <=> Ferro::Time::Date::MAX # => -1
      def <=>(other)
        Native.date_cmp(self, other) if other.is_a?(Date)
      end

      # The value as time's +Display+ writes it.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.to_s # => "2019-01-01"
      def to_s
        Native.date_display(self)
      end

      # The value as time's +Debug+ writes it.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.inspect # => "2019-01-01"
      def inspect
        Native.date_debug(self)
      end

      # The value itself. A Date is +Copy+ in Rust and frozen here, so a copy
      # would be the same value; Ruby answers the same way for an Integer.
      #
      # === Example
      #
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.dup.equal?(date) # => true
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
      #   date = Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::January, 1)
      #   date.clone.equal?(date) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::Date" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
