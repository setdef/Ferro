# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: Apache-2.0 OR MIT
# SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
# SPDX-SnippetComment: test_parse_hotkey, test_equality, and the module
#   doc's examples ported from global-hotkey 0.9.0 src/hotkey.rs:11-27,
#   460-577
#++

# HotKey's construction, parsing, and text, through global-hotkey.
class TestHotKey < Minitest::Test
  include HotkeySuite

  Mods = Hotkey::Modifiers
  Code = Hotkey::Code
  HotKey = Hotkey::HotKey

  private def assert_parses(text, mods, key)
    parsed = HotKey.from_str(text)

    assert_equal [mods, key], [parsed.mods, parsed.key], text
  end

  # global-hotkey's test_parse_hotkey (src/hotkey.rs:460-558).
  def test_global_hotkeys_parse_cases
    assert_parses "KeyX", Mods.empty, Code::KeyX
    assert_parses "CTRL+KeyX", Mods::CONTROL, Code::KeyX
    assert_parses "SHIFT+KeyC", Mods::SHIFT, Code::KeyC
    assert_parses "meta+ctrl+SHIFT+alt+ArrowUp", Mods::META | Mods::CONTROL | Mods::SHIFT | Mods::ALT, Code::ArrowUp
    assert_parses "Digit5", Mods.empty, Code::Digit5
    assert_parses "KeyG", Mods.empty, Code::KeyG
    assert_parses "SHiFT+F12", Mods::SHIFT, Code::F12
    assert_parses "CmdOrCtrl+Space", ((PLATFORM == :macos) ? Mods::META : Mods::CONTROL), Code::Space

    # Just modifiers is not a hotkey, and must not panic.
    assert_raises(Hotkey::HotKeyParseError::InvalidFormat) { HotKey.from_str("Shift+Ctrl") }
  end

  # global-hotkey's test_equality (src/hotkey.rs:560-577).
  def test_equal_hotkeys_have_equal_ids
    h1 = HotKey.from_str("Shift+KeyR")
    h2 = HotKey.from_str("Shift+KeyR")
    h3 = HotKey.new(Mods::SHIFT, Code::KeyR)
    h4 = HotKey.from_str("Alt+KeyR")
    h5 = HotKey.from_str("Alt+KeyR")
    h6 = HotKey.from_str("KeyR")

    assert(h1 == h2 && h2 == h3 && h3 != h4 && h4 == h5 && h5 != h6)
    assert(h1.id == h2.id && h2.id == h3.id && h3.id != h4.id && h4.id == h5.id && h5.id != h6.id)
  end

  # The module doc: modifiers come before the key (src/hotkey.rs:18-27).
  def test_modifiers_must_come_before_the_key
    assert_equal "shift+alt+KeyQ", HotKey.from_str("shift+alt+KeyQ").to_s
    error = assert_raises(Hotkey::HotKeyParseError::InvalidFormat) { HotKey.from_str("shift+KeyQ+alt") }
    assert_equal 'Invalid hotkey format: "shift+KeyQ+alt", an hotkey should have the modifiers first and only ' \
      'one main key, for example: "Shift + Alt + K"', error.message
  end

  def test_new_computes_global_hotkeys_id
    assert_equal (0x200 << 16) | 22, HotKey.new(Mods::SHIFT, Code::KeyD).id
    assert_equal 22, HotKey.new(nil, Code::KeyD).id
    assert_equal Mods.empty, HotKey.new(nil, Code::KeyD).mods
    assert_equal (0x8 << 16) | 62, HotKey.new(Mods::CONTROL, Code::Space).id
  end

  def test_new_turns_super_into_meta
    super_d = quietly { HotKey.new(Mods::SUPER | Mods::SHIFT, Code::KeyD) }

    assert_equal Mods::META | Mods::SHIFT, super_d.mods
    assert_equal HotKey.new(Mods::META | Mods::SHIFT, Code::KeyD), super_d
  end

  def test_an_id_makes_the_rust_struct_literal
    literal = HotKey.new(mods: quietly { Mods::SUPER }, key: Code::KeyD, id: 7)

    assert_equal [quietly { Mods::SUPER }, 7], [literal.mods, literal.id]
    assert_equal 7, HotKey.new(Mods::ALT, Code::F19, 7).id
    assert_equal 9, literal.with(id: 9).id
    assert_equal HotKey.new(Mods::ALT, Code::KeyQ), HotKey.new(mods: Mods::ALT, key: Code::KeyQ)
  end

  # The literal path checks its fields as the constructor does: a Rust
  # literal with the wrong types would not compile (plan 004, decision 9).
  def test_the_literal_checks_its_fields
    assert_raises(TypeError) { HotKey.new(mods: "junk", key: Code::KeyA, id: 3) }
    assert_raises(TypeError) { HotKey.new(mods: nil, key: Code::KeyA, id: 3) }
    assert_raises(TypeError) { HotKey.new(mods: Mods::ALT, key: 2, id: 3) }
    assert_raises(RangeError) { HotKey.new(mods: Mods::ALT, key: Code::KeyA, id: 1 << 32) }
    assert_raises(TypeError) { HotKey.new(Mods::ALT, Code::KeyA, "3") }
  end

  def test_a_positional_field_and_keywords_together_raise
    assert_raises(ArgumentError) { HotKey.new(Mods::SHIFT, mods: Mods::ALT, key: Code::KeyA) }
    assert_raises(ArgumentError) { HotKey.new(nil, Code::KeyA, key: Code::KeyB) }
  end

  def test_a_hotkey_survives_marshal
    hotkey = HotKey.from_str("ctrl+alt+F19")
    copy = Marshal.load(Marshal.dump(hotkey))

    assert_equal hotkey, copy
    assert copy.eql?(hotkey)
    assert_equal hotkey.hash, copy.hash
    assert_same Code::F19, copy.key
  end

  def test_a_hotkey_is_a_frozen_shareable_value
    hotkey = HotKey.from_str("alt+F19")

    assert_predicate hotkey, :frozen?
    assert Ractor.shareable?(Ractor.make_shareable(hotkey))
    assert_equal({ hotkey => 1 }, { HotKey.from_str("Alt+F19") => 1 })
  end

  def test_wrong_types_raise_type_error
    assert_raises(TypeError) { HotKey.new(:shift, Code::KeyQ) }
    assert_raises(TypeError) { HotKey.new(Mods::SHIFT, "KeyQ") }
    assert_raises(ArgumentError) { HotKey.new(Mods::SHIFT, Code::KeyQ, mods: Mods::ALT) }
    assert_raises(TypeError) { HotKey.from_str(:KeyQ) }
  end

  def test_each_parse_error_has_global_hotkeys_message
    unsupported = assert_raises(Hotkey::HotKeyParseError::UnsupportedKey) { HotKey.from_str("Shift+Nope") }
    assert_equal "Couldn't recognize \"Nope\" as a valid key for hotkey, if you feel like it should be, please " \
      "report this to https://github.com/tauri-apps/muda", unsupported.message

    empty = assert_raises(Hotkey::HotKeyParseError::EmptyToken) { HotKey.from_str("Shift++KeyA") }
    assert_equal "Found empty token while parsing hotkey: Shift++KeyA", empty.message

    assert_raises(Hotkey::HotKeyParseError::UnsupportedKey) { HotKey.from_str("") }
    assert_kind_of StandardError, unsupported
    refute_kind_of GlobalHotkey::Error, unsupported
  end

  def test_try_from_is_from_str
    assert_equal HotKey.from_str("ctrl+F19"), HotKey.try_from("ctrl+F19")
    assert_raises(Hotkey::HotKeyParseError::InvalidFormat) { HotKey.try_from("F19+ctrl") }
  end

  def test_text_lists_modifiers_in_global_hotkeys_order
    hotkey = HotKey.from_str("Meta+Alt+Control+Shift+F19")

    assert_equal "shift+control+alt+meta+F19", hotkey.into_string
    assert_equal hotkey.into_string, hotkey.to_s
    assert_equal hotkey, HotKey.from_str(hotkey.to_s)
  end

  def test_single_characters_and_aliases_parse_as_global_hotkey_maps_them
    assert_equal Code::KeyA, HotKey.from_str("a").key
    assert_equal Code::Digit5, HotKey.from_str("5").key
    assert_equal Code::Escape, HotKey.from_str("ctrl+Esc").key
    assert_equal Code::ArrowUp, HotKey.from_str("alt+up").key
    assert_equal Code::NumpadAdd, HotKey.from_str("NumPlus").key
    assert_equal quietly { Code::Super }, HotKey.from_str("Super").key
  end

  def test_matches_counts_only_shift_control_alt_and_meta
    shift_q = HotKey.from_str("shift+KeyQ")

    assert shift_q.matches(Mods::SHIFT | Mods::CAPS_LOCK | Mods::NUM_LOCK, Code::KeyQ)
    refute shift_q.matches(Mods::SHIFT | Mods::ALT, Code::KeyQ)
    refute shift_q.matches(Mods::SHIFT, Code::KeyW)
    assert_raises(TypeError) { shift_q.matches(Mods::SHIFT, :KeyQ) }
  end

  def test_cmd_or_ctrl_follows_the_platform
    expected = (PLATFORM == :macos) ? Mods::META : Mods::CONTROL

    assert_equal expected, Hotkey::CMD_OR_CTRL
  end
end

#--
# SPDX-SnippetEnd
#++
