# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"

# Tests what a gem's extconf.rb has rb_sys's Makefile hand rb-sys's build
# script: every RbConfig entry as RBCONFIG_<key>, except on Windows, where
# keys that differ only in case would arrive as one variable, so bindgen
# lost CPPFLAGS and with it -DSIZEOF_RB_LEN_T=8
# (doc/contributors/plan/016.md). Each test writes the gem's real Makefile
# with its real extconf.rb.
class TestRbconfigEnv < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  # The gems whose extconf.rb leaves those keys out. The others gain it in
  # releases of their own.
  GEMS = %w[url].freeze

  private def exported(gem)
    extconf = Dir.glob(File.join(ROOT, "gems", gem, "ext", "*", "extconf.rb")).fetch(0)
    Dir.mktmpdir("ferro-rbconfig-env") do |dir|
      output, status = Open3.capture2e(RbConfig.ruby, extconf, chdir: dir)
      assert status.success?, output
      File.read(File.join(dir, "Makefile")).scan(/^export (RBCONFIG_\S+) :=/).flatten
    end
  end

  private def ambiguous
    RbConfig::CONFIG.keys.group_by(&:downcase).values.select { |keys| keys.size > 1 }.flatten
  end

  def test_on_windows_no_two_exported_keys_differ_only_in_case
    skip "Windows' environment names ignore case; elsewhere every key is exported" unless Gem.win_platform?
    refute_empty ambiguous, "RbConfig has no keys that differ only in case, so this test checks nothing"

    GEMS.each do |gem|
      names = exported(gem)

      assert_includes names, "RBCONFIG_host_os", gem
      assert_empty names.group_by(&:downcase).values.select { |keys| keys.size > 1 }, gem
      assert_empty names & ambiguous.map { |key| "RBCONFIG_#{key}" }, gem
    end
  end

  def test_elsewhere_every_key_is_exported
    skip "On Windows the keys that differ only in case are left out" if Gem.win_platform?

    GEMS.each do |gem|
      names = exported(gem)

      assert_empty RbConfig::CONFIG.keys.map { |key| "RBCONFIG_#{key}" } - names, gem
    end
  end
end
