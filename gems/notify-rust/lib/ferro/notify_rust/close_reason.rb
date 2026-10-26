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
    # SPDX-SnippetComment: CloseReason and its documentation from
    #   notify-rust 4.18.2 src/response.rs:8-45
    #++

    # Why a notification closed without the user choosing an action.
    #
    # A notification can disappear because it timed out, because the user
    # dismissed it, or because your program closed it. Telling these apart
    # lets you remind the user later about one they never saw.
    #
    # On Linux the reason is the server's +NotificationClosed+ signal
    # code. macOS does not tell them apart; notify-rust reports a
    # dismissal as Dismissed and a notification that went away by itself
    # as Expired. On Windows a toast the user cancelled is Dismissed, one
    # that timed out is Expired, and one the application hid is
    # CloseAction.
    #
    # Mirrors notify-rust's +CloseReason+ (<tt>src/response.rs:8-34</tt>).
    #
    # === Examples
    #
    #   notification.show.on_close do |reason|
    #     puts "missed it" if reason == Ferro::NotifyRust::CloseReason::Expired
    #   end
    #
    #   Ferro::NotifyRust::CloseReason.from(2) # => Ferro::NotifyRust::CloseReason::Dismissed
    module CloseReason
      # A close reason without data.
      class Unit # :nodoc:
        include CloseReason

        # [name] Symbol, the notify-rust variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        # The constant that holds this reason.
        def inspect
          "Ferro::NotifyRust::CloseReason::#{@name}"
        end
      end
      private_constant :Unit

      # The notification expired (timed out).
      Expired = Unit.new(:Expired)

      # The user dismissed the notification.
      Dismissed = Unit.new(:Dismissed)

      # The notification was closed programmatically.
      CloseAction = Unit.new(:CloseAction)

      # The platform reported a reason notify-rust does not know, or a
      # reserved one.
      #
      # === Example
      #
      #   Ferro::NotifyRust::CloseReason.from(4) # => #<data Ferro::NotifyRust::CloseReason::Other raw_reason=4>
      class Other < Data.define(:raw_reason)
        include CloseReason

        ##
        # :attr_reader: raw_reason
        # The platform's code, an Integer.
      end

      # The reason the XDG specification's code +raw_reason+ means: 1
      # Expired, 2 Dismissed, 3 CloseAction, anything else Other. Mirrors
      # <tt>From<u32> for CloseReason</tt> (<tt>src/response.rs:36-45</tt>).
      #
      # [raw_reason] Integer from 0 to <tt>2**32 - 1</tt>.
      #
      # === Example
      #
      #   Ferro::NotifyRust::CloseReason.from(1) # => Ferro::NotifyRust::CloseReason::Expired
      def self.from(raw_reason)
        from_native(Native.close_reason_from(raw_reason))
      end

      # The reason the native layer's +tag+ names: a Symbol or a code.
      def self.from_native(tag) # :nodoc:
        case tag
        when :Expired then Expired
        when :Dismissed then Dismissed
        when :CloseAction then CloseAction
        else Other.new(tag)
        end
      end
      private_class_method :from_native
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
