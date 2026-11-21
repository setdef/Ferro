# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Debug texts of what a real clipboard gives: a raised error, and the
# builders, which have none. The rest are in test_debug.rb.
class TestClipboardDebug < Minitest::Test
  include ClipboardSuite

  def test_a_raised_error_debugs_as_arboard_does
    clipboard.clear

    error = assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get_text }

    assert_equal %(ContentNotAvailable - "#{NOT_AVAILABLE}"), error.debug
  end

  # Clipboard, Get, Set, and Clear derive no Debug (src/lib.rs:70, :182-185,
  # :221-224, :267-270), and the base Error is no variant of arboard's: it
  # is raised for a panic, or for a variant a later arboard adds.
  def test_what_arboard_gives_no_debug_has_none
    [clipboard, clipboard.get, clipboard.set, clipboard.clear_with, Ferro::Arboard::Error.new].each do |value|
      refute_respond_to value, :debug
    end
  end
end
