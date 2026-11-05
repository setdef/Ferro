# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# keyboard-types' Code, whose constants code.rb generates from its source.
class TestCode < Minitest::Test
  include HotkeySuite

  Code = Hotkey::Code

  private def codes
    quietly { Code.constants(false).map { |name| Code.const_get(name) }.select { |value| value.is_a?(Code) } }
  end

  # Every constant is a keyboard-types variant, at its discriminant, and
  # there are as many as keyboard-types has.
  def test_the_constants_are_keyboard_types_variants_in_order
    native = GlobalHotkey.const_get(:Native)
    places = codes.sort.map { |code| GlobalHotkey.__send__(:settle, native.code_from_str(code.to_s)) }

    assert_equal native.code_count, codes.size
    assert_equal Array.new(native.code_count) { |place| place }, places
  end

  def test_from_str_takes_the_exact_w3c_name
    assert_same Code::KeyA, Code.from_str("KeyA")
    assert_same Code::F19, Code.from_str("F19")
    error = assert_raises(Hotkey::UnrecognizedCodeError) { Code.from_str("keya") }
    assert_equal "Unrecognized code", error.message
    assert_equal "Unrecognized code", Hotkey::UnrecognizedCodeError.new.message
  end

  def test_text_debug_and_inspect
    assert_equal "BracketLeft", Code::BracketLeft.to_s
    assert_equal "BracketLeft", Code::BracketLeft.debug
    assert_match(/\A#<Ferro::GlobalHotkey::Hotkey::Code:0x\h+ @name=:BracketLeft, @index=2>\z/, Code::BracketLeft.inspect)
  end

  # Code's integer value is Rust's `as u32`, which global-hotkey puts in
  # the low bits of the id HotKey::new computes (src/hotkey.rs:99), so a
  # hotkey with no modifiers has the code's value as its id.
  def test_to_i_is_the_value_global_hotkey_puts_in_an_id
    codes = Code.constants(false).map { |name| quietly { Code.const_get(name, false) } }.grep(Code)

    assert_equal 216, codes.size
    codes.each { |code| assert_equal Hotkey::HotKey.new(nil, code).id, code.to_i, code.to_s }
    assert_equal 215, Code::ZoomToggle.to_i
    assert_equal 0, Code::Backquote.to_i
  end

  def test_codes_order_as_keyboard_types_declares_them
    assert_operator Code::Backquote, :<, Code::Backslash
    assert_operator Code::KeyA, :<, Code::KeyB
    assert_operator Code::F12, :<, Code::F13
    assert_nil Code::KeyA <=> "KeyA"
  end

  def test_hyper_super_and_turbo_are_deprecated
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    %i[Hyper Super Turbo].each do |name|
      assert_output(nil, /#{name} is deprecated/) { Code.const_get(name) }
    end
  ensure
    Warning[:deprecated] = deprecated
  end

  def test_parsing_a_deprecated_code_does_not_warn
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    assert_output(nil, "") { Code.from_str("Super") }
  ensure
    Warning[:deprecated] = deprecated
  end

  def test_a_code_survives_marshal_as_its_constant
    assert_same Code::KeyA, Marshal.load(Marshal.dump(Code::KeyA))
    assert_equal({ Code::KeyA => 1 }, { Marshal.load(Marshal.dump(Code::KeyA)) => 1 })
  end

  def test_codes_are_frozen_singletons
    assert_predicate Code::KeyA, :frozen?
    assert Ractor.shareable?(Code::KeyA)
    assert_raises(NoMethodError) { Code.new(:KeyA, 19) }
  end
end
