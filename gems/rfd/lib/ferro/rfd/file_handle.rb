# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: FileHandle and its docs from rfd 0.17.2
    #   src/file_handle/mod.rs:1-6, src/file_handle/native.rs:112-195
    #++

    # A file an async dialog returned.
    #
    # In a browser, a file the user picks is an object you can read but
    # whose path you never learn. rfd's async API returns the same kind of
    # handle everywhere, so code written for the browser runs on the
    # desktop too. On the desktop, where Ruby runs, the handle just wraps
    # the file's path.
    #
    # Use #path, or pass the handle straight to Ruby's file methods (it
    # answers #to_path). #read and #write exist, as rfd says, "solely to
    # keep native api in pair with async only web api": each runs on a
    # thread rfd starts and returns a Future.
    #
    # A handle is frozen, so Ractors may share it.
    #
    # Mirrors rfd's +FileHandle+ (<tt>src/file_handle/native.rs:112-195</tt>).
    #
    # === Examples
    #
    #   file = Ferro::Rfd::AsyncFileDialog.new.pick_file.value
    #   if file
    #     puts file.file_name
    #     text = File.read(file)
    #   end
    #
    #   handle = Ferro::Rfd::FileHandle.new("notes.txt")
    #   handle.write("hello").value
    #   handle.read.value # => "hello"
    class FileHandle
      # Wraps +path+, a String or an object with +to_path+.
      #
      # Mirrors rfd's <tt>From<PathBuf> for FileHandle</tt>
      # (<tt>src/file_handle/native.rs:179-183</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileHandle.new("/etc/hosts").file_name # => "hosts"
      def initialize(path)
        @path = -File.path(path)
        freeze
      end

      # The file's name, without its directory. Empty when the path has no
      # final component or the name is not valid UTF-8.
      #
      # Mirrors rfd's <tt>FileHandle::file_name</tt>
      # (<tt>src/file_handle/native.rs:124-131</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileHandle.new("/tmp/report.csv").file_name # => "report.csv"
      def file_name
        Native.file_name(@path)
      end

      # The file's path.
      #
      # Mirrors rfd's <tt>FileHandle::path</tt>
      # (<tt>src/file_handle/native.rs:133-138</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileHandle.new("/tmp/report.csv").path # => "/tmp/report.csv"
      def path
        @path
      end

      # The file's path, as rfd's +file-handle-inner+ feature returns it
      # for code that reads the file itself. The same as #path.
      #
      # Mirrors rfd's <tt>FileHandle::inner</tt>
      # (<tt>src/file_handle/native.rs:158-170</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileHandle.new("/tmp/report.csv").inner # => "/tmp/report.csv"
      def inner
        @path
      end

      # Starts reading the whole file. Returns a Future of its bytes, a
      # binary String.
      #
      # rfd reads on a thread of its own and unwraps the result, so a file
      # that cannot be read panics inside rfd; Future#value raises that as
      # Error (<tt>rfd panicked: ...</tt>).
      #
      # Mirrors rfd's <tt>FileHandle::read</tt>
      # (<tt>src/file_handle/native.rs:140-147</tt>).
      #
      # === Example
      #
      #   bytes = Ferro::Rfd::FileHandle.new("photo.png").read.value
      def read
        Future.__send__(:new, Native.read(@path))
      end

      # Starts writing +data+, a String, to the file, replacing it. Returns
      # a Future that finishes with +nil+.
      #
      # A failed write raises from Future#value: on Unix, the +Errno+
      # class for the system's error, naming the path, as Ruby's own file
      # methods do; on Windows, whose error codes are not errno values,
      # +IOError+ with Rust's message.
      #
      # Mirrors rfd's <tt>FileHandle::write</tt>
      # (<tt>src/file_handle/native.rs:149-156</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::FileHandle.new("out.txt").write("hello\n").value
      def write(data)
        Future.__send__(:new, Native.write(@path, Rfd.__send__(:bytes, data)))
      end

      # rfd's +Debug+ text: the path, quoted.
      #
      # === Example
      #
      #   Ferro::Rfd::FileHandle.new("/tmp/x").inspect # => "\"/tmp/x\""
      def inspect
        Native.file_handle_debug(@path)
      end

      # The file's path, so <tt>File.read(handle)</tt> and other methods
      # that take a path accept the handle.
      #
      # Mirrors rfd's <tt>From<FileHandle> for PathBuf</tt>
      # (<tt>src/file_handle/native.rs:185-195</tt>).
      #
      # === Example
      #
      #   File.exist?(Ferro::Rfd::FileHandle.new("/etc/hosts")) # => true
      def to_path
        @path
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
