# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# ImageData, and the shapes ferro-arboard refuses before arboard sees them
# (plan 001, decision 4).
class TestImageData < Minitest::Test
  include ClipboardSuite

  RED_THEN_GREEN = [255, 0, 0, 255, 0, 255, 0, 255].pack("C*")

  def test_it_is_a_value_with_arboards_fields
    by_keyword = Ferro::Arboard::ImageData.new(width: 2, height: 1, bytes: RED_THEN_GREEN)
    by_position = Ferro::Arboard::ImageData.new(2, 1, RED_THEN_GREEN)

    assert_equal by_keyword, by_position
    assert_equal [2, 1, RED_THEN_GREEN], [by_keyword.width, by_keyword.height, by_keyword.bytes]
    assert_predicate by_keyword, :frozen?
  end

  def test_a_drawable_image_reaches_the_clipboard
    clipboard.set_image(Ferro::Arboard::ImageData.new(width: 2, height: 1, bytes: RED_THEN_GREEN))

    assert_equal RED_THEN_GREEN, clipboard.get_image.bytes
  end

  # Each shape raises ConversionFailure. On Linux and Windows ferro-arboard
  # refuses them all, since the PNG encoder there asserts the byte count
  # (image 0.25.10 src/codecs/png.rs:740-746). On macOS it refuses only the
  # empty buffer, which arboard would panic on (src/platform/osx.rs:58-69),
  # and arboard itself refuses the rest, when CGImageCreate fails
  # (osx.rs:80-95); the two shapes arboard accepts there are skipped. The
  # clipboard keeps its text, which shows no image reached it: arboard
  # clears the clipboard only after it converts the image (osx.rs:345-347).
  MACOS_DRAWS = ["too many bytes", "a byte count that is not a pixel"].freeze

  {
    "zero width" => [0, 1, "\x00" * 4],
    "zero height" => [1, 0, "\x00" * 4],
    "zero size" => [0, 0, ""],
    "no bytes" => [1, 1, ""],
    "too few bytes" => [2, 1, "\x00" * 4],
    "too many bytes" => [2, 1, "\x00" * 12],
    "a byte count that is not a pixel" => [1, 1, "\x00" * 5],
  }.each do |shape, (width, height, bytes)|
    define_method("test_#{shape.tr(' ', '_')}_raises_conversion_failure") do
      skip "arboard draws this on macOS; see test_an_oversized_buffer_draws_its_first_pixels_on_macos" if PLATFORM == :macos && MACOS_DRAWS.include?(shape)
      clipboard.set_text("keep me")
      image = Ferro::Arboard::ImageData.new(width:, height:, bytes: bytes.b)

      error = assert_raises(Ferro::Arboard::Error::ConversionFailure) { clipboard.set_image(image) }

      assert_equal CONVERSION_FAILURE, error.message
      assert_equal "keep me", clipboard.get_text
    end
  end

  # macOS's arboard builds the image with 4 * width bytes a row from however
  # many bytes it gets (osx.rs:80-95), so a longer buffer draws from its
  # first width * height * 4 bytes.
  def test_an_oversized_buffer_draws_its_first_pixels_on_macos
    skip_unless_platform(:macos)

    clipboard.set_image(Ferro::Arboard::ImageData.new(width: 2, height: 1, bytes: RED_THEN_GREEN + ("\x00" * 4).b))

    image = clipboard.get_image
    assert_equal [2, 1, RED_THEN_GREEN], [image.width, image.height, image.bytes]
  end

  def test_a_huge_width_that_overflows_raises_conversion_failure
    image = Ferro::Arboard::ImageData.new(width: 2 ** 63, height: 4, bytes: "\x00" * 4)

    assert_raises(Ferro::Arboard::Error::ConversionFailure) { clipboard.set_image(image) }
  end

  def test_dimensions_outside_usize_raise_range_error
    assert_raises(RangeError) { clipboard.set_image(Ferro::Arboard::ImageData.new(width: -1, height: 1, bytes: "abcd")) }
    assert_raises(RangeError) { clipboard.set_image(Ferro::Arboard::ImageData.new(width: 2 ** 70, height: 1, bytes: "abcd")) }
  end

  def test_set_image_takes_only_image_data
    error = assert_raises(TypeError) { clipboard.set_image([1, 1, "abcd"]) }

    assert_equal "wrong argument type Array (expected Ferro::Arboard::ImageData)", error.message
  end
end
