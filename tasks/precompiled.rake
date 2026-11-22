# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "digest"
require "tmpdir"
require_relative "package_check"
require_relative "platform_gem"

# Each gem's precompiled gem for this platform and Ruby (plan 015). Neither
# task is in the gate: the build compiles the extension from the source
# gem, and the check installs what it built. Nothing here tags, releases,
# or pushes a gem anywhere.
namespace :package do
  namespace :native do
    FERRO_GEMS.each do |gem|
      desc "Build #{gem.name}'s precompiled gem for this platform and Ruby into pkg/ ([REF] builds that tag's sources)"
      task gem.short_name, [:ref] do |_task, args|
        Dir.mktmpdir("ferro-native") do |work|
          source = PlatformGem.source_gem(root: Dir.pwd, dir: gem.dir, gemspec: "#{gem.name}.gemspec", work:,
            ref: args[:ref].to_s.empty? ? nil : args[:ref])
          package = PlatformGem.new(source:, extension: gem.extension).build("pkg")
          puts "✅ Built #{File.join('pkg', File.basename(package))}, sha256 #{Digest::SHA256.file(package).hexdigest}"
        end
      rescue PlatformGem::Failure => e
        abort "❌ #{e.message}"
      end
    end
  end

  # Builds nothing, so it checks a gem built on another machine as well as
  # one package:native built here.
  namespace :deliver do
    FERRO_GEMS.each do |gem|
      desc "Install #{gem.name}'s precompiled gems given (default pkg/ ones for this platform) with no Rust on PATH, " \
        "and load each"
      task gem.short_name do |_task, args|
        platform = PlatformGem.new(source: nil, extension: gem.extension).platform
        files = args.extras.empty? ? Dir.glob("pkg/#{gem.name}-[0-9]*-#{platform}.gem") : args.extras
        abort "❌ no precompiled gem of #{gem.name} for #{platform} in pkg/; run rake package:native:#{gem.short_name}" if files.empty?

        target = gem.package_target
        files.each do |file|
          puts "#{File.basename(file)}: sha256 #{Digest::SHA256.file(file).hexdigest}"
          PackageCheck.new(root: Dir.pwd, gems: [target]).precompiled(target, file)
        end
      rescue PackageCheck::Failure => e
        abort "❌ #{e.message}"
      end
    end
  end
end
