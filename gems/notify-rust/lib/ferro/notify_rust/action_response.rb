# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "close_reason"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: ActionResponse and its documentation from
    #   notify-rust 4.18.2 src/response.rs:104-122
    #++

    # The answer to a notification, as notify-rust's older API reports it.
    #
    # Deprecated since notify-rust 4.18.0: use NotificationResponse, which
    # covers more cases. notify-rust keeps this type so existing code still
    # compiles, and NotifyRust.handle_action (Linux) still yields it.
    #
    # Custom carries the key of the action the user chose, or
    # <tt>"default"</tt> when they clicked the notification itself; Closed
    # carries a CloseReason.
    #
    # Mirrors notify-rust's +ActionResponse+ (<tt>src/response.rs:104-116</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust.handle_action(id) do |response|
    #     case response
    #     in Ferro::NotifyRust::ActionResponse::Custom(key:) then puts "chose #{key}"
    #     in Ferro::NotifyRust::ActionResponse::Closed(reason:) then puts "closed: #{reason.inspect}"
    #     end
    #   end
    module ActionResponse
      # The user clicked a named action button, or the notification body,
      # whose key is <tt>"default"</tt>.
      #
      # === Example
      #
      #   Ferro::NotifyRust::ActionResponse::Custom.new("default")
      class Custom < Data.define(:key)
        include ActionResponse

        ##
        # :attr_reader: key
        # The action's identifier, a String.
      end

      # The notification closed without any action being taken.
      #
      # === Example
      #
      #   Ferro::NotifyRust::ActionResponse::Closed.new(Ferro::NotifyRust::CloseReason::Expired)
      class Closed < Data.define(:reason)
        include ActionResponse

        ##
        # :attr_reader: reason
        # Why it closed, a CloseReason.
      end

      # The response for the action key +key+: Custom. Mirrors
      # <tt>From<&str> for ActionResponse</tt>
      # (<tt>src/response.rs:118-122</tt>).
      #
      # [key] String, the action's identifier.
      #
      # === Example
      #
      #   Ferro::NotifyRust::ActionResponse.from("ok") # => #<data Ferro::NotifyRust::ActionResponse::Custom key="ok">
      def self.from(key)
        from_native(Native.action_response_from(NotifyRust.__send__(:string, key)))
      end

      # The response the native layer's +tag+ names.
      def self.from_native(tag) # :nodoc:
        name, value = tag
        (name == :Custom) ? Custom.new(String(value)) : Closed.new(CloseReason.__send__(:from_native, value))
      end
      private_class_method :from_native
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
