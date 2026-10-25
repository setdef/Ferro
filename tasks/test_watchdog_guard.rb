# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

# The guard process TestWatchdog starts (tasks/test_watchdog.rb). It reads
# "start <test>" and "done" lines on stdin and kills the process ARGV[0]
# when a test outlives ARGV[1] seconds, which only happens when that
# process's own watchdog thread could not run. It exits when the pipe
# closes, that is, when the test process ends.
parent = Integer(ARGV.fetch(0))
limit = Float(ARGV.fetch(1))
current = nil
Thread.new do
  $stdin.each_line do |line|
    current = line.start_with?("start ") ? [line.chomp.delete_prefix("start "), Time.now] : nil
  end
  exit
end
loop do
  sleep 1
  test, started = current
  next unless test && Time.now - started > limit

  warn "❌ #{test} did not finish within #{limit.round} s, and holds Ruby's VM lock; killing the test process"
  Process.kill(:KILL, parent)
  exit 1
end
