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
# SPDX-SnippetComment: ported from idna 1.1.0 tests/uts46.rs and
#   tests/deprecated.rs, over its IdnaTestV2.txt
#++

# idna's UTS 46 conformance tests, ported: every line of Unicode's
# IdnaTestV2.txt through Uts46#to_unicode, #to_ascii, and #process with
# both sinks, and through the deprecated Config, with idna's own skips.
#
# idna 1.1.0 ships IdnaTestV2.txt for Unicode 16.0.0, and the
# idna_adapter 1.2.2 that Cargo locks reads ICU4X 2.4's newer Unicode
# data, which assigns some code points those lines expect to be
# disallowed (V7). idna's own suite, run against this lockfile, fails
# exactly the lines below (plan 006, Results). Each test checks that the
# binding fails those lines and no others, so the Ruby answers match the
# Rust ones line for line.
class TestUts46Conformance < Minitest::Test
  include IdnaSuite

  # The lines idna's own tests/uts46.rs fails at this lockfile.
  RUST_FAILS_UTS46 = [3386, 4219, 4220, 4405, 5858, 5859, 5860].freeze

  # The lines idna's own tests/deprecated.rs fails at this lockfile.
  RUST_FAILS_DEPRECATED = [
    3384,
    3385,
    3386,
    4219,
    4220,
    4401,
    4402,
    4403,
    4404,
    4405,
    4408,
    4409,
    4410,
    4411,
    5858,
    5859,
    5860,
].freeze

  # One line of IdnaTestV2.txt.
  Line = Data.define(:number, :source, :to_unicode, :to_unicode_status, :to_ascii_n, :to_ascii_n_status,
    :to_ascii_t, :to_ascii_t_status)

  def self.lines
    @lines ||= IdnaSuite.crate_test_file("IdnaTestV2.txt").each_line.with_index(1).filter_map do |raw, number|
      raw = raw.chomp
      next if raw.empty? || raw.start_with?("#")

      parse(raw.split("#", 2).first, number)
    end
  end

  def self.parse(line, number)
    pieces = line.split(";").map(&:strip)
    source = unescape(pieces.shift)
    to_unicode = unescape(pieces.shift)
    to_unicode = source if to_unicode.empty?
    to_unicode_status = status(pieces.shift)
    to_ascii_n = pieces.shift
    to_ascii_n = to_unicode if to_ascii_n.empty?
    to_ascii_n_status = pieces.shift
    to_ascii_n_status = to_ascii_n_status.empty? ? to_unicode_status : status(to_ascii_n_status)
    to_ascii_t = pieces.shift.to_s
    to_ascii_t = to_ascii_n if to_ascii_t.empty?
    to_ascii_t_status = pieces.shift.to_s
    to_ascii_t_status = to_ascii_t_status.empty? ? to_ascii_n_status : status(to_ascii_t_status)
    Line.new(number, source, to_unicode, to_unicode_status, to_ascii_n, to_ascii_n_status, to_ascii_t,
      to_ascii_t_status)
  end

  # idna's unescape: \uXXXX becomes the character, or stays as text when
  # it names a surrogate.
  def self.unescape(input)
    input.gsub(/\\(\\|u(\h{4}))/) do
      next "\\" if Regexp.last_match(1) == "\\"

      code = Regexp.last_match(2).to_i(16)
      code.between?(0xD800, 0xDFFF) ? "\\u#{Regexp.last_match(2).upcase}" : code.chr(Encoding::UTF_8)
    end
  end

  def self.status(text)
    return [] if text.nil? || text.empty? || text == "[]"

    text.delete_prefix("[").delete_suffix("]").split(", ")
  end

  # idna's check: an expected error (not one the test ignores) means no
  # result; no expected error means exactly the expected text. Answers
  # whether the line passes.
  private def check(expected, statuses, actual, ignore = -> (_) { false })
    if statuses.any?
      statuses.any?(&ignore) || actual.nil?
    else
      actual == expected
    end
  end

  private def ok(pair)
    text, errors = pair
    errors ? nil : text
  end

  private def or_nil
    yield
  rescue Idna::Errors
    nil
  end

  def test_every_line_through_uts46
    uts46 = Uts46::Uts46.new
    list = Uts46::AsciiDenyList::STD3
    lines = self.class.lines

    assert_operator lines.size, :>, 6000
    x4_2 = -> (error) { error == "X4_2" }
    failing = lines.reject do |line|
      unicode, ascii = simultaneous(uts46, line.source)
      [
        check(line.to_unicode, line.to_unicode_status,
          ok(uts46.to_unicode(line.source, list, Uts46::Hyphens::Check)), x4_2),
        check(line.to_ascii_n, line.to_ascii_n_status,
          or_nil { uts46.to_ascii(line.source, list, Uts46::Hyphens::Check, Uts46::DnsLength::Verify) }),
        check(line.to_unicode, line.to_unicode_status, unicode, x4_2),
        check(line.to_ascii_n, line.to_ascii_n_status, ascii),
      ].all?
    end

    assert_equal RUST_FAILS_UTS46, failing.map(&:number)
  end

  # idna's simultaneous ToUnicode and ToASCII through process, with both
  # sinks (tests/uts46.rs:90-140).
  private def simultaneous(uts46, source)
    display = +""
    lookup = +""
    outcome = uts46.process(source, Uts46::AsciiDenyList::STD3, Uts46::Hyphens::Check,
      Uts46::ErrorPolicy::MarkErrors, -> (*) { true }, display, lookup)
    case outcome
    when Uts46::ProcessingSuccess::Passthrough
      [source, Uts46.verify_dns_length(source, false) ? source : nil]
    else
      ascii = lookup.empty? ? display : lookup
      [display, Uts46.verify_dns_length(ascii, false) ? ascii : nil]
    end
  rescue Uts46::ProcessingError::ValidityError
    [nil, nil]
  end

  def test_every_line_through_the_deprecated_config
    config = config_class.default.use_std3_ascii_rules(true).verify_dns_length(true).check_hyphens(true)
    unicode_ignores = -> (error) { %w[X4_2 V2].include?(error) }
    ascii_ignores = -> (error) { %w[V2 A4_2].include?(error) }
    failing = self.class.lines.reject do |line|
      [
        check(line.to_unicode, line.to_unicode_status,
          ok(config.transitional_processing(false).to_unicode(line.source)), unicode_ignores),
        check(line.to_ascii_n, line.to_ascii_n_status,
          or_nil { config.transitional_processing(false).to_ascii(line.source) }, ascii_ignores),
        check(line.to_ascii_t, line.to_ascii_t_status,
          or_nil { config.transitional_processing(true).to_ascii(line.source) }, ascii_ignores),
      ].all?
    end

    assert_equal RUST_FAILS_DEPRECATED, failing.map(&:number)
  end
end

#--
# SPDX-SnippetEnd
#++
