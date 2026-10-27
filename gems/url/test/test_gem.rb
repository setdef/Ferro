# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The gem names the url it binds in one place a user reads (README), one a
# tool reads (metadata), and two Cargo reads (manifest, lockfile). They
# must agree, and url's copy of idna must be the one ferro-idna binds.
class TestGem < Minitest::Test
  ROOT = UrlSuite::ROOT
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-url.gemspec"))

  private def locked(name)
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "#{name}"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_url
    assert_equal locked("url"), SPEC.metadata.fetch("url_version")
  end

  # Every feature that builds is on (plan 005, decision 2).
  def test_the_manifest_pins_that_url_and_form_urlencoded
    manifest = File.read(File.join(ROOT, "ext/ferro_url/Cargo.toml"))
    url = manifest[/^url = .*$/]

    assert_includes url, %(version = "=#{locked('url')}")
    assert_includes url, %(features = ["serde", "expose_internals"])
    assert_includes manifest, %(form_urlencoded = "=#{locked('form_urlencoded')}")
  end

  def test_the_readme_names_that_url
    assert_includes File.read(File.join(ROOT, "README.rdoc")), "url #{locked('url')}"
  end

  # Two copies of idna's tables are harmless, but two releases of idna or
  # of anything under it would let Url.parse and Ferro::Idna disagree about
  # a domain (plan 006), so every package both lockfiles name is the same
  # release in both: idna, idna_adapter, every icu_ crate and its data.
  def test_url_locks_what_ferro_idna_locks
    idna_lock = File.expand_path("../../idna/Cargo.lock", __dir__)
    skip "ferro-idna is not beside this gem" unless File.exist?(idna_lock)

    ours = packages(File.join(ROOT, "Cargo.lock"))
    theirs = packages(idna_lock)
    shared = ours.keys & theirs.keys

    assert_includes shared, "icu_properties_data"
    shared.each { |name| assert_equal theirs[name], ours[name], name }
  end

  # Each package in +lockfile+, by name, with its version.
  private def packages(lockfile)
    File.read(lockfile).scan(/^name = "([^"]+)"\nversion = "([^"]+)"$/).to_h
  end

  def test_the_gem_takes_urls_licenses_and_ruby_4
    assert_equal %w[Apache-2.0 MIT], SPEC.licenses.sort
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
