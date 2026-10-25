# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# One exception class per arboard error variant, each with arboard's
# Display text (src/common.rs:14-65).
class TestError < Minitest::Test
  include ClipboardSuite

  VARIANTS = {
    ContentNotAvailable: NOT_AVAILABLE,
    ClipboardNotSupported: NOT_SUPPORTED,
    ClipboardOccupied: OCCUPIED,
    ConversionFailure: CONVERSION_FAILURE,
  }.freeze

  def test_error_is_a_standard_error
    assert_operator Ferro::Arboard::Error, :<, StandardError
  end

  def test_each_variant_is_an_error_with_arboards_message
    VARIANTS.each do |name, message|
      klass = Ferro::Arboard::Error.const_get(name)

      assert_operator klass, :<, Ferro::Arboard::Error
      assert_equal message, klass.new.message
      assert_equal "custom", klass.new("custom").message
    end
  end

  def test_unknown_carries_its_description
    error = Ferro::Arboard::Error::Unknown.new("pasteboard unavailable")

    assert_operator Ferro::Arboard::Error::Unknown, :<, Ferro::Arboard::Error
    assert_equal "pasteboard unavailable", error.description
    assert_equal "Unknown error while interacting with the clipboard: pasteboard unavailable", error.message
  end

  def test_the_variants_are_exactly_arboards
    assert_equal %i[ClipboardNotSupported ClipboardOccupied ContentNotAvailable ConversionFailure Unknown],
      Ferro::Arboard::Error.constants.sort
  end

  def test_the_native_layer_raises_the_variant_with_arboards_message
    clipboard.clear

    error = assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get_text }

    assert_equal NOT_AVAILABLE, error.message
  end

  def test_a_missing_image_raises_content_not_available
    clipboard.set_text("not an image")

    error = assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get_image }

    assert_equal NOT_AVAILABLE, error.message
  end
end
