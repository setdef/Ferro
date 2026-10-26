# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

module Ferro
  module GlobalHotkey
    module Hotkey
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: Apache-2.0 OR MIT
      # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
      # SPDX-SnippetComment: HotKey, its methods, and their docs from
      #   global-hotkey 0.9.0 src/hotkey.rs:48-168
      #++

      # A keyboard shortcut that consists of an optional combination of
      # modifier keys (Modifiers) and one key (Code).
      #
      # A global shortcut has to be the same thing in three places: the
      # call that registers it, the event that reports it, and the
      # settings text that names it. Matching those by hand means comparing
      # modifier bits and key codes, and agreeing on an id.
      #
      # A HotKey is that shortcut as one value. HotKey.new computes its
      # #id from the modifiers and key, so every GlobalHotKeyEvent for it
      # carries the same id; HotKey.from_str parses text such as
      # <tt>"shift+alt+KeyQ"</tt>, and #to_s writes it back.
      #
      # Its three fields are public in global-hotkey, so a Rust struct
      # literal can set any id; HotKey.new with an +id+ is that literal,
      # and #with is Rust's struct update syntax. Every
      # method that reaches global-hotkey rebuilds the Rust value from the
      # three fields.
      #
      # Mirrors global-hotkey's <tt>hotkey::HotKey</tt>
      # (<tt>src/hotkey.rs:48-168</tt>).
      #
      # === Examples
      #
      #   hotkey = Ferro::GlobalHotkey::Hotkey
      #   quit = hotkey::HotKey.new(hotkey::Modifiers::SHIFT, hotkey::Code::KeyQ)
      #   quit.to_s # => "shift+KeyQ"
      #   quit == hotkey::HotKey.from_str("Shift+KeyQ") # => true
      #
      #   hotkey::HotKey.new(nil, hotkey::Code::KeyQ).mods.is_empty # => true
      #
      #   # A struct literal, with an id of your own:
      #   hotkey::HotKey.new(mods: hotkey::Modifiers::ALT, key: hotkey::Code::F19, id: 1)
      class HotKey < Data.define(:mods, :key, :id)
        # :attr_reader: mods
        # The hotkey modifiers, a Modifiers.

        # :attr_reader: key
        # The hotkey key, a Code.

        # :attr_reader: id
        # The hotkey id, an Integer (a +u32+): the modifiers' bits shifted
        # left 16 bits, ORed with the key's place in Code's order, for a
        # hotkey HotKey.new or HotKey.from_str made. Every event for this
        # hotkey carries it. Mirrors <tt>HotKey::id</tt>.

        class << self
          # Creates a new hotkey to define keyboard shortcuts throughout your
          # application. Only Modifiers::ALT, Modifiers::SHIFT,
          # Modifiers::CONTROL, and Modifiers::META count; the deprecated
          # Modifiers::SUPER becomes META.
          #
          # Without an +id+, this is global-hotkey's <tt>HotKey::new</tt>
          # (<tt>src/hotkey.rs:84-101</tt>), which computes the id and turns
          # SUPER into META. With an +id+, it is the Rust struct literal,
          # which keeps every field as given.
          #
          # Pass the three fields positionally, <tt>(mods, key, id)</tt>, or
          # by keyword, <tt>(mods:, key:, id:)</tt>, not both.
          #
          # [mods] Modifiers, or +nil+ for none when there is no +id+.
          # [key] Code.
          # [id] Integer, a +u32+, or +nil+ to compute it.
          #
          # === Examples
          #
          #   hotkey = Ferro::GlobalHotkey::Hotkey
          #   hotkey::HotKey.new(hotkey::Modifiers::CONTROL, hotkey::Code::Space).id # => 524350
          #   hotkey::HotKey.new(mods: hotkey::Modifiers::ALT, key: hotkey::Code::F19, id: 1).id # => 1
          def new(given_mods = nil, given_key = nil, given_id = nil, mods: nil, key: nil, id: nil)
            if [given_mods, given_key, given_id].any?
              raise ArgumentError, "pass a hotkey's fields positionally or by keyword, not both" if mods || key || id

              mods = given_mods
              key = given_key
              id = given_id
            end
            return literal(mods, key, id) if id

            unless mods.nil? || mods.is_a?(Modifiers)
              raise TypeError, "wrong argument type #{mods.class} (expected #{Modifiers})"
            end
            raise TypeError, "wrong argument type #{key.class} (expected #{Code})" unless key.is_a?(Code)

            bits, _, id = GlobalHotkey.__send__(:settle, Native.hotkey_new(mods&.bits, key.to_s))
            literal(Modifiers.from_bits_retain(bits), key, id)
          end

          # Parses +string+ as global-hotkey's +FromStr+ does: modifiers
          # first, then one key, joined by <tt>+</tt>, any case. Modifiers
          # are +Shift+, +Control+ or +Ctrl+, +Alt+ or +Option+, +Super+,
          # +Meta+, +Command+ or +Cmd+, and +CommandOrControl+ (or
          # +CmdOrCtrl+ and the other spellings), which is META on macOS
          # and CONTROL elsewhere. A key is a Code's name, a single
          # character such as <tt>a</tt> or <tt>5</tt>, or a common name
          # such as +Esc+ or +Up+. Raises a HotKeyParseError subclass.
          #
          # Mirrors <tt>FromStr for HotKey</tt>
          # (<tt>src/hotkey.rs:147-233</tt>).
          #
          # [string] String.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::HotKey.from_str("CmdOrCtrl+Shift+K").to_s
          #   # => "shift+control+KeyK" on Windows and Linux
          def from_str(string)
            from_parts(GlobalHotkey.__send__(:settle, Native.hotkey_parse(string)))
          end

          # Parses +value+ as from_str does. Mirrors global-hotkey's
          # <tt>TryFrom<&str></tt> and <tt>TryFrom<String></tt>
          # (<tt>src/hotkey.rs:154-168</tt>).
          #
          # [value] String.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::HotKey.try_from("alt+F19").to_s # => "alt+F19"
          def try_from(value)
            from_str(value)
          end

          # The Rust struct literal: Data's own construction, which keeps
          # the three fields as given and freezes the value. +new+ replaces
          # Data's constructor, so this builds the value the way Data's
          # does, through its +initialize+. A field of the wrong type raises
          # +TypeError+, and an id outside a +u32+ +RangeError+, as the Rust
          # literal would not compile.
          def literal(mods, key, id) # :nodoc:
            raise TypeError, "wrong argument type #{mods.class} (expected #{Modifiers})" unless mods.is_a?(Modifiers)
            raise TypeError, "wrong argument type #{key.class} (expected #{Code})" unless key.is_a?(Code)

            id = Native.u32(id)
            # @type var hotkey: HotKey
            hotkey = allocate
            hotkey.__send__(:initialize, mods:, key:, id:)
            hotkey
          end
          private :literal

          # The hotkey a native <tt>[bits, key name, id]</tt> describes.
          def from_parts(parts) # :nodoc:
            bits, key, id = parts
            new(mods: Modifiers.from_bits_retain(bits), key: Code.from_str(key), id:)
          end
          private :from_parts
        end

        # Whether +modifiers+ and +key+ match this hotkey. Only Shift,
        # Control, Alt, and Meta in +modifiers+ count, so a pressed Caps
        # Lock still matches. Mirrors <tt>HotKey::matches</tt>
        # (<tt>src/hotkey.rs:109-116</tt>).
        #
        # [modifiers] Modifiers.
        # [key] Code.
        #
        # === Example
        #
        #   hotkey = Ferro::GlobalHotkey::Hotkey
        #   shift_q = hotkey::HotKey.from_str("shift+KeyQ")
        #   shift_q.matches(hotkey::Modifiers::SHIFT | hotkey::Modifiers::CAPS_LOCK, hotkey::Code::KeyQ) # => true
        def matches(modifiers, key)
          raise TypeError, "wrong argument type #{modifiers.class} (expected #{Modifiers})" unless modifiers.is_a?(Modifiers)
          raise TypeError, "wrong argument type #{key.class} (expected #{Code})" unless key.is_a?(Code)

          GlobalHotkey.__send__(:settle,
            Native.hotkey_matches(GlobalHotkey.__send__(:parts, self), modifiers.bits, key.to_s))
        end

        # Converts this hotkey into a string: the modifiers in the order
        # <tt>shift+</tt>, <tt>control+</tt>, <tt>alt+</tt>, <tt>meta+</tt>,
        # then the key's name. HotKey.from_str reads it back. Mirrors
        # <tt>HotKey::into_string</tt> (<tt>src/hotkey.rs:118-135</tt>).
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::HotKey.from_str("Alt+Shift+F19").into_string # => "shift+alt+F19"
        def into_string
          GlobalHotkey.__send__(:settle, Native.hotkey_into_string(GlobalHotkey.__send__(:parts, self)))
        end

        # The same text as #into_string, global-hotkey's +Display+
        # (<tt>src/hotkey.rs:138-142</tt>).
        #
        # === Example
        #
        #   "#{Ferro::GlobalHotkey::Hotkey::HotKey.from_str("ctrl+F19")}" # => "control+F19"
        def to_s
          into_string
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
