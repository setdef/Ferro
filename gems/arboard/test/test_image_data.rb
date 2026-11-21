# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# ImageData, a value with arboard's fields. desktop/test_image_data.rb sends
# images through a real clipboard, and the shapes ferro-arboard refuses
# before arboard sees them (plan 001, decision 4).
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
end
