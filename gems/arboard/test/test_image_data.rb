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

  # arboard would panic on these (a zero dimension on macOS, a wrong byte
  # count on Linux and Windows) or, for an oversized buffer on macOS,
  # silently draw part of it. The clipboard keeps its text, which shows the
  # image never reached arboard: arboard clears the clipboard before it
  # writes an image it could convert.
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
      clipboard.set_text("keep me")
      image = Ferro::Arboard::ImageData.new(width:, height:, bytes: bytes.b)

      error = assert_raises(Ferro::Arboard::Error::ConversionFailure) { clipboard.set_image(image) }

      assert_equal CONVERSION_FAILURE, error.message
      assert_equal "keep me", clipboard.get_text
    end
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
