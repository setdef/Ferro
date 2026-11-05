# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# Future#value waits for rfd's future with the GVL released and an
# unblocking function (plan 002, decision 3). A FIFO makes a future that
# finishes only when the test says: rfd's reader thread blocks opening it
# until a writer comes.
class TestFuture < Minitest::Test
  include RfdSuite

  def setup
    skip "needs a FIFO (mkfifo), which Windows lacks" if PLATFORM == :windows
    @dir = Dir.mktmpdir("ferro-rfd")
    @fifo = File.join(@dir, "fifo")
    File.mkfifo(@fifo)
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end

  # The writer runs only if the waiting thread released the GVL; with it
  # held, the wait never ends and the watchdog fails the test.
  def test_value_lets_other_threads_run_while_it_waits
    future = Ferro::Rfd::FileHandle.new(@fifo).read
    writer = Thread.new { File.write(@fifo, "from another thread") }

    assert_equal "from another thread", future.value
    writer.join
  end

  # An interrupt ends the wait without ending rfd's future; the next value
  # waits on and finishes.
  def test_an_interrupted_wait_leaves_the_future_pending
    future = Ferro::Rfd::FileHandle.new(@fifo).read
    waiter = Thread.new { future.value }
    waiter.report_on_exception = false
    Thread.pass until waiter.status == "sleep"
    waiter.raise(Interrupt)

    assert_raises(Interrupt) { waiter.join }
    writer = Thread.new { File.write(@fifo, "later") }

    assert_equal "later", future.value
    writer.join
  end

  def test_thread_kill_ends_a_wait_and_leaves_the_future_pending
    future = Ferro::Rfd::FileHandle.new(@fifo).read
    waiter = Thread.new { future.value }
    Thread.pass until waiter.status == "sleep"
    waiter.kill
    waiter.join

    assert_equal false, waiter.status
    writer = Thread.new { File.write(@fifo, "after the kill") }

    assert_equal "after the kill", future.value
    writer.join
  end

  # A wait begun with an interrupt pending that Ruby will not run yet
  # still waits with the GVL released (RfdSuite::WHILE_RAISING). The
  # writer writes only once the reader sleeps in that wait, and the value
  # is the writer's, so the writer ran during it; a wait that held the GVL
  # would never end, and the child would be killed.
  def test_a_wait_begun_while_raising_with_an_interrupt_pending_releases_the_gvl
    value, = in_child(<<~RUBY)
      #{WHILE_RAISING}
      reader = Thread.current
      writer = Thread.new do
        Thread.pass until reader.status == "sleep"
        File.write(#{@fifo.dump}, "written meanwhile")
      end
      future = Ferro::Rfd::FileHandle.new(#{@fifo.dump}).read
      value = WhileRaising.run { Thread.current.wakeup; future.value }
      writer.join
      value
    RUBY

    assert_equal "written meanwhile", value
  end

  # An interrupt that raises after rfd's future finished keeps the answer
  # for the next value. Under :on_blocking, Ruby defers the pending
  # Interrupt past the check before the wait (thread.c:319-343 at v4.0.9)
  # and raises it at the check after (thread.c:1636-1638), once the read
  # has finished. The gem used to drop the answer there and poll the
  # finished future again, which panicked into a lasting Ferro::Rfd::Error.
  # The writer writes only during that first wait, so a joined writer shows
  # the Interrupt raised after the read.
  def test_an_interrupt_that_raises_as_the_future_finishes_keeps_the_answer
    future = Ferro::Rfd::FileHandle.new(@fifo).read
    reader = Thread.current
    first_wait = true
    writer = Thread.new do
      Thread.pass until reader.status == "sleep" && first_wait
      File.write(@fifo, "kept")
    end

    assert_raises(Interrupt) do
      Thread.handle_interrupt(Object => :on_blocking) do
        Thread.current.raise(Interrupt)
        future.value
      end
    end
    first_wait = false

    assert writer.join(5), "the Interrupt raised before the read finished"
    assert_equal "kept", future.value
  ensure
    writer&.kill
  end

  # Ruby also checks for interrupts as a C method returns, which can
  # discard the native layer's answer before Future keeps it. A TracePoint
  # raising at that return stands in for the interrupt; the gem used to
  # answer the next value with "this future has already finished".
  def test_an_exception_raised_as_the_native_answer_returns_keeps_the_answer
    path = File.join(@dir, "file")
    File.write(path, "kept")
    future = Ferro::Rfd::FileHandle.new(path).read
    raised = false
    trace = TracePoint.new(:c_return) do |point|
      next if raised || point.method_id != :native_value

      raised = true
      raise Interrupt
    end

    assert_raises(Interrupt) { trace.enable { future.value } }
    assert raised
    assert_equal "kept", future.value
  end

  def test_value_keeps_what_the_future_finished_with
    future = Ferro::Rfd::FileHandle.new(@fifo).read
    writer = Thread.new { File.write(@fifo, "once") }
    first = future.value
    writer.join

    assert_same first, future.value
  end

  def test_a_future_is_made_only_by_rfds_methods
    assert_raises(NoMethodError) { Ferro::Rfd::Future.new(nil) }
  end
end
