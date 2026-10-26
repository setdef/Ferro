# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "builder"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: Notification and its documentation from
    #   notify-rust 4.18.2 src/notification.rs:35-125
    #++

    # A desktop notification, configured step by step and then shown.
    #
    # A notification has a summary, a body, an icon, actions, hints, and a
    # timeout, and each platform reads a different subset of them.
    # Assembling those for D-Bus, the macOS notification center, or a
    # Windows toast by hand means three different APIs.
    #
    # This class is notify-rust's builder. Each setter (from Builder)
    # returns the notification, so calls chain, and Builder#show sends it.
    # Most fields start empty; +appname+ starts as the name of the running
    # executable, which some desktops use to group notifications.
    #
    # +dup+ and +clone+ copy the notification, as Rust's +Clone+ does, and
    # Builder#finalize returns a copy too. A frozen notification refuses
    # its setters, and can be shared between Ractors. #inspect shows
    # notify-rust's own +Debug+ text.
    #
    # Mirrors notify-rust's +Notification+ (<tt>src/notification.rs:35-125</tt>).
    #
    # === Examples
    #
    #   Ferro::NotifyRust::Notification.new
    #     .summary("☝️ A notification")
    #     .show
    #
    #   Ferro::NotifyRust::Notification.new
    #     .summary("Category:email")
    #     .body("This has nothing to do with emails.\nIt should not go away until you acknowledge it.")
    #     .icon("thunderbird")
    #     .appname("thunderbird")
    #     .hint(Ferro::NotifyRust::Hint::Category.new("email"))
    #     .hint(Ferro::NotifyRust::Hint::Resident.new(true)) # this is not supported by all implementations
    #     .timeout(Ferro::NotifyRust::Timeout::Never) # this however is
    #     .show
    class Notification
      include Builder

      ##
      # :singleton-method: new
      # Creates an empty notification whose +appname+ is the executable's
      # name. Mirrors <tt>Notification::new</tt>
      # (<tt>src/notification.rs:117-125</tt>).
      #
      # === Example
      #
      #   notification = Ferro::NotifyRust::Notification.new

      # notify-rust's +Debug+ text for the notification.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Hi").inspect # => "Notification { appname: \"ruby\", summary: \"Hi\", ... }"
      def inspect
        native_inspect
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
