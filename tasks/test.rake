# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "minitest/test_task"

Rake::Task["test"].clear if Rake::Task.task_defined?("test")

desc "Run every test: the tooling's, then each gem's Rust and Ruby tests"
task test: ["test:tooling", *FERRO_GEMS.map { |gem| "test:#{gem.short_name}" }]

namespace :test do
  # CI runs these again under a second display server (Wayland, after the
  # gate's X11), so they have a task of their own.
  desc "Run every gem's Ruby tests"
  task ruby: FERRO_GEMS.map { |gem| "test:ruby:#{gem.short_name}" }

  Minitest::TestTask.create(:tooling) do |t|
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
      cargo!("test", "--locked", chdir: gem.dir)
    end

    Minitest::TestTask.create("ruby:#{gem.short_name}") do |t|
      t.libs = [File.join(gem.dir, "lib"), File.join(gem.dir, "test"), "."]
      t.test_globs = [File.join(gem.dir, "test/**/test_*.rb")]
      t.warning = true
    end
    task "ruby:#{gem.short_name}" => "compile:#{gem.short_name}"

    desc "Run #{gem.name}'s tests, Rust then Ruby"
    task gem.short_name => ["test:rust:#{gem.short_name}", "test:ruby:#{gem.short_name}"]
  end
end
