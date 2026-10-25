# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "minitest"
require "rbconfig"

# Ends a test run that hangs, naming the test that did.
#
# The gem tests drive real system clipboards, and a call that never returns
# hangs the whole run with nothing printed: the test's name appears only
# once it finishes. A Windows run sat silent for 54 minutes that way, until
# CI cancelled the job. Each test runs under a limit (FERRO_TEST_TIMEOUT
# seconds, 60 by default). Past it, a watchdog thread prints the test's
# name and every Ruby thread's backtrace, and ends the process with a
# failure.
#
# A thread cannot help when a native call holds Ruby's global VM lock, as
# short clipboard calls do on macOS and Windows: no other Ruby thread runs
# until it returns. So a guard process, which needs no lock in this one,
# also watches, and kills this process GRACE seconds after the limit,
# naming the test.
#
# The test tasks load it before Minitest (Minitest::TestTask#test_prelude).
module TestWatchdog
  # Seconds a test may take.
  LIMIT = Float(ENV.fetch("FERRO_TEST_TIMEOUT", "60"))

  # Seconds the guard process waits beyond LIMIT for the watchdog thread.
  GRACE = 15

  # The guard process's script (tasks/test_watchdog_guard.rb). A file
  # rather than -e, whose quoting differs on Windows.
  GUARD = File.expand_path("test_watchdog_guard.rb", __dir__)

  @current = nil
  @lock = Mutex.new

  class << self
    # Starts the guard process and the watchdog thread.
    def start
      reader, @guard = IO.pipe
      Process.detach(spawn(RbConfig.ruby, GUARD, Process.pid.to_s, (LIMIT + GRACE).to_s, in: reader))
      reader.close
      @guard.sync = true
      Thread.new { watch }
    end

    # Marks +test+ as running from now.
    def started(test)
      @lock.synchronize { @current = [test, monotonic] }
      tell("start #{test}")
    end

    # Marks the running test as done.
    def finished
      @lock.synchronize { @current = nil }
      tell("done")
    end

    private def tell(line)
      @guard.puts(line)
    rescue IOError, SystemCallError
      nil
    end

    private def watch
      loop do
        sleep 0.5
        test, started = @lock.synchronize { @current }
        next unless test && monotonic - started > LIMIT

        report(test)
        exit!(1)
      end
    end

    private def report(test)
      warn "\n❌ #{test} did not finish within #{LIMIT.round} s. Ruby's threads:"
      Thread.list.each do |thread|
        warn "#{thread.inspect}\n  #{(thread.backtrace || ['(no backtrace)']).join("\n  ")}"
      end
      $stderr.flush
    end

    private def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # Times each test, setup and teardown included.
  module Hooks
    # Starts the clock.
    def before_setup
      TestWatchdog.started("#{self.class}##{name}")
      super
    end

    # Stops the clock.
    def after_teardown
      super
    ensure
      TestWatchdog.finished
    end
  end
end

TestWatchdog.start
Minitest::Test.prepend(TestWatchdog::Hooks)
