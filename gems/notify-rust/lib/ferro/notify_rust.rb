# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "notify_rust/version"
require_relative "notify_rust/ferro_notify_rust"
require_relative "notify_rust/error"
require_relative "notify_rust/urgency"
require_relative "notify_rust/timeout"
require_relative "notify_rust/close_reason"
require_relative "notify_rust/notification_response"
require_relative "notify_rust/action_response"
require_relative "notify_rust/notification_id"
require_relative "notify_rust/hint"
require_relative "notify_rust/server_information"
require_relative "notify_rust/builder"
require_relative "notify_rust/notification"
require_relative "notify_rust/notification_handle"
require_relative "notify_rust/linux"
require_relative "notify_rust/linux_windows"
require_relative "notify_rust/windows"
require_relative "notify_rust/apple"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, such as desktop notifications. Each Ferro gem binds one crate,
# keeps its names and behavior, and adds nothing of its own.
module Ferro
  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: MIT OR Apache-2.0
  # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
  # SPDX-SnippetComment: the crate overview from notify-rust 4.18.2
  #   src/lib.rs:1-130
  #++

  # Desktop notifications, through notify-rust 4.18.2.
  #
  # Desktop notifications are popup messages a program shows to tell the
  # user something happened: a download finished, a build failed, a
  # message arrived. Each system shows them its own way: Linux and the
  # BSDs through the XDG notification server on D-Bus, macOS through its
  # notification center, Windows as toasts.
  #
  # This module binds notify-rust (https://github.com/hoodie/notify-rust)
  # one to one. Build a Notification, then #show it. On Linux the
  # NotificationHandle that +show+ returns can wait for the user to click
  # an action, close the notification, or update it in place.
  #
  # notify-rust was written for the XDG notification specification, and
  # the platforms differ. Each method's documentation says where it
  # works; a method a platform lacks is not defined there, so
  # +respond_to?+ answers. On macOS +appname+ and +icon+ do nothing, and
  # +hint+, +urgency+, and the handle's +close+ and +update+ do not
  # exist. Careful: nothing checks whether you set a hint twice. With
  # <tt>urgency=Low</tt> and <tt>urgency=Critical</tt> both set, the
  # server's behavior is undefined.
  #
  # === Examples
  #
  #   require "ferro/notify_rust"
  #
  #   Ferro::NotifyRust::Notification.new
  #     .summary("Firefox News")
  #     .body("This will almost look like a real firefox notification.")
  #     .icon("firefox")
  #     .timeout(Ferro::NotifyRust::Timeout::Milliseconds.new(6000))
  #     .show
  #
  #   # Ask the user to do something (Linux):
  #   Ferro::NotifyRust::Notification.new.summary("click me")
  #     .action("default", "default")
  #     .action("clicked", "click here")
  #     .hint(Ferro::NotifyRust::Hint::Resident.new(true))
  #     .show
  #     .wait_for_action do |action|
  #       case action
  #       when "default" then puts "you clicked \"default\""
  #       when "clicked" then puts "that was correct"
  #       when "__closed" then puts "the notification was closed"
  #       end
  #     end
  module NotifyRust
    private_constant :PLATFORM, :Native

    # +value+ if it is a String (or converts to one implicitly), frozen;
    # otherwise raises +TypeError+ in Ruby's words. notify-rust's
    # <tt>&str</tt> arguments take Strings.
    def self.string(value) # :nodoc:
      string = String.try_convert(value)
      raise TypeError, "no implicit conversion of #{value.nil? ? 'nil' : value.class} into String" unless string

      -string
    end
    private_class_method :string
  end

  #--
  # SPDX-SnippetEnd
  #++
end
