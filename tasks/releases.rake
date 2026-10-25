# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "release"

# Replaces bundler/gem_tasks, whose v0.1.0 tags would collide between gems
# (ADR 001, section 5). release:<gem>:tag tags the release commit a bump
# made and pushes only the tag; agents may run it once the gate and CI pass
# for that commit. release:<gem> also pushes the gem to RubyGems.org, which
# only the maintainer does, and not yet.
namespace :release do
  FERRO_GEMS.each do |gem|
    release = -> { Release.new(root: Dir.pwd, name: gem.name, dir: gem.dir, version: gem.spec.version.to_s, scope: gem.short_name) }

    desc "Tag #{gem.name}/vX.Y.Z, push it, and push the gem to RubyGems (maintainer only)"
    task gem.short_name do
      release.call.run!
    rescue Release::Failure => e
      abort "❌ #{e.message}"
    end

    namespace gem.short_name do
      desc "Tag #{gem.name}'s release commit #{gem.tag_prefix}X.Y.Z and push only the tag"
      task :tag do
        release.call.tag!
      rescue Release::Failure => e
        abort "❌ #{e.message}"
      end
    end
  end
end
