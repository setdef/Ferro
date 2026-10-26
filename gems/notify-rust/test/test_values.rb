# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# notify-rust's enums and their conversions, which every platform has. The
# Urgency tests port notify-rust 4.18.2's tests/conversion.rs, and the
# Timeout ones its doc tests (src/timeout.rs:5-12, :28-33,
# src/notification.rs:341-355).
class TestValues < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def test_urgency_has_three_frozen_constants
    assert_equal %w[Low Normal Critical].map { |name| "Ferro::NotifyRust::Urgency::#{name}" },
      [urgency::Low, urgency::Normal, urgency::Critical].map(&:inspect)
    assert [urgency::Low, urgency::Normal, urgency::Critical].all?(&:frozen?)
    assert_raises(NoMethodError) { urgency.new(:Low) }
  end

  def test_urgency_from_int
    assert_equal urgency::Low, urgency.from(0)
    assert_equal urgency::Normal, urgency.from(1)
    assert_equal urgency::Critical, urgency.from(2)
    assert_equal urgency::Critical, urgency.from(900)
    assert_equal urgency::Critical, urgency.from((2 ** 64) - 1)
    assert_raises(RangeError) { urgency.from(-1) }
  end

  def test_urgency_from_option_int
    assert_equal urgency::Normal, urgency.from(nil)
  end

  def test_urgency_from_str
    assert_equal urgency::Low, urgency.try_from("low")
    assert_equal urgency::Low, urgency.try_from("lo")
    assert_equal urgency::Normal, urgency.try_from("medium")
    assert_equal urgency::Normal, urgency.try_from("Normal")
    assert_equal urgency::Normal, urgency.try_from("NoRmaL")
    assert_equal urgency::Critical, urgency.try_from("High")
    assert_equal urgency::Critical, urgency.try_from("Hi")
    assert_equal urgency::Critical, urgency.try_from("Critical")
  end

  def test_an_unknown_urgency_raises_notify_rusts_conversion_error
    error = assert_raises(NotifyRust::Error::Conversion) { urgency.try_from("urgent") }

    assert_equal 'Conversion Error: invalid input "urgent"', error.message
    assert_raises(TypeError) { urgency.try_from(:low) }
  end

  def test_timeout_parses_as_notify_rust_does
    assert_equal NotifyRust::Timeout::Default, NotifyRust::Timeout.from_str("default")
    assert_equal NotifyRust::Timeout::Never, NotifyRust::Timeout.from_str("never")
    assert_equal NotifyRust::Timeout::Milliseconds.new(42), NotifyRust::Timeout.from_str("42")
    error = assert_raises(ArgumentError) { NotifyRust::Timeout.from_str("soon") }
    assert_equal "invalid digit found in string", error.message
  end

  def test_timeout_from_i32
    assert_equal NotifyRust::Timeout::Milliseconds.new(234), NotifyRust::Timeout.from(234)
    assert_equal NotifyRust::Timeout::Default, NotifyRust::Timeout.from(-234)
    assert_equal NotifyRust::Timeout::Never, NotifyRust::Timeout.from(0)
    assert_raises(RangeError) { NotifyRust::Timeout.from(2 ** 31) }
  end

  def test_timeout_as_the_specification_sends_it
    assert_equal(-1, NotifyRust::Timeout::Default.to_i)
    assert_equal 0, NotifyRust::Timeout::Never.to_i
    assert_equal 6000, NotifyRust::Timeout::Milliseconds.new(6000).to_i
    # Rust's `as i32` wraps; notify-rust sends this to the server as -1.
    assert_equal(-1, NotifyRust::Timeout::Milliseconds.new((2 ** 32) - 1).to_i)
    assert_raises(RangeError) { NotifyRust::Timeout::Milliseconds.new(2 ** 32).to_i }
  end

  def test_timeout_defaults_to_default
    assert_same NotifyRust::Timeout::Default, NotifyRust::Timeout.default
    assert_kind_of NotifyRust::Timeout, NotifyRust::Timeout::Milliseconds.new(1)
  end

  def test_close_reason_from_the_specifications_codes
    assert_same NotifyRust::CloseReason::Expired, NotifyRust::CloseReason.from(1)
    assert_same NotifyRust::CloseReason::Dismissed, NotifyRust::CloseReason.from(2)
    assert_same NotifyRust::CloseReason::CloseAction, NotifyRust::CloseReason.from(3)
    assert_equal NotifyRust::CloseReason::Other.new(4), NotifyRust::CloseReason.from(4)
    assert_equal NotifyRust::CloseReason::Other.new(0), NotifyRust::CloseReason.from(0)
    assert_equal "Ferro::NotifyRust::CloseReason::Expired", NotifyRust::CloseReason::Expired.inspect
  end

  def test_notification_response_from_a_key_is_an_action
    assert_equal NotifyRust::NotificationResponse::Action.new("ok"), NotifyRust::NotificationResponse.from("ok")
    assert NotifyRust::NotificationResponse::Default.is_default_action
    refute NotifyRust::NotificationResponse.from("default").is_default_action
    closed = NotifyRust::NotificationResponse::Closed.new(NotifyRust::CloseReason::Dismissed)

    refute closed.is_default_action
    assert_equal NotifyRust::CloseReason::Dismissed, closed.reason
  end

  def test_action_response_from_a_key_is_custom
    assert_equal NotifyRust::ActionResponse::Custom.new("default"), NotifyRust::ActionResponse.from("default")
    assert_kind_of NotifyRust::ActionResponse, NotifyRust::ActionResponse::Closed.new(NotifyRust::CloseReason::Expired)
  end

  def test_notification_id_from_a_number_or_a_string
    assert_equal NotifyRust::NotificationId::Xdg.new(42), NotifyRust::NotificationId.from(42)
    assert_equal NotifyRust::NotificationId::Mac.new("my-app.status"), NotifyRust::NotificationId.from("my-app.status")
    assert_raises(RangeError) { NotifyRust::NotificationId.from(2 ** 32) }
  end

  def test_hint_from_key_val
    hint = NotifyRust::Hint

    assert_equal hint::ActionIcons.new(true), hint.from_key_val("action-icons", "true")
    assert_equal hint::Category.new("email"), hint.from_key_val("category", "email")
    assert_equal hint::DesktopEntry.new("firefox"), hint.from_key_val("desktop-entry", "firefox")
    assert_equal hint::ImagePath.new("/a.png"), hint.from_key_val("image-path", "/a.png")
    assert_equal hint::Resident.new(false), hint.from_key_val("resident", "false")
    assert_equal hint::SoundFile.new("/a.oga"), hint.from_key_val("sound-file", "/a.oga")
    assert_equal hint::SoundName.new("bell"), hint.from_key_val("sound-name", "bell")
    assert_equal hint::SuppressSound.new(true), hint.from_key_val("suppress-sound", "true")
    assert_equal hint::Transient.new(true), hint.from_key_val("transient", "true")
    assert_equal hint::X.new(-12), hint.from_key_val("x", "-12")
    assert_equal hint::Y.new(7), hint.from_key_val("y", "7")
  end

  def test_hint_from_key_val_raises_notify_rusts_reasons
    hint = NotifyRust::Hint

    assert_equal "unknown name", assert_raises(ArgumentError) { hint.from_key_val("urgency", "low") }.message
    assert_equal "provided string was not `true` or `false`",
      assert_raises(ArgumentError) { hint.from_key_val("resident", "yes") }.message
    assert_equal "invalid digit found in string", assert_raises(ArgumentError) { hint.from_key_val("x", "left") }.message
  end

  def test_hint_accessors_answer_as_notify_rusts_do
    hint = NotifyRust::Hint

    assert hint::Transient.new(true).as_bool
    assert_nil hint::Category.new("email").as_bool
    assert_equal 3, hint::Y.new(3).as_i32
    assert_nil hint::CustomInt.new("value", 3).as_i32
    assert_equal "bell", hint::SoundName.new("bell").as_str
    assert_nil hint::Category.new("email").as_str
    assert_nil hint::Custom.new("k", "v").as_str
    assert_nil hint::Invalid.as_bool
    assert_nil hint::Urgency.new(urgency::Low).as_str
  end

  def test_hints_compare_by_value
    assert_equal NotifyRust::Hint::Category.new("email"), NotifyRust::Hint::Category.new("email")
    refute_equal NotifyRust::Hint::Category.new("email"), NotifyRust::Hint::DesktopEntry.new("email")
    assert_equal 1, [NotifyRust::Hint::Resident.new(true), NotifyRust::Hint::Resident.new(true)].uniq.size
    assert_equal "Ferro::NotifyRust::Hint::Invalid", NotifyRust::Hint::Invalid.inspect
  end

  def test_server_information_holds_four_strings
    info = NotifyRust::ServerInformation.new(name: "dunst", vendor: "knopwob", version: "1.12", spec_version: "1.2")

    assert_equal %w[dunst knopwob 1.12 1.2], info.to_h.values
  end
end
