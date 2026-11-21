# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Errors a real clipboard raises, each the variant arboard returns, with
# its message. The rest are in test_error.rb.
class TestClipboardError < Minitest::Test
  include ClipboardSuite

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
