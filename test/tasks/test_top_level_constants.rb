# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"

# ferro-time defines Ferro::Time and Ferro::Time::Date, so inside module
# Ferro a bare Time or Date can name the binding, not Ruby's class (ADR 001,
# amendment of 2026-10-27). RuboCop's Lint/ConstantResolution refuses one in
# every other gem's lib; RuboCop does not read RBS, so this test refuses one
# in every other gem's signatures.
class TestTopLevelConstants < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  # A Time or Date with no namespace before it: not ::Time, not
  # Ferro::Time::Date, and not part of a longer name.
  BARE = /(?<![\w:])(?:Time|Date)(?!\w)/

  # The bare Time and Date references in +source+, an RBS file's text, as
  # "line: text", skipping the SPDX header's comment lines.
  private def bare_references(source)
    source.each_line.with_index(1).filter_map do |line, number|
      next if line.lstrip.start_with?("#")

      "#{number}: #{line.strip}" if line.match?(BARE)
    end
  end

  def test_the_check_finds_a_bare_time_or_date_and_nothing_else
    assert_equal ["1: def at: (Time time) -> Date"], bare_references("def at: (Time time) -> Date\n")
    assert_empty bare_references("# Time\ndef at: (::Time time) -> ::Date\n")
    assert_empty bare_references("def at: (Ferro::Time::Date date, DateTime d, Times t) -> void\n")
  end

  def test_signatures_outside_ferro_time_name_ruby_s_time_and_date_from_the_top
    files = Dir.chdir(ROOT) { `git ls-files -- "gems/*/sig/*.rbs" "gems/*/sig/**/*.rbs"`.split("\n") }
    files = files.uniq.reject { |path| path.start_with?("gems/time/") }
    refute_empty files
    offenses = files.flat_map do |path|
      bare_references(File.read(File.join(ROOT, path))).map { |reference| "#{path}:#{reference}" }
    end
    assert_empty offenses, "write ::Time and ::Date (ADR 001, amendment of 2026-10-27)"
  end
end
