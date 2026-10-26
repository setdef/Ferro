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
    # SPDX-SnippetComment: GlobalHotKeyEvent, receiver, set_event_handler,
    #   and their docs from global-hotkey 0.9.0 src/lib.rs:36-45, 73-133
    #++

    # Describes a global hotkey event emitted when a Hotkey::HotKey is
    # pressed or released.
    #
    # A hotkey fires while your app is in the background, on whatever
    # thread the system reports keys on. Your code wants each press as a
    # plain value it can match against the hotkeys it registered.
    #
    # Each event holds the #id of the hotkey, the same as
    # Hotkey::HotKey#id, and its #state. Read events from the channel
    # receiver returns, or have set_event_handler call your block with
    # each one. Events arrive only while the system's event loop runs, as
    # GlobalHotkey describes.
    #
    # Mirrors global-hotkey's +GlobalHotKeyEvent+ (<tt>src/lib.rs:73-133</tt>).
    #
    # === Examples
    #
    #   receiver = Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver
    #   begin
    #     event = receiver.try_recv
    #     puts "#{event.id} #{event.state.inspect}"
    #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::TryRecvError::Empty
    #     # No hotkey since the last look.
    #   end
    #
    #   Ferro::GlobalHotkey::GlobalHotKeyEvent.set_event_handler do |event|
    #     quit if event.id == quit_hotkey.id
    #   end
    class GlobalHotKeyEvent < Data.define(:id, :state)
      include Comparable

      # :attr_reader: id
      # Id of the associated Hotkey::HotKey, an Integer. Mirrors
      # <tt>GlobalHotKeyEvent::id</tt>.

      # :attr_reader: state
      # State of the associated Hotkey::HotKey, a HotKeyState. Mirrors
      # <tt>GlobalHotKeyEvent::state</tt>.

      # Orders events as global-hotkey derives +Ord+: by #id, then #state.
      # +nil+ for anything but a GlobalHotKeyEvent.
      #
      # [other] Object.
      #
      # === Example
      #
      #   event = Ferro::GlobalHotkey::GlobalHotKeyEvent
      #   pressed = Ferro::GlobalHotkey::HotKeyState::Pressed
      #   event.new(id: 1, state: pressed) < event.new(id: 2, state: pressed) # => true
      def <=>(other)
        [id, state] <=> [other.id, other.state] if other.is_a?(GlobalHotKeyEvent)
      end

      class << self
        # The event channel's receiver, which can be used to listen for
        # global hotkey events.
        #
        # This will not receive any events if set_event_handler has been
        # called with a handler.
        #
        # Every receiver reads the same channel, which lives as long as
        # the process. Mirrors <tt>GlobalHotKeyEvent::receiver</tt>
        # (<tt>src/lib.rs:102-110</tt>).
        #
        # === Example
        #
        #   Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.try_iter.each { |event| p event }
        def receiver
          GlobalHotKeyEventReceiver.__send__(:new)
        end

        # Sets a handler to be called for new events. Useful for
        # implementing a custom event sender.
        #
        # Calling this with a handler will not send new events to the
        # channel receiver reads.
        #
        # The handler is a block, or any object that responds to +call+,
        # not both; +nil+, or neither, means none, and events keep going
        # to receiver. global-hotkey keeps the choice in a cell set once:
        # the first call decides for the life of the process, and later
        # calls change nothing. Once global-hotkey has sent any event, the
        # cell holds "no handler", so a call after that changes nothing
        # either.
        #
        # global-hotkey runs its handler on the thread that saw the key,
        # where no Ruby code can run. So the gem's handler only passes each
        # event to a Ruby thread it starts here, which calls yours with the
        # event, once it can take the global VM lock. An exception your
        # handler raises ends that thread, and Ruby reports it as it
        # reports any thread's; later events are dropped, as global-hotkey
        # never returns them to the receiver. Call this from the main
        # Ractor: the handler lives on this module, which other Ractors
        # cannot change.
        #
        # Mirrors <tt>GlobalHotKeyEvent::set_event_handler</tt>
        # (<tt>src/lib.rs:112-124</tt>).
        #
        # [handler] An object that responds to +call+ with the event, or
        # +nil+.
        #
        # === Examples
        #
        #   Ferro::GlobalHotkey::GlobalHotKeyEvent.set_event_handler { |event| queue << event }
        #
        #   Ferro::GlobalHotkey::GlobalHotKeyEvent.set_event_handler(method(:on_hotkey))
        def set_event_handler(handler = nil, &block)
          raise ArgumentError, "give a handler or a block, not both" if handler && block

          handler ||= block
          raise TypeError, "wrong argument type #{handler.class} (expected a callable)" unless handler.nil? || handler.respond_to?(:call)

          unless defined?(@handler_chosen)
            @handler_chosen = true
            @handler_thread = start_handler(handler) if handler
          end
          Native.set_event_handler(!handler.nil?)
          nil
        end

        # The Ruby thread that calls +handler+ with each event the native
        # handler passes along, until +handler+ raises.
        private def start_handler(handler)
          Thread.new do
            Thread.current.name = "ferro-global-hotkey handler"
            loop { handler.call(GlobalHotkey.__send__(:event, GlobalHotkey.__send__(:settle, Native.handler_recv))) }
          ensure
            Native.handler_close
          end
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
