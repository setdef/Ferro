# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "lint"

desc "Type-check every gem with Steep, and forbid untyped signatures"
task steep: %w[steep:check steep:no_untyped]

namespace :steep do
  desc "Run Steep on every gem (Steepfile has a target per gem)"
  task :check do
    sh "bundle exec steep check"
  end

  FERRO_GEMS.each do |gem|
    desc "Run Steep on #{gem.name}"
    task gem.short_name do
      sh "bundle", "exec", "steep", "check", "--group", gem.short_name
    end
  end

  desc "Forbid 'untyped' in RBS files except approved exceptions"
  task :no_untyped do
    Lint.load(File.expand_path("../rbs_exceptions.rb", __dir__)).enforce!(
      glob: "gems/*/sig/**/*.rbs",
      pattern: /\buntyped\b/,
      reject_pattern: /^\s*#/,
      violation_name: "'untyped' in RBS files"
    )
  end
end

namespace :rbs do
  desc "Validate every gem's signatures"
  task :validate do
    sh "bundle", "exec", "rbs", *FerroGem.rbs_validate_arguments(FERRO_GEMS)
  end

  namespace :parity do
    FERRO_GEMS.each do |gem|
      desc "Check #{gem.name}'s signatures and implementation describe the same methods"
      task gem.short_name => "compile:#{gem.short_name}" do
        args = %W[--sig #{gem.dir}/sig --lib #{gem.dir}/lib --native #{gem.native_namespace} --allow rbs_exceptions.rb]
        args += gem.foreign_sigs(gem.platform).flat_map { |path| ["--exclude-sig", path] }
        ruby File.expand_path("rbs_parity.rb", __dir__), *args
      end
    end
  end

  desc "Check every gem's signatures against its implementation"
  task parity: FERRO_GEMS.map { |gem| "rbs:parity:#{gem.short_name}" }
end

namespace :lint do
  desc "Run every RBS lint"
  task rbs: %w[steep:no_untyped rbs:validate rbs:parity]
end
