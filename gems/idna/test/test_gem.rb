# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The gem names the idna it binds in one place a user reads (README), one
# a tool reads (metadata), and two Cargo reads (manifest, lockfile). They
# must agree.
class TestGem < Minitest::Test
  ROOT = IdnaSuite::ROOT
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-idna.gemspec"))

  private def locked(name)
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "#{name}"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_idna
    assert_equal locked("idna"), SPEC.metadata.fetch("idna_version")
  end

  # idna's three features are its defaults (plan 006, decision 2).
  def test_the_manifest_pins_that_idna_with_its_default_features
    manifest = File.read(File.join(ROOT, "ext/ferro_idna/Cargo.toml"))

    assert_includes manifest, %(idna = "=#{locked('idna')}")
  end

  def test_the_readme_names_that_idna
    assert_includes File.read(File.join(ROOT, "README.rdoc")), "idna #{locked('idna')}"
  end

  def test_the_gem_takes_idnas_licenses_and_ruby_4
    assert_equal %w[Apache-2.0 MIT], SPEC.licenses.sort
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
