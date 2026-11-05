# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require_relative "../tuple_variant"

module Ferro
  module GlobalHotkey
    module Hotkey
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: Apache-2.0 OR MIT
      # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
      # SPDX-SnippetComment: HotKeyParseError and its Display text from
      #   global-hotkey 0.9.0 src/hotkey.rs:38-46
      #++

      # A hotkey's text did not parse.
      #
      # Shortcut text comes from people: a settings file, a preferences
      # field. It can name a key nobody knows, leave a part empty, or put
      # the key before a modifier.
      #
      # HotKey.from_str and HotKey.try_from raise one subclass per way the
      # text can be wrong, each with global-hotkey's message. Each variant
      # carries a String, the part of the text at fault, by position, as
      # Rust does, and answers +debug+ with
      # global-hotkey's +Debug+ text. It is a separate class from Error, as
      # global-hotkey's <tt>hotkey::HotKeyParseError</tt> is a separate
      # type.
      #
      # Mirrors global-hotkey's <tt>hotkey::HotKeyParseError</tt>
      # (<tt>src/hotkey.rs:38-46</tt>).
      #
      # === Example
      #
      #   begin
      #     Ferro::GlobalHotkey::Hotkey::HotKey.from_str(text)
      #   rescue Ferro::GlobalHotkey::Hotkey::HotKeyParseError::UnsupportedKey => e
      #     key, = e.to_a
      #     warn "No such key: #{key}"
      #   rescue Ferro::GlobalHotkey::Hotkey::HotKeyParseError => e
      #     warn "Not a shortcut: #{e.message}"
      #   end
      class HotKeyParseError < StandardError
        # A part names no key global-hotkey knows; the field is that part.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::HotKey.from_str("Shift+Nope")
        #   # raises UnsupportedKey, "Couldn't recognize \"Nope\" as a valid key for hotkey, ...", with ["Nope"]
        class UnsupportedKey < HotKeyParseError
          include TupleVariant
        end

        # A part between two <tt>+</tt> signs is empty; the field is the
        # whole text.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::HotKey.from_str("Shift++KeyA")
        #   # raises EmptyToken, "Found empty token while parsing hotkey: Shift++KeyA", with ["Shift++KeyA"]
        class EmptyToken < HotKeyParseError
          include TupleVariant
        end

        # The text has more than one key, a key before a modifier, or only
        # modifiers; the field is the whole text.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::HotKey.from_str("Shift+Ctrl")
        #   # raises InvalidFormat, "Invalid hotkey format: \"Shift+Ctrl\", ...", with ["Shift+Ctrl"]
        class InvalidFormat < HotKeyParseError
          include TupleVariant
        end
      end

      #--
      # SPDX-SnippetEnd
      #++

      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: 2017 Pyfisch
      # SPDX-SnippetComment: UnrecognizedCodeError and its Display text from
      #   keyboard-types 0.8.3 src/code.rs:940-954
      #++

      # Text that names no Code.
      #
      # Code.from_str turns the W3C name of a key, such as <tt>KeyA</tt>,
      # into its Code, and raises this for any other text, with
      # keyboard-types' message. keyboard-types defines it beside +Code+;
      # global-hotkey does not re-export it, so it sits here beside Code.
      #
      # Mirrors keyboard-types' +UnrecognizedCodeError+
      # (<tt>src/code.rs:940-954</tt>).
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::Hotkey::Code.from_str("A")
      #   # raises UnrecognizedCodeError, "Unrecognized code"
      class UnrecognizedCodeError < StandardError
        # Creates the error. Without a +message+, or with +nil+, the
        # message is keyboard-types'.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::UnrecognizedCodeError.new.message # => "Unrecognized code"
        def initialize(message = nil)
          super(message || "Unrecognized code")
        end

        # keyboard-types' derived +Debug+ text, formatted by Rust: the
        # type's name, as it has no fields (<tt>src/code.rs:946-947</tt>).
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::UnrecognizedCodeError.new.debug # => "UnrecognizedCodeError"
        def debug
          Native.error_debug(GlobalHotkey.__send__(:variant_path, self), nil)
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
