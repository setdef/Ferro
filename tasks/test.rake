# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "minitest/test_task"
require_relative "desktop"

Rake::Task["test"].clear if Rake::Task.task_defined?("test")

desc "Run every test: those that leave the desktop alone, then the desktop tests if #{Desktop::VARIABLE}=1"
task test: %w[test:core test:desktop]

namespace :test do
  # Every test process loads the watchdog, which ends a hanging test with
  # its name instead of letting the run sit silent (tasks/test_watchdog.rb).
  watchdog = %(require "tasks/test_watchdog")

  desc "Run every test that leaves the desktop alone: the tooling's, then each gem's Rust and Ruby tests"
  task core: ["test:tooling", *FERRO_GEMS.map { |gem| "test:core:#{gem.short_name}" }]

  # The tests in each gem's test/desktop/, which use the session's desktop:
  # the clipboard, notifications, dialogs, and hotkeys (plan 014,
  # tasks/desktop.rb). Each gem that has them adds its own task below.
  desc "Run each gem's desktop tests, in this session, if #{Desktop::VARIABLE}=1 (the gate sets it)"
  task :desktop

  # CI runs these again under a second display server (Wayland, after the
  # gate's X11), so they have a task of their own.
  desc "Run every gem's Ruby tests, the desktop ones if #{Desktop::VARIABLE}=1"
  task ruby: FERRO_GEMS.map { |gem| "test:ruby:#{gem.short_name}" }

  # The gate runs the desktop tests (the Rakefile's default task, and
  # tasks/gate.rake), so it sets the variable first.
  task :allow_desktop do
    ENV[Desktop::VARIABLE] = "1"
  end

  Minitest::TestTask.create(:tooling) do |t|
    t.test_prelude = watchdog
    t.libs = %w[test .]
    t.test_globs = ["test/**/test_*.rb"]
    t.warning = true
  end
  # The packaging check's tests resolve fixture crates with cargo metadata
  # --offline, which needs every platform's dependencies in Cargo's cache;
  # compiling downloads only this machine's.
  task tooling: "package:fetch"

  FERRO_GEMS.each do |gem|
    desc "Run #{gem.name}'s Rust unit tests"
    task "rust:#{gem.short_name}" do
      cargo!("test", "--locked", *gem.test_hooks_features, chdir: gem.dir)
    end

    desktop_tests = Dir[File.join(gem.dir, "test/desktop/**/test_*.rb")]
    kinds = { core: [Dir[File.join(gem.dir, "test/**/test_*.rb")] - desktop_tests, false] }
    kinds[:desktop] = [desktop_tests, true] unless desktop_tests.empty?
    kinds.each do |kind, (files, desktop)|
      name = "ruby:#{kind}:#{gem.short_name}"
      test_task = Minitest::TestTask.create(name) do |t|
        # Every desktop test skips, naming the reason, where there is no
        # desktop session.
        t.test_prelude = desktop ? %(#{watchdog}; require "tasks/desktop"; Desktop.skip_each_test_without_a_session) : watchdog
        t.libs = [File.join(gem.dir, "lib"), File.join(gem.dir, "test"), "."]
        t.test_globs = files
        t.warning = true
      end
      # A test process gets FERRO_DESKTOP=1 only if it runs desktop tests,
      # whatever the shell exported, and those run only when it is 1 here.
      Rake::Task["test:#{name}"].clear_actions.clear_comments
      task name => "compile:#{gem.short_name}" do
        if desktop && !Desktop.allowed?
          puts "test:desktop:#{gem.short_name}: skipped, since its tests would use this session's desktop " \
            "(set #{Desktop::VARIABLE}=1 to run them; the gate does)"
          next
        end
        sh Desktop.run_env(desktop), "#{FileUtils::RUBY} #{test_task.make_test_cmd}", verbose: test_task.verbose
      end
    end

    task "ruby:#{gem.short_name}" => kinds.keys.map { |kind| "test:ruby:#{kind}:#{gem.short_name}" }

    desc "Run #{gem.name}'s tests that leave the desktop alone, Rust then Ruby"
    task "core:#{gem.short_name}" => ["test:rust:#{gem.short_name}", "test:ruby:core:#{gem.short_name}"]

    if kinds.key?(:desktop)
      desc "Run #{gem.name}'s desktop tests, in this session, if #{Desktop::VARIABLE}=1 (the gate sets it)"
      task "desktop:#{gem.short_name}" => "test:ruby:desktop:#{gem.short_name}"
      task desktop: "test:desktop:#{gem.short_name}"
    end

    desc "Run #{gem.name}'s tests, Rust then Ruby#{", the desktop ones if #{Desktop::VARIABLE}=1" if kinds.key?(:desktop)}"
    task gem.short_name => ["test:core:#{gem.short_name}", *("test:desktop:#{gem.short_name}" if kinds.key?(:desktop))]
  end
end
