# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# global-hotkey's values and channel are Send and Sync, so the extension is
# marked Ractor-safe, and a HotKey, Modifiers, Code, or receiver may cross
# Ractors (plan 004, decision 13). Without rb_ext_ractor_safe, every
# native call from a non-main Ractor raises Ractor::UnsafeError.
#
# On Windows the script runs in a child process, because of the Ruby 4.0
# barrier bug plan 001 found: a GC inside a Ractor waits forever while the
# main Ractor has a sleeping thread, and Minitest and the watchdog keep
# some. Elsewhere it runs in this process.
class TestRactor < Minitest::Test
  include HotkeySuite

  private def run_script(script)
    return in_child(script).first if PLATFORM == :windows

    experimental = Warning[:experimental]
    Warning[:experimental] = false
    eval(script, TOPLEVEL_BINDING)
  ensure
    Warning[:experimental] = experimental unless PLATFORM == :windows
  end

  def test_another_ractor_parses_and_writes_hotkeys_through_global_hotkey
    text = run_script(<<~RUBY)
      Ractor.new do
        hotkey = Ferro::GlobalHotkey::Hotkey::HotKey.from_str("alt+shift+F19")
        [hotkey.to_s, hotkey.mods.inspect, hotkey.matches(hotkey.mods, hotkey.key)]
      end.value
    RUBY

    assert_equal ["shift+alt+F19", "Ferro::GlobalHotkey::Hotkey::Modifiers(ALT | SHIFT)", true], text
  end

  def test_another_ractor_reads_a_shared_receiver
    message = run_script(<<~RUBY)
      shared = Ractor.make_shareable(Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver)
      Ractor.new(shared) do |receiver|
        receiver.try_recv
      rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::TryRecvError::Empty => e
        e.message
      end.value
    RUBY

    assert_equal "receiving on an empty channel", message
  end

  # The handler lives on the module, which only the main Ractor may
  # change; the refusal comes before global-hotkey is asked.
  def test_set_event_handler_belongs_to_the_main_ractor
    error = run_script(<<~RUBY)
      Ractor.new do
        Ferro::GlobalHotkey::GlobalHotKeyEvent.set_event_handler(nil)
      rescue Ractor::IsolationError => e
        e.class.name
      end.value
    RUBY

    assert_equal "Ractor::IsolationError", error
  end
end
