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
    # SPDX-SnippetComment: SignedDuration, its methods, and their docs from time 0.3.55 src/signed_duration.rs
    #++

    # A span of time with nanosecond precision, positive or negative.
    #
    # Ruby code measures spans in Float seconds, which lose nanoseconds past a
    # few months and cannot tell a week from 604,800 unrelated seconds.
    # Arithmetic on dates and times wants a span that is exact, signed, and
    # bounded the way the dates it moves are.
    #
    # A SignedDuration is time's +SignedDuration+ (until 0.3.54 its
    # +Duration+, a name time keeps as an alias, and so does this gem):
    # seconds and nanoseconds with one sign, from about -292 billion to
    # +292 billion years. Build one with SignedDuration.new or a unit such as
    # SignedDuration.days, read it back in any unit, and add, subtract,
    # multiply, or divide it. Operations that overflow raise +RangeError+
    # with time's message where Rust panics, and the +checked_+ and
    # +saturating_+ methods answer without raising.
    #
    # A SignedDuration is frozen and shareable between Ractors.
    #
    # Where time takes Rust's unsigned <tt>std::time::Duration</tt>, this
    # takes any Numeric number of seconds, and where time returns one, this
    # returns a Rational number of seconds, exact to the nanosecond, as
    # Ruby's own <tt>Time#subsec</tt> is (ADR 001, 2026-11-05). So
    # <tt>duration + 1.5</tt> adds a second and a half, as time's
    # <tt>Add<std::time::Duration></tt> does, while <tt>duration * 2</tt>
    # still multiplies by a count, as <tt>Mul<i32></tt> does: Rust picks
    # the impl by type, and here the operator picks it: <tt>*</tt> and
    # <tt>/</tt> take counts, and <tt>+</tt>, <tt>-</tt>, and the
    # comparisons take spans. A Float
    # crosses as core's <tt>Duration::try_from_secs_f64</tt> reads it,
    # rounding to the nearest nanosecond, and raises +ArgumentError+ with
    # core's words for a negative, NaN, or infinite one; any other Numeric
    # is exact, rounded to the nearest nanosecond, and raises +RangeError+
    # where that rounding leaves it negative or past 2**64 seconds, so
    # <tt>Rational(-1, 10**10)</tt>, a tenth of a nanosecond below zero,
    # is zero. <tt>Div<std::time::Duration></tt>
    # has no operator here, since <tt>/</tt> by a number divides by a
    # count; its answer is <tt>duration / SignedDuration.try_from(seconds)</tt>.
    #
    # Mirrors time's +SignedDuration+ (<tt>src/signed_duration.rs</tt>).
    #
    # === Examples
    #
    #   duration = Ferro::Time::Duration.hours(36) + Ferro::Time::Duration.minutes(5)
    #   duration.whole_days # => 1
    #   duration.to_s # => "1d12h5m"
    #   (duration * 2).whole_hours # => 72
    #
    #   Ferro::Time::Duration::MAX + Ferro::Time::Duration::NANOSECOND
    #   # raises RangeError: overflow when adding durations
    class SignedDuration
      include Comparable

      class << self
        # The zero duration, time's +Default+. Mirrors time's <tt>Default for
        # SignedDuration</tt> (<tt>src/signed_duration.rs:103-108</tt>).
        #
        # === Example
        #
        #   Ferro::Time::Duration.default.is_zero # => true
        def default
          ZERO
        end

        # Creates a SignedDuration from seconds and nanoseconds. Nanoseconds
        # of a billion or more carry into the seconds, and the two take one
        # sign. Where Rust panics because the seconds overflow, this raises
        # +RangeError+ with time's message. Mirrors time's
        # <tt>SignedDuration::new</tt>
        # (<tt>src/signed_duration.rs:428-461</tt>).
        #
        # [seconds] Integer.
        # [nanoseconds] Integer, within a 32-bit signed integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.new(1, 0) == Ferro::Time::Duration.seconds(1) # => true
        #   Ferro::Time::Duration.new(1, 2_000_000_000) == Ferro::Time::Duration.seconds(3) # => true
        def new(seconds, nanoseconds)
          Native.duration_new(seconds, nanoseconds)
        end

        # Creates a SignedDuration of +weeks+ weeks. Where Rust panics because
        # the seconds overflow, this raises +RangeError+ with time's message,
        # "overflow constructing <tt>time::SignedDuration</tt>". Mirrors
        # time's <tt>SignedDuration::weeks</tt>
        # (<tt>src/signed_duration.rs:487-506</tt>).
        #
        # [weeks] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.weeks(2).whole_weeks # => 2
        def weeks(weeks)
          Native.duration_unit(:weeks, weeks)
        end

        # Creates a SignedDuration of +days+ days. Where Rust panics because
        # the seconds overflow, this raises +RangeError+ with time's message,
        # "overflow constructing <tt>time::SignedDuration</tt>". Mirrors
        # time's <tt>SignedDuration::days</tt>
        # (<tt>src/signed_duration.rs:508-526</tt>).
        #
        # [days] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.days(2).whole_days # => 2
        def days(days)
          Native.duration_unit(:days, days)
        end

        # Creates a SignedDuration of +hours+ hours. Where Rust panics because
        # the seconds overflow, this raises +RangeError+ with time's message,
        # "overflow constructing <tt>time::SignedDuration</tt>". Mirrors
        # time's <tt>SignedDuration::hours</tt>
        # (<tt>src/signed_duration.rs:528-547</tt>).
        #
        # [hours] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.hours(2).whole_hours # => 2
        def hours(hours)
          Native.duration_unit(:hours, hours)
        end

        # Creates a SignedDuration of +minutes+ minutes. Where Rust panics
        # because the seconds overflow, this raises +RangeError+ with time's
        # message, "overflow constructing <tt>time::SignedDuration</tt>".
        # Mirrors time's <tt>SignedDuration::minutes</tt>
        # (<tt>src/signed_duration.rs:549-568</tt>).
        #
        # [minutes] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.minutes(2).whole_minutes # => 2
        def minutes(minutes)
          Native.duration_unit(:minutes, minutes)
        end

        # Creates a SignedDuration of +seconds+ seconds. Mirrors time's
        # <tt>SignedDuration::seconds</tt>
        # (<tt>src/signed_duration.rs:570-579</tt>).
        #
        # [seconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.seconds(2).whole_seconds # => 2
        def seconds(seconds)
          Native.duration_unit(:seconds, seconds)
        end

        # Creates a SignedDuration of +milliseconds+ milliseconds. Mirrors
        # time's <tt>SignedDuration::milliseconds</tt>
        # (<tt>src/signed_duration.rs:787-804</tt>).
        #
        # [milliseconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.milliseconds(2).whole_milliseconds # => 2
        def milliseconds(milliseconds)
          Native.duration_unit(:milliseconds, milliseconds)
        end

        # Creates a SignedDuration of +microseconds+ microseconds. Mirrors
        # time's <tt>SignedDuration::microseconds</tt>
        # (<tt>src/signed_duration.rs:806-823</tt>).
        #
        # [microseconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.microseconds(2).whole_microseconds # => 2
        def microseconds(microseconds)
          Native.duration_unit(:microseconds, microseconds)
        end

        # Creates a SignedDuration of +nanoseconds+ nanoseconds. Mirrors
        # time's <tt>SignedDuration::nanoseconds</tt>
        # (<tt>src/signed_duration.rs:825-841</tt>).
        #
        # [nanoseconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.nanoseconds(2).whole_nanoseconds # => 2
        def nanoseconds(nanoseconds)
          Native.duration_unit(:nanoseconds, nanoseconds)
        end

        # Creates a SignedDuration from a number of nanoseconds wider than 64
        # bits. Where Rust panics because the seconds do not fit, this raises
        # +RangeError+ with time's message. Mirrors time's
        # <tt>SignedDuration::nanoseconds_i128</tt>
        # (<tt>src/signed_duration.rs:843-869</tt>).
        #
        # [nanoseconds] Integer, within a 128-bit signed integer.
        #
        # === Example
        #
        #   Ferro::Time::Duration.nanoseconds_i128(10**20).whole_seconds # => 100_000_000_000
        def nanoseconds_i128(nanoseconds)
          Native.duration_nanoseconds_i128(nanoseconds)
        end

        # Creates a SignedDuration from a number of seconds. Where Rust
        # panics, for NaN or a value past the range, this raises +RangeError+
        # with time's message. Mirrors time's
        # <tt>SignedDuration::seconds_f64</tt>
        # (<tt>src/signed_duration.rs:617-641</tt>).
        #
        # [seconds] Float, in 64-bit precision.
        #
        # === Example
        #
        #   Ferro::Time::Duration.seconds_f64(0.5).whole_milliseconds # => 500
        def seconds_f64(seconds)
          Native.duration_float(:seconds_f64, seconds)
        end

        # Creates a SignedDuration from a number of seconds. Where Rust
        # panics, for NaN or a value past the range, this raises +RangeError+
        # with time's message. Mirrors time's
        # <tt>SignedDuration::seconds_f32</tt>
        # (<tt>src/signed_duration.rs:643-667</tt>).
        #
        # [seconds] Float, rounded to 32-bit precision as Rust's <tt>as
        #   f32</tt> does.
        #
        # === Example
        #
        #   Ferro::Time::Duration.seconds_f32(0.5).whole_milliseconds # => 500
        def seconds_f32(seconds)
          Native.duration_float32(:seconds_f32, seconds)
        end

        # Creates a SignedDuration from a number of seconds, saturating at MIN
        # or MAX past the range and answering ZERO for NaN. Mirrors time's
        # <tt>SignedDuration::saturating_seconds_f64</tt>
        # (<tt>src/signed_duration.rs:669-701</tt>).
        #
        # [seconds] Float, in 64-bit precision.
        #
        # === Example
        #
        #   Ferro::Time::Duration.saturating_seconds_f64(0.5).whole_milliseconds # => 500
        def saturating_seconds_f64(seconds)
          Native.duration_float(:saturating_seconds_f64, seconds)
        end

        # Creates a SignedDuration from a number of seconds, saturating at MIN
        # or MAX past the range and answering ZERO for NaN. Mirrors time's
        # <tt>SignedDuration::saturating_seconds_f32</tt>
        # (<tt>src/signed_duration.rs:703-735</tt>).
        #
        # [seconds] Float, rounded to 32-bit precision.
        #
        # === Example
        #
        #   Ferro::Time::Duration.saturating_seconds_f32(0.5).whole_milliseconds # => 500
        def saturating_seconds_f32(seconds)
          Native.duration_float32(:saturating_seconds_f32, seconds)
        end

        # Creates a SignedDuration from a number of seconds, or +nil+ for NaN
        # or a value past the range. Mirrors time's
        # <tt>SignedDuration::checked_seconds_f64</tt>
        # (<tt>src/signed_duration.rs:737-760</tt>).
        #
        # [seconds] Float.
        #
        # === Example
        #
        #   Ferro::Time::Duration.checked_seconds_f64(0.5).whole_milliseconds # => 500
        #   Ferro::Time::Duration.checked_seconds_f64(Float::NAN) # => nil
        def checked_seconds_f64(seconds)
          Native.duration_checked_float(seconds)
        end

        # Creates a SignedDuration from a number of seconds, or +nil+ for NaN
        # or a value past the range. Mirrors time's
        # <tt>SignedDuration::checked_seconds_f32</tt>
        # (<tt>src/signed_duration.rs:762-785</tt>).
        #
        # [seconds] Float.
        #
        # === Example
        #
        #   Ferro::Time::Duration.checked_seconds_f32(0.5).whole_milliseconds # => 500
        #   Ferro::Time::Duration.checked_seconds_f32(Float::NAN) # => nil
        def checked_seconds_f32(seconds)
          Native.duration_checked_float32(seconds)
        end

        # Converts a std +Duration+, given as a Numeric number of seconds,
        # raising Error::ConversionRange when its whole seconds do not fit
        # a 64-bit signed integer. Mirrors time's
        # <tt>TryFrom<std::time::Duration> for SignedDuration</tt>
        # (<tt>src/signed_duration.rs:1423-1436</tt>).
        #
        # [seconds] Numeric, as the class RDoc says a std +Duration+ is
        #           read.
        #
        # === Example
        #
        #   Ferro::Time::Duration.try_from(1.5) == Ferro::Time::Duration.milliseconds(1_500) # => true
        #   Ferro::Time::Duration.try_from(2**63)
        #   # raises Ferro::Time::Error::ConversionRange: Source value is out of range for the target type
        def try_from(seconds)
          Native.duration_try_from_std(Arguments.std_duration(seconds))
        end
      end

      # Equivalent to <tt>SignedDuration.seconds(0)</tt>. Mirrors time's
      # <tt>SignedDuration::ZERO</tt>
      # (<tt>src/signed_duration.rs:241-247</tt>).
      ZERO = Native.duration_constant(:ZERO)

      # Equivalent to <tt>SignedDuration.nanoseconds(1)</tt>. Mirrors time's
      # <tt>SignedDuration::NANOSECOND</tt>
      # (<tt>src/signed_duration.rs:249-255</tt>).
      NANOSECOND = Native.duration_constant(:NANOSECOND)

      # Equivalent to <tt>SignedDuration.microseconds(1)</tt>. Mirrors time's
      # <tt>SignedDuration::MICROSECOND</tt>
      # (<tt>src/signed_duration.rs:257-263</tt>).
      MICROSECOND = Native.duration_constant(:MICROSECOND)

      # Equivalent to <tt>SignedDuration.milliseconds(1)</tt>. Mirrors time's
      # <tt>SignedDuration::MILLISECOND</tt>
      # (<tt>src/signed_duration.rs:265-271</tt>).
      MILLISECOND = Native.duration_constant(:MILLISECOND)

      # Equivalent to <tt>SignedDuration.seconds(1)</tt>. Mirrors time's
      # <tt>SignedDuration::SECOND</tt>
      # (<tt>src/signed_duration.rs:273-279</tt>).
      SECOND = Native.duration_constant(:SECOND)

      # Equivalent to <tt>SignedDuration.minutes(1)</tt>. Mirrors time's
      # <tt>SignedDuration::MINUTE</tt>
      # (<tt>src/signed_duration.rs:281-287</tt>).
      MINUTE = Native.duration_constant(:MINUTE)

      # Equivalent to <tt>SignedDuration.hours(1)</tt>. Mirrors time's
      # <tt>SignedDuration::HOUR</tt>
      # (<tt>src/signed_duration.rs:289-295</tt>).
      HOUR = Native.duration_constant(:HOUR)

      # Equivalent to <tt>SignedDuration.days(1)</tt>. Mirrors time's
      # <tt>SignedDuration::DAY</tt>
      # (<tt>src/signed_duration.rs:297-303</tt>).
      DAY = Native.duration_constant(:DAY)

      # Equivalent to <tt>SignedDuration.weeks(1)</tt>. Mirrors time's
      # <tt>SignedDuration::WEEK</tt>
      # (<tt>src/signed_duration.rs:305-311</tt>).
      WEEK = Native.duration_constant(:WEEK)

      # The minimum possible duration. Adding any negative duration to this
      # will cause an overflow. Mirrors time's <tt>SignedDuration::MIN</tt>
      # (<tt>src/signed_duration.rs:313-314</tt>).
      MIN = Native.duration_constant(:MIN)

      # The maximum possible duration. Adding any positive duration to this
      # will cause an overflow. Mirrors time's <tt>SignedDuration::MAX</tt>
      # (<tt>src/signed_duration.rs:316-317</tt>).
      MAX = Native.duration_constant(:MAX)

      # Whether the duration is zero. Mirrors time's
      # <tt>SignedDuration::is_zero</tt>
      # (<tt>src/signed_duration.rs:319-329</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration::ZERO.is_zero # => true
      def is_zero
        Native.duration_bool(self, :is_zero)
      end

      # Whether the duration is less than zero. Mirrors time's
      # <tt>SignedDuration::is_negative</tt>
      # (<tt>src/signed_duration.rs:331-342</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.seconds(-1).is_negative # => true
      def is_negative
        Native.duration_bool(self, :is_negative)
      end

      # Whether the duration is greater than zero. Mirrors time's
      # <tt>SignedDuration::is_positive</tt>
      # (<tt>src/signed_duration.rs:344-355</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.seconds(1).is_positive # => true
      def is_positive
        Native.duration_bool(self, :is_positive)
      end

      # The absolute value of the duration. MIN, whose absolute value does not
      # fit, saturates to MAX, as time's does. Mirrors time's
      # <tt>SignedDuration::abs</tt>
      # (<tt>src/signed_duration.rs:357-373</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.seconds(-1).abs == Ferro::Time::Duration::SECOND # => true
      def abs
        Native.duration_abs(self)
      end

      # The absolute value as a std +Duration+, a Rational number of
      # seconds. Unlike #abs it never saturates, since a std +Duration+
      # holds the absolute value of MIN. Mirrors time's
      # <tt>SignedDuration::unsigned_abs</tt>
      # (<tt>src/signed_duration.rs:375-391</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.seconds(-1).unsigned_abs # => 1r
      #   Ferro::Time::Duration.seconds(-(2**63)).unsigned_abs # => 9_223_372_036_854_775_808r
      def unsigned_abs
        Arguments.seconds(Native.duration_unsigned_abs(self))
      end

      # This duration as a std +Duration+, a Rational number of seconds,
      # exact to the nanosecond. A std +Duration+ is unsigned, so a
      # negative duration raises Error::ConversionRange, the error time's
      # +TryFrom+ returns. Ruby's core calls +to_r+ on any object it is
      # handed as a number before checking that the object is one
      # (<tt>num_exact_check</tt>, <tt>time.c:561</tt>), so a negative
      # duration given to core raises this gem's class:
      # <tt>::Time.at(0) + -Duration::MINUTE</tt> raises
      # Error::ConversionRange, where <tt>::Time.at(0) + Duration::MINUTE</tt>
      # raises core's +TypeError+. Rust names this
      # conversion after its target, <tt>std::time::Duration::try_from</tt>;
      # in Ruby the target is a Rational, and +to_r+ is Ruby's conversion to
      # one, as OffsetDateTime#to_time is time's <tt>From</tt> into a
      # +SystemTime+. Mirrors time's
      # <tt>TryFrom<SignedDuration> for std::time::Duration</tt>
      # (<tt>src/signed_duration.rs:1438-1455</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.milliseconds(1_500).to_r # => 3/2r
      #   (-Ferro::Time::Duration::SECOND).to_r
      #   # raises Ferro::Time::Error::ConversionRange: Source value is out of range for the target type
      def to_r
        Arguments.seconds(Native.duration_to_std(self))
      end

      # The whole weeks. Mirrors time's <tt>SignedDuration::whole_weeks</tt>
      # (<tt>src/signed_duration.rs:871-883</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_weeks # => 0
      def whole_weeks
        Native.duration_int(self, :whole_weeks)
      end

      # The whole days. Mirrors time's <tt>SignedDuration::whole_days</tt>
      # (<tt>src/signed_duration.rs:885-897</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_days # => 1
      def whole_days
        Native.duration_int(self, :whole_days)
      end

      # The whole hours. Mirrors time's <tt>SignedDuration::whole_hours</tt>
      # (<tt>src/signed_duration.rs:899-911</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_hours # => 26
      def whole_hours
        Native.duration_int(self, :whole_hours)
      end

      # The whole minutes. Mirrors time's
      # <tt>SignedDuration::whole_minutes</tt>
      # (<tt>src/signed_duration.rs:913-925</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_minutes # => 1_563
      def whole_minutes
        Native.duration_int(self, :whole_minutes)
      end

      # The whole seconds. Mirrors time's
      # <tt>SignedDuration::whole_seconds</tt>
      # (<tt>src/signed_duration.rs:927-939</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_seconds # => 93_784
      def whole_seconds
        Native.duration_int(self, :whole_seconds)
      end

      # The whole milliseconds. Mirrors time's
      # <tt>SignedDuration::whole_milliseconds</tt>
      # (<tt>src/signed_duration.rs:965-978</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_milliseconds # => 93_784_000
      def whole_milliseconds
        Native.duration_int(self, :whole_milliseconds)
      end

      # The milliseconds past the whole seconds, with the duration's sign.
      # Mirrors time's <tt>SignedDuration::subsec_milliseconds</tt>
      # (<tt>src/signed_duration.rs:980-992</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.subsec_milliseconds # => 0
      def subsec_milliseconds
        Native.duration_int(self, :subsec_milliseconds)
      end

      # The whole microseconds. Mirrors time's
      # <tt>SignedDuration::whole_microseconds</tt>
      # (<tt>src/signed_duration.rs:994-1007</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_microseconds # => 93_784_000_000
      def whole_microseconds
        Native.duration_int(self, :whole_microseconds)
      end

      # The microseconds past the whole seconds, with the duration's sign.
      # Mirrors time's <tt>SignedDuration::subsec_microseconds</tt>
      # (<tt>src/signed_duration.rs:1009-1021</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.subsec_microseconds # => 0
      def subsec_microseconds
        Native.duration_int(self, :subsec_microseconds)
      end

      # The whole nanoseconds. Mirrors time's
      # <tt>SignedDuration::whole_nanoseconds</tt>
      # (<tt>src/signed_duration.rs:1023-1035</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.whole_nanoseconds # => 93_784_000_000_005
      def whole_nanoseconds
        Native.duration_int(self, :whole_nanoseconds)
      end

      # The nanoseconds past the whole seconds, with the duration's sign.
      # Mirrors time's <tt>SignedDuration::subsec_nanoseconds</tt>
      # (<tt>src/signed_duration.rs:1037-1049</tt>).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.subsec_nanoseconds # => 5
      def subsec_nanoseconds
        Native.duration_int(self, :subsec_nanoseconds)
      end

      # The duration in seconds, as a 64-bit float. Mirrors time's
      # <tt>SignedDuration::as_seconds_f64</tt>
      # (<tt>src/signed_duration.rs:941-951</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.milliseconds(1_500).as_seconds_f64 # => 1.5
      def as_seconds_f64
        Native.duration_as_float(self, :as_seconds_f64)
      end

      # The duration in seconds, as a 32-bit float, widened exactly to a Ruby
      # Float. Mirrors time's <tt>SignedDuration::as_seconds_f32</tt>
      # (<tt>src/signed_duration.rs:953-963</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration.milliseconds(1_500).as_seconds_f32 # => 1.5
      def as_seconds_f32
        Native.duration_as_float(self, :as_seconds_f32)
      end

      # Computes <tt>self + rhs</tt>, returning +nil+ if an overflow occurred.
      # Mirrors time's <tt>SignedDuration::checked_add</tt>
      # (<tt>src/signed_duration.rs:1058-1082</tt>).
      #
      # [rhs] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Duration::MAX.checked_add(Ferro::Time::Duration::NANOSECOND) # => nil
      def checked_add(rhs)
        Native.duration_with(self, :checked_add, Arguments.duration(rhs))
      end

      # Computes <tt>self - rhs</tt>, returning +nil+ if an overflow occurred.
      # Mirrors time's <tt>SignedDuration::checked_sub</tt>
      # (<tt>src/signed_duration.rs:1084-1111</tt>).
      #
      # [rhs] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Duration::MIN.checked_sub(Ferro::Time::Duration::NANOSECOND) # => nil
      def checked_sub(rhs)
        Native.duration_with(self, :checked_sub, Arguments.duration(rhs))
      end

      # Computes <tt>self + rhs</tt>, saturating at MIN or MAX on overflow.
      # Mirrors time's <tt>SignedDuration::saturating_add</tt>
      # (<tt>src/signed_duration.rs:1179-1225</tt>).
      #
      # [rhs] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Duration::MAX.saturating_add(Ferro::Time::Duration::SECOND) == Ferro::Time::Duration::MAX # => true
      def saturating_add(rhs)
        Native.duration_with(self, :saturating_add, Arguments.duration(rhs))
      end

      # Computes <tt>self - rhs</tt>, saturating at MIN or MAX on overflow.
      # Mirrors time's <tt>SignedDuration::saturating_sub</tt>
      # (<tt>src/signed_duration.rs:1227-1273</tt>).
      #
      # [rhs] SignedDuration.
      #
      # === Example
      #
      #   Ferro::Time::Duration::MIN.saturating_sub(Ferro::Time::Duration::SECOND) == Ferro::Time::Duration::MIN # => true
      def saturating_sub(rhs)
        Native.duration_with(self, :saturating_sub, Arguments.duration(rhs))
      end

      # Computes <tt>self * rhs</tt>, returning +nil+ if an overflow occurred.
      # Mirrors time's <tt>SignedDuration::checked_mul</tt>
      # (<tt>src/signed_duration.rs:1113-1135</tt>).
      #
      # [rhs] Integer, within a 32-bit signed integer.
      #
      # === Example
      #
      #   Ferro::Time::Duration::MAX.checked_mul(2) # => nil
      def checked_mul(rhs)
        Native.duration_by(self, :checked_mul, rhs)
      end

      # Computes <tt>self / rhs</tt>, returning +nil+ if +rhs+ is zero or an
      # overflow occurred. Mirrors time's <tt>SignedDuration::checked_div</tt>
      # (<tt>src/signed_duration.rs:1137-1157</tt>).
      #
      # [rhs] Integer, within a 32-bit signed integer.
      #
      # === Example
      #
      #   Ferro::Time::Duration::SECOND.checked_div(0) # => nil
      def checked_div(rhs)
        Native.duration_by(self, :checked_div, rhs)
      end

      # Computes <tt>self * rhs</tt>, saturating at MIN or MAX on overflow.
      # Mirrors time's <tt>SignedDuration::saturating_mul</tt>
      # (<tt>src/signed_duration.rs:1275-1310</tt>).
      #
      # [rhs] Integer, within a 32-bit signed integer.
      #
      # === Example
      #
      #   Ferro::Time::Duration::MAX.saturating_mul(2) == Ferro::Time::Duration::MAX # => true
      def saturating_mul(rhs)
        Native.duration_by(self, :saturating_mul, rhs)
      end

      # Computes <tt>-self</tt>, returning +nil+ if an overflow occurred.
      # Mirrors time's <tt>SignedDuration::checked_neg</tt>
      # (<tt>src/signed_duration.rs:1159-1177</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Duration::MIN.checked_neg # => nil
      def checked_neg
        Native.duration_checked_neg(self)
      end

      # Adds a duration, as time's +Add+ does, or a std +Duration+ given as
      # Numeric seconds, as <tt>Add<std::time::Duration></tt> does. Where
      # Rust panics this raises +RangeError+ with time's message: "overflow
      # when adding durations", or, for a std +Duration+ past 64-bit signed
      # seconds, "overflow converting <tt>std::time::Duration</tt> to
      # <tt>time::SignedDuration</tt>: ConversionRange". Mirrors time's
      # <tt>Add for SignedDuration</tt> and <tt>Add<std::time::Duration></tt>
      # (<tt>src/signed_duration.rs:1457-1483</tt>).
      #
      # [rhs] SignedDuration, or Numeric seconds.
      #
      # === Example
      #
      #   (Ferro::Time::Duration::HOUR + Ferro::Time::Duration::MINUTE).to_s # => "1h1m"
      #   (Ferro::Time::Duration::HOUR + 1.5).to_s # => "1h1s500ms"
      def +(rhs)
        return Native.duration_std(self, :+, Arguments.std_duration(rhs)) if rhs.is_a?(Numeric)

        Native.duration_op(self, :+, Arguments.duration(rhs))
      end

      # Subtracts a duration, as time's +Sub+ does, or a std +Duration+
      # given as Numeric seconds, as <tt>Sub<std::time::Duration></tt>
      # does, raising +RangeError+ with time's message, "overflow when
      # subtracting durations" or the conversion's message #+ gives, where
      # Rust panics. Mirrors time's <tt>Sub for SignedDuration</tt> and
      # <tt>Sub<std::time::Duration></tt>
      # (<tt>src/signed_duration.rs:1547-1573</tt>).
      #
      # [rhs] SignedDuration, or Numeric seconds.
      #
      # === Example
      #
      #   (Ferro::Time::Duration::HOUR - Ferro::Time::Duration::MINUTE).to_s # => "59m"
      #   (Ferro::Time::Duration::HOUR - 60).to_s # => "59m"
      def -(rhs)
        return Native.duration_std(self, :-, Arguments.std_duration(rhs)) if rhs.is_a?(Numeric)

        Native.duration_op(self, :-, Arguments.duration(rhs))
      end

      # The negated duration, as time's +Neg+ gives it, raising +RangeError+
      # with time's message, "overflow when negating duration", for MIN.
      # Mirrors time's <tt>Neg for SignedDuration</tt>
      # (<tt>src/signed_duration.rs:1534-1545</tt>).
      #
      # === Example
      #
      #   (-Ferro::Time::Duration::SECOND).to_s # => "-1s"
      def -@
        Native.duration_op(self, :-@, self)
      end

      # Multiplies by an Integer, as time's <tt>Mul<i32></tt> does, the impl
      # Rust picks for an integer literal, or by a Float, as <tt>Mul<f64></tt>
      # does. Where Rust panics, on overflow or a NaN product, this raises
      # +RangeError+ with time's message; an Integer outside 32 bits raises
      # magnus's +RangeError+. A number on the left, <tt>2 * duration</tt>,
      # reaches this method through #coerce, as time's reflexive
      # <tt>Mul<SignedDuration> for i32</tt> and +f64+ reach it (plan 007,
      # decision 8). Mirrors time's <tt>Mul<i32> for SignedDuration</tt>
      # (<tt>src/signed_duration.rs:1640-1755</tt>).
      #
      # [rhs] Integer or Float.
      #
      # === Example
      #
      #   (Ferro::Time::Duration::SECOND * 3).to_s # => "3s"
      #   (Ferro::Time::Duration::SECOND * 1.5).to_s # => "1s500ms"
      #   (2 * Ferro::Time::Duration::SECOND).to_s # => "2s"
      def *(rhs)
        case rhs
        when Integer then Native.duration_scale_int(self, :*, rhs)
        when Float then Native.duration_scale_float(self, :*, rhs)
        else raise TypeError, "#{rhs.class} can't be coerced into Ferro::Time::SignedDuration"
        end
      end

      # Lets a number on the left of a SignedDuration reach time's impls
      # with a number on the left. Ruby's numeric operators ask the
      # right-hand value to coerce the left (<tt>numeric.c</tt>,
      # +rb_num_coerce_bin+ and +rb_num_coerce_relop+, at Ruby v4.0.9), so
      # none of them changes. The pair returned holds +number+ in a private
      # wrapper that answers as Rust does:
      #
      # - <tt>2 * duration</tt>, by an Integer or a Float, is time's
      #   reflexive <tt>Mul<SignedDuration> for i32</tt> or <tt>for f64</tt>,
      #   <tt>duration * 2</tt>
      #   (<tt>src/signed_duration.rs:1657-1668, 1757-1768</tt>).
      # - <tt>2 + duration</tt> and <tt>2 - duration</tt> take the number as
      #   a std +Duration+ in seconds, as <tt>Add<SignedDuration></tt> and
      #   <tt>Sub<SignedDuration> for std::time::Duration</tt> do, returning
      #   a SignedDuration (<tt>:1485-1497</tt>, <tt>:1575-1589</tt>).
      # - <tt>2 / duration</tt> is <tt>Div<SignedDuration> for
      #   std::time::Duration</tt>, a Float (<tt>:1866-1877</tt>).
      # - <tt>2 < duration</tt> and <tt>2 <=> duration</tt> compare as
      #   <tt>PartialOrd<SignedDuration> for std::time::Duration</tt> does
      #   (<tt>:1912-1917</tt>); a number no std +Duration+ holds, such as a
      #   negative one, compares as +nil+, so <tt><</tt> raises Ruby's own
      #   +ArgumentError+.
      #
      # Any other operator raises Ruby's own +TypeError+.
      #
      # [number] Numeric.
      #
      # === Example
      #
      #   (2 * Ferro::Time::Duration::SECOND).to_s # => "2s"
      #   (1.5 * Ferro::Time::Duration::SECOND).to_s # => "1s500ms"
      #   (2 + Ferro::Time::Duration::SECOND).to_s # => "3s"
      #   1 < Ferro::Time::Duration::MINUTE # => true
      def coerce(number)
        raise TypeError, "#{number.class} can't be coerced into Ferro::Time::SignedDuration" unless number.is_a?(Numeric)

        [Scalar.new(number), self]
      end

      # Divides by an Integer, as time's <tt>Div<i32></tt> does; by a
      # Float, as <tt>Div<f64></tt> does; or by another SignedDuration,
      # returning their ratio as a Float, as <tt>Div for SignedDuration</tt>
      # does. Where Rust panics this raises +RangeError+ with the panic's
      # text: time's message for an overflowing or NaN quotient, and Rust's
      # "attempt to divide by zero" for an Integer zero. Mirrors time's
      # <tt>Div for SignedDuration</tt>
      # (<tt>src/signed_duration.rs:1681-1851</tt>).
      #
      # [rhs] Integer, Float, or SignedDuration.
      #
      # === Example
      #
      #   (Ferro::Time::Duration::MINUTE / 4).to_s # => "15s"
      #   Ferro::Time::Duration::HOUR / Ferro::Time::Duration::MINUTE # => 60.0
      #   Ferro::Time::Duration::SECOND / 0 # raises RangeError: attempt to divide by zero
      def /(rhs)
        case rhs
        when Integer then Native.duration_scale_int(self, :/, rhs)
        when Float then Native.duration_scale_float(self, :/, rhs)
        when SignedDuration then Native.duration_ratio(self, rhs)
        else raise TypeError, "#{rhs.class} can't be coerced into Ferro::Time::SignedDuration"
        end
      end

      # Whether +other+ is the same SignedDuration, by time's +PartialEq+,
      # or the same span as a std +Duration+ given as Numeric seconds, by
      # <tt>PartialEq<std::time::Duration></tt>
      # (<tt>src/signed_duration.rs:1879-1891</tt>), so a negative duration
      # equals no number. +false+ for anything else, and for a number no
      # std +Duration+ holds. Ruby's own <tt>Integer#==</tt> asks this
      # method when it is handed a SignedDuration, so <tt>60 ==
      # Duration::MINUTE</tt> answers the same, as Rust's impl the other
      # way round does.
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration == Ferro::Time::Duration::MAX # => false
      #   duration == duration # => true
      #   Ferro::Time::Duration::MINUTE == 60 # => true
      def ==(other)
        case other
        when SignedDuration then Native.duration_eq(self, other)
        when Numeric
          std = Arguments.std_duration_or_nil(other)
          !std.nil? && Native.duration_std_eq(self, std)
        else false
        end
      end

      # Whether +other+ is an equal SignedDuration, as time's +Eq+ says, so
      # that equal values are the same Hash key.
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.eql?(duration) # => true
      def eql?(other)
        other.is_a?(SignedDuration) && Native.duration_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.hash == duration.hash # => true
      def hash
        Native.duration_hash(self)
      end

      # Compares with another SignedDuration by time's +Ord+, or with a std
      # +Duration+ given as Numeric seconds by
      # <tt>PartialOrd<std::time::Duration></tt>
      # (<tt>src/signed_duration.rs:1893-1910</tt>), so the Comparable
      # operators answer as Rust's do; +nil+ for anything else, and for a
      # number no std +Duration+ holds.
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration <=> Ferro::Time::Duration::MAX # => -1
      #   Ferro::Time::Duration::MINUTE < 61 # => true
      def <=>(other)
        case other
        when SignedDuration then Native.duration_cmp(self, other)
        when Numeric
          std = Arguments.std_duration_or_nil(other)
          Native.duration_std_cmp(self, std) unless std.nil?
        end
      end

      # The value as time's +Display+ writes it. Without a +precision+ it
      # is the exact, full-precision form, Rust's <tt>{}</tt>. With one it
      # is the concise form, Rust's <tt>{:.3}</tt>: the largest unit the
      # duration has at least one of, rounded to +precision+ decimal
      # places, where a day is exactly 24 hours and a minute exactly 60
      # seconds. time warns that the form is not stable and must not be
      # relied upon.
      #
      # Rust's formatter takes the precision with its width and fill;
      # this binds the precision alone, since Ruby's padding of the whole
      # String cannot reproduce how time pads each part (plan 010,
      # decision 17).
      #
      # Mirrors time's <tt>Display for SignedDuration</tt>
      # (<tt>src/signed_duration.rs:1331-1419</tt>).
      #
      # [precision] Integer from 0 to 65,535, or +nil+. Rust's formatter
      #             keeps a precision in 16 bits and panics past it, so a
      #             precision from 65,536 up to <tt>2**63 - 1</tt>
      #             (+usize+'s maximum on a 64-bit platform) raises
      #             +RangeError+ with that message, "Formatting argument
      #             out of range". A larger one, or a negative one, is
      #             no +usize+, and raises Ruby's own +RangeError+ ("bignum
      #             too big to convert into 'unsigned long long'" from
      #             <tt>2**64</tt> up).
      #
      # === Examples
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.to_s # => "1d2h3m4s5ns"
      #   duration.to_s(3) # => "1.085d"
      #   Ferro::Time::Duration::ZERO.to_s(3) # => "0.000s"
      def to_s(precision = nil)
        return Native.duration_display(self) if precision.nil?

        Native.duration_display_precision(self, precision)
      end

      # The value as time's +Debug+ writes it, formatted by Rust.
      # +inspect+ stays Ruby's (ADR 001, 2026-11-05).
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.debug # => "SignedDuration { seconds: 93784, nanoseconds: 5 }"
      def debug
        Native.duration_debug(self)
      end

      # The value itself. A SignedDuration is +Copy+ in Rust and frozen here,
      # so a copy would be the same value; Ruby answers the same way for an
      # Integer.
      #
      # === Example
      #
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.dup.equal?(duration) # => true
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
      #   duration = Ferro::Time::Duration.new(93_784, 5)
      #   duration.clone.equal?(duration) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::SignedDuration" if freeze == false

        self
      end

      # A number on the left of a SignedDuration, as #coerce hands it to
      # Ruby's numeric operators. It answers each operator time has with a
      # number on the left, and refuses every other with Ruby's own error.
      class Scalar
        # Holds +number+, the Numeric on the left.
        def initialize(number)
          @number = number
          freeze
        end

        # +duration+ times the number, as time's <tt>Mul<SignedDuration> for
        # i32</tt> and <tt>for f64</tt> compute <tt>rhs * self</tt>. Rust has
        # no such impl for a std +Duration+, so any other Numeric raises
        # Ruby's own +TypeError+.
        def *(other)
          case (number = @number)
          when Integer, Float then other * number
          else method_missing(:*, other)
          end
        end

        # The number as a std +Duration+ plus +duration+, as time's
        # <tt>Add<SignedDuration> for std::time::Duration</tt> computes
        # <tt>rhs + self</tt>.
        def +(other)
          other + @number
        end

        # The number as a std +Duration+ minus +duration+, as time's
        # <tt>Sub<SignedDuration> for std::time::Duration</tt> does.
        def -(other)
          Native.duration_std(other, :rsub, Arguments.std_duration(@number))
        end

        # The number as a std +Duration+ divided by +duration+, a Float, as
        # time's <tt>Div<SignedDuration> for std::time::Duration</tt> does.
        def /(other)
          Native.std_duration_ratio(Arguments.std_duration(@number), other)
        end

        # The number as a std +Duration+ compared with +duration+, as time's
        # <tt>PartialOrd<SignedDuration> for std::time::Duration</tt>
        # compares; +nil+ for a number no std +Duration+ holds.
        def <=>(other)
          std = Arguments.std_duration_or_nil(@number)
          Native.std_duration_cmp(std, other) unless std.nil?
        end

        # Whether the number is less than +duration+, by #<=>; +nil+, so
        # that Ruby raises its own +ArgumentError+, where they do not
        # compare.
        def <(other)
          (self <=> other)&.negative?
        end

        # See #<.
        def <=(other)
          order = self <=> other
          order <= 0 unless order.nil?
        end

        # See #<.
        def >(other)
          (self <=> other)&.positive?
        end

        # See #<.
        def >=(other)
          order = self <=> other
          order >= 0 unless order.nil?
        end

        # Raises the +TypeError+ Ruby raises for an operand that does not
        # coerce, since Rust has no other operator with a number on the left.
        def method_missing(_name, *_args)
          raise TypeError, "Ferro::Time::SignedDuration can't be coerced into #{@number.class}"
        end

        # Answers +false+: the wrapper responds to no operator but its own.
        def respond_to_missing?(_name, _include_private)
          false
        end
      end
      private_constant :Scalar
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
