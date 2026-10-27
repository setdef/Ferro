# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The gem names the time it binds in one place a user reads (README), one
# a tool reads (metadata), and two Cargo reads (manifest, lockfile). They
# must agree, and the features must be the ones plan 007 chose.
class TestGem < Minitest::Test
  ROOT = TimeSuite::ROOT
  SPEC = Gem::Specification.load(File.join(ROOT, "ferro-time.gemspec"))

  private def locked(name)
    File.read(File.join(ROOT, "Cargo.lock"))[/^name = "#{name}"\nversion = "([^"]+)"$/, 1]
  end

  def test_the_metadata_names_the_locked_time
    assert_equal locked("time"), SPEC.metadata.fetch("time_version")
  end

  # Every feature with a Ruby meaning is on, and large-dates is off
  # (plan 007, decision 2).
  def test_the_manifest_pins_that_time_without_large_dates
    manifest = File.read(File.join(ROOT, "ext/ferro_time/Cargo.toml"))
    time = manifest[/^time = .*$/]

    assert_includes time, %(version = "=#{locked('time')}")
    assert_includes time, %(features = ["std", "formatting", "parsing", "local-offset", "macros", "serde-human-readable"])
    refute_includes time, "large-dates"
    refute_includes File.read(File.join(ROOT, "Cargo.lock")), %(name = "rand")
  end

  # Years past 9999 are refused, as time builds without large-dates.
  def test_years_run_from_minus_9999_to_9999
    assert_equal [-9999, 9999], [Ferro::Time::Date::MIN.year, Ferro::Time::Date::MAX.year]
    assert_raises(Ferro::Time::Error::ComponentRange) do
      Ferro::Time::Date.from_calendar_date(10_000, Ferro::Time::Month::January, 1)
    end
  end

  def test_the_readme_names_that_time
    assert_includes File.read(File.join(ROOT, "README.rdoc")), "time #{locked('time')}"
  end

  def test_the_gem_takes_times_licenses_and_ruby_4
    assert_equal %w[Apache-2.0 MIT], SPEC.licenses.sort
    assert_equal Gem::Requirement.new(">= 4.0"), SPEC.required_ruby_version
    assert_equal "true", SPEC.metadata.fetch("rubygems_mfa_required")
  end
end
