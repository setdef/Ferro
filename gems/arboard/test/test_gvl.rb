# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "open3"
require "rbconfig"

# Calls that can block release Ruby's global VM lock; short calls keep it,
# since releasing and retaking it costs a time slice per competing thread
# (plan 001, decision 14). On Linux every read can block on the owning
# program, and so can a write that waits; on macOS and Windows none does.
#
# These tests count the releases (gvl.rs RELEASES) rather than time a
# spinning thread. A released lock does not promise another thread runs:
# from Ruby 4.0.6 on, a thread back from a short blocking region takes the
# lock straight back when the thread it woke has not started yet
# (thread_pthread.c:846-867 and :1055-1066 at v4.0.9), and a spinner test
# failed that way in a few runs in ten. test_linux.rb shows a released lock
# at work: another thread replaces the text while a write waits.
#
# The count comes from the private Clipboard#native_gvl_releases, a hook
# that exists only in the repository's build (the test-hooks feature, ADR 001,
# amendment of 2026-11-05: test hooks). The packaged gem has no such method.
class TestGvl < Minitest::Test
  include ClipboardSuite

  # How many more calls released the lock while the block ran. The block's
  # result does not matter here, only its path: on X11 a read can find
  # nothing when another test's clear lands late (Clipboard#clear), and it
  # takes the same path either way.
  private def releases
    before = clipboard.__send__(:native_gvl_releases)
    begin
      yield
    rescue Ferro::Arboard::Error::ContentNotAvailable
      nil
    end
    clipboard.__send__(:native_gvl_releases) - before
  end

  def test_linux_reads_and_waiting_writes_release_the_lock
    skip_unless_platform(:linux)
    clipboard.set_text("read me")
    past = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1

    assert_equal 1, releases { clipboard.get_text }
    assert_equal 1, releases { clipboard.set.wait_until(past).text("waited") }
  end

  def test_reads_keep_the_lock_off_linux
    skip "Linux reads release the lock; see test_linux_reads_and_waiting_writes_release_the_lock" if PLATFORM == :linux
    clipboard.set_text("read me")

    assert_equal 0, releases { clipboard.get_text }
  end

  def test_writes_that_do_not_wait_keep_the_lock
    assert_equal 0, releases { clipboard.set_text("short") }
  end

  # The scripts below hold the clipboard in a write that waits for another
  # program (SetExtLinux#wait), on a thread of their own, so a second call
  # on the same Clipboard waits for its lock. Only Linux has such a write.
  # Each starts a watchdog process that prints a mark and then sets the
  # text after 120 seconds, ending the wait if nothing else did; a test
  # that sees the mark fails. The delay only bounds a failing run. The holder owns the text once a second Clipboard
  # reads it back (arboard serves the read in process, x11.rs:307-308).
  HOLD = <<~RUBY
    require "ferro/arboard"
    require "rbconfig"

    mark, marker = IO.pipe
    watchdog = spawn(RbConfig.ruby, "-I", $LOAD_PATH.first, "-e",
      %(sleep 120; puts "fired"; $stdout.flush; require "ferro/arboard"; Ferro::Arboard::Clipboard.new.set_text("watchdog")),
      out: marker)
    marker.close
    clipboard = Ferro::Arboard::Clipboard.new
    probe = Ferro::Arboard::Clipboard.new
    holder = Thread.new { clipboard.set.wait.text("held") }
    Thread.pass until (probe.get_text rescue nil) == "held"
  RUBY

  # Ends the holder's wait by setting the text from another Clipboard, as
  # arboard's own wait test does, and reports whether the watchdog fired.
  RELEASE = <<~RUBY
    Ferro::Arboard::Clipboard.new.set_text("released") if holder.alive?
    holder.join
    Process.kill(:KILL, watchdog)
    Process.wait(watchdog)
    fired = mark.read
  RUBY

  # The value of +script+, run in a child Ruby, which prints it marshaled.
  private def in_child(script)
    output, errors, status = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__),
      stdin_data: "#{script}\n$stdout.binmode.write(Marshal.dump(result))\n", binmode: true)
    assert_predicate status, :success?, "the child Ruby failed: #{errors}"
    Marshal.load(output)
  end

  # Ruby asks an exception for its backtrace while raising it, with the
  # thread marked as raising (setup_exception, eval.c:542-543, and
  # rb_get_backtrace, error.c:1929, at v4.0.9). A thread so marked runs no
  # interrupts (thread.c:2625), so one made pending there stays pending.
  # rb_thread_call_without_gvl2 skips its work while any interrupt is
  # pending (thread.c:320-327), so the gem used to give up, run the read
  # with the GVL held, and refuse the busy lock with ClipboardOccupied.
  # Raised inside a backtrace, that exception turns into a fatal jump
  # (eval.c:542, :561, :612-615) that the outer raise drops, so the read
  # returned nothing. Now the read waits for the lock with the GVL
  # released: the releaser thread runs only once the reader sleeps in that
  # wait, and the read returns only after the releaser frees the lock, so
  # the read's text proves the order. The child process keeps Ruby's
  # raising state, and any fatal end, out of this run.
  def test_a_call_made_while_raising_with_an_interrupt_pending_waits_for_the_lock_with_the_gvl_released
    skip_unless_platform(:linux)
    read, fired = in_child(<<~RUBY)
      #{HOLD}
      class ReadWhileRaising < StandardError
        attr_reader :read

        def initialize(&reader)
          super("read while raising")
          @reader = reader
        end

        def backtrace
          reader, @reader = @reader, nil
          @read = reader.call if reader
          super
        end
      end

      reader = Thread.current
      releaser = Thread.new do
        Thread.pass until reader.status == "sleep"
        Ferro::Arboard::Clipboard.new.set_text("released")
      end
      read = begin
        raise ReadWhileRaising.new { Thread.current.wakeup; clipboard.get_text }
      rescue ReadWhileRaising => e
        e.read
      end
      releaser.join
      #{RELEASE}
      result = [read, fired]
    RUBY

    assert_equal "released", read
    assert_empty fired, "only the watchdog freed the lock"
  end

  # A call waiting for the lock another thread holds through a wait has an
  # unblocking function, which ends the wait for Thread#raise and
  # Thread#kill (thread.c:2969-2982, :3007-3027 at v4.0.9). The holder is
  # still waiting when the waiter ends, so the waiter did not wait for it.
  def test_thread_raise_ends_a_wait_for_the_lock
    skip_unless_platform(:linux)
    error, holding, fired = in_child(<<~RUBY)
      #{HOLD}
      waiter = Thread.new { clipboard.get_text }
      waiter.report_on_exception = false
      Thread.pass until waiter.status == "sleep"
      waiter.raise(IOError, "raised")
      error = begin
        waiter.join
        nil
      rescue IOError => e
        e.message
      end
      holding = holder.alive?
      #{RELEASE}
      result = [error, holding, fired]
    RUBY

    assert_equal "raised", error
    assert holding, "the waiter ended only once the holder did"
    assert_empty fired, "only the watchdog freed the lock"
  end

  # An interrupt that raises nothing (Thread#wakeup, a signal trap that
  # returns) runs the unblocking function and ends the waiter's wait without
  # a turn; Ruby handles the interrupt and the call waits again (gvl.rs
  # drive). Each wait counts a release, so a count that grew while the
  # thread sleeps again shows the retry, and the read returning the
  # releaser's text shows it still waited for the lock.
  def test_a_wakeup_that_raises_nothing_leaves_the_waiter_waiting_for_the_lock
    skip_unless_platform(:linux)
    read, fired = in_child(<<~RUBY)
      #{HOLD}
      waiter = Thread.new { clipboard.get_text }
      Thread.pass until waiter.status == "sleep"
      before = clipboard.__send__(:native_gvl_releases)
      waiter.wakeup
      Thread.pass until clipboard.__send__(:native_gvl_releases) > before && waiter.status == "sleep"
      #{RELEASE}
      read = waiter.value
      result = [read, fired]
    RUBY

    assert_equal "released", read
    assert_empty fired, "only the watchdog freed the lock"
  end

  def test_thread_kill_ends_a_wait_for_the_lock
    skip_unless_platform(:linux)
    status, holding, fired = in_child(<<~RUBY)
      #{HOLD}
      waiter = Thread.new { clipboard.get_text }
      Thread.pass until waiter.status == "sleep"
      waiter.kill
      waiter.join
      status = waiter.status
      holding = holder.alive?
      #{RELEASE}
      result = [status, holding, fired]
    RUBY

    assert_equal false, status
    assert holding, "the waiter ended only once the holder did"
    assert_empty fired, "only the watchdog freed the lock"
  end
end
