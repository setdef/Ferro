# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

# Runs Ractor scenarios in fresh processes until one stops, to find why the
# Ractor tests hang on Windows CI only when the shared-clipboard test runs
# first. Not a test: CI runs it on Windows as a diagnostic step.
#
#   bundle exec ruby -Igems/arboard/lib gems/arboard/test/ractor_probe.rb [runs]
#
# Each scenario is a sequence of steps, each run in its own Ractor. A child
# process runs one sequence and prints every step it starts and ends, and
# each Ractor prints its own steps, so a child that stops shows exactly
# where. The parent gives each child DEADLINE seconds, then kills it.
#
# The scenarios separate the suspects: whether the hang needs the shared
# clipboard, any earlier Ractor, an exception raised from the native layer
# inside a Ractor, or the gem at all.

require "rbconfig"
require "tmpdir"

DEADLINE = 15

# The steps a child can run. Each returns what its Ractor returned.
STEPS = <<~'RUBY'
  require "ferro/arboard"
  Warning[:experimental] = false
  $stdout.sync = $stderr.sync = true

  STEPS = {
    # test_another_ractor_round_trips_text_through_a_shared_clipboard
    "shared" => lambda do
      shared = Ractor.make_shareable(Ferro::Arboard::Clipboard.new)
      Ractor.new(shared) do |clipboard|
        $stderr.puts("    ractor: set_text"); clipboard.set_text("from a Ractor")
        $stderr.puts("    ractor: get_text"); text = clipboard.get_text
        $stderr.puts("    ractor: returning"); text
      end.value
    end,
    # test_another_ractor_opens_its_own_clipboard_and_rescues_arboards_errors
    "own" => lambda do
      Ractor.new do
        $stderr.puts("    ractor: new"); clipboard = Ferro::Arboard::Clipboard.new
        $stderr.puts("    ractor: clear"); clipboard.clear
        $stderr.puts("    ractor: get_text"); clipboard.get_text
      rescue Ferro::Arboard::Error::ContentNotAvailable => e
        $stderr.puts("    ractor: rescued, returning"); e.message
      end.value
    end,
    # The same, but nothing raises inside the Ractor.
    "own_no_raise" => lambda do
      Ractor.new do
        $stderr.puts("    ractor: new"); clipboard = Ferro::Arboard::Clipboard.new
        $stderr.puts("    ractor: set_text"); clipboard.set_text("own")
        $stderr.puts("    ractor: get_text"); text = clipboard.get_text
        $stderr.puts("    ractor: returning"); text
      end.value
    end,
    # The gem's exception, raised from Ruby rather than the native layer.
    "ruby_raise" => lambda do
      Ractor.new do
        $stderr.puts("    ractor: raising")
        raise Ferro::Arboard::Error::ContentNotAvailable, "from Ruby"
      rescue Ferro::Arboard::Error::ContentNotAvailable => e
        $stderr.puts("    ractor: rescued, returning"); e.message
      end.value
    end,
    # A Ractor that touches no clipboard.
    "plain" => -> { Ractor.new { $stderr.puts("    ractor: returning"); 1 }.value },
    # A frozen, shareable plain object used from a Ractor.
    "shared_plain" => lambda do
      shared = Ractor.make_shareable(Object.new)
      Ractor.new(shared) { |object| $stderr.puts("    ractor: returning"); object.frozen? }.value
    end,
    # Another thread in the main Ractor, asleep, as Minitest's and the
    # watchdog's are during the tests.
    "sleeper" => lambda do
      sleeper = Thread.new { sleep }
      Thread.pass until sleeper.status == "sleep"
      :sleeping
    end,
    # A GC inside a Ractor, which needs a VM barrier, while the main thread
    # waits in Ractor#value. No gem involved.
    "ractor_gc" => lambda do
      Ractor.new { sleep 0.1; $stderr.puts("    ractor: GC.start"); GC.start; :gc_done }.value
    end,
    # The same GC, but the main thread waits by polling, so it stays runnable.
    "ractor_gc_polled" => lambda do
      ractor = Ractor.new { sleep 0.1; $stderr.puts("    ractor: GC.start"); GC.start; :gc_done }
      Thread.pass until ractor.inspect.include?("terminated")
      ractor.value
    end,
    # The shared-clipboard test with a GC inside its Ractor.
    "shared_gc" => lambda do
      shared = Ractor.make_shareable(Ferro::Arboard::Clipboard.new)
      Ractor.new(shared) do |clipboard|
        clipboard.set_text("from a Ractor")
        sleep 0.1
        $stderr.puts("    ractor: GC.start"); GC.start
        clipboard.get_text
      end.value
    end,
    # The main thread's own read, as the shared test ends.
    "main_read" => -> { Ferro::Arboard::Clipboard.new.get_text },
  }.freeze

  ARGV.each do |name|
    $stderr.puts("  step #{name}: start")
    result = begin
      STEPS.fetch(name).call
    rescue StandardError => e
      "#{e.class}: #{e.message}"
    end
    $stderr.puts("  step #{name}: done (#{result.inspect[0, 60]})")
    GC.start
  end
RUBY

SCENARIOS = {
  # The CI hangs: the tests' two orders, each process holding only its main
  # thread, never stopped in 140 runs.
  "shared, own" => %w[shared main_read own],
  "own, shared" => %w[own shared main_read],
  # The suspected Ruby bug, without the gem: a Ractor's GC while another
  # main-Ractor thread sleeps. Expected to stop on Windows only.
  "ruby: sleeper, ractor_gc" => %w[sleeper ractor_gc],
  "ruby: ractor_gc" => %w[ractor_gc],
  "ruby: sleeper, ractor_gc_polled" => %w[sleeper ractor_gc_polled],
  # The same trigger through the gem's shared-clipboard test.
  "gem: sleeper, shared_gc" => %w[sleeper shared_gc],
  "gem: shared_gc" => %w[shared_gc],
}.freeze

runs = Integer(ARGV.fetch(0, "20"))
lib = File.expand_path("../lib", __dir__)
hangs = 0
Dir.mktmpdir("ractor_probe") do |dir|
  # A file, not -e, whose quoting differs on Windows.
  script = File.join(dir, "steps.rb")
  File.write(script, STEPS)
  SCENARIOS.each do |label, steps|
    outcomes = Hash.new(0)
    runs.times do
      # Three stops are evidence enough; more would only spend CI time.
      break if outcomes["stopped"] >= 3

      log = File.join(dir, "child.log")
      pid = spawn(RbConfig.ruby, "-I", lib, script, *steps, out: log, err: [:child, :out])
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
      status = nil
      until (status = Process.wait2(pid, Process::WNOHANG)&.last) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.1
      end
      if status
        outcomes[status.success? ? "finished" : "failed (#{status.exitstatus})"] += 1
        next if status.success?
      else
        Process.kill(:KILL, pid)
        Process.wait(pid)
        outcomes["stopped"] += 1
        hangs += 1
        puts "  #{label}: stopped after #{DEADLINE} s; the child's last lines:"
      end
      puts File.readlines(log).last(8).map { |line| "    #{line}" }.join
    end
    puts "#{label}: #{outcomes.map { |outcome, count| "#{count} #{outcome}" }.join(', ')}"
  end
end
exit(hangs.zero? ? 0 : 1)
