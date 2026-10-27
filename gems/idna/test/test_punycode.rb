# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: MIT OR Apache-2.0
# SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
# SPDX-SnippetComment: ported from idna 1.1.0 tests/punycode.rs, over its
#   punycode_tests.json and bad_punycode_tests.json
#++

# idna's own Punycode tests, ported: every case in its test data decodes
# with both decoders and encodes back, and every bad case neither panics
# nor encodes.
class TestPunycode < Minitest::Test
  include IdnaSuite

  def test_every_case_in_idnas_data_round_trips
    cases = JSON.parse(IdnaSuite.crate_test_file("punycode_tests.json"))

    assert_operator cases.size, :>, 10
    cases.each do |test|
      decoded = test.fetch("decoded", "")
      encoded = test.fetch("encoded", "")
      name = test["description"]

      assert_equal decoded, Idna::Punycode.decode(encoded)&.join, "decode: #{name}"
      assert_equal decoded, Idna::Punycode.decode_to_string(encoded), "decode_to_string: #{name}"
      assert_equal encoded, Idna::Punycode.encode_str(decoded), "encode_str: #{name}"
      assert_equal encoded, Idna::Punycode.encode(decoded.chars), "encode: #{name}"
    end
  end

  def test_every_bad_case_in_idnas_data_encodes_to_nil
    cases = JSON.parse(IdnaSuite.crate_test_file("bad_punycode_tests.json"))

    refute_empty cases
    cases.each do |test|
      assert_nil Idna::Punycode.encode_str(test.fetch("decoded", "")), test["description"]
    end
  end

  def test_malformed_punycode_decodes_to_nil
    assert_nil Idna::Punycode.decode("99999999999999")
    assert_nil Idna::Punycode.decode_to_string("99999999999999")
  end

  def test_a_character_is_a_one_character_string
    assert_equal %w[b ü c h e r], Idna::Punycode.decode("bcher-kva")

    error = assert_raises(TypeError) { Idna::Punycode.encode(["ab"]) }
    assert_match "could not convert string to char", error.message
    assert_raises(TypeError) { Idna::Punycode.encode([""]) }
    assert_raises(TypeError) { Idna::Punycode.encode([1]) }
  end
end

#--
# SPDX-SnippetEnd
#++
