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
    # SPDX-SnippetComment: UtcOffset, its methods, and their docs from time 0.3.55 src/utc_offset.rs
    #++

    # An offset from UTC, to the second, from -25:59:59 to +25:59:59.
    #
    # Ruby's ::Time keeps its offset as a count of seconds or a zone name,
    # and nothing checks either against the range a time library on the
    # other side will accept. An offset that is its own value can be checked
    # once, compared, negated, and formatted as ISO 8601 writes it.
    #
    # A UtcOffset is time's +UtcOffset+: hours, minutes, and seconds that
    # share one sign. Build one with UtcOffset.from_hms or
    # UtcOffset.from_whole_seconds, or ask the system for its local offset
    # with UtcOffset.current_local_offset and UtcOffset.local_offset_at.
    #
    # A UtcOffset is frozen and shareable between Ractors.
    #
    # Mirrors time's +UtcOffset+ (<tt>src/utc_offset.rs</tt>).
    #
    # === Examples
    #
    #   offset = Ferro::Time::UtcOffset.from_hms(5, 30, 0)
    #   offset.whole_minutes # => 330
    #   (-offset).to_s # => "-05:30:00"
    #
    #   Ferro::Time::UtcOffset.from_hms(26, 0, 0)
    #   # raises Ferro::Time::Error::ComponentRange: offset hour was not in range
    class UtcOffset
      include Comparable

      class << self
        # Creates a UtcOffset from the hours, minutes, and seconds. The sign
        # of the first non-zero component wins: a minute or second with the
        # other sign takes the hour's, as time's does. Raises
        # Error::ComponentRange when a component is out of range. Mirrors
        # time's <tt>UtcOffset::from_hms</tt>
        # (<tt>src/utc_offset.rs:183-206</tt>).
        #
        # [hours] Integer, from -25 to 25.
        # [minutes] Integer, from -59 to 59.
        # [seconds] Integer, from -59 to 59.
        #
        # === Example
        #
        #   Ferro::Time::UtcOffset.from_hms(1, 2, 3).as_hms # => [1, 2, 3]
        #   Ferro::Time::UtcOffset.from_hms(1, -2, -3).as_hms # => [1, 2, 3]
        def from_hms(hours, minutes, seconds)
          Native.utc_offset_from_hms(hours, minutes, seconds)
        end

        # Creates a UtcOffset from a number of seconds, raising
        # Error::ComponentRange outside -93,599 to 93,599. Mirrors time's
        # <tt>UtcOffset::from_whole_seconds</tt>
        # (<tt>src/utc_offset.rs:268-280</tt>).
        #
        # [seconds] Integer.
        #
        # === Example
        #
        #   Ferro::Time::UtcOffset.from_whole_seconds(3_723).as_hms # => [1, 2, 3]
        def from_whole_seconds(seconds)
          Native.utc_offset_from_whole_seconds(seconds)
        end

        # The system's offset from UTC at the instant +datetime+ names,
        # raising Error::IndeterminateOffset when it cannot be determined. The
        # system's time-zone rules decide it, so it differs from season to
        # season where daylight saving applies (plan 007, decision 13).
        # Mirrors time's <tt>UtcOffset::local_offset_at</tt>
        # (<tt>src/utc_offset.rs:435-449</tt>).
        #
        # [datetime] OffsetDateTime.
        #
        # === Example
        #
        #   Ferro::Time::UtcOffset.local_offset_at(Ferro::Time::OffsetDateTime::UNIX_EPOCH).whole_seconds
        #   # => ::Time.at(0).utc_offset
        def local_offset_at(datetime)
          Native.utc_offset_local_offset_at(datetime)
        end

        # The system's offset from UTC now, raising Error::IndeterminateOffset
        # when it cannot be determined (plan 007, decision 13). Mirrors time's
        # <tt>UtcOffset::current_local_offset</tt>
        # (<tt>src/utc_offset.rs:451-466</tt>).
        #
        # === Example
        #
        #   Ferro::Time::UtcOffset.current_local_offset.whole_seconds # => ::Time.now.utc_offset
        def current_local_offset
          Native.utc_offset_current_local_offset
        end

        # Parses a UtcOffset from +input+ with +description+, which takes the
        # same kinds of description as #format. Raises an Error::Parse variant
        # when the input does not match. Mirrors time's
        # <tt>UtcOffset::parse</tt> (<tt>src/utc_offset.rs:499-515</tt>).
        #
        # [input] String, UTF-8 text.
        # [description] A format description.
        #
        # === Example
        #
        #   Ferro::Time::UtcOffset.parse("+05:30", Ferro::Time::FormatDescription.parse_owned(3, "[offset_hour]:[offset_minute]")).to_s # => "+05:30:00"
        def parse(input, description)
          Native.utc_offset_parse(input, Arguments.description(description))
        end
      end

      # A UtcOffset that is UTC. Mirrors time's <tt>UtcOffset::UTC</tt>
      # (<tt>src/utc_offset.rs:148-155</tt>).
      UTC = Native.utc_offset_constant(:UTC)

      # The hours, minutes, and seconds, all with the offset's sign, as an
      # Array for Rust's tuple. Mirrors time's <tt>UtcOffset::as_hms</tt>
      # (<tt>src/utc_offset.rs:305-316</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.as_hms # => [-1, -2, -3]
      def as_hms
        Native.utc_offset_as_hms(self)
      end

      # The whole hours of the offset, with its sign. Mirrors time's
      # <tt>UtcOffset::whole_hours</tt> (<tt>src/utc_offset.rs:326-337</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.whole_hours # => -1
      def whole_hours
        Native.utc_offset_int(self, :whole_hours)
      end

      # The whole minutes of the offset, with its sign. Mirrors time's
      # <tt>UtcOffset::whole_minutes</tt>
      # (<tt>src/utc_offset.rs:339-350</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.whole_minutes # => -62
      def whole_minutes
        Native.utc_offset_int(self, :whole_minutes)
      end

      # The minutes past the whole hours, with the offset's sign. Mirrors
      # time's <tt>UtcOffset::minutes_past_hour</tt>
      # (<tt>src/utc_offset.rs:352-363</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.minutes_past_hour # => -2
      def minutes_past_hour
        Native.utc_offset_int(self, :minutes_past_hour)
      end

      # The offset in seconds, with its sign. Mirrors time's
      # <tt>UtcOffset::whole_seconds</tt>
      # (<tt>src/utc_offset.rs:375-380</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.whole_seconds # => -3_723
      def whole_seconds
        Native.utc_offset_int(self, :whole_seconds)
      end

      # The seconds past the whole minutes, with the offset's sign. Mirrors
      # time's <tt>UtcOffset::seconds_past_minute</tt>
      # (<tt>src/utc_offset.rs:382-393</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.seconds_past_minute # => -3
      def seconds_past_minute
        Native.utc_offset_int(self, :seconds_past_minute)
      end

      # Whether the offset is UTC: zero. Mirrors time's
      # <tt>UtcOffset::is_utc</tt> (<tt>src/utc_offset.rs:395-407</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.is_utc # => false
      def is_utc
        Native.utc_offset_bool(self, :is_utc)
      end

      # Whether the offset is east of UTC. Mirrors time's
      # <tt>UtcOffset::is_positive</tt> (<tt>src/utc_offset.rs:409-420</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.is_positive # => false
      def is_positive
        Native.utc_offset_bool(self, :is_positive)
      end

      # Whether the offset is west of UTC. Mirrors time's
      # <tt>UtcOffset::is_negative</tt> (<tt>src/utc_offset.rs:422-433</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.is_negative # => true
      def is_negative
        Native.utc_offset_bool(self, :is_negative)
      end

      # The offset with its sign flipped, as time's +Neg+ does. Mirrors time's
      # <tt>Neg for UtcOffset</tt> (<tt>src/utc_offset.rs:618-625</tt>).
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   (-offset).to_s # => "+01:02:03"
      def -@
        Native.utc_offset_neg(self)
      end

      # Formats the value with +description+: a
      # FormatDescription::FormatDescriptionV3,
      # FormatDescription::WellKnown::Rfc2822 or
      # FormatDescription::WellKnown::Rfc3339 (the classes themselves), or a
      # FormatDescription::WellKnown::Iso8601. Raises an Error::Format variant
      # when a component cannot be formatted, and +TypeError+ when a
      # well-known format needs a component this type lacks, which Rust's
      # compiler refuses. Mirrors time's <tt>UtcOffset::format</tt>
      # (<tt>src/utc_offset.rs:481-494</tt>).
      #
      # [description] A format description.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.format(Ferro::Time::FormatDescription.parse_owned(3, "[offset_hour]:[offset_minute]")) # => "-01:02"
      def format(description)
        Native.utc_offset_format(self, Arguments.description(description))
      end

      # Formats the value with +description+ onto the end of +output+ and
      # returns the count time's +format_into+ returns, which is the number of
      # bytes written except where time leaves some out, as it does for the
      # digits of a fraction of a second in RFC 3339 and for an ISO 8601 hour
      # or minute with a decimal fraction. Rust writes to any
      # <tt>io::Write</tt>; here +output+ is a String, which keeps what time
      # wrote even when formatting fails partway, as Rust's writer does. A
      # frozen +output+ raises +FrozenError+ before anything is formatted.
      # Mirrors time's <tt>UtcOffset::format_into</tt>
      # (<tt>src/utc_offset.rs:471-479</tt>).
      #
      # [output] String, appended to.
      # [description] A format description.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   output = +"on "
      #   offset.format_into(output, Ferro::Time::FormatDescription.parse_owned(3, "[offset_hour]:[offset_minute]")) # => 6
      #   output # => "on -01:02"
      def format_into(output, description)
        Arguments.sink(output)
        written, count, failure = Native.utc_offset_format_into(self, Arguments.description(description))
        output << written
        raise(failure || Error) unless count

        count
      end

      # Whether +other+ is the same UtcOffset, by time's +PartialEq+. +false+
      # for anything else.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset == Ferro::Time::UtcOffset::UTC # => false
      #   offset == offset # => true
      def ==(other)
        other.is_a?(UtcOffset) && Native.utc_offset_eq(self, other)
      end

      # Whether +other+ is an equal UtcOffset, as time's +Eq+ says, so that
      # equal values are the same Hash key.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.eql?(offset) # => true
      def eql?(other)
        other.is_a?(UtcOffset) && Native.utc_offset_eq(self, other)
      end

      # A hash of the value, through time's +Hash+, so equal values hash
      # alike.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.hash == offset.hash # => true
      def hash
        Native.utc_offset_hash(self)
      end

      # Compares with another UtcOffset by time's +Ord+, so the Comparable
      # operators answer as Rust's do; +nil+ for anything else.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset <=> Ferro::Time::UtcOffset::UTC # => -1
      def <=>(other)
        Native.utc_offset_cmp(self, other) if other.is_a?(UtcOffset)
      end

      # The value as time's +Display+ writes it.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.to_s # => "-01:02:03"
      def to_s
        Native.utc_offset_display(self)
      end

      # The value as time's +Debug+ writes it.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.inspect # => "-01:02:03"
      def inspect
        Native.utc_offset_debug(self)
      end

      # The value itself. A UtcOffset is +Copy+ in Rust and frozen here, so a
      # copy would be the same value; Ruby answers the same way for an
      # Integer.
      #
      # === Example
      #
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.dup.equal?(offset) # => true
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
      #   offset = Ferro::Time::UtcOffset.from_hms(-1, -2, -3)
      #   offset.clone.equal?(offset) # => true
      def clone(freeze: true)
        raise ArgumentError, "can't unfreeze Ferro::Time::UtcOffset" if freeze == false

        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
