# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "package_check"

namespace :package do
  # The packaging check resolves each packaged crate offline, which needs
  # every platform's dependencies in Cargo's cache, not only this
  # machine's. Fetching them from the gem's own lockfile is a no-op once
  # they are there.
  task :fetch do
    FERRO_GEMS.each { |gem| cargo!("fetch", "--locked", chdir: gem.dir) }
  end

  desc "Build each gem and load it from its package, with the compiled extensions (fast)"
  task check: %i[compile fetch] do
    PackageCheck.new(root: Dir.pwd, gems: FERRO_GEMS.map(&:package_target)).fast
  rescue PackageCheck::Failure => e
    abort "❌ #{e.message}"
  end

  desc "Install each gem into an empty GEM_HOME, compiling from the packaged sources (slow, not in the gate)"
  task :install do
    PackageCheck.new(root: Dir.pwd, gems: FERRO_GEMS.map(&:package_target)).full
  rescue PackageCheck::Failure => e
    abort "❌ #{e.message}"
  end

  namespace :check do
    FERRO_GEMS.each do |gem|
      desc "Build #{gem.name} and load it from its package"
      task gem.short_name => ["compile:#{gem.short_name}", "package:fetch"] do
        PackageCheck.new(root: Dir.pwd, gems: [gem.package_target]).fast
      rescue PackageCheck::Failure => e
        abort "❌ #{e.message}"
      end
    end
  end
end
