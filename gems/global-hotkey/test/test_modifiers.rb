# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# keyboard-types' Modifiers, with the methods bitflags gives it.
class TestModifiers < Minitest::Test
  include HotkeySuite

  Mods = Hotkey::Modifiers

  # The Ruby constants are bitflags' own flag table, in its order.
  def test_the_constants_are_bitflags_flags
    native = GlobalHotkey.const_get(:Native).modifier_flags
    ruby = quietly { native.map { |name, _| [name, Mods.const_get(name).bits] } }

    assert_equal native, ruby
    assert_equal 14, native.size
    assert_equal native.sum { |_, bits| bits }, Mods.all.bits
  end

  def test_hyper_and_super_are_deprecated
    assert_output(nil, /SUPER is deprecated/) do
      deprecated = Warning[:deprecated]
      Warning[:deprecated] = true
      Mods::SUPER
    ensure
      Warning[:deprecated] = deprecated
    end
  end

  def test_operators_follow_bitflags
    both = Mods::SHIFT | Mods::ALT

    assert_equal 0x201, both.bits
    assert_equal Mods::ALT, both & Mods::ALT
    assert_equal Mods::SHIFT, both - Mods::ALT
    assert_equal Mods::SHIFT, both ^ Mods::ALT
    assert_equal Mods::SHIFT | Mods::ALT | Mods::META, both ^ Mods::META
    assert_equal both, Mods::SHIFT.union(Mods::ALT)
    assert_equal Mods::ALT, both.intersection(Mods::ALT)
    assert_equal Mods::SHIFT, both.difference(Mods::ALT)
    assert_equal Mods::SHIFT, both.symmetric_difference(Mods::ALT)
    assert_raises(TypeError) { both | 1 }
  end

  def test_complement_drops_unknown_bits
    assert_predicate(~Mods.all, :is_empty)
    assert_equal Mods.all - Mods::SHIFT, ~Mods::SHIFT
    assert_equal Mods.all, Mods.from_bits_retain(0x1_0000).complement
  end

  def test_from_bits_and_its_variants
    assert_equal Mods::CONTROL, Mods.from_bits(0x8)
    assert_nil Mods.from_bits(0x1_0008)
    assert_equal Mods::CONTROL, Mods.from_bits_truncate(0x1_0008)
    assert_equal 0x1_0008, Mods.from_bits_retain(0x1_0008).bits
    assert_raises(RangeError) { Mods.from_bits_retain(1 << 32) }
    assert_raises(RangeError) { Mods.from_bits_retain(-1) }
  end

  def test_from_name_takes_exact_names
    assert_equal Mods::SHIFT, Mods.from_name("SHIFT")
    assert_nil Mods.from_name("shift")
    assert_equal 0x2000, Mods.from_name("SUPER").bits
  end

  def test_predicates
    assert_predicate Mods.empty, :is_empty
    assert_predicate Mods.default, :is_empty
    assert_predicate Mods.all, :is_all
    refute_predicate Mods::SHIFT, :is_all
    assert((Mods::SHIFT | Mods::ALT).contains(Mods::SHIFT))
    refute Mods::SHIFT.contains(Mods::SHIFT | Mods::ALT)
    assert Mods::SHIFT.intersects(Mods::SHIFT | Mods::ALT)
    refute Mods::SHIFT.intersects(Mods::ALT)
  end

  def test_keyboard_types_helpers
    all = Mods::SHIFT | Mods::CONTROL | Mods::ALT | Mods::META

    assert [all.shift, all.ctrl, all.alt, all.meta].all?
    refute [Mods.empty.shift, Mods.empty.ctrl, Mods.empty.alt, Mods.empty.meta].any?
  end

  def test_iteration_yields_flags_in_order_then_unknown_bits
    mods = Mods::SHIFT | Mods::ALT | Mods.from_bits_retain(0x1_0000)

    assert_equal [["ALT", Mods::ALT], ["SHIFT", Mods::SHIFT]], mods.iter_names
    assert_equal [Mods::ALT, Mods::SHIFT, Mods.from_bits_retain(0x1_0000)], mods.iter
    assert_equal [], Mods.empty.iter
  end

  def test_inspect_is_bitflags_debug_text
    assert_equal "Ferro::GlobalHotkey::Hotkey::Modifiers(CONTROL | SHIFT)", (Mods::SHIFT | Mods::CONTROL).inspect
    assert_equal "Ferro::GlobalHotkey::Hotkey::Modifiers(0x0)", Mods.empty.inspect
    assert_equal "Ferro::GlobalHotkey::Hotkey::Modifiers(ALT | 0x10000)", Mods.from_bits_retain(0x1_0001).inspect
  end

  def test_values_order_and_hash_by_bits
    assert_operator Mods::ALT, :<, Mods::SHIFT
    assert_nil Mods::ALT <=> 1
    assert Mods::SHIFT.eql?(Mods.from_bits(0x200))
    assert_equal({ Mods::SHIFT => 1 }, { Mods.from_name("SHIFT") => 1 })
    assert_predicate Mods::SHIFT, :frozen?
    assert Ractor.shareable?(Mods::SHIFT)
    assert_raises(NoMethodError) { Mods.new(1) }
  end
end
