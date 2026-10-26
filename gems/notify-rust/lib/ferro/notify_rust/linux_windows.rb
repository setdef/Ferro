# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "urgency"
require_relative "builder"
require_relative "notification_handle"

# notify-rust compiles these for its XDG platforms and Windows, not for
# macOS without preview-macos-un (src/notification.rs:386, :410; the
# handle's Deref at src/xdg/mod.rs:330-354 and src/windows.rs:146-158).
return if Ferro::NotifyRust.const_get(:PLATFORM) == :macos

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: Notification::urgency and its documentation from
    #   notify-rust 4.18.2 src/notification.rs:366-414
    #++

    module Builder
      # Sets the Urgency: Low, Normal, or Critical.
      #
      # On Linux it is a hint to the server. Most desktops are fairly
      # relaxed about urgency and may not change much, but critical
      # notifications are meant not to time out. On Windows it picks the
      # toast's scenario: Low and Normal show a standard toast, and Critical
      # a reminder that stays on screen until the user dismisses it. Defined
      # only on Linux and Windows. Mirrors <tt>Notification::urgency</tt>
      # (<tt>src/notification.rs:366-414</tt>).
      #
      # [urgency] Urgency.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("oh no").urgency(Ferro::NotifyRust::Urgency::Critical).show
      def urgency(urgency)
        raise TypeError, "no implicit conversion of #{urgency.class} into Ferro::NotifyRust::Urgency" unless urgency.is_a?(Urgency)

        __send__(:native_urgency, urgency.__send__(:to_native))
        self
      end
    end

    # On Linux and Windows a handle reaches the notification it showed, as
    # Rust's Deref and DerefMut do: every Builder method acts on it.
    class NotificationHandle
      include Builder
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
