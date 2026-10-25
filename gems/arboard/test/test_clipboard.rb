# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: Apache-2.0 OR MIT
# SPDX-SnippetCopyrightText: 2022 The Arboard contributors
# SPDX-SnippetComment: Ported from arboard 3.7.0 src/lib.rs:280-516
#++

# arboard's own tests (src/lib.rs:282-516), run through the Ruby API
# against the real clipboard. Each block of arboard's all_tests is a test
# here; the Linux selection block lives in test_linux.rb.
class TestClipboard < Minitest::Test
  include ClipboardSuite

  def test_text_round_trips_and_outlives_its_clipboard
    clipboard.set_text("some string")
    assert_equal "some string", clipboard.get_text

    # The content must persist after the clipboard is dropped, which matters
    # most on X11. Give any clipboard manager time to take it over.
    @clipboard = nil
    GC.start
    sleep 0.3

    assert_equal "some string", Ferro::Arboard::Clipboard.new.get_text
  end

  def test_utf8_text_round_trips
    text = "Some utf8: 🤓 ∑φ(n)<ε 🐔"
    clipboard.set_text(text)

    assert_equal text, clipboard.get_text
    assert_equal Encoding::UTF_8, clipboard.get_text.encoding
  end

  def test_clear_empties_the_clipboard_and_may_repeat
    clipboard.set_text("hello world")
    assert_equal "hello world", clipboard.get_text

    clipboard.clear
    assert_no_text

    # Clearing an empty clipboard is fine.
    clipboard.clear
    assert_no_text
  end

  # arboard's test expects no text, which holds everywhere but Wayland.
  # There a text read takes any text type the clipboard offers, text/html
  # included (wl-clipboard-rs 0.9.4 src/paste.rs:441-443 and
  # src/utils.rs:33-39), so the HTML reads back as the text.
  def test_html_without_alt_text_leaves_no_plain_text_except_on_wayland
    html = "<b>hello</b> <i>world</i>!"
    clipboard.set_html(html, nil)

    if PLATFORM == :linux && ENV["WAYLAND_DISPLAY"]
      assert_equal html, clipboard.get_text
    else
      assert_no_text
    end
  end

  def test_html_alt_text_is_the_plain_text
    clipboard.set_html("<b>hello</b> <i>world</i>!", "hello world!")

    assert_equal "hello world!", clipboard.get_text
  end

  def test_html_reads_back_through_get
    html = "<b>hello</b> <i>world</i>!"
    clipboard.set.html(html, nil)

    if ClipboardSuite::PLATFORM == :macos
      # macOS wraps the HTML to mark it as UTF-8 (src/platform/osx.rs:316-318).
      assert clipboard.get.html.end_with?("#{html}</body></html>"), clipboard.get.html
    else
      assert_equal html, clipboard.get.html
    end
  end

  def test_file_list_round_trips
    gem_dir = File.expand_path("..", __dir__)
    paths = [File.join(gem_dir, "README.rdoc"), File.join(gem_dir, "ferro-arboard.gemspec")].map { |path| File.realpath(path) }

    clipboard.set.file_list(paths)

    assert_equal paths, clipboard.get.file_list
  end

  def test_each_format_overwrites_the_other
    bytes = [
      [255, 100, 100, 255],
      [100, 255, 100, 100],
      [100, 100, 255, 100],
      [0, 0, 0, 255],
    ].flatten.pack("C*")
    image = Ferro::Arboard::ImageData.new(width: 2, height: 2, bytes:)

    clipboard.set_image(image)
    assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get_text }

    clipboard.set_text("clipboard test")
    assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get_image }

    clipboard.set_image(image)
    assert_equal image.bytes, clipboard.get_image.bytes
  end

  def test_a_wider_image_round_trips
    bytes = [
      [255, 100, 100, 255],
      [100, 255, 100, 100],
      [100, 100, 255, 100],

      [0, 1, 2, 255],
      [0, 1, 2, 255],
      [0, 1, 2, 255],
    ].flatten.pack("C*")
    clipboard.set_image(Ferro::Arboard::ImageData.new(width: 3, height: 2, bytes:))

    image = clipboard.get_image

    assert_equal [3, 2, bytes], [image.width, image.height, image.bytes]
    assert_equal Encoding::BINARY, image.bytes.encoding
  end

  # Any number of clipboards may be open at once, as long as they are not
  # used at the same moment (arboard src/lib.rs:483-508).
  def test_many_clipboards_at_once
    threads = Array.new(100) do
      Thread.new do
        Ferro::Arboard::Clipboard.new.tap { sleep 0.01 }
      end
    end

    assert_equal [Ferro::Arboard::Clipboard], threads.map(&:value).map(&:class).uniq
  end

  # arboard asserts its Clipboard is Send and Sync (src/lib.rs:510-516);
  # in Ruby that is a frozen clipboard any Ractor may hold.
  def test_a_frozen_clipboard_is_ractor_shareable
    shared = Ractor.make_shareable(Ferro::Arboard::Clipboard.new)

    assert Ractor.shareable?(shared)
  end
end

#--
# SPDX-SnippetEnd
#++
