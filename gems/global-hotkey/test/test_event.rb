# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# HotKeyState and GlobalHotKeyEvent, the values an event carries.
class TestEvent < Minitest::Test
  include HotkeySuite

  State = GlobalHotkey::HotKeyState
  Event = GlobalHotkey::GlobalHotKeyEvent

  def test_states_order_as_global_hotkey_declares_them
    assert_operator State::Pressed, :<, State::Released
    assert_nil State::Pressed <=> :Pressed
    assert_raises(NoMethodError) { State.new(:Pressed, 0) }
  end

  # global-hotkey derives Debug for HotKeyState and GlobalHotKeyEvent
  # (src/lib.rs:63, :74); Rust formats both. inspect stays Ruby's.
  def test_debug_is_global_hotkeys_derived_debug
    assert_equal "Released", State::Released.debug
    assert_equal "GlobalHotKeyEvent { id: 7, state: Pressed }", Event.new(id: 7, state: State::Pressed).debug
    assert_match(/\A#<Ferro::GlobalHotkey::HotKeyState:0x\h+ @name=:Released, @index=1>\z/, State::Released.inspect)
    assert_match(/\A#<data Ferro::GlobalHotkey::GlobalHotKeyEvent id=7, state=#<Ferro/, Event.new(id: 7, state: State::Pressed).inspect)
    assert_raises(TypeError) { Event.new(id: 7, state: :Pressed).debug }
    assert_raises(RangeError) { Event.new(id: -1, state: State::Pressed).debug }
  end

  # HotKeyState's integer value is Rust's `as u32`: its declaration order.
  def test_a_states_integer_value_is_its_declaration_order
    assert_equal [0, 1], [State::Pressed.to_i, State::Released.to_i]
  end

  def test_events_order_by_id_then_state
    first = Event.new(id: 1, state: State::Released)
    second = Event.new(id: 2, state: State::Pressed)
    pressed = Event.new(id: 1, state: State::Pressed)

    assert_equal [pressed, first, second], [second, first, pressed].sort
    assert_equal pressed, Event.new(1, State::Pressed)
    assert_nil pressed <=> 1
  end

  def test_states_and_events_survive_marshal
    event = Event.new(id: 1, state: State::Released)
    copy = Marshal.load(Marshal.dump(event))

    assert_same State::Released, copy.state
    assert_equal({ event => 1 }, { copy => 1 })
    assert_raises(ArgumentError) { State._load("Held") }
  end

  def test_an_event_is_a_shareable_value
    event = Event.new(id: 1, state: State::Pressed)

    assert_equal [1, State::Pressed], [event.id, event.state]
    assert Ractor.shareable?(Ractor.make_shareable(event))
  end

  def test_the_native_pair_becomes_an_event
    assert_equal Event.new(id: 5, state: State::Released), GlobalHotkey.__send__(:event, [5, :Released])
  end

  # The handler thread on every platform, with no key press: the native
  # handler_forward hook hands an event to the very handler
  # set_event_handler installs, as global-hotkey would (src/lib.rs:126-132),
  # and the thread reads it through the native wait. The hooks exist only
  # in the repository's build (the test-hooks feature).
  def test_the_handler_thread_gets_each_forwarded_event
    (events, pending), = in_child(<<~RUBY)
      g = Ferro::GlobalHotkey
      native = g.const_get(:Native)
      queue = Thread::Queue.new
      g::GlobalHotKeyEvent.set_event_handler { |event| queue << event }
      native.__send__(:handler_forward, 9, :Pressed)
      native.__send__(:handler_forward, 9, :Released)
      events = Array.new(2) { queue.pop(timeout: 10) }
      [events.compact.map(&:debug), native.__send__(:handler_pending)]
    RUBY

    assert_equal ["GlobalHotKeyEvent { id: 9, state: Pressed }", "GlobalHotKeyEvent { id: 9, state: Released }"], events
    assert_equal 0, pending
  end

  # A handler that raises ends its thread, as a Rust handler's panic ends
  # global-hotkey's X11 thread on Linux; later events are dropped rather
  # than kept where nobody reads them, so none waits in the channel.
  def test_after_a_handler_raises_later_events_are_dropped
    (status, pending), errors = in_child(<<~RUBY)
      g = Ferro::GlobalHotkey
      native = g.const_get(:Native)
      g::GlobalHotKeyEvent.set_event_handler { |_| raise "handler failed" }
      thread = g::GlobalHotKeyEvent.instance_variable_get(:@handler_thread)
      native.__send__(:handler_forward, 1, :Pressed)
      thread.join(10) rescue nil
      3.times { native.__send__(:handler_forward, 1, :Released) }
      [thread.status.inspect, native.__send__(:handler_pending)]
    RUBY

    assert_equal ["nil", 0], [status, pending]
    assert_includes errors, "handler failed"
  end

  # Kernel#loop rescues StopIteration, which would end the handler's
  # thread as if it had finished. The hook forwards an event, so no key
  # press is needed; the loop, the thread, and Ruby's report are the gem's
  # own.
  def test_a_handler_that_raises_stop_iteration_ends_its_thread_with_a_report
    (status, raised), errors = in_child(<<~RUBY)
      native = Ferro::GlobalHotkey.const_get(:Native)
      Ferro::GlobalHotkey::GlobalHotKeyEvent.set_event_handler { |_| raise StopIteration, "handler stopped" }
      thread = Ferro::GlobalHotkey::GlobalHotKeyEvent.instance_variable_get(:@handler_thread)
      native.__send__(:handler_forward, 1, :Pressed)
      thread.join(10) rescue nil
      raised = begin
        thread.value
        nil
      rescue StopIteration => e
        e.message
      end
      [thread.status.inspect, raised]
    RUBY

    assert_equal ["nil", "handler stopped"], [status, raised]
    assert_includes errors, "handler stopped"
  end

  def test_set_event_handler_takes_a_handler_or_a_block_not_both
    assert_raises(ArgumentError) { Event.set_event_handler(proc {}) { nil } }
    assert_raises(TypeError) { Event.set_event_handler(42) }
  end
end
