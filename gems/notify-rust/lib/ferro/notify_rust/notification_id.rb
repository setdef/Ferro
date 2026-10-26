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
    # SPDX-SnippetComment: NotificationId and its documentation from
    #   notify-rust 4.18.2 src/notification_id.rs:1-44
    #++

    # A platform-independent notification identifier.
    #
    # Platforms name notifications differently. On XDG (Linux and the BSDs)
    # the server assigns each a number; macOS's +UNUserNotificationCenter+
    # takes a string the caller picks. Code that keeps identifiers for
    # both needs one type for either.
    #
    # Xdg holds a number and Mac a string. notify-rust uses Mac only with
    # its <tt>preview-macos-un</tt> feature, which ferro-notify-rust does
    # not build, so Notification#id takes an Integer everywhere; this type
    # is here because notify-rust exports it on every platform.
    #
    # Mirrors notify-rust's +NotificationId+
    # (<tt>src/notification_id.rs:19-26</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust::NotificationId.from(42)              # => #<data Ferro::NotifyRust::NotificationId::Xdg value=42>
    #   Ferro::NotifyRust::NotificationId.from("my-app.status") # => #<data Ferro::NotifyRust::NotificationId::Mac value="my-app.status">
    module NotificationId
      # An XDG / D-Bus numeric identifier (Linux, BSD).
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationId::Xdg.new(42)
      class Xdg < Data.define(:value)
        include NotificationId

        ##
        # :attr_reader: value
        # The identifier, an Integer from 0 to <tt>2**32 - 1</tt>.
      end

      # A macOS +UNNotificationRequest+ string identifier.
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationId::Mac.new("my-app.status")
      class Mac < Data.define(:value)
        include NotificationId

        ##
        # :attr_reader: value
        # The identifier, a String.
      end

      # Xdg for an Integer, Mac for a String. Mirrors the +From+ impls of
      # +NotificationId+ (<tt>src/notification_id.rs:28-44</tt>).
      #
      # [value] Integer from 0 to <tt>2**32 - 1</tt>, or a String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::NotificationId.from(7) # => #<data Ferro::NotifyRust::NotificationId::Xdg value=7>
      def self.from(value)
        name, id = Native.notification_id_from(value)
        (name == :Xdg) ? Xdg.new(Integer(id)) : Mac.new(String(id))
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
