# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The gem names the arboard it binds in one place a user reads (README),
# one a tool reads (metadata), and two Cargo reads (manifest, lockfile).
# They must agree.
class TestGem < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-arboard.gemspec"))

  private def locked_arboard
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "arboard"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_arboard
    assert_equal locked_arboard, SPEC.metadata.fetch("arboard_version")
  end

  def test_the_manifest_pins_that_arboard_with_every_feature
    manifest = File.read(File.join(ROOT, "ext/ferro_arboard/Cargo.toml"))
    arboard = manifest[/^arboard = .*$/]

    assert_includes arboard, %(version = "=#{locked_arboard}")
    assert_includes arboard, %(features = ["image-data", "wayland-data-control"])
  end

  def test_the_readme_names_that_arboard
    assert_includes File.read(File.join(ROOT, "README.rdoc")), "arboard #{locked_arboard}"
  end

  def test_the_gem_takes_arboards_licenses_and_ruby_4
    assert_equal %w[Apache-2.0 MIT], SPEC.licenses.sort
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
