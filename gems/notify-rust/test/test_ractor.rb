# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# notify-rust's Notification is Send and Sync, so the extension is marked
# Ractor-safe and a frozen Notification may cross Ractors (plan 003,
# decision 14). Without rb_ext_ractor_safe, every native call from a
# non-main Ractor raises Ractor::UnsafeError.
#
# On Windows the script runs in a child process, because of the Ruby 4.0
# barrier bug plan 001 found: a GC inside a Ractor waits forever while the
# main Ractor has a sleeping thread, and Minitest and the watchdog keep
# some. Elsewhere it runs in this process.
class TestRactor < Minitest::Test
  include NotifySuite

  private def run_script(script)
    return in_child(script).first if PLATFORM == :windows

    experimental = Warning[:experimental]
    Warning[:experimental] = false
    eval(script, TOPLEVEL_BINDING)
  ensure
    Warning[:experimental] = experimental unless PLATFORM == :windows
  end

  def test_another_ractor_reads_a_shared_notification_through_notify_rust
    summary = run_script(<<~RUBY)
      shared = Ractor.make_shareable(Ferro::NotifyRust::Notification.new.summary("shared").freeze)
      Ractor.new(shared) { |notification| [notification.summary, notification.finalize.body("copied").body] }.value
    RUBY

    assert_equal %w[shared copied], summary
  end

  def test_another_ractor_builds_notifications_and_converts_values
    built = run_script(<<~RUBY)
      Ractor.new do
        [Ferro::NotifyRust::Notification.new.summary("built").timeout(0).timeout.inspect,
          Ferro::NotifyRust::Timeout.from_str("42").value]
      end.value
    RUBY

    assert_equal ["Ferro::NotifyRust::Timeout::Never", 42], built
  end
end
