# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "close_reason"
require_relative "notification_response"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: NotificationHandle's waits and their documentation
    #   from notify-rust 4.18.2 src/xdg/mod.rs:67-288,
    #   src/macos/nsusernotifications.rs:5-139, src/windows.rs:99-144
    #++

    # A notification you showed, and what you can still do with it.
    #
    # Showing a notification is often the start of a conversation: you
    # want to know whether the user clicked it, which action they chose,
    # or when it went away. Each platform reports that differently.
    #
    # Builder#show returns one of these. On every platform you can wait
    # for the user: #wait_for_action, #wait_for_response, and #on_close
    # each block until the notification is answered or closed, then call
    # your block. On Linux the handle also keeps the D-Bus connection that
    # some desktops need for actions to work, can close and update the
    # notification, and answers its id; on Linux and Windows it answers
    # every Notification setter and field, acting on the notification it
    # showed (see Builder).
    #
    # In Rust each wait consumes the handle. Ruby keeps it: on Linux a
    # second wait waits for the next signal about the same notification.
    # On macOS and Windows a wait takes the notification out of the handle,
    # as notify-rust does, so a second wait returns at once without calling
    # its block, as does a wait on a handle whose notification +show+ has
    # already sent.
    #
    # A wait or #close borrows the handle; a setter or #update needs it to
    # itself, as Rust's <tt>&mut</tt> does. Rust refuses that at compile
    # time, so on Linux a setter or #update while another thread waits on
    # or closes the handle raises Error (<tt>already borrowed: ...</tt>) at
    # once, and so does any call while #update runs. On Windows, after a
    # wait has consumed the handle, every Builder method raises Error.
    #
    # Every wait releases Ruby's global VM lock, so other threads keep
    # running. On Linux an interrupt (Ctrl-C, <tt>Thread#raise</tt>,
    # +Timeout+) ends a wait. On macOS and Windows nothing can end one
    # early, so Ctrl-C and process exit wait until the user answers. On
    # macOS a wait needs the main thread's run loop: on the main thread it
    # runs the loop itself; on any other thread it finishes only while the
    # main thread runs its run loop, as a windowed app's event loop does,
    # and otherwise blocks indefinitely.
    #
    # Mirrors notify-rust's +NotificationHandle+ (<tt>src/xdg/mod.rs:67-73</tt>,
    # <tt>src/macos/nsusernotifications.rs:5-12</tt>,
    # <tt>src/windows.rs:99-107</tt>).
    #
    # === Examples
    #
    #   Ferro::NotifyRust::Notification.new.summary("click me")
    #     .action("default", "default")
    #     .action("clicked_a", "button a")
    #     .show do |handle|
    #       handle.wait_for_action do |action|
    #         puts action # "default", "clicked_a", or "__closed"
    #       end
    #     end
    #
    #   Ferro::NotifyRust::Notification.new.summary("Time is running out")
    #     .show
    #     .on_close { |reason| puts "closed: #{reason.inspect}" }
    class NotificationHandle
      private_class_method :new

      # Waits for the user to act on the notification, then yields the
      # action's identifier: the key you gave Builder#action,
      # <tt>"default"</tt> when the user clicked the notification itself,
      # or <tt>"__closed"</tt>, a hard-coded keyword, when it closed
      # without an action. On macOS a reply yields its text. Yields nothing
      # when the wait ends without an answer. Returns +nil+.
      #
      # #wait_for_response yields a NotificationResponse instead, which
      # tells these apart. Mirrors
      # <tt>NotificationHandle::wait_for_action</tt>
      # (<tt>src/xdg/mod.rs:99-128</tt>,
      # <tt>src/macos/nsusernotifications.rs:23-62</tt>,
      # <tt>src/windows.rs:110-120</tt>).
      #
      # === Example
      #
      #   handle.wait_for_action do |action|
      #     case action
      #     when "clicked_a" then puts "clicked \"action\""
      #     when "__closed" then puts "the notification was closed"
      #     end
      #   end
      def wait_for_action
        action = native_wait_for_action
        yield action unless action.nil?
        nil
      end

      # Waits for the user to act on the notification, then yields a
      # NotificationResponse. Yields nothing when the wait ends without an
      # answer. Returns +nil+. Raises Error when the platform reports a
      # failure: on macOS, delivering the notification; on Windows, losing
      # the toast's events. Mirrors
      # <tt>NotificationHandle::wait_for_response</tt>
      # (<tt>src/xdg/mod.rs:130-144</tt>,
      # <tt>src/macos/nsusernotifications.rs:64-106</tt>,
      # <tt>src/windows.rs:122-133</tt>).
      #
      # === Example
      #
      #   handle.wait_for_response do |response|
      #     puts "body clicked" if response.is_default_action
      #   end
      def wait_for_response
        tag = native_wait_for_response
        yield NotificationResponse.__send__(:from_native, tag) unless tag.nil?
        nil
      end

      # Waits until the notification closes, then yields the CloseReason. A
      # block that takes no argument works too, as notify-rust takes both
      # kinds of closure. When the user acts on the notification instead,
      # the block is not called. Returns +nil+.
      #
      # On macOS the wait shows a Close button, since it ends only when the
      # user dismisses the notification or it goes away. Mirrors
      # <tt>NotificationHandle::on_close</tt>
      # (<tt>src/xdg/mod.rs:240-288</tt>,
      # <tt>src/macos/nsusernotifications.rs:108-139</tt>,
      # <tt>src/windows.rs:135-143</tt>).
      #
      # === Example
      #
      #   handle.on_close { |reason| puts "closed: #{reason.inspect}" }
      #   handle.on_close { puts "closed" }
      def on_close
        tag = native_on_close
        yield CloseReason.__send__(:from_native, tag) unless tag.nil?
        nil
      end

      # Ends the handle's part in Builder#show. Only macOS has anything to
      # do (apple.rb).
      private def release
        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
