# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "cargo_output"
require_relative "lint"

# Runs a cargo command, failing the task on any warning (CargoOutput).
def cargo!(*command, chdir:)
  CargoOutput.run!("cargo", *command, chdir:)
rescue CargoOutput::Failure => e
  abort "❌ #{e.message}"
end

# Each gem's crate is its own Cargo workspace (ADR 001, section 3), so
# every cargo task runs once per gem.
namespace :rust do
  FERRO_GEMS.each do |gem|
    namespace :clippy do
      desc "Run Clippy, warnings as errors, on #{gem.name}"
      task gem.short_name do
        cargo!("clippy", "--locked", "--all-targets", "--", "-D", "warnings", chdir: gem.dir)
      end
    end

    namespace :fmt do
      desc "Check #{gem.name}'s Rust formatting"
      task gem.short_name do
        cargo!("fmt", "--all", "--check", chdir: gem.dir)
      end
    end

    desc "Run every Rust lint on #{gem.name}"
    task gem.short_name => ["rust:clippy:#{gem.short_name}", "rust:fmt:#{gem.short_name}", "rust:no_allows"]
  end

  desc "Run Clippy on every gem"
  task clippy: FERRO_GEMS.map { |gem| "rust:clippy:#{gem.short_name}" }

  desc "Check every gem's Rust formatting"
  task fmt: FERRO_GEMS.map { |gem| "rust:fmt:#{gem.short_name}" }

  desc "Format every gem's Rust"
  task "fmt:fix" do
    FERRO_GEMS.each { |gem| sh "cargo", "fmt", "--all", chdir: gem.dir }
  end

  desc "Apply Clippy's suggested fixes to every gem (rewrites files; review the diff)"
  task "clippy:fix" do
    FERRO_GEMS.each do |gem|
      sh "cargo", "clippy", "--fix", "--allow-dirty", "--allow-staged", "--locked", "--all-targets", chdir: gem.dir
    end
  end

  desc "Forbid #[allow(clippy::...)] except approved exceptions"
  task :no_allows do
    Lint.load(File.expand_path("../clippy_exceptions.rb", __dir__)).enforce!(
      glob: "gems/*/ext/**/*.rs",
      pattern: /#\[allow\(clippy::/,
      violation_name: "#[allow(clippy::...)]"
    )
  end
end

namespace :lint do
  desc "Run every Rust lint on every gem"
  task rust: %w[rust:clippy rust:fmt rust:no_allows]
end
