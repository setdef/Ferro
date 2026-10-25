# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

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
end
