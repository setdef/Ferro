# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "file_dialog"
require_relative "async_file_dialog"

# rfd compiles these only for macOS (src/file_dialog.rs:141-155, :293-307),
# and the native extension reports which platform it was built for.
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
  end
end
