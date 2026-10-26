# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The gem names the notify-rust it binds in one place a user reads
# (README), one a tool reads (metadata), and two Cargo reads (manifest,
# lockfile). They must agree.
class TestGem < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-notify-rust.gemspec"))

  private def locked_notify_rust
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "notify-rust"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_notify_rust
    assert_equal locked_notify_rust, SPEC.metadata.fetch("notify_rust_version")
  end

  # notify-rust's default (z) with images and chrono; plan 003, decision 2
  # says why the other features are not built.
  def test_the_manifest_pins_that_notify_rust_with_its_features
    manifest = File.read(File.join(ROOT, "ext/ferro_notify_rust/Cargo.toml"))
    notify_rust = manifest[/^notify-rust = .*$/]

    assert_includes notify_rust, %(version = "=#{locked_notify_rust}")
    assert_includes notify_rust, %(features = ["images", "chrono"])
    refute_includes notify_rust, "default-features"
  end

  def test_the_readme_names_that_notify_rust
    assert_includes File.read(File.join(ROOT, "README.rdoc")), "notify-rust #{locked_notify_rust}"
  end

  def test_the_gem_takes_notify_rusts_licenses_and_ruby_4
    assert_equal %w[Apache-2.0 MIT], SPEC.licenses.sort
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
