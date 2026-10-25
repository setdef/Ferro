# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "release"

# Replaces bundler/gem_tasks, whose v0.1.0 tags would collide between gems
# (ADR 001, section 5). A human runs these; agents never do.
namespace :release do
  FERRO_GEMS.each do |gem|
    desc "Tag #{gem.name}/vX.Y.Z, push it, and push the gem to RubyGems (maintainer only)"
    task gem.short_name do
      Release.new(root: Dir.pwd, name: gem.name, dir: gem.dir, version: gem.spec.version.to_s).run!
    rescue Release::Failure => e
      abort "❌ #{e.message}"
    end
  end
end
