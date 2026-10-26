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
