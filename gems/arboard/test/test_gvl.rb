# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Calls that can block release Ruby's global VM lock; short calls keep it,
# since releasing and retaking it costs a time slice per competing thread
# (plan 001, decision 14). On Linux every read can block on the owning
# program; on macOS and Windows none does. test_linux.rb covers the waits.
class TestGvl < Minitest::Test
  include ClipboardSuite

  # A thread spins on a counter while this one reads the clipboard three
  # times, and returns how far the counter moved during each read.
  private def spinner_progress
    clipboard.set_text("spin")
    count = 0
    stop = false
    spinner = Thread.new { count += 1 until stop }
    Thread.pass until count.positive?

    Array.new(3) do
      before = count
      clipboard.get_text
      count - before
    end
  ensure
    stop = true
    spinner&.join
  end

  # A released lock lets the spinner run during each read. Holding it, the
  # counter could move only if Ruby switched threads in the instant before
  # the read, three times over.
  def test_linux_reads_let_other_threads_run
    skip_unless_platform(:linux)

    progress = spinner_progress

    assert progress.all?(&:positive?), "the spinner stalled during a read: #{progress}"
  end

  # The reverse: a read that keeps the lock leaves the spinner still. One
  # switch in the instant before a read is allowed for.
  def test_short_reads_keep_the_lock_off_linux
    skip "Linux reads release the lock; see test_linux_reads_let_other_threads_run" if PLATFORM == :linux

    progress = spinner_progress

    assert_operator progress.count(&:zero?), :>=, 2, "a short read released the lock: #{progress}"
  end
end
