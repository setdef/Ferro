# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

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
    # class for all of them.
    #
    # A variant a later global-hotkey adds raises this class itself, with
    # global-hotkey's message, until ferro-global-hotkey names it. So does
    # a panic inside global-hotkey, with the message
    # <tt>global-hotkey panicked: ...</tt>, which would otherwise end the
    # Ruby process.
    #
    # Mirrors global-hotkey's +Error+ (<tt>src/error.rs:9-31</tt>).
    #
    # === Examples
    #
    #   begin
    #     manager.register(hotkey)
    #   rescue Ferro::GlobalHotkey::Error::AlreadyRegistered => e
    #     warn "#{e.hotkey} is taken"
    #   rescue Ferro::GlobalHotkey::Error => e
    #     warn "No hotkey: #{e.message}"
    #   end
    class Error < StandardError
      # The operating system refused a call, with its own description,
      # such as Windows' when the hidden window that receives hotkeys
      # could not be made.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::OsError => e
      #     warn e.message # => "Access is denied. (os error 5)"
      class OsError < Error
      end

      # A hotkey did not parse. global-hotkey 0.9.0 never raises it:
      # Hotkey::HotKey.from_str raises Hotkey::HotKeyParseError instead.
      # The class exists because global-hotkey's +Error+ has the variant.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::HotKeyParseError, "bad hotkey"
      class HotKeyParseError < Error
      end

      # A key name global-hotkey did not recognize. global-hotkey 0.9.0
      # never raises it; the class exists because +Error+ has the variant.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::UnrecognizedHotKeyCode, "no such key"
      class UnrecognizedHotKeyCode < Error
      end

      # An empty part in a hotkey's text. global-hotkey 0.9.0 never raises
      # it; the class exists because +Error+ has the variant.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::EmptyHotKeyToken, "empty token"
      class EmptyHotKeyToken < Error
      end

      # A hotkey's text in the wrong shape. global-hotkey 0.9.0 never
      # raises it; the class exists because +Error+ has the variant.
      #
      # === Example
      #
      #   raise Ferro::GlobalHotkey::Error::UnexpectedHotKeyFormat, "wrong shape"
      class UnexpectedHotKeyFormat < Error
      end

      # The system would not register the hotkey. The message is
      # <tt>Unable to register hotkey: </tt> and the reason, such as
      # <tt>Unknown scancode for F24</tt> for a key macOS has no code for,
      # or <tt>Unable to find keycode for key: F24</tt> for a key the X
      # server's keymap lacks.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::FailedToRegister => e
      #     warn e.message # => "Unable to register hotkey: Unknown scancode for F24"
      class FailedToRegister < Error
      end

      # The system would not unregister the hotkey, which #hotkey holds.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::FailedToUnRegister => e
      #     warn "#{e.hotkey} stays registered"
      class FailedToUnRegister < Error
        # The Hotkey::HotKey global-hotkey could not unregister, or +nil+.
        attr_reader :hotkey

        # Creates the error.
        #
        # [message] String, global-hotkey's message.
        # [hotkey] Hotkey::HotKey, the hotkey, or +nil+.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Error::FailedToUnRegister.new("Failed to unregister hotkey", hotkey).hotkey
        def initialize(message = nil, hotkey = nil)
          @hotkey = hotkey
          super(message)
        end
      end

      # Another registration holds the hotkey, which #hotkey holds: another
      # program's on Windows and Linux, or this manager's own.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::Error::AlreadyRegistered => e
      #     warn "#{e.hotkey} is taken"
      class AlreadyRegistered < Error
        # The Hotkey::HotKey already registered, or +nil+.
        attr_reader :hotkey

        # Creates the error.
        #
        # [message] String, global-hotkey's message.
        # [hotkey] Hotkey::HotKey, the hotkey, or +nil+.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Error::AlreadyRegistered.new("HotKey already registered", hotkey).hotkey
        def initialize(message = nil, hotkey = nil)
          @hotkey = hotkey
          super(message)
        end
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
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
