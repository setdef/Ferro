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
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: 2017 Pyfisch
      # SPDX-SnippetComment: Modifiers, its flags, and its docs from
      #   keyboard-types 0.8.3 src/modifiers.rs:1-55
      #++

      # Pressed modifier keys.
      #
      # Modifier keys like Shift and Control alter the character value and
      # are used in keyboard shortcuts. A shortcut holds a set of them, and
      # a set of on-off flags is easy to get wrong as a bare Integer: which
      # bit is Alt, and which bits mean nothing at all?
      #
      # This value is that set, as keyboard-types defines it after the W3C
      # specification (https://w3c.github.io/uievents-key/#keys-modifier).
      # Use the constants to match for combinations of the modifier keys,
      # and combine them with <tt>|</tt>. A hotkey uses only ALT, SHIFT,
      # CONTROL, and META; HotKey.new turns the deprecated SUPER into META.
      #
      # The methods are the ones bitflags gives keyboard-types' type, with
      # the same names and meanings. A Modifiers is frozen, so the methods
      # that change a Rust value in place (+insert+, +remove+, +toggle+,
      # +set+, and <tt>|=</tt> and the other assignment operators) are not
      # here: <tt>|</tt>, <tt>-</tt>, and <tt>^</tt> return the same
      # result as a new value. Rust's <tt>!flags</tt> is <tt>~flags</tt>,
      # since Ruby's <tt>!</tt> answers true or false.
      #
      # Mirrors keyboard-types' +Modifiers+ (<tt>src/modifiers.rs:8-55</tt>)
      # and the methods bitflags 2.13.2 generates for it
      # (<tt>src/public.rs</tt>).
      #
      # === Examples
      #
      #   mods = Ferro::GlobalHotkey::Hotkey::Modifiers
      #   both = mods::SHIFT | mods::CONTROL
      #   both.contains(mods::SHIFT) # => true
      #   both.inspect # => "Ferro::GlobalHotkey::Hotkey::Modifiers(CONTROL | SHIFT)"
      #   (both - mods::SHIFT) == mods::CONTROL # => true
      #   mods.from_bits(0x8) # => mods::CONTROL
      class Modifiers
        include Comparable

        private_class_method :new

        # The flags as an Integer, a +u32+.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::Modifiers::SHIFT.bits # => 512
        attr_reader :bits

        # Creates the value holding +bits+.
        #
        # [bits] Integer, a +u32+; anything else raises +RangeError+ or
        #   +TypeError+.
        def initialize(bits)
          @bits = Native.u32(bits)
          freeze
        end

        # An Alt key, or Option on a Mac.
        ALT = new(0x01)

        # The AltGr key.
        ALT_GRAPH = new(0x2)

        # Caps Lock, when it is on.
        CAPS_LOCK = new(0x4)

        # A Control key.
        CONTROL = new(0x8)

        # The Fn key.
        FN = new(0x10)

        # Fn Lock, when it is on.
        FN_LOCK = new(0x20)

        # A Meta key: Command on a Mac, the Windows key on Windows, often
        # called Super on Linux.
        META = new(0x40)

        # Num Lock, when it is on.
        NUM_LOCK = new(0x80)

        # Scroll Lock, when it is on.
        SCROLL_LOCK = new(0x100)

        # A Shift key.
        SHIFT = new(0x200)

        # The Symbol key.
        SYMBOL = new(0x400)

        # Symbol Lock, when it is on.
        SYMBOL_LOCK = new(0x800)

        # Hyper. Deprecated: marked as legacy in the spec, use META instead.
        HYPER = new(0x1000)

        # Super. Deprecated: marked as legacy in the spec, use META instead.
        SUPER = new(0x2000)

        # Every flag, by name, in declaration order, as bitflags lists them.
        FLAGS = {
          "ALT" => ALT,
          "ALT_GRAPH" => ALT_GRAPH,
          "CAPS_LOCK" => CAPS_LOCK,
          "CONTROL" => CONTROL,
          "FN" => FN,
          "FN_LOCK" => FN_LOCK,
          "META" => META,
          "NUM_LOCK" => NUM_LOCK,
          "SCROLL_LOCK" => SCROLL_LOCK,
          "SHIFT" => SHIFT,
          "SYMBOL" => SYMBOL,
          "SYMBOL_LOCK" => SYMBOL_LOCK,
          "HYPER" => HYPER,
          "SUPER" => SUPER,
        }.freeze
        private_constant :FLAGS

        # Every known bit.
        ALL_BITS = FLAGS.each_value.sum(&:bits)
        private_constant :ALL_BITS

        deprecate_constant :HYPER, :SUPER

        class << self
          # No flags. Mirrors bitflags' +empty+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.empty.bits # => 0
          def empty
            new(0)
          end

          # Every known flag. Mirrors bitflags' +all+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.all.bits # => 16383
          def all
            new(ALL_BITS)
          end

          # No flags, keyboard-types' derived +Default+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.default == Ferro::GlobalHotkey::Hotkey::Modifiers.empty # => true
          def default
            empty
          end

          # The value for +bits+, or +nil+ if any bit names no flag.
          # Mirrors bitflags' +from_bits+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.from_bits(0x10000) # => nil
          def from_bits(bits)
            value = new(bits)
            value if value.bits.nobits?(~ALL_BITS)
          end

          # The value for +bits+, dropping any bit that names no flag.
          # Mirrors bitflags' +from_bits_truncate+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.from_bits_truncate(0x10008).bits # => 8
          def from_bits_truncate(bits)
            new(new(bits).bits & ALL_BITS)
          end

          # The value for +bits+, keeping every bit, known or not. Mirrors
          # bitflags' +from_bits_retain+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.from_bits_retain(0x10008).bits # => 65544
          def from_bits_retain(bits)
            new(bits)
          end

          # The flag named exactly +name+, such as <tt>"SHIFT"</tt>, or
          # +nil+. Mirrors bitflags' +from_name+.
          #
          # === Example
          #
          #   Ferro::GlobalHotkey::Hotkey::Modifiers.from_name("SHIFT") # => Modifiers::SHIFT
          def from_name(name)
            bits = Native.modifiers_from_name(name)
            new(bits) if bits
          end
        end

        # Whether no flag is set. Mirrors bitflags' +is_empty+.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::Modifiers.empty.is_empty # => true
        def is_empty
          @bits.zero?
        end

        # Whether every known flag is set. Mirrors bitflags' +is_all+.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::Modifiers.all.is_all # => true
        def is_all
          @bits.allbits?(ALL_BITS)
        end

        # Whether every flag in +other+ is set here. Mirrors bitflags'
        # +contains+.
        #
        # [other] Modifiers.
        #
        # === Example
        #
        #   (mods::SHIFT | mods::ALT).contains(mods::SHIFT) # => true
        def contains(other)
          @bits.allbits?(bits_of(other))
        end

        # Whether any flag in +other+ is set here. Mirrors bitflags'
        # +intersects+.
        #
        # [other] Modifiers.
        #
        # === Example
        #
        #   mods::SHIFT.intersects(mods::SHIFT | mods::ALT) # => true
        def intersects(other)
          @bits.anybits?(bits_of(other))
        end

        # The flags set here or in +other+. Mirrors bitflags' +union+ and
        # <tt>BitOr</tt>.
        #
        # [other] Modifiers.
        #
        # === Example
        #
        #   (mods::SHIFT | mods::ALT).bits # => 513
        def union(other)
          Modifiers.from_bits_retain(@bits | bits_of(other))
        end
        alias | union

        # The flags set both here and in +other+. Mirrors bitflags'
        # +intersection+ and <tt>BitAnd</tt>.
        #
        # [other] Modifiers.
        #
        # === Example
        #
        #   ((mods::SHIFT | mods::ALT) & mods::ALT) == mods::ALT # => true
        def intersection(other)
          Modifiers.from_bits_retain(@bits & bits_of(other))
        end
        alias & intersection

        # The flags set here and not in +other+. Mirrors bitflags'
        # +difference+ and <tt>Sub</tt>.
        #
        # [other] Modifiers.
        #
        # === Example
        #
        #   ((mods::SHIFT | mods::ALT) - mods::ALT) == mods::SHIFT # => true
        def difference(other)
          Modifiers.from_bits_retain(@bits & ~bits_of(other))
        end
        alias - difference

        # The flags set in exactly one of this and +other+. Mirrors
        # bitflags' +symmetric_difference+ and <tt>BitXor</tt>.
        #
        # [other] Modifiers.
        #
        # === Example
        #
        #   ((mods::SHIFT | mods::ALT) ^ mods::ALT) == mods::SHIFT # => true
        def symmetric_difference(other)
          Modifiers.from_bits_retain(@bits ^ bits_of(other))
        end
        alias ^ symmetric_difference

        # Every known flag not set here; bits that name no flag are
        # dropped. Mirrors bitflags' +complement+ and <tt>Not</tt>, Rust's
        # <tt>!flags</tt>.
        #
        # === Example
        #
        #   (~mods::all).is_empty # => true
        def complement
          Modifiers.from_bits_retain(~@bits & ALL_BITS)
        end
        alias ~ complement

        # Each flag set here, as a Modifiers, in declaration order, then
        # the bits that name no flag, if any, as one more. Mirrors
        # bitflags' +iter+.
        #
        # === Example
        #
        #   (mods::SHIFT | mods::ALT).iter # => [mods::ALT, mods::SHIFT]
        def iter
          named, remaining = names_and_remaining
          flags = named.map(&:last)
          remaining.zero? ? flags : [*flags, Modifiers.from_bits_retain(remaining)]
        end

        # Each flag set here with its name, in declaration order. Bits that
        # name no flag are left out. Mirrors bitflags' +iter_names+.
        #
        # === Example
        #
        #   (mods::SHIFT | mods::ALT).iter_names # => [["ALT", mods::ALT], ["SHIFT", mods::SHIFT]]
        def iter_names
          names_and_remaining.first
        end

        # Whether a Shift key is pressed. Mirrors keyboard-types'
        # <tt>Modifiers::shift</tt>.
        #
        # === Example
        #
        #   mods::SHIFT.shift # => true
        def shift
          contains(SHIFT)
        end

        # Whether a Control key is pressed. Mirrors keyboard-types'
        # <tt>Modifiers::ctrl</tt>.
        #
        # === Example
        #
        #   mods::CONTROL.ctrl # => true
        def ctrl
          contains(CONTROL)
        end

        # Whether an Alt key is pressed. Mirrors keyboard-types'
        # <tt>Modifiers::alt</tt>.
        #
        # === Example
        #
        #   mods::ALT.alt # => true
        def alt
          contains(ALT)
        end

        # Whether a Meta key is pressed. Mirrors keyboard-types'
        # <tt>Modifiers::meta</tt>.
        #
        # === Example
        #
        #   mods::META.meta # => true
        def meta
          contains(META)
        end

        # Orders by bits, as keyboard-types derives +Ord+; +nil+ for
        # anything but a Modifiers.
        #
        # [other] Object.
        #
        # === Example
        #
        #   mods::ALT < mods::SHIFT # => true
        def <=>(other)
          @bits <=> other.bits if other.is_a?(Modifiers)
        end

        # Whether +other+ is a Modifiers with the same bits, for Hash keys.
        #
        # [other] Object.
        #
        # === Example
        #
        #   { mods::SHIFT => :shift }.key?(mods.from_name("SHIFT")) # => true
        def eql?(other)
          other.is_a?(Modifiers) && @bits == other.bits
        end

        # A hash of the bits, so equal values are one Hash key.
        #
        # === Example
        #
        #   mods::SHIFT.hash == mods.from_bits(0x200).hash # => true
        def hash
          [Modifiers, @bits].hash
        end

        # bitflags' +Debug+ text, with this class's Ruby path:
        # <tt>...::Modifiers(CONTROL | SHIFT)</tt>, <tt>...::Modifiers(0x0)</tt>
        # when empty, and unknown bits in hex.
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::Hotkey::Modifiers::SHIFT.inspect
        #   # => "Ferro::GlobalHotkey::Hotkey::Modifiers(SHIFT)"
        def inspect
          Native.modifiers_debug(@bits).sub(/\AModifiers/, "Ferro::GlobalHotkey::Hotkey::Modifiers")
        end

        # bitflags' name iterator (bitflags 2.13.2 <tt>src/iter.rs</tt>): a
        # flag is yielded when all its bits are set here and some are not
        # yet covered by an earlier flag; what no flag covers remains.
        private def names_and_remaining
          remaining = @bits
          # @type var named: Array[[String, Modifiers]]
          named = FLAGS.filter_map do |name, flag|
            next unless @bits.allbits?(flag.bits) && remaining.anybits?(flag.bits)

            remaining &= ~flag.bits
            [name, flag]
          end
          [named, remaining]
        end

        private def bits_of(other)
          raise TypeError, "wrong argument type #{other.class} (expected #{Modifiers})" unless other.is_a?(Modifiers)

          other.bits
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
