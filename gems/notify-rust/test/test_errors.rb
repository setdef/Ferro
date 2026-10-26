# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# notify-rust's error kinds as classes. The native layer's classification
# of each kind is pinned by Rust tests (src/error.rs); these check the
# Ruby side and an error raised end to end.
class TestErrors < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def test_each_kind_is_an_error
    kinds = %i[Msg Parse SpecVersion Conversion ImplementationMissing]
    kinds += %i[Zbus Image] if PLATFORM == :linux
    kinds << :MacNotificationSys if PLATFORM == :macos

    kinds.each { |kind| assert_operator NotifyRust::Error.const_get(kind, false), :<, NotifyRust::Error }
    assert_operator NotifyRust::Error, :<, StandardError
  end

  def test_platform_kinds_exist_only_on_their_platform
    assert_equal PLATFORM == :linux, NotifyRust::Error.const_defined?(:Zbus, false)
    assert_equal PLATFORM == :linux, NotifyRust::Error.const_defined?(:Image, false)
    assert_equal PLATFORM == :linux, NotifyRust.const_defined?(:ImageError, false)
    assert_equal PLATFORM == :macos, NotifyRust::Error.const_defined?(:MacNotificationSys, false)
  end

  def test_implementation_missing_has_notify_rusts_message
    assert_equal 'No Dbus implementation available, please compile with either feature ="z" or feature="d"',
      NotifyRust::Error::ImplementationMissing.new.message
  end

  def test_an_error_from_notify_rust_arrives_as_its_class
    error = assert_raises(NotifyRust::Error) { urgency.try_from("") }

    assert_instance_of NotifyRust::Error::Conversion, error
    assert_equal 'Conversion Error: invalid input ""', error.message
  end

  def test_mac_notification_sys_errors_nest_under_their_kind
    skip_unless_platform(:macos)
    mac = NotifyRust::Error::MacNotificationSys

    assert_operator mac::Application::AlreadySet, :<, mac::Application
    assert_operator mac::Notification::UnableToDeliver, :<, mac::Notification
    assert_equal "Application 'a.b' can only be set once.", mac::Application::AlreadySet.new("a.b").message
    assert_equal "a.b", mac::Application::CouldNotSet.new("a.b").name
    assert_equal "Could not schedule notification", mac::Notification::UnableToSchedule.new.message
    assert_equal "Could not deliver notification", mac::Notification::UnableToDeliver.new.message
  end
end
