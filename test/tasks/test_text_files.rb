# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"

# Every tracked file is text. Git treats a file holding a NUL or another
# control byte as binary and skips its line-ending conversion on a Windows
# checkout, where RuboCop then reports that one file's line endings and
# every other file's pass; two stray NULs in a ported comment failed the
# Windows gate that way. A test that needs such a byte writes it as an
# escape, such as "\0".
class TestTextFiles < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  # A control byte other than tab, line feed, and carriage return.
  CONTROL = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/n

  # The control bytes in +bytes+, as "line: byte" for each line that has one.
  private def control_bytes(bytes)
    bytes.b.each_line.with_index(1).filter_map do |line, number|
      found = line.scan(CONTROL)
      "#{number}: #{found.uniq.map(&:ord).inspect}" unless found.empty?
    end
  end

  def test_the_check_finds_a_control_byte_and_nothing_else
    assert_equal ["2: [0]"], control_bytes("fine\tline\r\nbad \0 line\n")
    assert_empty control_bytes("tab\tand CR LF\r\n\"\\0\" escaped\n")
  end

  def test_every_tracked_file_is_text
    files = Dir.chdir(ROOT) { `git ls-files -z`.split("\0") }
    refute_empty files
    offenders = files.filter_map do |path|
      full = File.join(ROOT, path)
      next unless File.file?(full)

      lines = control_bytes(File.binread(full))
      "#{path} (#{lines.join(', ')})" unless lines.empty?
    end
    assert_empty offenders, "these tracked files hold control bytes, so git treats them as binary"
  end
end
