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
    # SPDX-SnippetComment: NotificationResponse and its documentation from
    #   notify-rust 4.18.2 src/response.rs:47-102
    #++

    # What became of a shown notification: the user clicked it, chose an
    # action, replied, or it closed.
    #
    # A notification with actions asks the user something, and the answer
    # comes back later. Matching strings such as <tt>"__closed"</tt>, as
    # NotificationHandle#wait_for_action passes, mixes the actions you
    # named with notify-rust's own keywords.
    #
    # NotificationHandle#wait_for_response yields one of these instead:
    # Default when the user activated the notification itself, Action
    # with the key of the button they chose, Reply with the text they
    # typed (only notify-rust's macOS backends produce it), or Closed with
    # a CloseReason.
    #
    # Mirrors notify-rust's +NotificationResponse+
    # (<tt>src/response.rs:47-90</tt>).
    #
    # === Examples
    #
    #   handle.wait_for_response do |response|
    #     case response
    #     in Ferro::NotifyRust::NotificationResponse::Default then puts "body clicked"
    #     in Ferro::NotifyRust::NotificationResponse::Action(key:) then puts "button '#{key}' clicked"
    #     in Ferro::NotifyRust::NotificationResponse::Reply(text:) then puts "user replied: #{text}"
    #     in Ferro::NotifyRust::NotificationResponse::Closed(reason:) then puts "closed: #{reason.inspect}"
    #     end
    #   end
    module NotificationResponse
      # A response without data.
      class Unit # :nodoc:
        include NotificationResponse

        # [name] Symbol, the notify-rust variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        # The constant that holds this response.
        def inspect
          "Ferro::NotifyRust::NotificationResponse::#{@name}"
        end
      end
      private_constant :Unit

      # The default action was invoked: the user activated the
      # notification without choosing a specific button (clicked the body,
      # tapped the banner). It is the D-Bus <tt>"default"</tt> action key,
      # Apple's +UNNotificationDefaultActionIdentifier+, and a body click on
      # Windows.
      Default = Unit.new(:Default)

      # The user invoked a named action button.
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationResponse::Action.new("reply")
      class Action < Data.define(:key)
        include NotificationResponse

        ##
        # :attr_reader: key
        # The action's identifier, a String: what you passed
        # Notification#action first.
      end

      # The user submitted an inline text reply. Only notify-rust's macOS
      # backends produce it; on other platforms it never comes.
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationResponse::Reply.new("On my way")
      class Reply < Data.define(:text)
        include NotificationResponse

        ##
        # :attr_reader: text
        # What the user typed, a String.
      end

      # The notification closed without any action being taken.
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationResponse::Closed.new(Ferro::NotifyRust::CloseReason::Dismissed)
      class Closed < Data.define(:reason)
        include NotificationResponse

        ##
        # :attr_reader: reason
        # Why it closed, a CloseReason.
      end

      # The response for the action key +key+: Action. Mirrors
      # <tt>From<&str> for NotificationResponse</tt>
      # (<tt>src/response.rs:92-102</tt>).
      #
      # [key] String, the action's identifier.
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationResponse.from("ok") # => #<data Ferro::NotifyRust::NotificationResponse::Action key="ok">
      def self.from(key)
        from_native(Native.notification_response_from(NotifyRust.__send__(:string, key)))
      end

      # The response the native layer's +tag+ names.
      def self.from_native(tag) # :nodoc:
        name, value = tag
        case name
        when :Default then Default
        when :Action then Action.new(String(value))
        when :Reply then Reply.new(String(value))
        else Closed.new(CloseReason.__send__(:from_native, value))
        end
      end
      private_class_method :from_native

      # Whether this is Default, the user activating the notification
      # itself. Mirrors <tt>NotificationResponse::is_default_action</tt>
      # (<tt>src/response.rs:85-90</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationResponse::Default.is_default_action # => true
      def is_default_action
        equal?(Default)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
