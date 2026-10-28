# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "message_dialog"
require_relative "future"

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: AsyncMessageDialog and its docs from rfd 0.17.2
    #   src/message_dialog.rs:87-151, examples/msg.rs
    #++

    # A message dialog you start now and wait for later.
    #
    # A message box that blocks your main thread freezes your windows until
    # the user answers it. That is fine for a command-line tool and wrong
    # for an app with an event loop.
    #
    # This builder takes the same options as MessageDialog, but #show
    # returns a Future of the MessageDialogResult. On macOS, a dialog
    # without a parent opens at once, on a thread of rfd's own, from any
    # thread, with or without an application. On Windows and Linux it opens
    # when you first call Future#value, on a thread of rfd's own.
    #
    # Use it to ask a question without stalling the thread that asked.
    #
    # Mirrors rfd's +AsyncMessageDialog+ (<tt>src/message_dialog.rs:87-151</tt>),
    # which wraps a +MessageDialog+ as this one does.
    #
    # === Example
    #
    #   result = Ferro::Rfd::AsyncMessageDialog.new
    #     .set_title("Msg!")
    #     .set_description("Description!")
    #     .set_buttons(Ferro::Rfd::MessageButtons::OkCancel)
    #     .show
    #     .value
    #   puts "res: #{result}"
    class AsyncMessageDialog
      # Creates a dialog with rfd's defaults, as MessageDialog.new does.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::new</tt>
      # (<tt>src/message_dialog.rs:96-98</tt>).
      #
      # === Example
      #
      #   dialog = Ferro::Rfd::AsyncMessageDialog.new
      def initialize
        @message_dialog = MessageDialog.new
      end

      # Sets how serious the message is. Returns the dialog. See
      # MessageDialog#set_level.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::set_level</tt>
      # (<tt>src/message_dialog.rs:100-107</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncMessageDialog.new.set_level(Ferro::Rfd::MessageLevel::Error)
      def set_level(level)
        @message_dialog = @message_dialog.dup.set_level(level)
        self
      end

      # Titles the dialog +text+. Returns the dialog.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::set_title</tt>
      # (<tt>src/message_dialog.rs:109-113</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncMessageDialog.new.set_title("Update ready")
      def set_title(text)
        @message_dialog = @message_dialog.dup.set_title(text)
        self
      end

      # Sets the message itself, +text+. Returns the dialog.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::set_description</tt>
      # (<tt>src/message_dialog.rs:115-121</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncMessageDialog.new.set_description("Restart now?")
      def set_description(text)
        @message_dialog = @message_dialog.dup.set_description(text)
        self
      end

      # Chooses the buttons. Returns the dialog. See
      # MessageDialog#set_buttons.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::set_buttons</tt>
      # (<tt>src/message_dialog.rs:123-132</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncMessageDialog.new.set_buttons(Ferro::Rfd::MessageButtons::YesNo)
      def set_buttons(btn)
        @message_dialog = @message_dialog.dup.set_buttons(btn)
        self
      end

      # Keeps the dialog in front of +parent+'s window. Returns the dialog.
      # See FileDialog#set_parent.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::set_parent</tt>
      # (<tt>src/message_dialog.rs:134-145</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncMessageDialog.new.set_parent(window)
      def set_parent(parent)
        @message_dialog = @message_dialog.dup.set_parent(parent)
        self
      end

      # Starts showing the dialog. Returns a Future of the
      # MessageDialogResult for the button the user pressed.
      #
      # Mirrors rfd's <tt>AsyncMessageDialog::show</tt>
      # (<tt>src/message_dialog.rs:147-150</tt>).
      #
      # === Example
      #
      #   future = Ferro::Rfd::AsyncMessageDialog.new.set_description("Hi").show
      #   future.value # => Ferro::Rfd::MessageDialogResult::Ok
      def show
        Future.__send__(:new, Native.async_message_dialog(@message_dialog.__send__(:settings)))
      end

      # rfd's +Debug+ text for this dialog. On macOS, with an
      # AppKitWindowHandle parent, it looks the window up as the dialog
      # would, and from another thread waits for the main thread's run
      # loop, uninterruptibly (FileDialog#set_parent).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncMessageDialog.new.inspect
      #   # => "AsyncMessageDialog(MessageDialog { title: \"\", ... })"
      def inspect
        Native.async_message_dialog_debug(@message_dialog.__send__(:settings))
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
