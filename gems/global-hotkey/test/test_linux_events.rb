# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# Real hotkey events on Linux: a child process registers a hotkey on the
# suite's private X server, xdotool presses it there through XTEST, and
# global-hotkey's X11 thread reports the press and the release. Each runs
# in its own child, as global-hotkey's handler is set once per process.
class TestLinuxEvents < Minitest::Test
  include HotkeySuite

  # The child's setup: a manager and the hotkey, registered, and a way to
  # press it on the private server.
  PRELUDE = <<~RUBY
    G = Ferro::GlobalHotkey
    MANAGER = G::GlobalHotKeyManager.new
    HOTKEY = G::Hotkey::HotKey.from_str("ctrl+alt+shift+F24")
    MANAGER.register(HOTKEY)
    def press
      system("xdotool", "key", "--delay", "100", "ctrl+alt+shift+F24") or raise "xdotool failed"
    end
    def described(events)
      events.map { |event| [event.id, event.state.inspect] }
    end
  RUBY

  def setup
    skip_unless_platform(:linux)
    require_x_server
  end

  private def run_child(script)
    in_child(PRELUDE + script, XServer.env)
  end

  private def press_and_release(id)
    [[id, "Ferro::GlobalHotkey::HotKeyState::Pressed"], [id, "Ferro::GlobalHotkey::HotKeyState::Released"]]
  end

  def test_the_receiver_gets_the_press_and_the_release
    (id, events), = run_child(<<~RUBY)
      press
      receiver = G::GlobalHotKeyEvent.receiver
      events = Array.new(2) { receiver.recv_timeout(10) }
      MANAGER.unregister(HOTKEY)
      [HOTKEY.id, described(events)]
    RUBY

    assert_equal press_and_release(id), events
  end

  def test_an_unregistered_hotkey_sends_nothing
    events, = run_child(<<~RUBY)
      MANAGER.unregister(HOTKEY)
      press
      sleep 0.5
      G::GlobalHotKeyEvent.receiver.try_iter.to_a.size
    RUBY

    assert_equal 0, events
  end

  # The handler gets the events instead of the receiver, and a second
  # set_event_handler changes nothing (src/lib.rs:112-124).
  def test_the_first_handler_gets_the_events_and_the_receiver_none
    (id, events, leftover), = run_child(<<~RUBY)
      queue = Thread::Queue.new
      G::GlobalHotKeyEvent.set_event_handler { |event| queue << event }
      G::GlobalHotKeyEvent.set_event_handler { |_| raise "the second handler ran" }
      press
      events = Array.new(2) { queue.pop(timeout: 10) }
      sleep 0.3
      [HOTKEY.id, described(events.compact), G::GlobalHotKeyEvent.receiver.try_iter.to_a.size]
    RUBY

    assert_equal press_and_release(id), events
    assert_equal 0, leftover
  end

  # A callable object is a handler as a block is.
  def test_a_callable_handler_gets_the_events
    (id, events), = run_child(<<~RUBY)
      queue = Thread::Queue.new
      G::GlobalHotKeyEvent.set_event_handler(queue.method(:push))
      press
      [HOTKEY.id, described(Array.new(2) { queue.pop(timeout: 10) }.compact)]
    RUBY

    assert_equal press_and_release(id), events
  end

  # set_event_handler(nil) keeps events on the receiver, and fixes the
  # choice: a later handler is ignored.
  def test_no_handler_keeps_events_on_the_receiver
    (id, events, called), = run_child(<<~RUBY)
      G::GlobalHotKeyEvent.set_event_handler(nil)
      called = []
      G::GlobalHotKeyEvent.set_event_handler { |event| called << event }
      press
      receiver = G::GlobalHotKeyEvent.receiver
      events = Array.new(2) { receiver.recv_timeout(10) }
      [HOTKEY.id, described(events), called.size]
    RUBY

    assert_equal press_and_release(id), events
    assert_equal 0, called
  end

  # Once global-hotkey sends an event, its cell holds "no handler"
  # (src/lib.rs:126-132), so a handler set after that is ignored.
  def test_a_handler_set_after_an_event_is_ignored
    (id, events, called), = run_child(<<~RUBY)
      receiver = G::GlobalHotKeyEvent.receiver
      press
      2.times { receiver.recv_timeout(10) }
      called = Thread::Queue.new
      G::GlobalHotKeyEvent.set_event_handler { |event| called << event }
      press
      events = Array.new(2) { receiver.recv_timeout(10) }
      [HOTKEY.id, described(events), called.size]
    RUBY

    assert_equal press_and_release(id), events
    assert_equal 0, called
  end

  # An exception in the handler ends its thread, which Ruby reports; later
  # events are dropped, not sent to the receiver.
  def test_a_handler_that_raises_ends_and_later_events_are_dropped
    (status, leftover), errors = run_child(<<~RUBY)
      G::GlobalHotKeyEvent.set_event_handler { |_| raise "handler failed" }
      thread = G::GlobalHotKeyEvent.instance_variable_get(:@handler_thread)
      press
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      sleep 0.05 while thread.alive? && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      press
      sleep 0.5
      [thread.status.inspect, G::GlobalHotKeyEvent.receiver.try_iter.to_a.size]
    RUBY

    assert_equal ["nil", 0], [status, leftover]
    assert_includes errors, "handler failed"
  end
end
