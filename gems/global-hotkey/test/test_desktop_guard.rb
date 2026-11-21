# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# Outside a desktop run, making a manager in the test process raises
# instead of registering with the session (doc/contributors/plan/014.md).
# This reads the method's owner, so it makes nothing even where the guard
# is missing.
class TestDesktopGuard < Minitest::Test
  def test_outside_a_desktop_run_making_a_manager_is_refused
    assert Desktop.guarded?(Ferro::GlobalHotkey::GlobalHotKeyManager.singleton_class, :new)
  end
end
