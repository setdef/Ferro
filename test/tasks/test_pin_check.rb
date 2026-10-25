# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require_relative "../../tasks/pin_check"

# Tests the check that every gem links the same magnus and rb-sys
# (ADR 001, section 3), on lockfiles shaped like Cargo's.
class TestPinCheck < Minitest::Test
  REGISTRY = "registry+https://github.com/rust-lang/crates.io-index"

  private def lock(magnus: "0.9.3", rb_sys: "0.9.130", magnus_source: REGISTRY)
    <<~TOML
      version = 4

      [[package]]
      name = "arboard"
      version = "3.7.0"
      source = "#{REGISTRY}"

      [[package]]
      name = "magnus"
      version = "#{magnus}"
      source = "#{magnus_source}"

      [[package]]
      name = "rb-sys"
      version = "#{rb_sys}"
      source = "#{REGISTRY}"

      [[package]]
      name = "ferro_arboard"
      version = "0.1.0-pre.1"
    TOML
  end

  private def check(lockfiles, requirements = lockfiles.transform_values { "~> 0.9.129" })
    PinCheck.new(lockfiles:, requirements:).check!
  end

  def test_gems_that_agree_pass_and_report_the_pins
    pins = check({ "ferro-a" => lock, "ferro-b" => lock })

    assert_equal({ "magnus" => "0.9.3 (#{REGISTRY})", "rb-sys" => "0.9.130 (#{REGISTRY})" }, pins)
  end

  def test_a_different_magnus_version_fails
    error = assert_raises(PinCheck::Failure) { check({ "ferro-a" => lock, "ferro-b" => lock(magnus: "0.9.2") }) }

    assert_includes error.message, "Gems disagree on magnus"
    assert_includes error.message, "ferro-b: 0.9.2"
  end

  def test_a_different_magnus_source_fails
    git = "git+https://github.com/matsadler/magnus?rev=2370a352#2370a352"

    error = assert_raises(PinCheck::Failure) do
      check({ "ferro-a" => lock, "ferro-b" => lock(magnus_source: git) })
    end

    assert_includes error.message, "ferro-b: 0.9.3 (#{git})"
  end

  def test_a_different_rb_sys_crate_fails
    error = assert_raises(PinCheck::Failure) { check({ "ferro-a" => lock, "ferro-b" => lock(rb_sys: "0.9.129") }) }

    assert_includes error.message, "Gems disagree on rb-sys"
  end

  def test_a_different_rb_sys_gem_requirement_fails
    error = assert_raises(PinCheck::Failure) do
      check({ "ferro-a" => lock, "ferro-b" => lock }, { "ferro-a" => "~> 0.9.129", "ferro-b" => "~> 0.9.130" })
    end

    assert_includes error.message, "Gems disagree on the rb_sys gem"
  end

  def test_a_gem_without_a_native_extension_is_ignored
    assert check({ "ferro-a" => lock, "ferro-pure" => "version = 4\n" }, { "ferro-a" => "~> 0.9.129", "ferro-pure" => nil })
  end

  def test_two_versions_in_one_lockfile_are_both_reported
    double = "#{lock}\n[[package]]\nname = \"magnus\"\nversion = \"0.8.4\"\nsource = \"#{REGISTRY}\"\n"

    assert_equal "0.8.4 (#{REGISTRY}), 0.9.3 (#{REGISTRY})", PinCheck.pin(double, "magnus")
  end

  def test_the_repositorys_gems_agree
    root = File.expand_path("../..", __dir__)
    lockfiles = Dir.glob("gems/*/Cargo.lock", base: root).to_h { |path| [path, File.read(File.join(root, path))] }

    refute_empty lockfiles
    assert check(lockfiles)
  end
end
