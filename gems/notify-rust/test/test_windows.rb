# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Windows toasts, through tauri-winrt-notification. Whether a CI runner's
# session shows toasts is unknown, so the test accepts a shown toast or
# notify-rust's own error for one that cannot show, and never waits: a
# wait blocks until a person answers.
class TestWindows < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def setup
    skip_unless_platform(:windows)
  end

  def test_show_returns_a_handle_that_reaches_its_notification_or_raises_msg
    handle = NotifyRust::Notification.new.summary("ferro-notify-rust test").timeout(0).show

    assert_kind_of NotifyRust::NotificationHandle, handle
    assert_equal "ferro-notify-rust test", handle.summary
    assert_same handle, handle.body("changed")
    assert_equal "changed", handle.body
  rescue NotifyRust::Error::Msg => e
    refute_empty e.message
  end
end
