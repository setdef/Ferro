# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# The exception classes, and how the native layer's failures become them.
# The Rust tests pin each message and Debug text global-hotkey builds.
class TestErrors < Minitest::Test
  include HotkeySuite

  Error = GlobalHotkey::Error
  Parse = Hotkey::HotKeyParseError

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

  # The variants whose Rust field is a String (src/error.rs:15-24,
  # src/hotkey.rs:38-46), each with its Debug name.
  TEXT_VARIANTS = {
    Error::HotKeyParseError => "HotKeyParseError",
    Error::UnrecognizedHotKeyCode => "UnrecognizedHotKeyCode",
    Error::EmptyHotKeyToken => "EmptyHotKeyToken",
    Error::UnexpectedHotKeyFormat => "UnexpectedHotKeyFormat",
    Error::FailedToRegister => "FailedToRegister",
    Parse::UnsupportedKey => "UnsupportedKey",
    Parse::EmptyToken => "EmptyToken",
    Parse::InvalidFormat => "InvalidFormat",
  }.freeze

  private def settle(result)
    GlobalHotkey.__send__(:settle, result)
  end

  private def shift_d
    Hotkey::HotKey.new(Hotkey::Modifiers::SHIFT, Hotkey::Code::KeyD)
  end

  def test_every_variant_is_a_class_under_error
    assert_equal VARIANTS.sort, Error.constants(false).sort
    VARIANTS.each { |name| assert_operator Error.const_get(name), :<, Error }
    assert_operator Error, :<, StandardError
  end

  def test_a_failure_raises_the_class_at_its_path_with_its_message
    error = assert_raises(Error::FailedToRegister) do
      settle([:error, "Error::FailedToRegister", "Unable to register hotkey: x", [:text, "x"]])
    end
    assert_equal "Unable to register hotkey: x", error.message
    assert_equal ["x"], error.to_a
    assert_raises(Error) { settle([:error, "Error", "global-hotkey panicked: boom", nil]) }
    assert_equal 7, settle([:ok, 7])
  end

  # A tuple variant's field is positional, as Rust leaves it (ADR 001,
  # amendment of 2026-11-05): deconstruct and to_a, so an array pattern
  # reads as Rust's does, and no reader the crate does not name.
  def test_a_failure_with_a_hotkey_carries_it_by_position
    error = assert_raises(Error::AlreadyRegistered) do
      settle([:error, "Error::AlreadyRegistered", "HotKey already registered", [:hotkey, [0x200, "KeyD", shift_d.id]]])
    end

    assert_equal [shift_d], error.deconstruct
    assert_equal [shift_d], error.to_a
    matched = case error
              in Error::AlreadyRegistered[hotkey] then hotkey
    end
    assert_equal shift_d, matched
    refute_respond_to error, :hotkey
    assert_equal [nil], Error::FailedToUnRegister.new("x").to_a
  end

  def test_every_text_variant_carries_its_string_and_its_debug
    TEXT_VARIANTS.each do |error_class, name|
      error = error_class.new("message", "a \"part\"")

      assert_equal ["a \"part\""], error.deconstruct, name
      assert_equal "message", error.message
      assert_equal "#{name}(\"a \\\"part\\\"\")", error.debug
      assert_equal "#{name}(\"x\")", Class.new(error_class).new(nil, "x").debug
      assert_raises(TypeError) { error_class.new("no field").debug }
    end
  end

  def test_the_hotkey_variants_debug_as_global_hotkey_derives
    debug = "HotKey { mods: Modifiers(SHIFT), key: KeyD, id: 33554454 }"

    assert_equal "AlreadyRegistered(#{debug})", Error::AlreadyRegistered.new(nil, shift_d).debug
    assert_equal "FailedToUnRegister(#{debug})", Error::FailedToUnRegister.new(nil, shift_d).debug
    assert_raises(TypeError) { Error::AlreadyRegistered.new("x", "not a hotkey").debug }
  end

  # global-hotkey's OsError holds its io::Error (src/error.rs:13-14).
  def test_an_os_error_carries_its_io_error
    skip "Unix errno values" if PLATFORM == :windows

    error = assert_raises(Error::OsError) do
      settle([:error, "Error::OsError", "Permission denied (os error 13)", [:os, 13, "Permission denied (os error 13)"]])
    end

    io_error, = error.to_a
    assert_instance_of Errno::EACCES, io_error
    assert_equal 13, io_error.errno
    assert_equal "Permission denied (os error 13)", error.message
    assert_nil error.cause
    refute_respond_to error, :io_error
    assert_equal 'OsError(Os { code: 13, kind: PermissionDenied, message: "Permission denied" })', error.debug
  end

  # On Windows the field is an IOError, which keeps no code; settle hands
  # the code to the error, so debug shows the crate's Os error. Deleting
  # that hand-off fails here.
  def test_settle_keeps_a_windows_os_errors_code_for_debug
    skip "Windows has no errno" unless PLATFORM == :windows

    error = assert_raises(Error::OsError) do
      settle([:error, "Error::OsError", "Access is denied. (os error 5)", [:os, 5, "Access is denied. (os error 5)"]])
    end

    assert_instance_of IOError, error.to_a.first
    assert_match(/\AOsError\(Os \{ code: 5, /, error.debug)
  end

  # On Windows, and for an io::Error without a code, the field is an
  # IOError, which keeps no code; debug still shows the error the crate
  # made, from the code the native layer gave.
  def test_an_os_error_without_an_errno_debugs_from_the_crates_code
    error = assert_raises(Error::OsError) do
      settle([:error, "Error::OsError", "custom", [:os, nil, "custom"]])
    end

    io_error, = error.to_a
    assert_instance_of IOError, io_error
    assert_equal "custom", io_error.message
    assert_equal 'OsError(Custom { kind: Other, error: "custom" })', error.debug

    coded = Error::OsError.new("denied", IOError.new("denied"))
    coded.__send__(:raw_os_error=, 13)
    assert_match(/\AOsError\(Os \{ code: 13, /, coded.debug)
  end

  def test_an_os_error_built_without_one_has_none
    assert_equal [nil], Error::OsError.new("x").to_a
    assert_equal [nil], Error::OsError.new.deconstruct
    assert_raises(TypeError) { Error::OsError.new("x").debug }
  end

  def test_the_media_key_error_has_global_hotkeys_text_and_debug
    error = Error::FailedToWatchMediaKeyEvent.new

    assert_equal "Failed to watch media key event", error.message
    assert_equal "FailedToWatchMediaKeyEvent", error.debug
    refute_respond_to error, :deconstruct
  end

  def test_the_unrecognized_code_error_debugs_as_keyboard_types_derives
    assert_equal "UnrecognizedCodeError", Hotkey::UnrecognizedCodeError.new.debug
  end

  def test_the_base_error_is_no_variant_and_has_no_debug
    refute_respond_to Error.new("x"), :debug
  end

  def test_inspect_stays_rubys
    assert_equal "#<Ferro::GlobalHotkey::Error::FailedToRegister: m>", Error::FailedToRegister.new("m", "F24").inspect
  end

  def test_receive_errors_follow_crossbeam
    receiver = GlobalHotkey::GlobalHotKeyEventReceiver

    assert_operator receiver::TryRecvError::Empty, :<, receiver::TryRecvError
    assert_operator receiver::TryRecvError::Disconnected, :<, receiver::TryRecvError
    assert_operator receiver::RecvTimeoutError::Timeout, :<, receiver::RecvTimeoutError
    assert_operator receiver::RecvTimeoutError::Disconnected, :<, receiver::RecvTimeoutError
    assert_operator receiver::RecvError, :<, StandardError
  end

  # crossbeam derives Debug for its receive errors (src/err.rs:53-74).
  def test_receive_errors_debug_as_crossbeam_derives
    receiver = GlobalHotkey::GlobalHotKeyEventReceiver

    assert_equal "RecvError", receiver::RecvError.new.debug
    assert_equal "Empty", receiver::TryRecvError::Empty.new.debug
    assert_equal "Disconnected", receiver::TryRecvError::Disconnected.new.debug
    assert_equal "Timeout", receiver::RecvTimeoutError::Timeout.new.debug
    assert_equal "Disconnected", receiver::RecvTimeoutError::Disconnected.new.debug
  end
end
