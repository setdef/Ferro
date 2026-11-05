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
    # In Rust each wait, and on Linux #close, takes the handle by value,
    # and the handle drops at the end of its scope. So here each of them,
    # and the end of Builder#show's block, uses the handle up: any later
    # call on it raises +IOError+ naming the call that did, as a closed IO
    # does, even when that call raised. A wait without a block raises
    # +ArgumentError+ first, without using the handle up, since Rust
    # requires the closure. On Linux, NotificationHandle#wait_for_action_async
    # and NotificationHandle#close_async borrow the handle, as notify-rust's
    # do, so they leave it usable.
    #
    # On Linux a borrowing call shares the handle; a setter or #update
    # needs it to itself, as Rust's <tt>&mut</tt> does. A setter or #update
    # while another thread's borrowing wait or close runs waits for that to
    # end, as a second thread waits for a Mutex, and any call while #update
    # runs waits for it; a close or another wait does not wait behind a
    # waiting setter. Ctrl-C, <tt>Thread#raise</tt>, and +Timeout+ end such
    # a wait. A setter or #update on the very thread whose own borrowing
    # wait holds the handle, as from a signal trap that runs during the
    # wait, would wait for itself, so it raises +ThreadError+
    # (<tt>already borrowed: ...</tt>), as Mutex#lock does. A wait or close
    # already under way on another thread when the handle is used up
    # finishes; a setter or #update still waiting for its turn then raises
    # +IOError+. On Linux, using the handle up frees its D-Bus connection,
    # as Rust drops a moved handle when the call returns, once any
    # borrowing call on another thread ends.
    #
    # Every wait releases Ruby's global VM lock, so other threads keep
    # running; it never runs with the lock held. On Linux an interrupt
    # (Ctrl-C, <tt>Thread#raise</tt>, +Timeout+) ends a wait. One that
    # arrives just as the user answers raises after the answer came, and
    # the answer is lost, as Ruby's IO methods lose data read just before
    # an interrupt. On macOS and Windows nothing can end a wait
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
    #   Ferro::NotifyRust::Notification.new.summary("Time is running out").show do |handle|
    #     handle.on_close { |reason| puts "closed: #{reason.debug}" }
    #   end
    class NotificationHandle
      private_class_method :new

      # notify-rust's +Debug+ text for the handle, formatted by Rust: on
      # Linux the server's id, the D-Bus connection, and the notification;
      # on macOS and Windows the notification it holds. +inspect+ stays
      # Ruby's. Raises +IOError+ once the handle is used up. Mirrors
      # notify-rust's <tt>#[derive(Debug)]</tt> on +NotificationHandle+
      # (<tt>src/xdg/mod.rs:70</tt>, <tt>src/macos/nsusernotifications.rs:9</tt>,
      # <tt>src/windows.rs:103</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Hi").show(&:debug)
      #   # => "NotificationHandle { inner: Zbus(ZbusNotificationHandle { id: 7, ... }) }"
      def debug
        native_debug
      end

      # Waits for the user to act on the notification, then yields the
      # action's identifier: the key you gave Builder#action,
      # <tt>"default"</tt> when the user clicked the notification itself,
      # or <tt>"__closed"</tt>, a hard-coded keyword, when it closed
      # without an action. On macOS a reply yields its text. Yields nothing
      # when the wait ends without an answer. Returns +nil+. Uses the handle
      # up.
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
        raise ArgumentError, "no block given; wait_for_action calls it with the action" unless block_given?

        action = native_wait_for_action
        yield action unless action.nil?
        nil
      end

      # Waits for the user to act on the notification, then yields a
      # NotificationResponse. Yields nothing when the wait ends without an
      # answer. Returns +nil+. Raises Error when the platform reports a
      # failure: on macOS, delivering the notification; on Windows, losing
      # the toast's events. Uses the handle up. Mirrors
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
        raise ArgumentError, "no block given; wait_for_response calls it with the response" unless block_given?

        tag = native_wait_for_response
        yield NotificationResponse.__send__(:from_native, tag) unless tag.nil?
        nil
      end

      # Waits until the notification closes, then yields the CloseReason. A
      # block that takes no argument works too, as notify-rust takes both
      # kinds of closure. When the user acts on the notification instead,
      # the block is not called. Returns +nil+. Uses the handle up.
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
      #   handle.on_close { |reason| puts "closed: #{reason.debug}" }
      #   handle.on_close { puts "closed" }
      def on_close
        raise ArgumentError, "no block given; on_close calls it with the reason" unless block_given?

        tag = native_on_close
        yield CloseReason.__send__(:from_native, tag) unless tag.nil?
        nil
      end

      # Ends the handle's scope, at the end of Builder#show: uses it up, as
      # Rust drops it, unless a wait already did. On macOS notify-rust's
      # drop sends the notification
      # (<tt>src/macos/nsusernotifications.rs:142-162</tt>), and waits up to
      # about two seconds for the notification center to confirm delivery,
      # with Ruby's global VM lock released.
      private def release
        native_release
        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
