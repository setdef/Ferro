# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require_relative "global_hotkey/version"
require_relative "global_hotkey/ferro_global_hotkey"
require_relative "global_hotkey/error"
require_relative "global_hotkey/hotkey"
require_relative "global_hotkey/hot_key_state"
require_relative "global_hotkey/global_hot_key_event"
require_relative "global_hotkey/global_hot_key_event_receiver"
require_relative "global_hotkey/global_hot_key_manager"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, such as global hotkeys. Each Ferro gem binds one crate, keeps its
# names and behavior, and adds nothing of its own.
module Ferro
  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: Apache-2.0 OR MIT
  # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
  # SPDX-SnippetComment: the crate overview from global-hotkey 0.9.0
  #   src/lib.rs:5-51
  #++

  # Global hotkeys for desktop applications, through global-hotkey 0.9.0.
  #
  # A keyboard shortcut normally reaches only the window that has focus.
  # A launcher, a push-to-talk button, or a screenshot tool wants its
  # shortcut to work from anywhere, and each system offers that its own
  # way: Carbon hot keys on macOS, +RegisterHotKey+ on Windows, X11 key
  # grabs on Linux.
  #
  # This module binds global-hotkey (https://github.com/tauri-apps/global-hotkey)
  # one to one. Build a Hotkey::HotKey, register it with a
  # GlobalHotKeyManager, and read each press and release as a
  # GlobalHotKeyEvent from GlobalHotKeyEvent.receiver, or hand
  # GlobalHotKeyEvent.set_event_handler a block. It works on Windows,
  # macOS, and Linux (X11 only).
  #
  # Events need an event loop, as global-hotkey's own notes say. On
  # Windows a win32 event loop must be running on the thread. It doesn't
  # need to be the main thread, but you have to create the manager on the
  # same thread as the event loop. On macOS an event loop must be running
  # on the main thread, so you also need to create the manager on the main
  # thread. A windowed app's loop does this, such as the tao loop Tokra
  # runs. Without one, registering works and no event ever arrives. On
  # Linux global-hotkey runs a thread of its own, so events arrive with no
  # loop, but only from an X server.
  #
  # === Examples
  #
  #   require "ferro/global_hotkey"
  #
  #   hotkey = Ferro::GlobalHotkey::Hotkey
  #   manager = Ferro::GlobalHotkey::GlobalHotKeyManager.new
  #   shift_d = hotkey::HotKey.new(hotkey::Modifiers::SHIFT, hotkey::Code::KeyD)
  #   manager.register(shift_d)
  #
  #   # Inside your app's event loop:
  #   event = Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.recv
  #   puts "#{event.state.inspect} #{event.id}" if event.id == shift_d.id
  module GlobalHotkey
    private_constant :PLATFORM, :Native

    # The value in +result+, a native <tt>[:ok, value]</tt>, or the
    # exception a native <tt>[:error, path, message, hotkey]</tt> names,
    # raised. +path+ is a class path under this module.
    def self.settle(result) # :nodoc:
      case result
      in [:ok, value]
        value
      in [:error, String => path, String => message, parts]
        error_class = path.split("::").reduce(self) { |namespace, name| namespace.const_get(name, false) }
        raise error_class.new(message, Hotkey::HotKey.__send__(:from_parts, parts)) if parts

        raise error_class, message
      end
    end
    private_class_method :settle

    # The parts of +hotkey+ the native layer rebuilds the Rust value from:
    # its modifiers' bits, its key's name, and its id. Anything but a
    # Hotkey::HotKey raises +TypeError+ as Ruby words a wrong argument
    # type.
    def self.parts(hotkey) # :nodoc:
      raise TypeError, "wrong argument type #{hotkey.class} (expected #{Hotkey::HotKey})" unless hotkey.is_a?(Hotkey::HotKey)

      mods = hotkey.mods
      key = hotkey.key
      raise TypeError, "wrong argument type #{mods.class} (expected #{Hotkey::Modifiers})" unless mods.is_a?(Hotkey::Modifiers)
      raise TypeError, "wrong argument type #{key.class} (expected #{Hotkey::Code})" unless key.is_a?(Hotkey::Code)

      [mods.bits, key.to_s, hotkey.id]
    end
    private_class_method :parts

    # The event a native <tt>[id, state]</tt> pair describes.
    def self.event(pair) # :nodoc:
      id, state = pair
      GlobalHotKeyEvent.new(id:, state: HotKeyState.const_get(state, false))
    end
    private_class_method :event
  end

  #--
  # SPDX-SnippetEnd
  #++
end
