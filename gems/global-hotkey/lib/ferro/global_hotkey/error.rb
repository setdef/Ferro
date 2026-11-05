# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require_relative "tuple_variant"

module Ferro
  module GlobalHotkey
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
    # SPDX-SnippetComment: Error, its variants, and their Display text from
    #   global-hotkey 0.9.0 src/error.rs:9-31
    #++

    # Registering or unregistering a hotkey failed.
    #
    # A global hotkey asks the operating system for a key combination
    # every program shares. The system can refuse: another program holds
    # it, the key has no code on this platform, or the system call itself
    # fails. A single "it failed" would leave you guessing which.
    #
    # Each of global-hotkey's errors is a subclass, named for its variant,
    # with global-hotkey's message. Rescue the one you can handle, or this
    # class for all of them. A variant that carries a value, such as the
    # hotkey another registration holds, gives it as Rust does, by
    # position: <tt>in Error::AlreadyRegistered[hotkey]</tt>.
    # Each variant answers +debug+ with global-hotkey's +Debug+ text, which
    # Rust formats; +inspect+ stays Ruby's.
    #
    # A variant a later global-hotkey adds raises this class itself, with
    # global-hotkey's message, until ferro-global-hotkey names it. So does
    # a panic inside global-hotkey, with the message
    # <tt>global-hotkey panicked: ...</tt>, which would otherwise end the
    # Ruby process. This class itself is no variant, so it has no +debug+.
    #
    # Mirrors global-hotkey's +Error+ (<tt>src/error.rs:9-31</tt>).
    #
    # === Examples
    #
    #   begin
    #     manager.register(hotkey)
    #   rescue Ferro::GlobalHotkey::Error::AlreadyRegistered => e
    #     taken, = e.to_a
    #     warn "#{taken} is taken"
    #   rescue Ferro::GlobalHotkey::Error => e
    #     warn "No hotkey: #{e.message}"
    #   end
    class Error < StandardError
      # The operating system refused a call, with its own description,
      # such as Windows' when the hidden window that receives hotkeys
      # could not be made.
      #
      # The variant's field is the +io::Error+ the call failed with, as a
      # Ruby value: on Unix, the +SystemCallError+ (an +Errno+ class) of
      # its OS error code; otherwise an +IOError+ with Rust's text, as
      # ferro-rfd and ferro-url give theirs. global-hotkey's variant is
      # <tt>#[error(transparent)]</tt>, so the error has no cause.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::OsError => e
      #     warn e.message # => "Access is denied. (os error 5)"
      #     io_error, = e.to_a
      class OsError < Error
        include TupleVariant

        # The OS error code global-hotkey's +io::Error+ had, kept for
        # +debug+, since a Windows +IOError+ does not carry it.
        private attr_writer :raw_os_error

        # The +io::Error+ as the native layer rebuilds it: its OS error
        # code, if it has one, and its text.
        private def native_field
          io_error = @field
          if io_error.is_a?(SystemCallError)
            [@raw_os_error || io_error.errno, io_error.message]
          elsif io_error.is_a?(IOError)
            [@raw_os_error, io_error.message]
          else
            [@raw_os_error, nil]
          end
        end
      end

      # A hotkey did not parse. global-hotkey 0.9.0 never raises it:
      # Hotkey::HotKey.from_str raises Hotkey::HotKeyParseError instead.
      # The class exists because global-hotkey's +Error+ has the variant,
      # whose field is a String, the message.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::HotKeyParseError.new("bad hotkey", "bad hotkey")
      class HotKeyParseError < Error
        include TupleVariant
      end

      # A key name global-hotkey did not recognize. global-hotkey 0.9.0
      # never raises it; the class exists because +Error+ has the variant,
      # whose field is a String, the name.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::UnrecognizedHotKeyCode, "no such key"
      class UnrecognizedHotKeyCode < Error
        include TupleVariant
      end

      # An empty part in a hotkey's text. global-hotkey 0.9.0 never raises
      # it; the class exists because +Error+ has the variant, whose field
      # is a String, the text.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::EmptyHotKeyToken, "empty token"
      class EmptyHotKeyToken < Error
        include TupleVariant
      end

      # A hotkey's text in the wrong shape. global-hotkey 0.9.0 never
      # raises it; the class exists because +Error+ has the variant, whose
      # field is a String, the text.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::UnexpectedHotKeyFormat, "wrong shape"
      class UnexpectedHotKeyFormat < Error
        include TupleVariant
      end

      # The system would not register the hotkey. The message is
      # <tt>Unable to register hotkey: </tt> and the reason, the variant's
      # String field, such as <tt>Unknown scancode for F24</tt> for a key
      # macOS has no code for, or <tt>Unable to find keycode for key:
      # F24</tt> for a key the X server's keymap lacks.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::FailedToRegister => e
      #     e.message # => "Unable to register hotkey: Unknown scancode for F24"
      #     e.to_a # => ["Unknown scancode for F24"]
      class FailedToRegister < Error
        include TupleVariant
      end

      # The system would not unregister the hotkey, the variant's field, a
      # Hotkey::HotKey.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::FailedToUnRegister => e
      #     hotkey, = e.to_a
      #     warn "#{hotkey} stays registered"
      class FailedToUnRegister < Error
        include TupleVariant
      end

      # Another registration holds the hotkey, the variant's field, a
      # Hotkey::HotKey: another program's on Windows and Linux, or this
      # manager's own.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::AlreadyRegistered => e
      #     hotkey, = e.to_a
      #     warn "#{hotkey} is taken"
      class AlreadyRegistered < Error
        include TupleVariant
      end

      # macOS would not let global-hotkey watch the media keys
      # (+MediaPlayPause+ and the rest), which it reads through an event
      # tap that needs the Accessibility permission.
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::Error::FailedToWatchMediaKeyEvent.new.message
      #   # => "Failed to watch media key event"
      class FailedToWatchMediaKeyEvent < Error
        # Creates the error. Without a +message+, or with +nil+, the
        # message is global-hotkey's.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Error::FailedToWatchMediaKeyEvent.new
        def initialize(message = nil)
          super(message || "Failed to watch media key event")
        end

        # global-hotkey's +Debug+ text for this variant, formatted by
        # Rust: its name.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Error::FailedToWatchMediaKeyEvent.new.debug # => "FailedToWatchMediaKeyEvent"
        def debug
          Native.error_debug(GlobalHotkey.__send__(:variant_path, self), nil)
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
