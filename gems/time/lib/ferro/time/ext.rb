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
    # SPDX-SnippetComment: the extension traits and their docs from time 0.3.55 src/ext/
    #++

    # time's extension traits, as refinements.
    #
    # In Rust, <tt>5.seconds()</tt> reads better than
    # <tt>SignedDuration::seconds(5)</tt>, so time adds methods to Rust's
    # numbers and to +SystemTime+ through traits a program brings into
    # scope with +use+. Changing Ruby's Integer, Float, or ::Time for every
    # program that loads this gem would reach code that never asked for it.
    #
    # Each trait is a module here holding refinements of the Ruby classes
    # that stand for the Rust types time implements it for, brought into
    # scope with +using+ as Rust's is with +use+; outside that file or
    # module nothing changes (ADR 001, 2026-11-05). Ruby's Integer stands
    # for +i64+ or +u64+, so an Integer outside it raises +RangeError+;
    # Float stands for +f64+; ::Time stands for +SystemTime+, as everywhere
    # in this gem.
    #
    # time's +InstantExt+ extends std's +Instant+, which no Ruby class
    # stands for, so it has no module here.
    #
    # Mirrors time's <tt>ext</tt> module (<tt>src/ext/mod.rs</tt>).
    #
    # === Example
    #
    #   using Ferro::Time::Ext::NumericalDuration
    #
    #   5.seconds == Ferro::Time::Duration.seconds(5) # => true
    #   (2.seconds + 500.milliseconds) == 2_500.milliseconds # => true
    module Ext
      # Creates SignedDurations from numbers: <tt>5.seconds</tt> is
      # <tt>SignedDuration.seconds(5)</tt>.
      #
      # Refines Integer as time's impl for +i64+ does: each method calls
      # SignedDuration's constructor of the same name, raising what it
      # raises, and an Integer outside 64 bits raises +RangeError+. Refines
      # Float as time's impl for +f64+ does: the count, in nanoseconds, is
      # truncated toward zero and saturates at the range, so a Float never
      # raises; time warns that floating-point numbers are inherently
      # imprecise and have limited capacity.
      #
      # Mirrors time's <tt>ext::NumericalDuration</tt>
      # (<tt>src/ext/numerical_duration.rs:57-168</tt>).
      #
      # === Example
      #
      #   using Ferro::Time::Ext::NumericalDuration
      #
      #   5.nanoseconds == Ferro::Time::Duration.nanoseconds(5) # => true
      #   (-5).weeks == Ferro::Time::Duration.weeks(-5) # => true
      #   1.5.seconds == Ferro::Time::Duration.milliseconds(1_500) # => true
      module NumericalDuration
        refine Integer do
          # A SignedDuration of this many nanoseconds.
          def nanoseconds
            Native.duration_unit(:nanoseconds, _ = self)
          end

          # A SignedDuration of this many microseconds.
          def microseconds
            Native.duration_unit(:microseconds, _ = self)
          end

          # A SignedDuration of this many milliseconds.
          def milliseconds
            Native.duration_unit(:milliseconds, _ = self)
          end

          # A SignedDuration of this many seconds.
          def seconds
            Native.duration_unit(:seconds, _ = self)
          end

          # A SignedDuration of this many minutes, raising +RangeError+ with
          # time's message where its seconds would overflow.
          def minutes
            Native.duration_unit(:minutes, _ = self)
          end

          # A SignedDuration of this many hours, as #minutes raises.
          def hours
            Native.duration_unit(:hours, _ = self)
          end

          # A SignedDuration of this many days, as #minutes raises.
          def days
            Native.duration_unit(:days, _ = self)
          end

          # A SignedDuration of this many weeks, as #minutes raises.
          def weeks
            Native.duration_unit(:weeks, _ = self)
          end
        end

        refine Float do
          # A SignedDuration of this many nanoseconds, truncated.
          def nanoseconds
            Native.numerical_duration_float(:nanoseconds, _ = self)
          end

          # A SignedDuration of this many microseconds, truncated to the
          # nanosecond.
          def microseconds
            Native.numerical_duration_float(:microseconds, _ = self)
          end

          # A SignedDuration of this many milliseconds, truncated to the
          # nanosecond.
          def milliseconds
            Native.numerical_duration_float(:milliseconds, _ = self)
          end

          # A SignedDuration of this many seconds, truncated to the
          # nanosecond.
          def seconds
            Native.numerical_duration_float(:seconds, _ = self)
          end

          # A SignedDuration of this many minutes, truncated to the
          # nanosecond.
          def minutes
            Native.numerical_duration_float(:minutes, _ = self)
          end

          # A SignedDuration of this many hours, truncated to the
          # nanosecond.
          def hours
            Native.numerical_duration_float(:hours, _ = self)
          end

          # A SignedDuration of this many days, truncated to the nanosecond.
          def days
            Native.numerical_duration_float(:days, _ = self)
          end

          # A SignedDuration of this many weeks, truncated to the
          # nanosecond.
          def weeks
            Native.numerical_duration_float(:weeks, _ = self)
          end
        end
      end

      # Creates std +Duration+s from numbers, each a Rational number of
      # seconds, exact to the nanosecond, as a std +Duration+ is in this gem
      # (ADR 001, 2026-11-05): <tt>5.std_minutes</tt> is <tt>300r</tt>.
      #
      # Refines Integer as time's impl for +u64+ does, so a negative Integer,
      # or one past 64 bits, raises +RangeError+; +std_minutes+ to
      # +std_weeks+ raise +RangeError+ with time's message where the seconds
      # overflow. Refines Float as time's impl for +f64+ does: a negative or
      # NaN count raises +ArgumentError+ with the text of time's assertion,
      # and otherwise the nanoseconds are truncated and saturate.
      #
      # Mirrors time's <tt>ext::NumericalStdDuration</tt>
      # (<tt>src/ext/numerical_std_duration.rs:46-212</tt>).
      #
      # === Example
      #
      #   using Ferro::Time::Ext::NumericalStdDuration
      #
      #   5.std_seconds # => 5r
      #   5.std_milliseconds # => 1/200r
      #   1.5.std_minutes # => 90r
      module NumericalStdDuration
        refine Integer do
          # A std +Duration+ of this many nanoseconds.
          def std_nanoseconds
            Arguments.seconds(Native.numerical_std_integer(:std_nanoseconds, _ = self))
          end

          # A std +Duration+ of this many microseconds.
          def std_microseconds
            Arguments.seconds(Native.numerical_std_integer(:std_microseconds, _ = self))
          end

          # A std +Duration+ of this many milliseconds.
          def std_milliseconds
            Arguments.seconds(Native.numerical_std_integer(:std_milliseconds, _ = self))
          end

          # A std +Duration+ of this many seconds.
          def std_seconds
            Arguments.seconds(Native.numerical_std_integer(:std_seconds, _ = self))
          end

          # A std +Duration+ of this many minutes, raising +RangeError+ with
          # time's message where its seconds would overflow.
          def std_minutes
            Arguments.seconds(Native.numerical_std_integer(:std_minutes, _ = self))
          end

          # A std +Duration+ of this many hours, as #std_minutes raises.
          def std_hours
            Arguments.seconds(Native.numerical_std_integer(:std_hours, _ = self))
          end

          # A std +Duration+ of this many days, as #std_minutes raises.
          def std_days
            Arguments.seconds(Native.numerical_std_integer(:std_days, _ = self))
          end

          # A std +Duration+ of this many weeks, as #std_minutes raises.
          def std_weeks
            Arguments.seconds(Native.numerical_std_integer(:std_weeks, _ = self))
          end
        end

        refine Float do
          # A std +Duration+ of this many nanoseconds, truncated.
          def std_nanoseconds
            Arguments.seconds(Native.numerical_std_float(:std_nanoseconds, _ = self))
          end

          # A std +Duration+ of this many microseconds, truncated to the
          # nanosecond.
          def std_microseconds
            Arguments.seconds(Native.numerical_std_float(:std_microseconds, _ = self))
          end

          # A std +Duration+ of this many milliseconds, truncated to the
          # nanosecond.
          def std_milliseconds
            Arguments.seconds(Native.numerical_std_float(:std_milliseconds, _ = self))
          end

          # A std +Duration+ of this many seconds, truncated to the
          # nanosecond.
          def std_seconds
            Arguments.seconds(Native.numerical_std_float(:std_seconds, _ = self))
          end

          # A std +Duration+ of this many minutes, truncated to the
          # nanosecond.
          def std_minutes
            Arguments.seconds(Native.numerical_std_float(:std_minutes, _ = self))
          end

          # A std +Duration+ of this many hours, truncated to the nanosecond.
          def std_hours
            Arguments.seconds(Native.numerical_std_float(:std_hours, _ = self))
          end

          # A std +Duration+ of this many days, truncated to the nanosecond.
          def std_days
            Arguments.seconds(Native.numerical_std_float(:std_days, _ = self))
          end

          # A std +Duration+ of this many weeks, truncated to the nanosecond.
          def std_weeks
            Arguments.seconds(Native.numerical_std_float(:std_weeks, _ = self))
          end
        end
      end

      # SignedDuration arithmetic on Ruby's ::Time, which stands for Rust's
      # +SystemTime+ in this gem. The ::Time crosses as its whole seconds
      # and nanoseconds since the epoch, and a ::Time it returns is in UTC,
      # since a +SystemTime+ has no offset, as OffsetDateTime#to_time is.
      #
      # Mirrors time's <tt>ext::SystemTimeExt</tt>
      # (<tt>src/ext/systemtime.rs:12-75</tt>).
      #
      # === Example
      #
      #   using Ferro::Time::Ext::SystemTimeExt
      #
      #   epoch = ::Time.at(0)
      #   other = epoch.checked_add_signed(Ferro::Time::Duration::SECOND)
      #   other.signed_duration_since(epoch) == Ferro::Time::Duration::SECOND # => true
      #   epoch.signed_duration_since(other) == -Ferro::Time::Duration::SECOND # => true
      module SystemTimeExt
        refine ::Time do
          # This instant plus +duration+, or +nil+ where the result leaves
          # +SystemTime+'s range.
          def checked_add_signed(duration)
            seconds, nanoseconds = Arguments.system_time(_ = self)
            parts = Native.system_time_checked_signed(seconds, nanoseconds, :checked_add_signed, Arguments.duration(duration))
            Arguments.ruby_time(parts) unless parts.nil?
          end

          # This instant minus +duration+, or +nil+ where the result leaves
          # +SystemTime+'s range.
          def checked_sub_signed(duration)
            seconds, nanoseconds = Arguments.system_time(_ = self)
            parts = Native.system_time_checked_signed(seconds, nanoseconds, :checked_sub_signed, Arguments.duration(duration))
            Arguments.ruby_time(parts) unless parts.nil?
          end

          # The SignedDuration from +earlier+ to this instant, negative if
          # +earlier+ is later, saturating at SignedDuration::MIN and MAX.
          def signed_duration_since(earlier)
            seconds, nanoseconds = Arguments.system_time(_ = self)
            earlier_seconds, earlier_nanoseconds = Arguments.system_time(earlier)
            Native.system_time_signed_duration_since(seconds, nanoseconds, earlier_seconds, earlier_nanoseconds)
          end
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
