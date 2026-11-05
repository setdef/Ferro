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
# SPDX-SnippetComment: ported from idna 1.1.0 tests/unit.rs and
#   tests/unitbis.rs
#++

# idna's unit tests, ported: tests/unit.rs and tests/unitbis.rs, through
# Uts46. The deprecated Config and Idna that tests/unit.rs calls are not
# bound (plan 006, decision 8).
class TestUnit < Minitest::Test
  include IdnaSuite

  PREFIXES = %w[xn-- xn--- xn----- xn--. xn--... .xn-- ...xn-- xn--.xn-- xn--.example.org].freeze

  private def lenient(domain)
    Uts46::Uts46.new.to_ascii(domain, Uts46::AsciiDenyList::EMPTY, Uts46::Hyphens::Allow, Uts46::DnsLength::Ignore)
  end

  private def unicode(uts46, domain)
    uts46.to_unicode(domain, Uts46::AsciiDenyList::EMPTY, Uts46::Hyphens::Allow)
  end

  private def strict(domain, dns_length = Uts46::DnsLength::Verify)
    Uts46::Uts46.new.to_ascii(domain, Uts46::AsciiDenyList::STD3, Uts46::Hyphens::Check, dns_length)
  end

  # https://github.com/servo/rust-url/issues/373
  def test_punycode_prefix_with_and_without_length_check
    [Uts46::DnsLength::Verify, Uts46::DnsLength::Ignore].each do |length|
      PREFIXES.each { |domain| assert_raises(Idna::Errors, domain) { strict(domain, length) } }
    end
  end

  def test_punycode_invalid_encoding
    assert_raises(Idna::Errors) { lenient("xn--55555577") }
  end

  # http://www.unicode.org/reports/tr46/#Table_Example_Processing
  def test_examples
    uts46 = Uts46::Uts46.new
    {
      "Bloß.de" => "bloß.de",
      "xn--blo-7ka.de" => "bloß.de",
      "ü.com" => "ü.com",
      "xn--tda.com" => "ü.com",
      "日本語。ＪＰ" => "日本語.jp",
      "☕.us" => "☕.us",
    }.each do |domain, expected|
      assert_equal [expected, nil], unicode(uts46, domain)
    end
    ["xn--u-ccb.com", "a⒈com", "xn--a-ecp.ru", "xn--0.pt"].each do |domain|
      _, errors = unicode(uts46, domain)
      assert_instance_of Idna::Errors, errors, domain
    end
  end

  def test_v5
    ["\u{11C3A}", "\u{850f}.\u{11C3A}", "\u{850f}\u{ff61}\u{11C3A}"].each do |domain|
      assert_raises(Idna::Errors) { strict(domain) }
    end
  end

  def test_v8_bidi_rules
    {
      "abc" => "abc",
      "123" => "123",
      "אבּג" => "xn--kdb3bdf",
      "ابج" => "xn--mgbcm",
      "abc.ابج" => "abc.xn--mgbcm",
      "אבּג.ابج" => "xn--kdb3bdf.xn--mgbcm",
    }.each do |domain, expected|
      assert_equal expected, strict(domain)
    end
    # Bidi domain names cannot start with digits, and bidi characters may
    # be Punycode-encoded.
    ["0a.א", "0à.א", "xn--0ca24w"].each do |domain|
      assert_raises(Idna::Errors) { strict(domain) }
    end
  end

  def test_emoji_domains
    assert_equal "xn--53h.com", strict("☕.com")
  end

  def test_unicode_before_delimiter
    assert_raises(Idna::Errors) { lenient("xn--f͊-PTP") }
    assert_raises(Idna::Errors) { strict("xn--f͊-PTP") }
  end

  def test_upper_case_ascii_in_punycode
    assert_equal ["aö", nil],
      Uts46::Uts46.new.to_unicode("xn--A-1ga", Uts46::AsciiDenyList::STD3, Uts46::Hyphens::Check)
  end
end

#--
# SPDX-SnippetEnd
#++
