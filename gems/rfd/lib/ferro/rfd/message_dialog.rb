# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "handles"
require_relative "message_level"
require_relative "message_buttons"
require_relative "message_dialog_result"

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: MessageDialog and its docs from rfd 0.17.2
    #   src/message_dialog.rs:9-85, and the crate docs in src/lib.rs:38-98
    #++

    # The system's message box: a short message and a few buttons.
    #
    # Command-line output goes unseen when your program runs from a dock
    # or a file manager, and a GUI program needs a way to tell the user
    # something or ask a yes-or-no question. Each system draws its own
    # alerts, with its own icons, button order, and keyboard shortcuts.
    #
    # This builder shows the system's alert. Set a title, a description, a
    # MessageLevel, and MessageButtons, then call #show, which waits for the
    # user and returns the MessageDialogResult for the button pressed.
    #
    # Use it to confirm a destructive action, report an error to a user
    # without a terminal, or ask before quitting with unsaved work.
    #
    # === Behavior
    #
    # Setters return the dialog, and #show may run again; #inspect shows
    # rfd's +Debug+ text. The dialog releases Ruby's global VM lock while
    # it is open, and rfd cannot close it early, so Ctrl-C waits for the
    # user.
    #
    # On macOS, without a parent, rfd shows a system alert that runs on any
    # thread with no application; but MessageDialog asks for the main
    # thread, or a running application, as FileDialog does, and raises
    # Error otherwise. AsyncMessageDialog runs the alert from any thread.
    #
    # On Linux, rfd runs +zenity+ for every message: OK-only dialogs as
    # <tt>zenity --info</tt> (or <tt>--warning</tt>, <tt>--error</tt>) and
    # the rest as <tt>zenity --question</tt>. Without +zenity+, #show
    # returns MessageDialogResult::Cancel at once. A parent is ignored.
    #
    # On Windows, rfd shows +MessageBoxW+. Custom labels need rfd's
    # <tt>common-controls-v6</tt> feature, which ferro-rfd does not build;
    # MessageButtons says what you get instead.
    #
    # Mirrors rfd's +MessageDialog+ (<tt>src/message_dialog.rs:9-85</tt>).
    #
    # === Examples
    #
    #   result = Ferro::Rfd::MessageDialog.new
    #     .set_title("Msg!")
    #     .set_description("Description!")
    #     .set_buttons(Ferro::Rfd::MessageButtons::OkCancel)
    #     .set_level(Ferro::Rfd::MessageLevel::Error)
    #     .show
    #   puts "res: #{result}"
    #
    #   Ferro::Rfd::MessageDialog.new.set_description("Export finished.").show
    class MessageDialog
      # Creates a dialog with rfd's defaults: an empty title and
      # description, MessageLevel::Info, MessageButtons::Ok, and no parent.
      #
      # Mirrors rfd's <tt>MessageDialog::new</tt>
      # (<tt>src/message_dialog.rs:29-31</tt>), which is its +Default+.
      #
      # === Example
      #
      #   dialog = Ferro::Rfd::MessageDialog.new
      def initialize
        @level = MessageLevel.default
        @title = nil
        @description = nil
        @buttons = MessageButtons.default
        @parent = nil
      end

      # Sets how serious the message is, a MessageLevel. Returns the
      # dialog.
      #
      # Depending on the system, the level shows as an icon that tells the
      # user whether the message is an error, a warning, or information.
      #
      # Mirrors rfd's <tt>MessageDialog::set_level</tt>
      # (<tt>src/message_dialog.rs:33-40</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.set_level(Ferro::Rfd::MessageLevel::Warning)
      def set_level(level)
        MessageLevel.__send__(:variant, level)
        @level = level
        self
      end

      # Titles the dialog +text+. Returns the dialog.
      #
      # Mirrors rfd's <tt>MessageDialog::set_title</tt>
      # (<tt>src/message_dialog.rs:42-46</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.set_title("Unsaved changes")
      def set_title(text)
        @title = Rfd.__send__(:string, text)
        self
      end

      # Sets the message itself, +text+. Returns the dialog.
      #
      # Mirrors rfd's <tt>MessageDialog::set_description</tt>
      # (<tt>src/message_dialog.rs:48-54</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.set_description("Save before closing?")
      def set_description(text)
        @description = Rfd.__send__(:string, text)
        self
      end

      # Chooses the buttons the dialog shows, MessageButtons. Returns the
      # dialog.
      #
      # - MessageButtons::Ok shows a single OK button.
      # - MessageButtons::OkCancel shows OK and Cancel.
      # - MessageButtons::YesNo shows Yes and No.
      # - MessageButtons::YesNoCancel shows Yes, No, and Cancel.
      # - The Custom classes show labels of your own.
      #
      # Mirrors rfd's <tt>MessageDialog::set_buttons</tt>
      # (<tt>src/message_dialog.rs:56-65</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.set_buttons(Ferro::Rfd::MessageButtons::YesNoCancel)
      def set_buttons(btn)
        MessageButtons.__send__(:variant, btn)
        @buttons = btn
        self
      end

      # Keeps the dialog in front of +parent+'s window. Returns the dialog.
      # See FileDialog#set_parent for what +parent+ answers and which
      # handles each platform takes. rfd uses it on Windows, and on macOS,
      # where the alert opens as a sheet on the window; on Linux, +zenity+
      # takes no parent.
      #
      # Mirrors rfd's <tt>MessageDialog::set_parent</tt>
      # (<tt>src/message_dialog.rs:67-79</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.set_parent(window)
      def set_parent(parent)
        @parent = Rfd.__send__(:parent_pair, parent)
        self
      end

      # Shows the dialog and returns the MessageDialogResult for the
      # button the user pressed.
      #
      # Mirrors rfd's <tt>MessageDialog::show</tt>
      # (<tt>src/message_dialog.rs:81-84</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.set_description("Hello!").show
      #   # => Ferro::Rfd::MessageDialogResult::Ok
      def show
        MessageDialogResult.__send__(:from_native, Native.message_dialog(settings))
      end

      # rfd's +Debug+ text for this dialog. On macOS, with an
      # AppKitWindowHandle parent, it looks the window up as the dialog
      # would, and from another thread waits for the main thread's run
      # loop, uninterruptibly (FileDialog#set_parent).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialog.new.inspect
      #   # => "MessageDialog { title: \"\", description: \"\", level: Info, buttons: Ok, ... }"
      def inspect
        Native.message_dialog_debug(settings)
      end

      # The options, in the order the native layer takes them.
      private def settings
        [
          MessageLevel.__send__(:variant, @level),
          @title,
          @description,
          MessageButtons.__send__(:variant, @buttons),
          @parent,
]
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
