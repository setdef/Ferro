# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# The exception classes, and how the native layer's failures become them.
# The Rust tests pin each message global-hotkey builds.
class TestErrors < Minitest::Test
  include HotkeySuite

  Error = GlobalHotkey::Error

  VARIANTS = %i[
    OsError
    HotKeyParseError
    UnrecognizedHotKeyCode
    EmptyHotKeyToken
    UnexpectedHotKeyFormat
    FailedToRegister
    FailedToUnRegister
    AlreadyRegistered
    FailedToWatchMediaKeyEvent
  ].freeze

  private def settle(result)
    GlobalHotkey.__send__(:settle, result)
  end

  def test_every_variant_is_a_class_under_error
    assert_equal VARIANTS.sort, Error.constants(false).sort
    VARIANTS.each { |name| assert_operator Error.const_get(name), :<, Error }
    assert_operator Error, :<, StandardError
  end

  def test_a_failure_raises_the_class_at_its_path_with_its_message
    error = assert_raises(Error::FailedToRegister) do
      settle([:error, "Error::FailedToRegister", "Unable to register hotkey: x", nil])
    end
    assert_equal "Unable to register hotkey: x", error.message
    assert_raises(Error) { settle([:error, "Error", "global-hotkey panicked: boom", nil]) }
    assert_equal 7, settle([:ok, 7])
  end

  def test_a_failure_with_a_hotkey_carries_it
    shift_d = Hotkey::HotKey.new(Hotkey::Modifiers::SHIFT, Hotkey::Code::KeyD)
    error = assert_raises(Error::AlreadyRegistered) do
      settle([:error, "Error::AlreadyRegistered", "HotKey already registered", [0x200, "KeyD", shift_d.id]])
    end
    assert_equal shift_d, error.hotkey
    assert_nil Error::FailedToUnRegister.new("x").hotkey
  end

  def test_the_media_key_error_has_global_hotkeys_text
    assert_equal "Failed to watch media key event", Error::FailedToWatchMediaKeyEvent.new.message
  end

  def test_receive_errors_follow_crossbeam
    receiver = GlobalHotkey::GlobalHotKeyEventReceiver

    assert_operator receiver::TryRecvError::Empty, :<, receiver::TryRecvError
    assert_operator receiver::TryRecvError::Disconnected, :<, receiver::TryRecvError
    assert_operator receiver::RecvTimeoutError::Timeout, :<, receiver::RecvTimeoutError
    assert_operator receiver::RecvTimeoutError::Disconnected, :<, receiver::RecvTimeoutError
    assert_operator receiver::RecvError, :<, StandardError
  end
end
