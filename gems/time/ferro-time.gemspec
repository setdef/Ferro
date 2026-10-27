# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "lib/ferro/time/version"

Gem::Specification.new do |spec|
  spec.name = "ferro-time"
  spec.version = Ferro::Time::VERSION
  spec.authors = ["Kerrick Long"]
  spec.email = ["me@kerricklong.com"]

  spec.summary = "Dates, times, offsets, and durations for Ruby: time, bound one to one"
  spec.description = File.read(File.expand_path("README.rdoc", __dir__)).gsub(/^--\n.*?^\+\+\n/m, "")
  spec.licenses = ["MIT", "Apache-2.0"]
  spec.homepage = "https://github.com/setdef/Ferro/tree/trunk/gems/time"
  spec.required_ruby_version = ">= 4.0"
  spec.required_rubygems_version = ">= 3.3.11"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = "https://github.com/setdef/Ferro/tree/trunk/gems/time"
  spec.metadata["changelog_uri"] = "https://github.com/setdef/Ferro/blob/trunk/gems/time/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["time_version"] = "0.3.55"

  # Ship what an installed app loads, what compiles the native extension
  # against its pinned dependencies, and the license texts.
  packaged = %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES]
  spec.files = IO.popen(["git", "ls-files", "-z", "--", *packaged], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/ferro_time/extconf.rb"]

  spec.add_dependency "rb_sys", "~> 0.9.129"
end
