# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "file_dialog"
require_relative "async_file_dialog"
require_relative "handles"

# rfd compiles these only for macOS (src/file_dialog.rs:141-155, :293-307),
# an AppKitWindowHandle names a view only there, and the native extension
# reports which platform it was built for.
return unless Ferro::Rfd.const_get(:PLATFORM) == :macos

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: the macOS pickers from rfd 0.17.2
    #   src/file_dialog.rs:141-155, 293-307
    #++

    class FileDialog
      # Asks the user for one file or folder. Returns its path, or +nil+ if
      # the user cancels.
      #
      # Defined only on macOS, whose open panel can offer both at once.
      #
      # Mirrors rfd's <tt>FileDialog::pick_file_or_folder</tt>
      # (<tt>src/file_dialog.rs:141-147</tt>).
      #
      # === Example
      #
      #   target = Ferro::Rfd::FileDialog.new.pick_file_or_folder
      def pick_file_or_folder
        consume("FileDialog#pick_file_or_folder")
        Native.file_dialog(:pick_file_or_folder, settings)
      end

      # Asks the user for one or more files or folders. Returns their
      # paths, or +nil+ if the user cancels.
      #
      # Defined only on macOS.
      #
      # Mirrors rfd's <tt>FileDialog::pick_files_or_folders</tt>
      # (<tt>src/file_dialog.rs:149-155</tt>).
      #
      # === Example
      #
      #   targets = Ferro::Rfd::FileDialog.new.pick_files_or_folders
      def pick_files_or_folders
        consume("FileDialog#pick_files_or_folders")
        Native.file_dialog(:pick_files_or_folders, settings)
      end
    end

    class AsyncFileDialog
      # Starts asking for one file or folder. Returns a Future of a
      # FileHandle, or of +nil+ if the user cancels.
      #
      # Defined only on macOS.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::pick_file_or_folder</tt>
      # (<tt>src/file_dialog.rs:293-299</tt>).
      #
      # === Example
      #
      #   target = Ferro::Rfd::AsyncFileDialog.new.pick_file_or_folder.value
      def pick_file_or_folder
        start(:pick_file_or_folder)
      end

      # Starts asking for one or more files or folders. Returns a Future of
      # an Array of FileHandle objects, or of +nil+ if the user cancels.
      #
      # Defined only on macOS.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::pick_files_or_folders</tt>
      # (<tt>src/file_dialog.rs:301-307</tt>).
      #
      # === Example
      #
      #   targets = Ferro::Rfd::AsyncFileDialog.new.pick_files_or_folders.value
      def pick_files_or_folders
        start(:pick_files_or_folders)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++

    class AppKitWindowHandle
      # raw-window-handle's +Debug+ text for the handle rfd would get,
      # formatted by Rust: <tt>AppKitWindowHandle { ns_view: 0x... }</tt>,
      # the content view of the window this number names. +inspect+ stays
      # Data's.
      #
      # The window is looked up as a dialog's parent is, on the main
      # thread, and the lookup raises what a dialog's would: +ArgumentError+
      # for a number that names none of your app's windows, or a window
      # without a content view, and +ThreadError+ from another thread with
      # no running app. Defined only on macOS: elsewhere no window number
      # names a view.
      #
      # Mirrors raw-window-handle's derived +Debug+ for
      # +AppKitWindowHandle+ (raw-window-handle 0.6.2
      # <tt>src/appkit.rs:87-91</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AppKitWindowHandle.new(window_number: my_window_number).debug
      #   # => "AppKitWindowHandle { ns_view: 0x7f8b4c40a2c0 }"
      def debug
        Native.window_handle_debug(Rfd.__send__(:native_window, self))
      end
    end
  end
end
