# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "pin_check"

namespace :pins do
  desc "Fail when two gems lock different magnus or rb-sys versions, or require different rb_sys gems"
  task :check do
    lockfiles = FERRO_GEMS.to_h { |gem| [gem.name, File.read(File.join(gem.dir, "Cargo.lock"))] }
    requirements = FERRO_GEMS.to_h do |gem|
      [gem.name, gem.spec.runtime_dependencies.find { |dependency| dependency.name == "rb_sys" }&.requirement&.to_s]
    end
    pins = PinCheck.new(lockfiles:, requirements:).check!
    puts "✅ Every gem links #{pins.map { |crate, pin| "#{crate} #{pin}" }.join(' and ')}"
  rescue PinCheck::Failure => e
    abort "❌ #{e.message}"
  end
end
