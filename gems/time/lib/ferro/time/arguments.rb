# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    # Converts the gem's Ruby values to what the native layer takes, and
    # back. Private to the gem.
    module Arguments # :nodoc:
      class << self
        # The number of +month+, refusing anything but a Month as Rust's
        # type checker would.
        def month(month)
          raise TypeError, "no implicit conversion of #{month.class} into Ferro::Time::Month" unless month.is_a?(Month)

          month.to_i
        end

        # The Month numbered +number+.
        def month_of(number)
          Month.const_get(:ALL).fetch(number - 1)
        end

        # The days from Monday of +weekday+, refusing anything but a Weekday.
        def weekday(weekday)
          unless weekday.is_a?(Weekday)
            raise TypeError, "no implicit conversion of #{weekday.class} into Ferro::Time::Weekday"
          end

          weekday.__send__(:days_from_monday)
        end

        # The Weekday +days+ after Monday.
        def weekday_of(days)
          Weekday.const_get(:ALL).fetch(days)
        end

        # +duration+, refusing anything but a SignedDuration.
        def duration(duration)
          unless duration.is_a?(SignedDuration)
            raise TypeError, "no implicit conversion of #{duration.class} into Ferro::Time::SignedDuration"
          end

          duration
        end

        # A year, month number, and day, with the month as a Month.
        def calendar_date(parts)
          year, month, day = parts
          [year, month_of(month), day]
        end

        # An ISO year, week, and weekday number, with the weekday as a
        # Weekday.
        def iso_week_date(parts)
          year, week, weekday = parts
          [year, week, weekday_of(weekday)]
        end

        # The native form of a description: a version 3 description itself,
        # a well-known format's name, or an ISO 8601 configuration's
        # settings (plan 007, decision 11).
        def description(description)
          wk = FormatDescription::WellKnown
          case description
          when FormatDescription::FormatDescriptionV3 then description
          when wk::Iso8601 then description.__send__(:config).__send__(:settings)
          else
            return :rfc2822 if description.equal?(wk::Rfc2822)
            return :rfc3339 if description.equal?(wk::Rfc3339)
            return wk::Iso8601::DEFAULT.__send__(:config).__send__(:settings) if description.equal?(wk::Iso8601)

            raise TypeError, "no implicit conversion of #{description.inspect} into a format description"
          end
        end

        # Refuses an +output+ that is not a String, or is frozen, before
        # anything is formatted.
        def sink(output)
          raise TypeError, "no implicit conversion of #{output.class} into String" unless output.is_a?(String)
          raise FrozenError.new("can't modify frozen String: #{output.inspect}", receiver: output) if output.frozen?
        end

        # The whole seconds and nanoseconds since the epoch of Ruby's
        # +time+, the parts of a +SystemTime+ (plan 007, decision 10).
        def system_time(time)
          raise TypeError, "no implicit conversion of #{time.class} into Time" unless time.is_a?(::Time)

          [time.to_i, time.nsec]
        end

        # Ruby's ::Time, in UTC, at +seconds+ and +nanoseconds+ after the
        # epoch.
        def ruby_time(parts)
          seconds, nanoseconds = parts
          ::Time.at(seconds, nanoseconds, :nsec, in: "UTC")
        end
      end
    end
  end
end
