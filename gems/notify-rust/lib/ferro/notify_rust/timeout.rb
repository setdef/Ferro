# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: Timeout, its documentation, and its conversions
    #   from notify-rust 4.18.2 src/timeout.rs:1-78 and
    #   src/notification.rs:325-364
    #++

    # How long a notification stays before it expires.
    #
    # Some notifications matter for a moment, others until the user deals
    # with them. Servers pick their own default, and many ignore what you
    # ask: the lifetime is "often not respected by the server".
    #
    # A timeout is one of three things: Default, expire as the server
    # decides; Never, stay until the user closes it; or Milliseconds, expire
    # after that many. On macOS notify-rust ignores the timeout.
    #
    # Mirrors notify-rust's +Timeout+ (<tt>src/timeout.rs:3-26</tt>).
    #
    # === Examples
    #
    #   Ferro::NotifyRust::Notification.new.summary("Saved").timeout(Ferro::NotifyRust::Timeout::Never)
    #
    #   Ferro::NotifyRust::Timeout.from_str("42") # => #<data Ferro::NotifyRust::Timeout::Milliseconds value=42>
    #   Ferro::NotifyRust::Timeout.from(0)       # => Ferro::NotifyRust::Timeout::Never
    module Timeout
      # A timeout without data: Default or Never.
      class Unit # :nodoc:
        include Timeout

        # [name] Symbol, the notify-rust variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        private def to_native
          @name
        end
      end
      private_constant :Unit

      # Expires according to the server's default, whatever that might be.
      # The default.
      Default = Unit.new(:Default)

      # Does not expire: the user has to close it.
      Never = Unit.new(:Never)

      # Expires after +value+ milliseconds.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Timeout::Milliseconds.new(6000)
      class Milliseconds < Data.define(:value)
        include TupleVariant
        include Timeout

        ##
        # :attr_reader: value
        # The milliseconds, an Integer from 0 to <tt>2**32 - 1</tt>.

        private def to_native
          value
        end
      end

      # Default, the timeout a new Notification has. Mirrors the derived
      # +Default+ (<tt>src/timeout.rs:13-19</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::Timeout.default # => Ferro::NotifyRust::Timeout::Default
      def self.default
        Default
      end

      # The timeout +value+ means. notify-rust converts two kinds of value,
      # and the class of +value+ picks one, as the type does in Rust:
      #
      # - An Integer is milliseconds, as the notification specification
      #   reads them: a positive number expires after that many, 0 never
      #   expires, and a negative number leaves it to the server. Mirrors
      #   <tt>From<i32> for Timeout</tt> (<tt>src/timeout.rs:35-44</tt>).
      #   Raises +RangeError+ outside a 32-bit signed range.
      # - Any other Numeric is a Rust +Duration+, in seconds: zero never
      #   expires, more milliseconds than 32 bits hold leaves it to the
      #   server, and anything else expires after its whole milliseconds.
      #   Mirrors <tt>From<Duration> for Timeout</tt>
      #   (<tt>src/timeout.rs:46-56</tt>). A negative, NaN, or infinite
      #   count, or one past a +Duration+'s range, raises +ArgumentError+
      #   with Rust's reason, where Rust would panic making the +Duration+.
      #
      # So <tt>from(2)</tt> is two milliseconds and <tt>from(2.0)</tt> two
      # seconds, as <tt>Timeout::from(2)</tt> and
      # <tt>Timeout::from(Duration::from_secs(2))</tt> are in Rust, where an
      # integer literal is an +i32+.
      #
      # [value] Integer milliseconds, or Numeric seconds.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Timeout.from(-234) # => Ferro::NotifyRust::Timeout::Default
      #   Ferro::NotifyRust::Timeout.from(1.5)  # => #<data Ferro::NotifyRust::Timeout::Milliseconds value=1500>
      def self.from(value)
        return from_native(Native.timeout_from_duration(_ = Float(value))) if value.is_a?(Numeric) && !value.is_a?(Integer)

        from_native(Native.timeout_from_i32(value))
      end

      # The timeout +string+ names: <tt>"default"</tt>, <tt>"never"</tt>,
      # or a number of milliseconds. Raises +ArgumentError+ with Rust's
      # reason for anything else. Mirrors <tt>FromStr for Timeout</tt>
      # (<tt>src/timeout.rs:68-78</tt>).
      #
      # [string] String to parse.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Timeout.from_str("never") # => Ferro::NotifyRust::Timeout::Never
      def self.from_str(string)
        from_native(Native.timeout_from_str(NotifyRust.__send__(:string, string)))
      end

      # The timeout the native layer's +tag+ names: a Symbol or the
      # milliseconds.
      def self.from_native(tag) # :nodoc:
        case tag
        when :Default then Default
        when :Never then Never
        else Milliseconds.new(tag)
        end
      end
      private_class_method :from_native

      # The timeout as the notification specification sends it: -1 for
      # Default, 0 for Never, or the milliseconds. Mirrors
      # <tt>From<Timeout> for i32</tt> (<tt>src/timeout.rs:58-66</tt>),
      # which wraps milliseconds past <tt>2**31 - 1</tt> to a negative
      # number, as Rust's <tt>as i32</tt> does.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Timeout::Never.to_i # => 0
      def to_i
        Native.timeout_to_i32(__send__(:to_native))
      end

      # notify-rust's derived +Debug+ text for this timeout
      # (<tt>src/timeout.rs:13</tt>), formatted by Rust. +inspect+ stays
      # Ruby's.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Timeout::Milliseconds.new(6000).debug # => "Milliseconds(6000)"
      def debug
        Native.timeout_debug(__send__(:to_native))
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
