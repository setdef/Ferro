# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"
require_relative "error"
require_relative "file_handle"
require_relative "message_dialog_result"

module Ferro
  module Rfd
    # A dialog's answer, or a file's contents, that arrives later.
    #
    # rfd's async methods return Rust futures: values that finish while
    # your program does something else, and that you +await+. Ruby has no
    # futures to await, and blocking at once would lose what async is for.
    # On macOS, a sheet opened on the main thread finishes only while that
    # thread keeps running its event loop.
    #
    # This object holds rfd's future as rfd made it. #value waits for it,
    # as <tt>.await</tt> does, and returns what it finished with. Methods
    # that return one: AsyncFileDialog's terminal methods,
    # AsyncMessageDialog#show, FileHandle#read, and FileHandle#write.
    #
    # Use it to start a dialog from your event loop and collect the answer
    # on another thread, or to read a picked file without blocking.
    #
    # === Behavior
    #
    # Like <tt>Thread#value</tt>, #value returns the same value, or raises
    # the same exception, every time, and one thread waits at a time.
    # Waiting releases Ruby's global VM lock, and an interrupt (Ctrl-C,
    # <tt>Thread#raise</tt>, +Timeout+) ends the wait without closing the
    # dialog; call #value again to keep waiting.
    #
    # Nothing waits for a Future you drop. On Windows and Linux its dialog
    # never opens unless #value runs; on macOS a sheet already open stays
    # open until the user closes it.
    #
    # Mirrors the <tt>impl Future</tt> rfd's async methods return
    # (rfd 0.17.2 <tt>src/backend.rs:88-92</tt>).
    #
    # === Examples
    #
    #   future = Ferro::Rfd::AsyncMessageDialog.new.set_description("Done!").show
    #   future.value # => Ferro::Rfd::MessageDialogResult::Ok
    #
    #   file = Ferro::Rfd::AsyncFileDialog.new.pick_file.value
    #   contents = file&.read&.value
    class Future
      private_class_method :new

      # Wraps rfd's future, which the native layer holds.
      #
      # [native] The native layer's future.
      def initialize(native)
        @native = native
        @lock = Thread::Mutex.new
        @done = false
        @value = nil
        @error = nil
      end

      # Waits for the future and returns what it finished with: a
      # FileHandle, an Array of them, or +nil+ for a file dialog; a
      # MessageDialogResult for a message dialog; a binary String for
      # FileHandle#read; +nil+ for FileHandle#write.
      #
      # Raises what the work raised: Error for a panic inside rfd (such as
      # FileHandle#read of a file that cannot be read), or a
      # +SystemCallError+ or +IOError+ for FileHandle#write. On macOS,
      # waiting on the main thread for a sheet raises Error at once, since
      # the sheet finishes on that thread's event loop.
      #
      # === Example
      #
      #   result = Ferro::Rfd::AsyncMessageDialog.new.set_title("Hi").show.value
      def value
        @lock.synchronize { settle unless @done }
        error = @error
        raise error if error

        @value
      end

      # Waits for the native layer's tagged outcome and keeps it.
      private def settle
        tag, payload = @native.__send__(:native_value)
        case tag
        when :handle then @value = payload && FileHandle.new(payload)
        when :handles then @value = payload&.map { |path| FileHandle.new(path) }
        when :result then @value = MessageDialogResult.__send__(:from_native, payload)
        when :raise then @error = payload
        else @value = payload
        end
        @done = true
      end
    end
  end
end
