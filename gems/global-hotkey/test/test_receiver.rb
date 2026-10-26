# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# global-hotkey's event channel, read through crossbeam's methods. No
# hotkey fires in this process, so the channel stays empty; the event
# tests deliver events in child processes.
class TestReceiver < Minitest::Test
  include HotkeySuite

  Receiver = GlobalHotkey::GlobalHotKeyEventReceiver

  private def receiver
    GlobalHotkey::GlobalHotKeyEvent.receiver
  end

  def test_try_recv_raises_empty_with_crossbeams_text
    error = assert_raises(Receiver::TryRecvError::Empty) { receiver.try_recv }

    assert_equal "receiving on an empty channel", error.message
  end

  def test_recv_timeout_times_out_with_crossbeams_text
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    error = assert_raises(Receiver::RecvTimeoutError::Timeout) { receiver.recv_timeout(0.2) }

    assert_equal "timed out waiting on receive operation", error.message
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.2
    assert_raises(Receiver::RecvTimeoutError::Timeout) { receiver.recv_timeout(0) }
  end

  # The wait releases the GVL: a spinning thread keeps counting through it.
  def test_a_wait_lets_other_threads_run
    count = 0
    running = true
    spinner = Thread.new { count += 1 while running }
    sleep 0.05
    before = count
    assert_raises(Receiver::RecvTimeoutError::Timeout) { receiver.recv_timeout(0.5) }
    during = count - before
    running = false
    spinner.join

    assert_operator during, :>, 1000, "the spinner barely ran while recv_timeout waited"
  end

  # The unblocking function ends a wait that has no deadline. A wait it
  # could not end would also keep Ruby from exiting, so the wait runs in a
  # child, which reports and leaves with exit!.
  def test_an_interrupt_ends_recv
    message, = in_child(<<~RUBY)
      waiter = Thread.new do
        Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.recv
      rescue IOError => e
        e.message
      end
      sleep 0.2
      waiter.raise(IOError, "stop waiting")
      message = waiter.join(5) ? waiter.value : "the interrupt did not end the wait"
      $stdout.binmode.write(Marshal.dump(message))
      $stdout.flush
      exit!(0)
    RUBY

    assert_equal "stop waiting", message
  end

  # A timeout too long for an Instant waits forever, as crossbeam's does,
  # rather than overflow (events.rs, deadline), and an interrupt still
  # ends it.
  def test_a_timeout_too_long_for_the_clock_waits_until_interrupted
    states, = in_child(<<~RUBY)
      waiter = Thread.new do
        Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.recv_timeout(1.8e19)
      rescue IOError => e
        e.message
      end
      sleep 0.3
      waiting = waiter.status
      waiter.raise(IOError, "stop waiting")
      states = [waiting, waiter.join(5) ? waiter.value : "the interrupt did not end the wait"]
      $stdout.binmode.write(Marshal.dump(states))
      $stdout.flush
      exit!(0)
    RUBY

    assert_equal ["sleep", "stop waiting"], states
  end

  def test_a_bad_timeout_raises
    error = assert_raises(ArgumentError) { receiver.recv_timeout(-1) }
    assert_equal "cannot convert float seconds to Duration: value is negative", error.message
    assert_raises(ArgumentError) { receiver.recv_timeout(Float::NAN) }
    assert_raises(TypeError) { receiver.recv_timeout(nil) }
    assert_raises(TypeError) { receiver.recv_timeout("1") }
  end

  def test_the_channel_is_empty_and_unbounded
    assert_predicate receiver, :is_empty
    refute_predicate receiver, :is_full
    assert_equal 0, receiver.len
    assert_nil receiver.capacity
  end

  def test_iterators_are_enumerators
    assert_equal [], receiver.try_iter.to_a
    assert_instance_of Enumerator, receiver.iter
  end

  def test_every_receiver_reads_the_one_channel
    one = receiver

    assert one.same_channel(receiver)
    assert one.same_channel(one.dup)
    assert_raises(TypeError) { one.same_channel(Object.new) }
    assert_predicate one, :frozen?
    assert Ractor.shareable?(one)
    assert_raises(NoMethodError) { Receiver.new }
  end
end
