# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# Real hotkey events on macOS, each in a child process, whose main thread
# makes the manager and runs Carbon's event loop, as global-hotkey asks
# (src/lib.rs:15-18). A child posts Control-Option-Shift-Command-F19, with
# the modifiers as the key events' flags, so no modifier key is left down,
# through CoreGraphics with Fiddle. Posting needs the Accessibility
# permission and watching media keys a permission of its own, so each
# test skips, saying which, when this process lacks or holds it.
class TestMacosEvents < Minitest::Test
  include HotkeySuite

  # The child's Fiddle bindings: CoreGraphics to post keys and ask for the
  # permissions, and Carbon's RunCurrentEventLoop to pump the main thread.
  PRELUDE = <<~RUBY
    require "fiddle"
    G = Ferro::GlobalHotkey
    CG = Fiddle.dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    CARBON = Fiddle.dlopen("/System/Library/Frameworks/Carbon.framework/Carbon")
    def cg(name, args, ret) = Fiddle::Function.new(CG[name], args, ret)
    POST_ACCESS = cg("CGPreflightPostEventAccess", [], Fiddle::TYPE_CHAR)
    LISTEN_ACCESS = cg("CGPreflightListenEventAccess", [], Fiddle::TYPE_CHAR)
    KEY_EVENT = cg("CGEventCreateKeyboardEvent", [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SHORT, Fiddle::TYPE_CHAR],
      Fiddle::TYPE_VOIDP)
    SET_FLAGS = cg("CGEventSetFlags", [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG], Fiddle::TYPE_VOID)
    POST = cg("CGEventPost", [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    RELEASE = Fiddle::Function.new(CG["CFRelease"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    RUN_LOOP = Fiddle::Function.new(CARBON["RunCurrentEventLoop"], [Fiddle::TYPE_DOUBLE], Fiddle::TYPE_INT)

    # kVK_F19, and Shift, Control, Option, and Command as CGEventFlags.
    F19 = 0x50
    FLAGS = 0x20000 | 0x40000 | 0x80000 | 0x100000

    def press_f19
      [true, false].each do |down|
        event = KEY_EVENT.call(nil, F19, down ? 1 : 0)
        SET_FLAGS.call(event, FLAGS)
        POST.call(0, event) # kCGHIDEventTap
        RELEASE.call(event)
      end
    end

    # Pumps the main thread until the block answers true or ten seconds
    # pass.
    def pump_until
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      RUN_LOOP.call(0.05) until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    end

    MANAGER = G::GlobalHotKeyManager.new
    HOTKEY = G::Hotkey::HotKey.from_str("ctrl+alt+shift+super+F19")
  RUBY

  def setup
    skip_unless_platform(:macos)
  end

  def test_the_receiver_gets_the_press_and_the_release
    (allowed, id, events), = in_child(PRELUDE + <<~RUBY)
      next_value = [false, nil, []]
      if POST_ACCESS.call == 1
        MANAGER.register(HOTKEY)
        receiver = G::GlobalHotKeyEvent.receiver
        events = []
        press_f19
        pump_until { events.concat(receiver.try_iter.to_a).size >= 2 }
        MANAGER.unregister(HOTKEY)
        next_value = [true, HOTKEY.id, events.map(&:debug)]
      end
      next_value
    RUBY
    skip "posting keys needs the Accessibility permission, which this process lacks" unless allowed

    assert_equal ["GlobalHotKeyEvent { id: #{id}, state: Pressed }", "GlobalHotKeyEvent { id: #{id}, state: Released }"],
      events
  end

  def test_the_handler_gets_the_events_and_the_receiver_none
    (allowed, id, events, leftover), = in_child(PRELUDE + <<~RUBY)
      next_value = [false, nil, [], 0]
      if POST_ACCESS.call == 1
        queue = Thread::Queue.new
        G::GlobalHotKeyEvent.set_event_handler { |event| queue << event }
        MANAGER.register(HOTKEY)
        press_f19
        pump_until { queue.size >= 2 }
        MANAGER.unregister(HOTKEY)
        events = Array.new(2) { queue.pop(timeout: 1) }.compact
        next_value = [true, HOTKEY.id, events.map(&:debug), G::GlobalHotKeyEvent.receiver.try_iter.to_a.size]
      end
      next_value
    RUBY
    skip "posting keys needs the Accessibility permission, which this process lacks" unless allowed

    assert_equal ["GlobalHotKeyEvent { id: #{id}, state: Pressed }", "GlobalHotKeyEvent { id: #{id}, state: Released }"],
      events
    assert_equal 0, leftover
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
