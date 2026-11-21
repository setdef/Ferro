# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# macOS, through mac-notification-sys, but for showing a notification,
# which desktop/test_macos.rb does. Its application hook is set once per
# process, so the tests that touch it run in a child.
class TestMacOS < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def setup
    skip_unless_platform(:macos)
  end

  def test_the_first_set_application_wins
    outcome, = in_child(<<~RUBY)
      first = Ferro::NotifyRust.set_application("com.apple.finder")
      second = begin
        Ferro::NotifyRust.set_application("com.apple.finder")
      rescue Ferro::NotifyRust::Error::MacNotificationSys::Application::AlreadySet => e
        [e.class.name, e.message, e.name, e.debug]
      end
      [first, second]
    RUBY

    assert_nil outcome.first
    # set_application returns mac-notification-sys's own error, and the
    # exception keeps its Debug text.
    assert_equal [
      "Ferro::NotifyRust::Error::MacNotificationSys::Application::AlreadySet",
      "Application 'com.apple.finder' can only be set once.",
      "com.apple.finder",
      'Application(AlreadySet("com.apple.finder"))',
], outcome.last
  end

  def test_an_unknown_bundle_cannot_be_set
    outcome, = in_child(<<~RUBY)
      begin
        Ferro::NotifyRust.set_application("no.such.bundle.ferro")
      rescue Ferro::NotifyRust::Error::MacNotificationSys::Application => e
        [e.class.name, e.message, e.name]
      end
    RUBY

    assert_equal [
      "Ferro::NotifyRust::Error::MacNotificationSys::Application::CouldNotSet",
      %(Could not set application 'no.such.bundle.ferro', using default "com.apple.Terminal"),
      "no.such.bundle.ferro",
],
      outcome
  end

  def test_get_bundle_identifier_or_default_asks_applescript
    assert_equal "com.apple.finder", NotifyRust.get_bundle_identifier_or_default("Finder")
    assert_equal "com.apple.Finder", NotifyRust.get_bundle_identifier_or_default("No Such App Ferro")
  end

  def test_scheduling_in_the_past_raises_mac_notification_sys_error
    notification = NotifyRust::Notification.new.summary("too late")
    error = assert_raises(NotifyRust::Error::MacNotificationSys::Notification::ScheduleInThePast) do
      notification.schedule_raw(0.0)
    end

    assert_equal "Can not schedule notification in the past", error.message
    assert_raises(NotifyRust::Error::MacNotificationSys::Notification) { notification.schedule(Time.now - 60) }
    assert_raises(TypeError) { notification.schedule(0) }
  end

  def test_macos_has_no_hints_or_urgency_and_urgency_is_deprecated
    notification = NotifyRust::Notification.new

    refute_respond_to notification, :hint
    refute_respond_to notification, :urgency
    refute_respond_to notification, :app_id
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    _, warnings = capture_io { NotifyRust::Urgency }

    assert_includes warnings, "constant Ferro::NotifyRust::Urgency is deprecated"
  ensure
    Warning[:deprecated] = deprecated
  end
end
