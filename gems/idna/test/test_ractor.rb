# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# idna's values are plain data and the extension keeps no Ruby value in a
# static, so the extension is marked Ractor-safe and every value the gem
# makes is shareable (plan 006, decision 16). Without rb_ext_ractor_safe,
# every native call from a non-main Ractor raises Ractor::UnsafeError.
#
# On Windows the script runs in a child process, because of the Ruby 4.0
# barrier bug plan 001 found. Elsewhere it runs in this process.
class TestRactor < Minitest::Test
  include IdnaSuite

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

  def test_another_ractor_runs_idna
    result = run_script(<<~RUBY)
      Ractor.new do
        idna = Ferro::Idna
        [idna.domain_to_ascii_cow("Bücher.example", idna::AsciiDenyList::URL),
          idna::Uts46::AsciiDenyList.new(false, "_") == idna::AsciiDenyList::URL,
          idna::Punycode.encode_str("☕")]
      end.value
    RUBY

    assert_equal ["xn--bcher-kva.example", false, "53h"], result
  end

  def test_the_gems_values_are_shareable
    result = run_script(<<~RUBY)
      idna = Ferro::Idna
      values = [idna::AsciiDenyList::URL, idna::Uts46::AsciiDenyList.new(true, "_"), idna::Uts46::Uts46.new,
        idna::Uts46::Hyphens::Check, idna::Uts46::DnsLength::Verify]
      Ractor.new(Ractor.make_shareable(values)) do |list, custom, uts46, hyphens, length|
        uts46.to_ascii("a.example", custom, hyphens, length) + " " + (list == Ferro::Idna::AsciiDenyList::URL).to_s
      end.value
    RUBY

    assert_equal "a.example true", result
  end
end
