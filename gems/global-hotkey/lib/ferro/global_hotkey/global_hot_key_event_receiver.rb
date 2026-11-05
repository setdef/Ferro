# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

module Ferro
  module GlobalHotkey
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2019 The Crossbeam Project Developers
    # SPDX-SnippetComment: the Receiver methods and errors global-hotkey's
    #   GlobalHotKeyEventReceiver alias gives, and their docs, from
    #   crossbeam-channel 0.5.17 src/channel.rs:711-1158, src/err.rs:54-90,
    #   282-333
    #++

    # A receiver that could be used to listen to global hotkey events.
    #
    # Hotkey events pile up while your code is busy, and an app reads them
    # in one of two ways: a loop that looks between frames and must never
    # wait, or a thread that does nothing but wait for the next one.
    #
    # This is global-hotkey's event channel, a crossbeam channel that lives
    # as long as the process, read both ways: try_recv and try_iter never
    # wait, while recv, recv_timeout, and iter wait for the next event with
    # Ruby's global VM lock released, so other threads run, and Ctrl-C,
    # <tt>Thread#raise</tt>, <tt>Thread#kill</tt>, and +Timeout+ end the
    # wait. An event that arrives during the wait usually stays in the
    # channel for the next read. One the wait has already taken when the
    # interrupt raises is discarded with the value the wait was returning,
    # and cannot be read again, as Ruby's own IO discards what a read took
    # when an interrupt raises just after it.
    #
    # Every receiver reads the one channel, so a copy (+dup+, +clone+) is
    # the same receiver, frozen like it, and a receiver can be shared with
    # other Ractors.
    # Its sender never closes, so the +Disconnected+ errors below cannot
    # happen; they exist because crossbeam's error types have them.
    #
    # Mirrors global-hotkey's +GlobalHotKeyEventReceiver+
    # (<tt>src/lib.rs:83-84</tt>), crossbeam's <tt>Receiver<GlobalHotKeyEvent></tt>.
    #
    # === Examples
    #
    #   receiver = Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver
    #
    #   # Between frames:
    #   receiver.try_iter.each { |event| handle(event) }
    #
    #   # On a thread of its own:
    #   Thread.new { receiver.iter.each { |event| handle(event) } }
    #
    #   # With a limit:
    #   begin
    #     receiver.recv_timeout(5)
    #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::RecvTimeoutError::Timeout
    #     puts "No hotkey in five seconds"
    #   end
    class GlobalHotKeyEventReceiver
      private_class_method :new

      # Creates a receiver of global-hotkey's channel. Use
      # GlobalHotKeyEvent.receiver.
      def initialize
        freeze
      end

      # A frozen copy, which is Ractor-shareable as the receiver is.
      # Mirrors crossbeam's <tt>Receiver::clone</tt>
      # (<tt>src/channel.rs:1174-1187</tt>), which makes another receiver
      # of the same channel; Object#dup would make an unfrozen one.
      #
      # === Example
      #
      #   Ractor.shareable?(receiver.dup) # => true
      def dup
        self.class.__send__(:new)
      end

      # crossbeam's error for a read that did not wait and found nothing.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::TryRecvError => e
      #     e.message # => "receiving on an empty channel"
      class TryRecvError < StandardError
        class << self
          # Converts a RecvError, as Rust's <tt>From<RecvError></tt> does:
          # returns (does not raise) a Disconnected with crossbeam's text
          # for it. Mirrors crossbeam-channel 0.5.17
          # <tt>src/err.rs:301-307</tt>.
          #
          # [error] RecvError.
          #
          # === Example
          #
          #   TryRecvError.from(RecvError.new).is_disconnected # => true
          def from(error)
            unless error.is_a?(RecvError)
              raise TypeError, "wrong argument type #{error.class} (expected #{RecvError})"
            end

            Disconnected.new(Native.recv_error_into("try_recv"))
          end
        end

        # Whether the read failed because the channel is empty. Mirrors
        # <tt>TryRecvError::is_empty</tt> (crossbeam-channel 0.5.17
        # <tt>src/err.rs:309-325</tt>).
        #
        # === Example
        #
        #   error.is_empty # => true
        def is_empty
          is_a?(Empty)
        end

        # Whether the read failed because the channel is disconnected.
        # Mirrors <tt>TryRecvError::is_disconnected</tt>.
        #
        # === Example
        #
        #   error.is_disconnected # => false
        def is_disconnected
          is_a?(Disconnected)
        end

        # The channel is empty. Mirrors <tt>TryRecvError::Empty</tt>.
        # Without a message, its message is crossbeam's.
        #
        # === Example
        #
        #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::TryRecvError::Empty
        class Empty < TryRecvError
          # Creates the error. Without a +message+, or with +nil+, the
          # message is crossbeam's: "receiving on an empty channel".
          #
          # [message] String, the error message.
          #
          # === Example
          #
          #   TryRecvError::Empty.new.message # => "receiving on an empty channel"
          def initialize(message = nil)
            super(message || Native.receive_error_text("TryRecvError::Empty"))
          end
        end

        # The channel is empty and disconnected, which cannot happen to
        # global-hotkey's. Mirrors <tt>TryRecvError::Disconnected</tt>.
        #
        # === Example
        #
        #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::TryRecvError::Disconnected
        class Disconnected < TryRecvError
          # Creates the error. Without a +message+, or with +nil+, the
          # message is crossbeam's: "receiving on an empty and
          # disconnected channel".
          #
          # [message] String, the error message.
          #
          # === Example
          #
          #   TryRecvError::Disconnected.new.is_disconnected # => true
          def initialize(message = nil)
            super(message || Native.receive_error_text("TryRecvError::Disconnected"))
          end
        end
      end

      # crossbeam's error for a wait on a channel that is empty and
      # disconnected, which cannot happen to global-hotkey's. Mirrors
      # +RecvError+.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::RecvError
      class RecvError < StandardError
        # Creates the error. Without a +message+, or with +nil+, the
        # message is crossbeam's: "receiving on an empty and disconnected
        # channel".
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   RecvError.new.message # => "receiving on an empty and disconnected channel"
        def initialize(message = nil)
          super(message || Native.receive_error_text("RecvError"))
        end
      end

      # crossbeam's error for a wait with a limit that ended without an
      # event.
      #
      # === Example
      #
      #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::RecvTimeoutError => e
      #     e.message # => "timed out waiting on receive operation"
      class RecvTimeoutError < StandardError
        class << self
          # Converts a RecvError, as Rust's <tt>From<RecvError></tt> does:
          # returns (does not raise) a Disconnected with crossbeam's text
          # for it. Mirrors crossbeam-channel 0.5.17
          # <tt>src/err.rs:338-344</tt>.
          #
          # [error] RecvError.
          #
          # === Example
          #
          #   RecvTimeoutError.from(RecvError.new).is_disconnected # => true
          def from(error)
            unless error.is_a?(RecvError)
              raise TypeError, "wrong argument type #{error.class} (expected #{RecvError})"
            end

            Disconnected.new(Native.recv_error_into("recv_timeout"))
          end
        end

        # Whether the wait timed out. Mirrors
        # <tt>RecvTimeoutError::is_timeout</tt> (crossbeam-channel 0.5.17
        # <tt>src/err.rs:346-362</tt>).
        #
        # === Example
        #
        #   error.is_timeout # => true
        def is_timeout
          is_a?(Timeout)
        end

        # Whether the wait failed because the channel is disconnected.
        # Mirrors <tt>RecvTimeoutError::is_disconnected</tt>.
        #
        # === Example
        #
        #   error.is_disconnected # => false
        def is_disconnected
          is_a?(Disconnected)
        end

        # No event came in time. Mirrors <tt>RecvTimeoutError::Timeout</tt>.
        # Without a message, its message is crossbeam's.
        #
        # === Example
        #
        #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::RecvTimeoutError::Timeout
        class Timeout < RecvTimeoutError
          # Creates the error. Without a +message+, or with +nil+, the
          # message is crossbeam's: "timed out waiting on receive
          # operation".
          #
          # [message] String, the error message.
          #
          # === Example
          #
          #   RecvTimeoutError::Timeout.new.message # => "timed out waiting on receive operation"
          def initialize(message = nil)
            super(message || Native.receive_error_text("RecvTimeoutError::Timeout"))
          end
        end

        # The channel is empty and disconnected, which cannot happen to
        # global-hotkey's. Mirrors <tt>RecvTimeoutError::Disconnected</tt>.
        #
        # === Example
        #
        #   rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::RecvTimeoutError::Disconnected
        class Disconnected < RecvTimeoutError
          # Creates the error. Without a +message+, or with +nil+, the
          # message is crossbeam's: "channel is empty and disconnected".
          #
          # [message] String, the error message.
          #
          # === Example
          #
          #   RecvTimeoutError::Disconnected.new.message # => "channel is empty and disconnected"
          def initialize(message = nil)
            super(message || Native.receive_error_text("RecvTimeoutError::Disconnected"))
          end
        end
      end

      # Attempts to receive an event without waiting: returns the next
      # GlobalHotKeyEvent, or raises TryRecvError::Empty when there is
      # none. Mirrors crossbeam's <tt>Receiver::try_recv</tt>.
      #
      # === Example
      #
      #   event = receiver.try_recv rescue nil
      def try_recv
        GlobalHotkey.__send__(:event, GlobalHotkey.__send__(:settle, Native.receiver_try_recv))
      end

      # Waits for the next event and returns it. The wait releases the
      # global VM lock and ends at an interrupt. Mirrors crossbeam's
      # <tt>Receiver::recv</tt>.
      #
      # === Example
      #
      #   event = receiver.recv
      def recv
        GlobalHotkey.__send__(:event, GlobalHotkey.__send__(:settle, Native.receiver_recv(nil)))
      end

      # Waits up to +timeout+ seconds for the next event and returns it, or
      # raises RecvTimeoutError::Timeout. A negative or NaN timeout raises
      # +ArgumentError+; one too long for the system clock waits forever,
      # as crossbeam's does. Mirrors crossbeam's
      # <tt>Receiver::recv_timeout</tt>, whose +Duration+ is seconds here.
      #
      # [timeout] Numeric, seconds.
      #
      # === Example
      #
      #   receiver.recv_timeout(0.5)
      def recv_timeout(timeout)
        raise TypeError, "can't convert #{timeout.nil? ? 'nil' : timeout.class} into Float" unless timeout.is_a?(Numeric)

        GlobalHotkey.__send__(:event, GlobalHotkey.__send__(:settle, Native.receiver_recv(timeout)))
      end

      # An Enumerator that waits for each event in turn, forever, as recv
      # does. Mirrors crossbeam's <tt>Receiver::iter</tt>.
      #
      # === Example
      #
      #   receiver.iter.each { |event| p event }
      def iter
        Enumerator.new do |events|
          # Kernel#loop would rescue a StopIteration the consumer's block
          # raises and end the enumeration silently.
          while true
            events << recv
          end
        end
      end

      # An Enumerator over the events already in the channel, which ends
      # when it is empty and never waits. Mirrors crossbeam's
      # <tt>Receiver::try_iter</tt>.
      #
      # === Example
      #
      #   receiver.try_iter.to_a
      def try_iter
        Enumerator.new do |events|
          # Kernel#loop would rescue a StopIteration the consumer's block
          # raises and end the enumeration silently.
          while true
            begin
              events << try_recv
            rescue TryRecvError
              break
            end
          end
        end
      end

      # Whether the channel is empty. Mirrors crossbeam's
      # <tt>Receiver::is_empty</tt>.
      #
      # === Example
      #
      #   receiver.is_empty # => true
      def is_empty
        Native.receiver_is_empty
      end

      # Whether the channel is full, which an unbounded channel never is.
      # Mirrors crossbeam's <tt>Receiver::is_full</tt>.
      #
      # === Example
      #
      #   receiver.is_full # => false
      def is_full
        Native.receiver_is_full
      end

      # How many events wait in the channel. Mirrors crossbeam's
      # <tt>Receiver::len</tt>.
      #
      # === Example
      #
      #   receiver.len # => 0
      def len
        Native.receiver_len
      end

      # The channel's capacity: +nil+, as it is unbounded. Mirrors
      # crossbeam's <tt>Receiver::capacity</tt>.
      #
      # === Example
      #
      #   receiver.capacity # => nil
      def capacity
        Native.receiver_capacity
      end

      # Whether +other+ reads the same channel: true for every receiver.
      # Mirrors crossbeam's <tt>Receiver::same_channel</tt>.
      #
      # [other] GlobalHotKeyEventReceiver.
      #
      # === Example
      #
      #   receiver.same_channel(Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver) # => true
      def same_channel(other)
        raise TypeError, "wrong argument type #{other.class} (expected #{GlobalHotKeyEventReceiver})" unless other.is_a?(GlobalHotKeyEventReceiver)

        true
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
