# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "file_dialog"
require_relative "future"

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: AsyncFileDialog and its docs from rfd 0.17.2
    #   src/file_dialog.rs:177-331, src/lib.rs:79-86, examples/async.rs
    #++

    # A file dialog you start now and wait for later.
    #
    # A windowed app runs an event loop on its main thread, and a dialog
    # that blocks that thread freezes every window until the user answers.
    # On macOS it is worse: the main thread is the only one that may run a
    # dialog, and a sheet, the dialog that slides out of a window, finishes
    # on that thread's event loop.
    #
    # This builder takes the same options as FileDialog, but its terminal
    # methods return a Future at once. On macOS, call one on the main thread
    # while your app's event loop runs: rfd opens the dialog as a sheet on
    # your window (the one you pass to #set_parent, or the app's main
    # window), returns, and your loop keeps running. Wait for the Future on
    # another thread. That is the pattern rfd recommends. Elsewhere, the
    # dialog opens when you first call Future#value, on a thread of rfd's
    # own.
    #
    # Use it in a GUI app that must keep drawing while the user picks a
    # file.
    #
    # === Behavior
    #
    # On macOS, without a running application or without any window, rfd
    # prints a note to standard error and shows an ordinary modal dialog
    # instead, there and then: the terminal method waits for the user (with
    # Ruby's global VM lock released) and returns a Future that is already
    # finished. Off the main thread that is impossible, and the terminal
    # method raises Error, with rfd's message, instead of letting rfd
    # panic. Future#value on the main thread refuses to wait for a sheet,
    # which would never finish.
    #
    # Results are FileHandle objects rather than path Strings. The options
    # behave as FileDialog's do; see each method there.
    #
    # Mirrors rfd's +AsyncFileDialog+ (<tt>src/file_dialog.rs:177-331</tt>),
    # which wraps a +FileDialog+ as this one does.
    #
    # === Examples
    #
    #   # On the main thread, inside your event loop's handler:
    #   future = Ferro::Rfd::AsyncFileDialog.new.add_filter("text", ["txt"]).pick_file
    #
    #   # Anywhere else:
    #   Thread.new do
    #     file = future.value
    #     puts file.path if file
    #   end
    #
    #   # Without an event loop, waiting at once is fine (on macOS, from the
    #   # main thread):
    #   handle = Ferro::Rfd::AsyncFileDialog.new.pick_folder.value
    class AsyncFileDialog
      # Creates a dialog with rfd's defaults, as FileDialog.new does.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::new</tt>
      # (<tt>src/file_dialog.rs:188-191</tt>).
      #
      # === Example
      #
      #   dialog = Ferro::Rfd::AsyncFileDialog.new
      def initialize
        @file_dialog = FileDialog.new
      end

      # Adds a file type filter. Returns the dialog. See
      # FileDialog#add_filter.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::add_filter</tt>
      # (<tt>src/file_dialog.rs:193-205</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.add_filter("Images", ["png", "jpg"])
      def add_filter(name, extensions)
        @file_dialog = @file_dialog.dup.add_filter(name, extensions)
        self
      end

      # Starts the dialog in +path+. Returns the dialog. See
      # FileDialog#set_directory.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::set_directory</tt>
      # (<tt>src/file_dialog.rs:207-214</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.set_directory(Dir.home)
      def set_directory(path)
        @file_dialog = @file_dialog.dup.set_directory(path)
        self
      end

      # Fills in +file_name+ as the starting file name. Returns the dialog.
      # See FileDialog#set_file_name.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::set_file_name</tt>
      # (<tt>src/file_dialog.rs:216-224</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.set_file_name("notes.txt")
      def set_file_name(file_name)
        @file_dialog = @file_dialog.dup.set_file_name(file_name)
        self
      end

      # Titles the dialog +title+. Returns the dialog. See
      # FileDialog#set_title.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::set_title</tt>
      # (<tt>src/file_dialog.rs:226-234</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.set_title("Open a log")
      def set_title(title)
        @file_dialog = @file_dialog.dup.set_title(title)
        self
      end

      # Keeps the dialog in front of +parent+'s window. Returns the dialog.
      # See FileDialog#set_parent for what +parent+ answers and which
      # handles each platform takes.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::set_parent</tt>
      # (<tt>src/file_dialog.rs:236-247</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.set_parent(window)
      def set_parent(parent)
        @file_dialog = @file_dialog.dup.set_parent(parent)
        self
      end

      # Lets the user create folders, or forbids it. Returns the dialog.
      # See FileDialog#set_can_create_directories.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::set_can_create_directories</tt>
      # (<tt>src/file_dialog.rs:249-254</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.set_can_create_directories(true)
      def set_can_create_directories(can)
        @file_dialog = @file_dialog.dup.set_can_create_directories(can)
        self
      end

      # Starts asking for one file. Returns a Future of a FileHandle, or of
      # +nil+ if the user cancels.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::pick_file</tt>
      # (<tt>src/file_dialog.rs:267-270</tt>).
      #
      # === Example
      #
      #   file = Ferro::Rfd::AsyncFileDialog.new.pick_file.value
      def pick_file
        start(:pick_file)
      end

      # Starts asking for one or more files. Returns a Future of an Array
      # of FileHandle objects, or of +nil+ if the user cancels.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::pick_files</tt>
      # (<tt>src/file_dialog.rs:272-275</tt>).
      #
      # === Example
      #
      #   files = Ferro::Rfd::AsyncFileDialog.new.pick_files.value
      def pick_files
        start(:pick_files)
      end

      # Starts asking for one folder. Returns a Future of a FileHandle, or
      # of +nil+ if the user cancels.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::pick_folder</tt>
      # (<tt>src/file_dialog.rs:277-283</tt>).
      #
      # === Example
      #
      #   folder = Ferro::Rfd::AsyncFileDialog.new.pick_folder.value
      def pick_folder
        start(:pick_folder)
      end

      # Starts asking for one or more folders. Returns a Future of an Array
      # of FileHandle objects, or of +nil+ if the user cancels.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::pick_folders</tt>
      # (<tt>src/file_dialog.rs:285-291</tt>).
      #
      # === Example
      #
      #   folders = Ferro::Rfd::AsyncFileDialog.new.pick_folders.value
      def pick_folders
        start(:pick_folders)
      end

      # Starts asking where to save a file. Returns a Future of a
      # FileHandle, or of +nil+ if the user cancels. FileDialog#save_file
      # describes how each platform treats filters here.
      #
      # Mirrors rfd's <tt>AsyncFileDialog::save_file</tt>
      # (<tt>src/file_dialog.rs:309-330</tt>).
      #
      # === Example
      #
      #   file = Ferro::Rfd::AsyncFileDialog.new.set_file_name("out.txt").save_file.value
      #   file&.write("hello").value
      def save_file
        start(:save_file)
      end

      # rfd's +Debug+ text for this dialog. On macOS, with an
      # AppKitWindowHandle parent, it looks the window up as the dialog
      # would, and from another thread waits for the main thread's run
      # loop, uninterruptibly (FileDialog#set_parent).
      #
      # === Example
      #
      #   Ferro::Rfd::AsyncFileDialog.new.inspect
      #   # => "AsyncFileDialog { file_dialog: FileDialog { filters: [], ... } }"
      def inspect
        Native.async_file_dialog_debug(@file_dialog.__send__(:settings))
      end

      # Starts rfd's +call+ and wraps its future.
      private def start(call)
        Future.__send__(:new, Native.async_file_dialog(call, @file_dialog.__send__(:settings)))
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
