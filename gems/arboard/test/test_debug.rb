# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# arboard's Debug texts, as debug answers them, and inspect, which stays
# Ruby's (ADR 001, 2026-11-05). Rust formats each text, so these strings
# are what format!("{:?}") gives for arboard 3.7.0; the Rust tests in
# ext/ferro_arboard/src pin the same strings against the crate.
class TestDebug < Minitest::Test
  include ClipboardSuite

  RED_THEN_GREEN = [255, 0, 0, 255, 0, 255, 0, 255].pack("C*")

  # arboard's hand-written Debug for Error: the variant, then the Display
  # text in quotes (src/common.rs:69-90).
  def test_each_error_variant_debugs_as_arboard_does
    {
      ContentNotAvailable: NOT_AVAILABLE,
      ClipboardNotSupported: NOT_SUPPORTED,
      ClipboardOccupied: OCCUPIED,
      ConversionFailure: CONVERSION_FAILURE,
    }.each do |name, message|
      error = Ferro::Arboard::Error.const_get(name).new

      assert_equal %(#{name} - "#{message}"), error.debug
    end
  end

  def test_a_variant_debugs_as_its_variant_whatever_its_message
    error = Ferro::Arboard::Error::ClipboardOccupied.new("custom")

    assert_equal %(ClipboardOccupied - "#{OCCUPIED}"), error.debug
  end

  # Unknown's name is the pattern arboard stringifies, Unknown { .. }
  # (src/common.rs:82-87).
  def test_unknown_debugs_with_its_description
    error = Ferro::Arboard::Error::Unknown.new("pasteboard unavailable")

    assert_equal 'Unknown { .. } - "Unknown error while interacting with the clipboard: pasteboard unavailable"',
      error.debug
  end

  def test_a_raised_error_debugs_as_arboard_does
    clipboard.clear

    error = assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get_text }

    assert_equal %(ContentNotAvailable - "#{NOT_AVAILABLE}"), error.debug
  end

  # ImageData derives Debug (src/common.rs:126); its Cow<[u8]> prints as a
  # list of bytes.
  def test_image_data_debugs_as_its_derived_debug
    image = Ferro::Arboard::ImageData.new(width: 2, height: 1, bytes: RED_THEN_GREEN)

    assert_equal "ImageData { width: 2, height: 1, bytes: [255, 0, 0, 255, 0, 255, 0, 255] }", image.debug
    assert_equal "ImageData { width: 0, height: 0, bytes: [] }",
      Ferro::Arboard::ImageData.new(width: 0, height: 0, bytes: "").debug
  end

  def test_image_data_debug_takes_what_arboards_fields_hold
    assert_raises(RangeError) { Ferro::Arboard::ImageData.new(width: -1, height: 1, bytes: "").debug }
    assert_raises(TypeError) { Ferro::Arboard::ImageData.new(width: 1, height: 1, bytes: nil).debug }
  end

  def test_inspect_stays_rubys
    image = Ferro::Arboard::ImageData.new(width: 2, height: 1, bytes: RED_THEN_GREEN)
    error = Ferro::Arboard::Error::ConversionFailure.new

    assert_equal "#<data Ferro::Arboard::ImageData width=2, height=1, bytes=#{RED_THEN_GREEN.inspect}>", image.inspect
    assert_equal "#<Ferro::Arboard::Error::ConversionFailure: #{CONVERSION_FAILURE}>", error.inspect
  end

  # Clipboard, Get, Set, and Clear derive no Debug (src/lib.rs:70, :182-185,
  # :221-224, :267-270), and the base Error is no variant of arboard's: it
  # is raised for a panic, or for a variant a later arboard adds.
  def test_what_arboard_gives_no_debug_has_none
    [clipboard, clipboard.get, clipboard.set, clipboard.clear_with, Ferro::Arboard::Error.new].each do |value|
      refute_respond_to value, :debug
    end
  end

  def test_the_native_layer_is_private
    refute_includes Ferro::Arboard.constants, :Native
    assert_raises(NameError) { Ferro::Arboard::Native }
  end
end
