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

  # ErrorKind::Conversion holds the reason, and its Display adds the
  # prefix (src/error.rs:44, 68).
  def test_conversion_builds_notify_rusts_message_around_its_reason
    assert_equal 'Conversion Error: invalid input "x"', NotifyRust::Error::Conversion.new('invalid input "x"').message
    assert_equal "Conversion Error: ", NotifyRust::Error::Conversion.new.message
  end

  def test_an_error_from_notify_rust_arrives_as_its_class
    error = assert_raises(NotifyRust::Error) { urgency.try_from("") }

    assert_instance_of NotifyRust::Error::Conversion, error
    assert_equal 'Conversion Error: invalid input ""', error.message
  end

  # An exception raised for an error notify-rust returned keeps that
  # error's Debug text, which Rust formatted (src/error.rs:15-16, :21-22);
  # inspect stays Ruby's.
  def test_an_error_from_notify_rust_keeps_its_debug_text
    error = assert_raises(NotifyRust::Error::Conversion) { urgency.try_from("urgent") }

    assert_equal 'Error { kind: Conversion("invalid input \"urgent\"") }', error.debug
    assert_equal '#<Ferro::NotifyRust::Error::Conversion: Conversion Error: invalid input "urgent">', error.inspect
  end

  # One Ruby code makes stands for the error notify-rust would build from
  # the same text, where the variant holds nothing else; a variant that
  # holds another crate's value, and a panic, have no Rust value to show.
  def test_an_error_ruby_makes_debugs_as_notify_rust_would_where_it_can
    error = NotifyRust::Error

    assert_equal 'Error { kind: Msg("invalid subpath") }', error::Msg.new("invalid subpath").debug
    assert_equal 'Error { kind: SpecVersion("0.9") }', error::SpecVersion.new("0.9").debug
    assert_equal 'Error { kind: Conversion("x") }', error::Conversion.new("x").debug
    assert_equal 'Error { kind: Conversion("42") }', error::Conversion.new(42).debug, "the reason as message reads it"
    assert_equal "Error { kind: ImplementationMissing }", error::ImplementationMissing.new.debug
    assert_nil error::Parse.new("Parsing Error: x").debug
    assert_nil error.new("notify-rust panicked: boom").debug
    assert_nil error::Zbus.new("no bus").debug if PLATFORM == :linux
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

  # Raised by schedule_raw, the error is notify-rust's, wrapping
  # mac-notification-sys's, and keeps that Debug text.
  def test_a_mac_notification_sys_error_keeps_its_debug_text
    skip_unless_platform(:macos)
    error = assert_raises(NotifyRust::Error::MacNotificationSys::Notification::ScheduleInThePast) do
      NotifyRust::Notification.new.summary("too late").schedule_raw(0.0)
    end

    assert_equal "Error { kind: MacNotificationSys(Notification(ScheduleInThePast)) }", error.debug
  end
end
