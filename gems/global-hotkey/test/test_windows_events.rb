# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# A real hotkey event on Windows: a child process registers
# Ctrl+Alt+Shift+F24 on its main thread, presses it with SendInput, and
# runs a message loop with Fiddle, PeekMessageW and DispatchMessageW, so
# WM_HOTKEY reaches global-hotkey's hidden window (windows/mod.rs:147-175).
# The release comes from global-hotkey's own polling thread. A runner with
# no interactive desktop injects nothing, and then the test skips; so does
# one that takes the input but delivers no WM_HOTKEY within ten seconds,
# saying so, since no event at all says more about the runner's desktop
# than about the binding. A press without its release fails.
class TestWindowsEvents < Minitest::Test
  include HotkeySuite

  SCRIPT = <<~RUBY
    require "fiddle"
    require "fiddle/import"

    module User32
      extend Fiddle::Importer
      dlload "user32.dll"
      extern "unsigned int SendInput(unsigned int, void*, int)"
      extern "int PeekMessageW(void*, void*, unsigned int, unsigned int, unsigned int)"
      extern "int TranslateMessage(void*)"
      extern "long long DispatchMessageW(void*)"
    end

    G = Ferro::GlobalHotkey
    manager = G::GlobalHotKeyManager.new
    hotkey = G::Hotkey::HotKey.from_str("ctrl+alt+shift+F24")
    manager.register(hotkey)

    # An INPUT for a key (winuser.h): type 1 (INPUT_KEYBOARD), then a
    # KEYBDINPUT at offset 8, 40 bytes in all on x64.
    keys = [0x11, 0x12, 0x10, 0x87] # VK_CONTROL, VK_MENU, VK_SHIFT, VK_F24
    inputs = keys.map { |vk| [vk, 0] } + keys.reverse.map { |vk| [vk, 2] } # 2: KEYEVENTF_KEYUP
    buffer = inputs.map { |vk, flags| [1, 0, vk, 0, flags, 0, 0, 0, 0].pack("L L S S L L L Q Q") }.join
    sent = User32.SendInput(inputs.size, Fiddle::Pointer[buffer], 40)

    events = []
    if sent == inputs.size
      message = Fiddle::Pointer.malloc(48, Fiddle::RUBY_FREE)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      receiver = G::GlobalHotKeyEvent.receiver
      while events.size < 2 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        while User32.PeekMessageW(message, nil, 0, 0, 1) != 0 # PM_REMOVE
          User32.TranslateMessage(message)
          User32.DispatchMessageW(message)
        end
        events.concat(receiver.try_iter.to_a)
        sleep 0.02
      end
    end
    manager.unregister(hotkey)
    [sent, inputs.size, hotkey.id, events.map { |event| [event.id, event.state.inspect] }]
  RUBY

  def test_sendinput_delivers_the_press_and_the_release
    skip_unless_platform(:windows)

    (sent, wanted, id, events), = in_child(SCRIPT)
    skip "SendInput injected #{sent} of #{wanted} inputs: no interactive desktop" unless sent == wanted
    skip "SendInput injected every input, but no WM_HOTKEY arrived in 10 s: this desktop does not deliver hotkeys" if events.empty?

    assert_equal [[id, "Ferro::GlobalHotkey::HotKeyState::Pressed"], [id, "Ferro::GlobalHotkey::HotKeyState::Released"]],
      events
  end
end
