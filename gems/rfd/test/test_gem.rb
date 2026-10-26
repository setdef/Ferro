# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# The gem names the rfd it binds in one place a user reads (README), one a
# tool reads (metadata), and two Cargo reads (manifest, lockfile). They
# must agree.
class TestGem < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-rfd.gemspec"))

  private def locked_rfd
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "rfd"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_rfd
    assert_equal locked_rfd, SPEC.metadata.fetch("rfd_version")
  end

  # rfd's defaults (xdg-portal and wayland) and file-handle-inner; plan
  # 002, decision 7 says why gtk3 and common-controls-v6 are not built.
  def test_the_manifest_pins_that_rfd_with_its_features
    manifest = File.read(File.join(ROOT, "ext/ferro_rfd/Cargo.toml"))
    rfd = manifest[/^rfd = .*$/]

    assert_includes rfd, %(version = "=#{locked_rfd}")
    assert_includes rfd, %(features = ["file-handle-inner"])
    refute_includes rfd, "default-features"
  end

  def test_the_readme_names_that_rfd
    assert_includes File.read(File.join(ROOT, "README.rdoc")), "rfd #{locked_rfd}"
  end

  def test_the_gem_takes_rfds_license_and_ruby_4
    assert_equal %w[MIT], SPEC.licenses
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
