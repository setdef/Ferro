# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Outside a desktop run, showing a notification, and starting the Linux
# server, raise instead of reaching this session
# (doc/contributors/plan/014.md). This reads each method's owner, so it
# shows nothing even where a guard is missing.
class TestDesktopGuard < Minitest::Test
  include NotifySuite

  def test_outside_a_desktop_run_showing_a_notification_is_refused
    names = DESKTOP.map { |owner, name, _| [owner, name] }

    assert_includes names, [Ferro::NotifyRust::Notification, :show]
    assert_includes names, [Ferro::NotifyRust::Notification, :show_async] if PLATFORM == :linux
    assert_includes names, [Server.singleton_class, :start]
    names.each { |owner, name| assert Desktop.guarded?(owner, name), "#{owner}##{name}" }
  end
end
