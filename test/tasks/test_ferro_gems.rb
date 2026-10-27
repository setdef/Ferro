# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require_relative "../../tasks/changelog"
require_relative "../../tasks/ferro_gems"

# Tests what the root tasks read from a FerroGem: where its version lives,
# whatever its name, and which signature files belong to other platforms.
class TestFerroGems < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  private def gem(**overrides)
    FerroGem.new(short_name: "notify-rust", name: "ferro-notify-rust", crate: "ext/ferro_notify_rust",
      extension: "lib/ferro/notify_rust/ferro_notify_rust", packaged: [], native_namespace: "Ferro::NotifyRust",
      platform_sigs: {}, platform_probe: "", smoke: "", **overrides)
  end

  # Most gems' signatures name only their own types and core's; one that
  # names a standard library's, as ferro-url names IPAddr, lists it.
  def test_a_gem_needs_no_standard_library_signatures_unless_it_says_so
    assert_empty gem.rbs_libraries
    assert_equal %w[ipaddr socket], gem(rbs_libraries: %w[ipaddr socket]).rbs_libraries
    assert_equal %w[ipaddr socket], FERRO_GEMS.find { |ferro_gem| ferro_gem.short_name == "url" }.rbs_libraries
  end

  # rbs validate loads each standard library once, before the gems'
  # signature directories, so a gem's IPAddr resolves.
  def test_rbs_validate_loads_the_libraries_the_gems_name
    plain = gem
    urlish = gem(short_name: "url", rbs_libraries: %w[ipaddr socket])
    other = gem(short_name: "idna", rbs_libraries: %w[ipaddr])

    assert_equal [
      "-r",
      "ipaddr",
      "-r",
      "socket",
      "-I",
      "gems/notify-rust/sig",
      "-I",
      "gems/url/sig",
      "-I",
      "gems/idna/sig",
      "validate",
], FerroGem.rbs_validate_arguments([plain, urlish, other])
  end

  # Steep checks each gem with the same libraries rbs validate loads.
  def test_steep_targets_come_from_the_registered_gems
    steepfile = File.read(File.join(ROOT, "Steepfile"))

    assert_includes steepfile, "FERRO_GEMS.each"
    assert_includes steepfile, "library(*ferro_gem.rbs_libraries)"
  end

  # A crate with a hyphen has a require path that follows its Rust name,
  # not the gem name with the hyphen turned into a slash (plan 003).
  def test_the_version_file_sits_beside_the_extension
    assert_equal "lib/ferro/notify_rust/version.rb", gem.version_file
  end

  def test_every_registered_gem_has_its_version_file
    FERRO_GEMS.each do |ferro_gem|
      path = File.join(ROOT, ferro_gem.dir, ferro_gem.version_file)

      assert_path_exists path
      assert_includes File.read(path), %(VERSION = "#{ferro_gem.spec.version}")
    end
  end

  # A release moves the Unreleased link at the bottom of the gem's
  # CHANGELOG.md (tasks/changelog.rb), so a gem without one cannot be
  # released; ferro-global-hotkey's first release found that out.
  def test_every_registered_gem_has_an_unreleased_link_to_move
    FERRO_GEMS.each do |ferro_gem|
      content = File.read(File.join(ROOT, ferro_gem.dir, ferro_gem.changelog))

      assert_match Changelog::UNRELEASED_LINK, content, "#{ferro_gem.name} has no [Unreleased]: link"
    end
  end

  def test_a_signature_file_two_platforms_share_is_foreign_only_to_the_third
    sigs = {
      "linux" => %w[sig/linux.rbs sig/deref.rbs],
      "macos" => "sig/apple.rbs",
      "windows" => %w[sig/windows.rbs sig/deref.rbs],
    }
    shared = gem(platform_sigs: sigs)

    assert_equal %w[sig/apple.rbs sig/windows.rbs].map { |path| "gems/notify-rust/#{path}" },
      shared.foreign_sigs("linux").sort
    assert_equal %w[sig/deref.rbs sig/linux.rbs sig/windows.rbs].map { |path| "gems/notify-rust/#{path}" },
      shared.foreign_sigs("macos").sort
  end
end
