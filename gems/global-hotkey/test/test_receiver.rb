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

  def test_thread_kill_ends_recv
    status, = in_child(<<~RUBY)
      waiter = Thread.new { Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.recv }
      Thread.pass until waiter.status == "sleep"
      waiter.kill
      status = waiter.join(5) ? waiter.status : "the kill did not end the wait"
      $stdout.binmode.write(Marshal.dump(status))
      $stdout.flush
      exit!(0)
    RUBY

    assert_equal false, status
  end

  # A wait begun with an interrupt pending that Ruby will not run yet
  # still waits with the GVL released (HotkeySuite::WHILE_RAISING). The
  # helper marks only while the reader sleeps in the wait, so a mark shows
  # it ran during the wait; a wait that held the GVL would run it only
  # after, when the reader no longer sleeps. No event comes here, so the
  # timeout ends each wait. Nothing ends one sooner (a wakeup only restarts
  # it, and a raise stays pending), so the waits run in growing steps that
  # stop at the first mark: a passing run is quick, and the steps total 10 s
  # of scheduling budget for the helper, which costs wall time only when
  # the helper never marks.
  # test_linux_events.rb has the variant an event ends.
  def test_a_wait_begun_while_raising_with_an_interrupt_pending_releases_the_gvl
    (ran_during, outcome), = in_child(<<~RUBY)
      #{WHILE_RAISING}
      native = Ferro::GlobalHotkey.const_get(:Native)
      reader = Thread.current
      ran_during = false
      helper = Thread.new do
        Thread.pass until reader.status == "sleep"
        ran_during = true
      end
      outcome = nil
      [0.5, 1.5, 8].each do |seconds|
        outcome = WhileRaising.run { Thread.current.wakeup; native.receiver_recv(seconds) }
        break if ran_during
      end
      during = ran_during
      helper.kill
      [during, outcome.first(2)]
    RUBY

    assert ran_during, "no other thread ran while the wait waited"
    assert_equal [:error, "GlobalHotKeyEventReceiver::RecvTimeoutError::Timeout"], outcome
  end

  # An interrupt that raises nothing (Thread#wakeup) restarts the wait
  # with the deadline it began with, so wakeups arriving throughout do
  # not end the wait early or stretch it (gvl.rs, recv; events.rs,
  # receiver_recv). The lower bound is the check: a restart that ended
  # the wait would be too short, one that took a fresh timeout would
  # never finish before the child limit.
  def test_wakeups_during_recv_timeout_keep_its_deadline
    (elapsed, outcome), = in_child(<<~RUBY)
      reader = Thread.current
      waker = Thread.new do
        loop do
          sleep 0.2
          reader.wakeup
        end
      end
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      outcome = begin
        Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.recv_timeout(1)
      rescue Exception => e
        e.class.name
      end
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      waker.kill
      [elapsed, outcome]
    RUBY

    assert_equal "Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::RecvTimeoutError::Timeout", outcome
    assert_operator elapsed, :>=, 1
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

  # crossbeam's Receiver is Clone (channel.rs:1174-1187): a copy reads the
  # same channel, and here it is as frozen and shareable as the receiver.
  def test_a_cloned_receiver_reads_the_same_channel
    copy = receiver.clone

    assert_predicate copy, :frozen?
    assert Ractor.shareable?(copy)
    assert receiver.same_channel(copy)
    assert_raises(Receiver::TryRecvError::Empty) { copy.try_recv }
  end

  def test_a_duplicated_receiver_is_frozen_and_shareable
    copy = receiver.dup

    refute_same receiver, copy
    assert_predicate copy, :frozen?
    assert Ractor.shareable?(copy)
    assert receiver.same_channel(copy)
    assert_raises(Receiver::TryRecvError::Empty) { copy.try_recv }
  end

  def test_try_recv_error_predicates
    empty = assert_raises(Receiver::TryRecvError::Empty) { receiver.try_recv }

    assert_predicate empty, :is_empty
    refute_predicate empty, :is_disconnected
    disconnected = Receiver::TryRecvError.from(Receiver::RecvError.new)
    assert_predicate disconnected, :is_disconnected
    refute_predicate disconnected, :is_empty
  end

  def test_recv_timeout_error_predicates
    timeout = assert_raises(Receiver::RecvTimeoutError::Timeout) { receiver.recv_timeout(0) }

    assert_predicate timeout, :is_timeout
    refute_predicate timeout, :is_disconnected
    disconnected = Receiver::RecvTimeoutError.from(Receiver::RecvError.new)
    assert_predicate disconnected, :is_disconnected
    refute_predicate disconnected, :is_timeout
  end

  # From<RecvError> (err.rs:301-307, :338-344) makes a Disconnected with
  # the Display text of the converted value.
  def test_a_recv_error_converts_to_a_disconnected
    try = Receiver::TryRecvError.from(Receiver::RecvError.new)
    timed = Receiver::RecvTimeoutError.from(Receiver::RecvError.new)

    assert_instance_of Receiver::TryRecvError::Disconnected, try
    assert_equal "receiving on an empty and disconnected channel", try.message
    assert_instance_of Receiver::RecvTimeoutError::Disconnected, timed
    assert_equal "channel is empty and disconnected", timed.message
    assert_raises(TypeError) { Receiver::TryRecvError.from(Receiver::TryRecvError::Empty.new) }
    error = assert_raises(TypeError) { Receiver::RecvTimeoutError.from("x") }
    assert_equal "wrong argument type String (expected #{Receiver::RecvError})", error.message
  end

  # An error built with new has crossbeam's Display text (err.rs:282-333).
  def test_errors_built_with_new_have_crossbeams_text
    {
      Receiver::RecvError => "receiving on an empty and disconnected channel",
      Receiver::TryRecvError::Empty => "receiving on an empty channel",
      Receiver::TryRecvError::Disconnected => "receiving on an empty and disconnected channel",
      Receiver::RecvTimeoutError::Timeout => "timed out waiting on receive operation",
      Receiver::RecvTimeoutError::Disconnected => "channel is empty and disconnected",
    }.each do |error_class, text|
      assert_equal text, error_class.new.message
      assert_equal text, error_class.new(nil).message
      assert_equal "mine", error_class.new("mine").message
      assert_equal text, assert_raises(error_class) { raise error_class }.message
    end
  end

  # Kernel#loop rescues StopIteration; a block that raises it must
  # propagate it like any exception.
  def test_a_stop_iteration_from_an_iter_block_propagates
    subclass = Class.new(Receiver) do
      def recv
        :event
      end
    end

    error = assert_raises(StopIteration) { subclass.__send__(:new).iter.each { raise StopIteration, "consumer stopped" } }
    assert_equal "consumer stopped", error.message
  end

  def test_a_stop_iteration_from_a_try_iter_block_propagates
    subclass = Class.new(Receiver) do
      def try_recv
        :event
      end
    end

    error = assert_raises(StopIteration) { subclass.__send__(:new).try_iter.each { raise StopIteration, "consumer stopped" } }
    assert_equal "consumer stopped", error.message
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
