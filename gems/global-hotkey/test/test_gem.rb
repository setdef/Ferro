# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# The gem names the global-hotkey it binds in one place a user reads
# (README), one a tool reads (metadata), and two Cargo reads (manifest,
# lockfile). They must agree.
class TestGem < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-global-hotkey.gemspec"))

  private def locked(name)
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "#{name}"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_global_hotkey
    assert_equal locked("global-hotkey"), SPEC.metadata.fetch("global_hotkey_version")
  end

  # Both of global-hotkey's features are built (plan 004, decision 2).
  def test_the_manifest_pins_that_global_hotkey_with_every_feature
    manifest = File.read(File.join(ROOT, "ext/ferro_global_hotkey/Cargo.toml"))
    global_hotkey = manifest[/^global-hotkey = .*$/]

    assert_includes global_hotkey, %(version = "=#{locked('global-hotkey')}")
    assert_includes global_hotkey, %(features = ["serde", "tracing"])
    refute_includes global_hotkey, "default-features"
  end

  def test_the_readme_names_that_global_hotkey_and_keyboard_types
    readme = File.read(File.join(ROOT, "README.rdoc"))

    assert_includes readme, "global-hotkey #{locked('global-hotkey')}"
    assert_includes File.read(File.join(ROOT, "lib/ferro/global_hotkey/hotkey/code.rb")),
      "keyboard-types #{locked('keyboard-types')}"
  end

  def test_the_gem_takes_global_hotkeys_licenses_and_ruby_4
    assert_equal %w[Apache-2.0 MIT], SPEC.licenses.sort
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
