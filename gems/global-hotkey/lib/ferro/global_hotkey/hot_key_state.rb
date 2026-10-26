# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

module Ferro
  module GlobalHotkey
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
    # SPDX-SnippetComment: HotKeyState and its docs from global-hotkey 0.9.0
    #   src/lib.rs:63-71
    #++

    # Describes the state of the Hotkey::HotKey: pressed or released.
    #
    # A push-to-talk button acts while the key is down and stops when it
    # comes up; a launcher acts once per press. Both need to know which
    # edge an event marks.
    #
    # Every GlobalHotKeyEvent carries one of these two values. global-hotkey
    # orders them as it declares them, Pressed before Released.
    #
    # Mirrors global-hotkey's +HotKeyState+ (<tt>src/lib.rs:63-71</tt>).
    #
    # === Example
    #
    #   event = Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.recv
    #   start_talking if event.state == Ferro::GlobalHotkey::HotKeyState::Pressed
    class HotKeyState
      include Comparable

      private_class_method :new

      # Creates the state named +name+. The two constants are the only
      # instances.
      #
      # [name] Symbol, the global-hotkey variant's name.
      # [index] Integer, its place in the declaration.
      def initialize(name, index)
        @name = name
        @index = index
        freeze
      end

      # The constant that holds this state.
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::HotKeyState::Pressed.inspect # => "Ferro::GlobalHotkey::HotKeyState::Pressed"
      def inspect
        "Ferro::GlobalHotkey::HotKeyState::#{@name}"
      end

      # Orders the states as global-hotkey derives +Ord+: Pressed, then
      # Released. +nil+ for anything but a HotKeyState.
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::HotKeyState::Pressed < Ferro::GlobalHotkey::HotKeyState::Released # => true
      def <=>(other)
        @index <=> other.index if other.is_a?(HotKeyState)
      end

      # The state's name, for Marshal: a dumped state loads as the same
      # constant.
      #
      # === Example
      #
      #   Marshal.load(Marshal.dump(Ferro::GlobalHotkey::HotKeyState::Pressed)).equal?(Ferro::GlobalHotkey::HotKeyState::Pressed) # => true
      def _dump(_level)
        @name.to_s
      end

      # The constant named +name+, for Marshal.
      #
      # [name] String, a dumped state's name.
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::HotKeyState._load("Released") # => Ferro::GlobalHotkey::HotKeyState::Released
      def self._load(name)
        case name
        when "Pressed" then Pressed
        when "Released" then Released
        else raise ArgumentError, "no HotKeyState named #{name.inspect}"
        end
      end

      # The state's place in global-hotkey's declaration.
      protected attr_reader :index

      # The hotkey is pressed (the key is down).
      Pressed = new(:Pressed, 0)

      # The hotkey is released (the key is up).
      Released = new(:Released, 1)
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
