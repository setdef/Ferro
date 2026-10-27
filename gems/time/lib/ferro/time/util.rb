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
    # SPDX-SnippetComment: time 0.3.55's util module and its docs (src/util.rs,
    #   and time-core 0.1.9 src/util.rs, which it re-exports)
    #++

    # Utility functions, including updating time zone information.
    #
    # Leap years, the length of a month, the number of ISO weeks in a year:
    # the calendar arithmetic every date library does, exposed as time
    # does it, so a Ruby program asks the same questions and gets the same
    # answers.
    #
    # Util also refreshes the system's time-zone information where time can
    # prove the call sound (Util.refresh_tz). time's
    # <tt>refresh_tz_unchecked</tt> is not bound: time says "it is not
    # possible for a library to soundly call this method", and a Ruby
    # process cannot vouch for every thread in it (plan 007, decision 13).
    #
    # Mirrors time's +util+ (<tt>src/util.rs</tt>).
    #
    # === Examples
    #
    #   Ferro::Time::Util.is_leap_year(2000) # => true
    #   Ferro::Time::Util.days_in_month(Ferro::Time::Month::February, 2100) # => 28
    module Util
      # Whether +year+ is a leap year in the proleptic Gregorian calendar.
      # Mirrors time-core's <tt>util::is_leap_year</tt>
      # (<tt>time-core-0.1.9 src/util.rs:68-101</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Util.is_leap_year(2000) # => true
      #   Ferro::Time::Util.is_leap_year(2001) # => false
      #   Ferro::Time::Util.is_leap_year(2100) # => false
      def self.is_leap_year(year)
        Native.util_is_leap_year(year)
      end

      # The number of days in +year+: 366 in a leap year, 365 otherwise.
      # Mirrors time-core's <tt>util::days_in_year</tt>
      # (<tt>time-core-0.1.9 src/util.rs:103-115</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Util.days_in_year(1900) # => 365
      #   Ferro::Time::Util.days_in_year(2000) # => 366
      def self.days_in_year(year)
        Native.util_days_in_year(year)
      end

      # The number of ISO weeks in +year+: 53 or 52. Mirrors time-core's
      # <tt>util::weeks_in_year</tt> (<tt>time-core-0.1.9 src/util.rs:117-142</tt>).
      #
      # [year] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Util.weeks_in_year(2019) # => 52
      #   Ferro::Time::Util.weeks_in_year(2020) # => 53
      def self.weeks_in_year(year)
        Native.util_weeks_in_year(year)
      end

      # The number of days in +month+ of +year+. Mirrors time's
      # <tt>util::days_in_month</tt> (<tt>src/util.rs:29-38</tt>).
      #
      # [month] Month.
      # [year] Integer.
      #
      # === Example
      #
      #   Ferro::Time::Util.days_in_month(Ferro::Time::Month::February, 2020) # => 29
      def self.days_in_month(month, year)
        Native.util_days_in_month(Arguments.month(month), year)
      end

      # The number of days in +month+ of +year+, as days_in_month answers.
      # Deprecated in time since 0.3.37 ("use +days_in_month+ or
      # <tt>Month::length</tt> instead"), so it warns in Ruby's
      # +:deprecated+ category, naming days_in_month and Month#length. Mirrors
      # time's <tt>util::days_in_year_month</tt> (<tt>src/util.rs:40-54</tt>).
      #
      # [year] Integer.
      # [month] Month.
      #
      # === Example
      #
      #   Ferro::Time::Util.days_in_year_month(2020, Ferro::Time::Month::February) # => 29
      def self.days_in_year_month(year, month)
        warn("Ferro::Time::Util.days_in_year_month is deprecated since time 0.3.37; use days_in_month or Month#length",
          category: :deprecated, uplevel: 1)
        Native.util_days_in_year_month(year, Arguments.month(month))
      end

      # Attempts to update time zone information from the system, as
      # +tzset+ does. Returns +true+ when it ran, or +nil+ when the call is
      # not known to be sound: time runs it only on illumos, NetBSD, and
      # macOS, whose environment functions are thread-safe, or in a
      # single-threaded process, which a Ruby process on Linux never is.
      # Rust's <tt>Option<()></tt> is +true+ or +nil+ here, since Ruby's
      # +nil+ alone could not tell the two apart (plan 007, decision 13).
      #
      # Mirrors time's <tt>util::refresh_tz</tt> (<tt>src/util.rs:126-133</tt>).
      #
      # === Example
      #
      #   if Ferro::Time::Util.refresh_tz
      #     # time reread the zone rules after ENV["TZ"] changed.
      #   end
      def self.refresh_tz
        Native.util_refresh_tz
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
