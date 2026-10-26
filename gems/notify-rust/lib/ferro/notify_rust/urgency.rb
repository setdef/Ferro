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
    # SPDX-SnippetComment: Urgency, its documentation, and its conversions
    #   from notify-rust 4.18.2 src/urgency.rs:3-75
    #++

    # How urgent a notification is: Low, Normal, or Critical.
    #
    # Not every notification deserves the same attention. A finished
    # download can wait; a failing battery cannot. The XDG specification
    # says it: "Developers must use their own judgement when deciding the
    # urgency of a notification. Typically, if the majority of programs are
    # using the same level for a specific type of urgency, other
    # applications should follow them. For low and normal urgencies, server
    # implementations may display the notifications how they choose. They
    # should, however, have a sane expiration timeout dependent on the
    # urgency level. Critical notifications should not automatically
    # expire, as they are things that the user will most likely want to
    # know about. They should only be closed when the user dismisses them,
    # for example, by clicking on the notification."
    #
    # Pass one to Notification#urgency (Linux and Windows) or to
    # Hint::Urgency. On macOS notify-rust deprecates this type, since
    # macOS has no urgency without notify-rust's <tt>preview-macos-un</tt>
    # feature, so referring to it warns when <tt>Warning[:deprecated]</tt>
    # is on.
    #
    # Mirrors notify-rust's +Urgency+ (<tt>src/urgency.rs:27-35</tt>).
    #
    # === Examples
    #
    #   Ferro::NotifyRust::Notification.new
    #     .summary("oh no")
    #     .icon("dialog-warning")
    #     .urgency(Ferro::NotifyRust::Urgency::Critical)
    #     .show
    #
    #   Ferro::NotifyRust::Urgency.try_from("high") # => Ferro::NotifyRust::Urgency::Critical
    class Urgency
      private_class_method :new

      # Creates the urgency named +name+. The three constants are the only
      # instances.
      #
      # [name] Symbol, the notify-rust variant's name.
      def initialize(name)
        @name = name
        freeze
      end

      # The constant that holds this urgency.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Urgency::Low.inspect # => "Ferro::NotifyRust::Urgency::Low"
      def inspect
        "Ferro::NotifyRust::Urgency::#{@name}"
      end

      # The behavior for +Low+ urgency depends on the notification server.
      Low = new(:Low)

      # The behavior for +Normal+ urgency depends on the notification
      # server.
      Normal = new(:Normal)

      # A critical notification will not time out.
      Critical = new(:Critical)

      # The urgency +string+ names, in any case: <tt>"low"</tt> or
      # <tt>"lo"</tt> for Low; <tt>"normal"</tt> or <tt>"medium"</tt> for
      # Normal; <tt>"critical"</tt>, <tt>"high"</tt>, or <tt>"hi"</tt> for
      # Critical. Raises Error::Conversion for anything else. Mirrors
      # <tt>TryFrom<&str> for Urgency</tt> (<tt>src/urgency.rs:37-53</tt>).
      #
      # [string] String, the name.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Urgency.try_from("NoRmaL") # => Ferro::NotifyRust::Urgency::Normal
      def self.try_from(string)
        from_native(Native.urgency_try_from(NotifyRust.__send__(:string, string)))
      end

      # The urgency a number means on the wire: 0 is Low, 1 is Normal, and
      # 2 or more is Critical; +nil+, no number, is Normal. Mirrors
      # <tt>From<u64></tt> and <tt>From<Option<u64>></tt> for +Urgency+
      # (<tt>src/urgency.rs:55-75</tt>).
      #
      # [value] Integer from 0 to <tt>2**64 - 1</tt>, or +nil+.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Urgency.from(900) # => Ferro::NotifyRust::Urgency::Critical
      #   Ferro::NotifyRust::Urgency.from(nil) # => Ferro::NotifyRust::Urgency::Normal
      def self.from(value)
        from_native(Native.urgency_from(value))
      end

      # The urgency the native layer's +name+ names.
      def self.from_native(name) # :nodoc:
        { Low: Low, Normal: Normal, Critical: Critical }.fetch(name)
      end
      private_class_method :from_native

      # The name the native layer takes.
      private def to_native
        @name
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
