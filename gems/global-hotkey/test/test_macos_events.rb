# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# Hotkey events on macOS, each in a child process, whose main thread makes
# the manager, as global-hotkey asks (src/lib.rs:15-18).
#
# A press reaches global-hotkey as a Carbon event: the window server
# matches the key against the table RegisterEventHotKey fills, and Carbon
# hands the application's event target a kEventClassKeyboard event of kind
# kEventHotKeyPressed or kEventHotKeyReleased, whose direct object is the
# EventHotKeyID registered with the key. global-hotkey's handler, which
# GlobalHotKeyManager.new installs on that target (macos/mod.rs:44-72),
# reads that id and sends the event on (:304-339). The child builds that
# very event with Carbon's CreateEvent and SetEventParameter, through
# Fiddle, and dispatches it with SendEventToEventTarget, so the crate's
# handler and the gem's delivery run for real, synchronously, and need no
# permission. SendEventToEventTarget answers noErr only when a handler
# took the event, and eventNotHandledErr (-9874) when none did, so the
# statuses show the crate's handler ran.
#
# The window server's match is left out. A key posted with CGEventPost did
# not fire the hotkey on GitHub's macOS 26 runner, where the process may
# post, and Apple documents no rule for when a posted key reaches the
# hotkey table, so no test here can count on it (plan 004, Follow-up:
# macOS delivery without the window server).
class TestMacosEvents < Minitest::Test
  include HotkeySuite

  # The child's Fiddle bindings: Carbon's event functions, and
  # CoreGraphics's check for permission to watch input.
  PRELUDE = <<~RUBY
    require "fiddle"
    G = Ferro::GlobalHotkey
    CG = Fiddle.dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    CARBON = Fiddle.dlopen("/System/Library/Frameworks/Carbon.framework/Carbon")
    def carbon(name, args, ret) = Fiddle::Function.new(CARBON[name], args, ret)
    LISTEN_ACCESS = Fiddle::Function.new(CG["CGPreflightListenEventAccess"], [], Fiddle::TYPE_CHAR)
    CREATE_EVENT = carbon("CreateEvent", [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT32_T, Fiddle::TYPE_UINT32_T,
      Fiddle::TYPE_DOUBLE, Fiddle::TYPE_UINT32_T, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT32_T)
    SET_PARAMETER = carbon("SetEventParameter", [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT32_T, Fiddle::TYPE_UINT32_T,
      Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT32_T)
    SEND = carbon("SendEventToEventTarget", [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT32_T)
    APPLICATION_TARGET = carbon("GetApplicationEventTarget", [], Fiddle::TYPE_VOIDP)
    RELEASE_EVENT = carbon("ReleaseEvent", [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)

    # The four-character codes global-hotkey uses (macos/ffi.rs:63-72):
    # kEventClassKeyboard, kEventHotKeyPressed and kEventHotKeyReleased,
    # kEventParamDirectObject, and typeEventHotKeyID; and the signature it
    # registers its hotkeys with (macos/mod.rs:102-112).
    KEYBOARD = "keyb".unpack1("N")
    KINDS = { Pressed: 5, Released: 6 }.freeze
    DIRECT_OBJECT = "----".unpack1("N")
    HOTKEY_ID_TYPE = "hkid".unpack1("N")
    SIGNATURE = "htrs".unpack1("N")

    # Dispatches the Carbon event a press or release of the hotkey +id+
    # becomes, and returns SendEventToEventTarget's status.
    def dispatch(id, state)
      out = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, Fiddle::RUBY_FREE)
      created = CREATE_EVENT.call(nil, KEYBOARD, KINDS.fetch(state), 0.0, 0, out)
      raise "CreateEvent failed: \#{created}" unless created.zero?

      event = out.ptr
      begin
        # EventHotKeyID: an OSType signature, then a UInt32 id
        # (macos/ffi.rs:78-81).
        hotkey_id = [SIGNATURE, id].pack("L2")
        set = SET_PARAMETER.call(event, DIRECT_OBJECT, HOTKEY_ID_TYPE, hotkey_id.bytesize, hotkey_id)
        raise "SetEventParameter failed: \#{set}" unless set.zero?

        SEND.call(event, APPLICATION_TARGET.call)
      ensure
        RELEASE_EVENT.call(event)
      end
    end

    MANAGER = G::GlobalHotKeyManager.new
    HOTKEY = G::Hotkey::HotKey.from_str("ctrl+alt+shift+super+F19")
  RUBY

  def setup
    skip_unless_platform(:macos)
  end

  def test_the_receiver_gets_the_press_and_the_release
    (statuses, id, events), = in_child(PRELUDE + <<~RUBY)
      statuses = %i[Pressed Released].map { |state| dispatch(HOTKEY.id, state) }
      [statuses, HOTKEY.id, G::GlobalHotKeyEvent.receiver.try_iter.map(&:debug)]
    RUBY

    assert_equal [0, 0], statuses
    assert_equal ["GlobalHotKeyEvent { id: #{id}, state: Pressed }", "GlobalHotKeyEvent { id: #{id}, state: Released }"],
      events
  end

  def test_the_handler_gets_the_events_and_the_receiver_none
    (statuses, id, events, leftover), = in_child(PRELUDE + <<~RUBY)
      queue = Thread::Queue.new
      G::GlobalHotKeyEvent.set_event_handler { |event| queue << event }
      statuses = %i[Pressed Released].map { |state| dispatch(HOTKEY.id, state) }
      events = Array.new(2) { queue.pop(timeout: 10) }.compact
      [statuses, HOTKEY.id, events.map(&:debug), G::GlobalHotKeyEvent.receiver.try_iter.to_a.size]
    RUBY

    assert_equal [0, 0], statuses
    assert_equal ["GlobalHotKeyEvent { id: #{id}, state: Pressed }", "GlobalHotKeyEvent { id: #{id}, state: Released }"],
      events
    assert_equal 0, leftover
  end

  # Without a manager no handler is on the application's target, so the
  # same events go unhandled and nothing arrives: what the tests above
  # receive comes from global-hotkey's handler, not from the dispatch.
  def test_without_a_manager_the_events_go_unhandled
    (statuses, events), = in_child(PRELUDE.sub("MANAGER = G::GlobalHotKeyManager.new\n", "") + <<~RUBY)
      statuses = %i[Pressed Released].map { |state| dispatch(HOTKEY.id, state) }
      [statuses, G::GlobalHotKeyEvent.receiver.try_iter.to_a]
    RUBY

    assert_equal [[-9874, -9874], []], [statuses, events]
  end

  # A media key makes global-hotkey install a CGEventTap
  # (macos/mod.rs:141-148, :197-216), which macOS refuses a process that
  # may not watch input; global-hotkey then returns
  # FailedToWatchMediaKeyEvent. The child asks first and skips, without
  # registering, when this process may watch input, since the tap would
  # then take the media keys of the whole session. A macOS that grants
  # the tap anyway is reported as a skip too, after unregistering.
  def test_a_media_key_without_input_access_fails_to_watch
    outcome, = in_child(PRELUDE + <<~RUBY)
      media = G::Hotkey::HotKey.new(nil, G::Hotkey::Code::MediaPlayPause)
      if LISTEN_ACCESS.call == 1
        :may_listen
      else
        begin
          MANAGER.register(media)
          MANAGER.unregister(media)
          :tap_allowed
        rescue G::Error::FailedToWatchMediaKeyEvent => e
          [e.class.name, e.message, e.debug]
        end
      end
    RUBY
    skip "this process may watch input, so the media-key tap would succeed" if outcome == :may_listen
    skip "this macOS allowed the media-key tap without input access" if outcome == :tap_allowed

    assert_equal [
      "Ferro::GlobalHotkey::Error::FailedToWatchMediaKeyEvent",
      "Failed to watch media key event",
      "FailedToWatchMediaKeyEvent",
], outcome
  end
end
