# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Get, Set, and Clear: arboard's builders, holding their clipboard (plan
# 001, decisions 1 and 2).
class TestBuilders < Minitest::Test
  include ClipboardSuite

  def test_the_builders_come_only_from_a_clipboard
    [Ferro::Arboard::Get, Ferro::Arboard::Set, Ferro::Arboard::Clear].each do |builder|
      assert_raises(NoMethodError) { builder.new(clipboard) }
    end
    assert_instance_of Ferro::Arboard::Get, clipboard.get
    assert_instance_of Ferro::Arboard::Set, clipboard.set
    assert_instance_of Ferro::Arboard::Clear, clipboard.clear_with
  end

  def test_get_and_set_text
    clipboard.set.text("through the builder")

    assert_equal "through the builder", clipboard.get.text
  end

  def test_a_get_reads_afresh_each_time
    get = clipboard.get
    clipboard.set_text("first")
    assert_equal "first", get.text

    clipboard.set_text("second")
    assert_equal "second", get.text
  end

  def test_set_html_through_the_builder_sets_alt_text
    clipboard.set.html("<i>rich</i>", "rich")

    assert_equal "rich", clipboard.get.text
  end

  def test_set_image_through_the_builder
    pixel = [1, 2, 3, 255].pack("C*")
    clipboard.set.image(Ferro::Arboard::ImageData.new(width: 1, height: 1, bytes: pixel))

    assert_equal Ferro::Arboard::ImageData.new(width: 1, height: 1, bytes: pixel), clipboard.get.image
  end

  def test_clear_with_default_empties_the_clipboard
    clipboard.set_text("to be cleared")

    clipboard.clear_with.default

    assert_no_text
  end

  def test_exclude_from_history_returns_the_set_on_every_platform
    set = clipboard.set

    assert_same set, set.exclude_from_history
    set.text("hidden from history")
    assert_equal "hidden from history", clipboard.get_text
  end

  # Reads the pasteboard's types with AppKit, to see what arboard wrote.
  private def pasteboard_types
    script = 'ObjC.import("AppKit"); $.NSPasteboard.generalPasteboard.types.js.map(t => t.js).join("\n")'
    IO.popen(["osascript", "-l", "JavaScript", "-e", script], err: File::NULL, &:read).split("\n")
  rescue Errno::ENOENT
    skip "osascript is not installed"
  end

  # arboard marks excluded contents with org.nspasteboard.ConcealedType
  # (src/platform/osx.rs:410-422).
  def test_macos_exclude_from_history_conceals_the_contents
    skip_unless_platform(:macos)

    clipboard.set.text("visible")
    refute_includes pasteboard_types, "org.nspasteboard.ConcealedType"

    clipboard.set.exclude_from_history.text("concealed")
    assert_includes pasteboard_types, "org.nspasteboard.ConcealedType"
  end
end
