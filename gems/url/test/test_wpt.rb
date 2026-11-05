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
#   urltestdata.json and expected_failures.txt, with the WHATWG getters
#   of src/quirks.rs:82-336
#++

# url's web-platform-tests driver, ported: every case of urltestdata.json
# through ParseOptions, read back through the URL Standard's getters, each
# named as wpt.rs names it. The cases that fail must be exactly url's
# expected_failures.txt, as wpt.rs requires: no unexpected failure, no
# unexpected success, and no expected failure that did not run.
#
# wpt.rs reads the getters, and runs setters_tests.json, through url's
# +quirks+ module, which url hides with <tt>#[doc(hidden)]</tt> and the gem
# therefore does not bind (ADR 001, 2026-11-05). The getters are one-liners
# over Url's public API, so this port computes them as quirks.rs does. The
# setters are not: they drive url's private parser, so setters_tests.json
# and its expected failures are not ported.
class TestWpt < Minitest::Test
  include UrlSuite

  # quirks.rs's trim (src/quirks.rs:330-336): a lone "?" or "#" is empty.
  def self.trim(text)
    (text.length == 1) ? "" : text
  end

  # The URL Standard's getters, as url's quirks.rs computes them
  # (src/quirks.rs:82-316), over Url's public API.
  GETTERS = {
    "href" => :as_str.to_proc,
    "protocol" => -> (url) { url.as_str[0, url.scheme.length + 1] },
    "username" => :username.to_proc,
    "password" => -> (url) { url.password || "" },
    "host" => -> (url) { url[Position::BeforeHost...Position::AfterPort] },
    "hostname" => -> (url) { url.host_str || "" },
    "port" => -> (url) { url[Position::BeforePort...Position::AfterPort] },
    "pathname" => :path.to_proc,
    "search" => -> (url) { trim(url[Position::AfterPath...Position::AfterQuery]) },
    "hash" => -> (url) { trim(url[Position::AfterQuery..]) },
  }.freeze

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

    GETTERS.each do |getter, read|
      actual = read.call(result)
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

  # The expected failures of urltestdata.json: wpt.rs names a setter case
  # "<href> set <kind> to <value>", and those are not ported.
  def self.expected_failures
    UrlSuite.crate_test_file("expected_failures.txt").lines(chomp: true)
      .grep_v(/\A<.*> set [a-z]+ to </)
  end

  def test_the_cases_that_fail_are_exactly_urls_expected_failures
    expected = self.class.expected_failures
    failures = {}
    JSON.parse(UrlSuite.crate_test_file("urltestdata.json")).grep(Hash).each do |test|
      name = "<#{self.class.escape_default(test['input'])}>"
      name += " against <#{self.class.escape_default(test['base'])}>" if test["base"]
      error = run_url_test(test)
      failures[name] = error if error
    end

    assert_operator expected.size, :>, 30
    assert_empty failures.keys - expected, "unexpected failures: #{failures.except(*expected)}"
    assert_empty expected - failures.keys, "expected to fail but passed or did not run"
  end
end

#--
# SPDX-SnippetEnd
#++
