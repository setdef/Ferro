# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"

# Each gem ships copies of the license texts its files use, since a gem
# cannot package files outside its own directory. REUSE checks the root
# copies, so the gem's must match them.
class TestLicenses < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_each_gems_license_texts_match_the_roots
    copies = Dir.glob("gems/*/LICENSES/*.txt", base: ROOT)

    refute_empty copies
    copies.each do |copy|
      original = File.join(ROOT, "LICENSES", File.basename(copy))

      assert File.exist?(original), "#{copy} has no counterpart in LICENSES/"
      assert_equal File.read(original), File.read(File.join(ROOT, copy)), "#{copy} differs from LICENSES/"
    end
  end

  def test_each_gem_ships_the_licenses_its_identifiers_name
    Dir.glob("gems/*", base: ROOT).each do |gem|
      # Each Cargo.lock is CC0-1.0, through its .license file.
      sources = Dir.glob(["#{gem}/{lib,sig,ext}/**/*.{rb,rbs,rs,toml}", "#{gem}/*.{rdoc,md,toml}"], base: ROOT)
      # REUSE-IgnoreStart
      used = sources
        .flat_map { |path| File.read(File.join(ROOT, path)).scan(/SPDX-License-Identifier: (.+)$/).flatten }
        .flat_map { |expression| expression.split(/\s+(?:OR|AND)\s+/) }.uniq
      # REUSE-IgnoreEnd
      shipped = Dir.glob("#{gem}/LICENSES/*.txt", base: ROOT).map { |path| File.basename(path, ".txt") }

      assert_empty used + ["CC0-1.0"] - shipped, "#{gem} uses licenses it does not ship"
    end
  end
end
