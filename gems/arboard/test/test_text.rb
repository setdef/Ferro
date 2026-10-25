# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Text and paths cross into arboard as Rust strings and paths (plan 001,
# decisions 10 and 11).
class TestText < Minitest::Test
  include ClipboardSuite

  def test_text_in_another_encoding_is_converted_to_utf8
    clipboard.set_text("caf\xE9".dup.force_encoding(Encoding::ISO_8859_1))

    assert_equal "café", clipboard.get_text
  end

  def test_ascii_bytes_are_text
    clipboard.set_text("plain".b)

    assert_equal "plain", clipboard.get_text
  end

  def test_invalid_utf8_raises_encoding_error
    assert_raises(EncodingError) { clipboard.set_text("\xFF".dup.force_encoding(Encoding::UTF_8)) }
  end

  def test_text_must_be_a_string
    error = assert_raises(TypeError) { clipboard.set_text(1) }

    assert_equal "no implicit conversion of Integer into String", error.message
  end

  def test_set_html_takes_its_alt_text_explicitly
    assert_raises(ArgumentError) { clipboard.set_html("<b>x</b>") }
  end

  def test_file_list_takes_pathnames
    readme = File.realpath(File.expand_path("../README.rdoc", __dir__))

    clipboard.set.file_list([Pathname(readme)])

    assert_equal [readme], clipboard.get.file_list
  end

  def test_file_list_skips_missing_files
    readme = File.realpath(File.expand_path("../README.rdoc", __dir__))

    clipboard.set.file_list([readme, "/nonexistent/ferro-arboard"])

    assert_equal [readme], clipboard.get.file_list
  end

  def test_a_file_list_of_only_missing_files_raises_conversion_failure
    error = assert_raises(Ferro::Arboard::Error::ConversionFailure) do
      clipboard.set.file_list(["/nonexistent/ferro-arboard"])
    end

    assert_equal CONVERSION_FAILURE, error.message
  end

  def test_file_list_takes_an_array_of_paths
    assert_raises(TypeError) { clipboard.set.file_list("README.rdoc") }
    assert_raises(TypeError) { clipboard.set.file_list([1]) }
  end

  def test_reading_files_from_text_raises_content_not_available
    clipboard.set_text("no files here")

    assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get.file_list }
  end
end
