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
# SPDX-SnippetComment: ported from url 2.5.8 tests/wpt.rs, over its
#   urltestdata.json, setters_tests.json, and expected_failures.txt
#++

# url's web-platform-tests driver, ported: every case of urltestdata.json
# through ParseOptions and the Quirks getters, and every case of
# setters_tests.json through the Quirks setters, each named as wpt.rs
# names it. The cases that fail must be exactly url's
# expected_failures.txt, as wpt.rs requires: no unexpected failure, no
# unexpected success, and no expected failure that did not run.
class TestWpt < Minitest::Test
  include UrlSuite

  QUIRKS = Ferro::Url::Quirks
  GETTERS = %w[href protocol username password host hostname port pathname search hash].freeze

  # Rust's str::escape_default, which wpt.rs names cases with.
  def self.escape_default(text)
    text.each_char.map do |char|
      case char
      when "\t" then "\\t"
      when "\r" then "\\r"
      when "\n" then "\\n"
      when "'" then "\\'"
      when '"' then '\\"'
      when "\\" then "\\\\"
      when " ".."~" then char
      else format("\\u{%x}", char.ord)
      end
    end.join
  end

  private def check_url(result, expected)
    return "expected success, but errored: #{result.message}" if result.is_a?(Exception)

    GETTERS.each do |getter|
      actual = QUIRKS.public_send(getter, result)
      return "expected #{getter} #{expected[getter].inspect}, but got #{actual.inspect}" unless actual == expected[getter]
    end
    nil
  end

  private def run_url_test(test)
    base = test["base"] && Url.parse(test["base"])
    result = begin
      Url.options.base_url(base).parse(test["input"])
    rescue U::ParseError => e
      e
    end
    if test["failure"]
      return "expected failure, but parsed successfully" unless result.is_a?(Exception)

      nil
    else
      check_url(result, test)
    end
  rescue U::ParseError => e
    "errored while parsing base: #{e.message}"
  end

  SETTERS = %w[protocol username password host hostname port pathname search hash].freeze

  private def run_setter_test(kind, test)
    return "unknown setter kind: #{kind.inspect}" unless SETTERS.include?(kind)

    url = Url.parse(test["href"])
    begin
      QUIRKS.public_send("set_#{kind}", url, test["new_value"])
    rescue U::Error
      nil # wpt.rs drops the Err with .ok()
    end
    test["expected"].each do |getter, expected|
      actual = QUIRKS.public_send(getter, url)
      return "expected #{getter} #{expected.inspect}, but got #{actual.inspect}" unless actual == expected
    end
    nil
  end

  def test_the_cases_that_fail_are_exactly_urls_expected_failures
    expected = UrlSuite.crate_test_file("expected_failures.txt").lines(chomp: true)
    failures = {}
    JSON.parse(UrlSuite.crate_test_file("urltestdata.json")).grep(Hash).each do |test|
      name = "<#{self.class.escape_default(test['input'])}>"
      name += " against <#{self.class.escape_default(test['base'])}>" if test["base"]
      error = run_url_test(test)
      failures[name] = error if error
    end
    JSON.parse(UrlSuite.crate_test_file("setters_tests.json")).except("comment").each do |kind, tests|
      tests.each do |test|
        name = "<#{self.class.escape_default(test['href'])}> set #{kind} to <#{self.class.escape_default(test['new_value'])}>"
        error = run_setter_test(kind, test)
        failures[name] = error if error
      end
    end

    assert_operator expected.size, :>, 40
    assert_empty failures.keys - expected, "unexpected failures: #{failures.except(*expected)}"
    assert_empty expected - failures.keys, "expected to fail but passed or did not run"
  end
end

#--
# SPDX-SnippetEnd
#++
