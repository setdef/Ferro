# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "bump"

# bump:<gem>:major, :minor, :patch, and :exact: each sets the gem's
# version, releases its CHANGELOG's Unreleased entries, runs the gate, and
# commits chore(<gem>): release X.Y.Z. A label makes a prerelease:
# rake bump:arboard:patch[pre] takes 0.1.0.pre.1 to 0.1.0.pre.2.
# bump:<gem>:current releases the version the gem has now, such as a new
# gem's 0.1.0.pre.1, when no tag here or on origin has it yet. Tag the
# commit afterwards with release:<gem>:tag.
namespace :bump do
  FERRO_GEMS.each do |gem|
    bump = lambda do |&target|
      bumper = Bump.new(root: Dir.pwd, gem:)
      version = target ? bumper.run!(&target) : bumper.release_current!
      puts "✅ #{gem.name} #{version} committed; tag it with rake release:#{gem.short_name}:tag"
    rescue Bump::Failure => e
      abort "❌ #{e.message}"
    end

    namespace gem.short_name do
      GemVersion::SEGMENTS.each do |segment|
        desc "Bump #{gem.name}'s #{segment} version, or to a prerelease with a label (bump:#{gem.short_name}:#{segment}[pre])"
        task segment, [:label] do |_, args|
          bump.call { |current| current.next(segment, args[:label]) }
        end
      end

      desc "Set #{gem.name}'s exact version (bump:#{gem.short_name}:exact[0.1.0.pre.2])"
      task :exact, [:version] do |_, args|
        bump.call { GemVersion.parse(args[:version] || raise(ArgumentError, "name the version, like exact[0.1.0.pre.2]")) }
      end

      desc "Release #{gem.name}'s current version, which no tag has yet (a new gem's 0.1.0.pre.1)"
      task :current do
        bump.call
      end
    end
  end
end
