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
      settle([:error, "Error::FailedToRegister", "Unable to register hotkey: x", nil, nil])
    end
    assert_equal "Unable to register hotkey: x", error.message
    assert_raises(Error) { settle([:error, "Error", "global-hotkey panicked: boom", nil, nil]) }
    assert_equal 7, settle([:ok, 7])
  end

  def test_a_failure_with_a_hotkey_carries_it
    shift_d = Hotkey::HotKey.new(Hotkey::Modifiers::SHIFT, Hotkey::Code::KeyD)
    error = assert_raises(Error::AlreadyRegistered) do
      settle([:error, "Error::AlreadyRegistered", "HotKey already registered", [0x200, "KeyD", shift_d.id], nil])
    end
    assert_equal shift_d, error.hotkey
    assert_nil Error::FailedToUnRegister.new("x").hotkey
  end

  # global-hotkey's OsError holds its io::Error (src/error.rs:13-14).
  def test_an_os_error_carries_its_io_error
    skip "Unix errno values" if PLATFORM == :windows

    error = assert_raises(Error::OsError) do
      settle([:error, "Error::OsError", "Permission denied (os error 13)", nil, [13, "Permission denied (os error 13)"]])
    end

    assert_instance_of Errno::EACCES, error.io_error
    assert_equal 13, error.io_error.errno
    assert_equal "Permission denied (os error 13)", error.message
    assert_nil error.cause
  end

  def test_an_os_error_without_a_code_carries_an_io_error_with_rusts_text
    error = assert_raises(Error::OsError) do
      settle([:error, "Error::OsError", "custom", nil, [nil, "custom"]])
    end

    assert_instance_of IOError, error.io_error
    assert_equal "custom", error.io_error.message
  end

  def test_an_os_error_built_without_one_has_none
    assert_nil Error::OsError.new("x").io_error
    assert_nil Error::OsError.new.io_error
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
