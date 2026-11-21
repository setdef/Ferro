# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Outside a desktop run, opening a clipboard raises instead of opening the
# session's (doc/contributors/plan/014.md). This reads the method's owner,
# so it opens nothing even where the guard is missing.
class TestDesktopGuard < Minitest::Test
  def test_outside_a_desktop_run_opening_a_clipboard_is_refused
    assert Desktop.guarded?(Ferro::Arboard::Clipboard.singleton_class, :new)
  end
end
