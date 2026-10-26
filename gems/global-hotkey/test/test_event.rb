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
    assert_equal "Ferro::GlobalHotkey::HotKeyState::Released", State::Released.inspect
    assert_nil State::Pressed <=> :Pressed
    assert_raises(NoMethodError) { State.new(:Pressed, 0) }
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

  def test_set_event_handler_takes_a_handler_or_a_block_not_both
    assert_raises(ArgumentError) { Event.set_event_handler(proc {}) { nil } }
    assert_raises(TypeError) { Event.set_event_handler(42) }
  end
end
