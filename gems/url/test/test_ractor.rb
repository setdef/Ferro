# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# url's types are Send and Sync and the extension keeps no Ruby value in a
# static, so the extension is marked Ractor-safe, and a frozen Url and
# url's values may cross Ractors (plan 005, decision 18). Without
# rb_ext_ractor_safe, every native call from a non-main Ractor raises
# Ractor::UnsafeError.
#
# On Windows the script runs in a child process, because of the Ruby 4.0
# barrier bug plan 001 found. Elsewhere it runs in this process.
class TestRactor < Minitest::Test
  include UrlSuite

  private def run_script(script)
    return in_child(script) if Gem.win_platform?

    experimental = Warning[:experimental]
    Warning[:experimental] = false
    # A fresh binding each time, so one script's locals are not another's
    # outer variables, which a Ractor's block may not touch.
    eval(script, Object.new.instance_eval { binding })
  ensure
    Warning[:experimental] = experimental unless Gem.win_platform?
  end

  def test_another_ractor_parses_and_changes_urls
    result = run_script(<<~RUBY)
      Ractor.new do
        url = Ferro::Url::Url.parse("https://Bücher.example/a")
        url.query_pairs_mut.append_pair("q", "1")
        [url.as_str, url.host.to_s, url[Ferro::Url::Position::BeforePath..]]
      end.value
    RUBY

    assert_equal ["https://xn--bcher-kva.example/a?q=1", "xn--bcher-kva.example", "/a?q=1"], result
  end

  def test_a_frozen_url_and_urls_values_are_shareable
    result = run_script(<<~RUBY)
      url = Ferro::Url::Url.parse("https://example.com:8443/a")
      values = Ractor.make_shareable([url, url.origin, url.host, Ferro::Url::Position::AfterPath,
        Ferro::Url::SyntaxViolation::Backslash])
      Ractor.new(values) do |shared, origin, host, position, violation|
        [shared.join("b").as_str, origin.ascii_serialization, host.to_s, shared[...position], violation.to_s,
          shared.frozen?]
      end.value
    RUBY

    assert_equal [
      "https://example.com:8443/b",
      "https://example.com:8443",
      "example.com",
      "https://example.com:8443/a",
      "backslash",
      true,
], result
  end
end
