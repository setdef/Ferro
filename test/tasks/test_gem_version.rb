# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require_relative "../../tasks/gem_version"

# Tests the version arithmetic behind bump:<gem>:*, written as RubyGems
# writes versions.
class TestGemVersion < Minitest::Test
  private def bump(from, segment, label = nil)
    GemVersion.parse(from).next(segment, label).to_s
  end

  def test_a_segment_bump_resets_the_segments_after_it
    assert_equal "0.1.1", bump("0.1.0", :patch)
    assert_equal "0.2.0", bump("0.1.3", :minor)
    assert_equal "1.0.0", bump("0.4.2", :major)
  end

  def test_a_bump_finishes_a_prerelease_it_leads_up_to
    assert_equal "0.1.0", bump("0.1.0.pre.2", :patch)
    assert_equal "0.1.0", bump("0.1.0.pre.2", :minor)
    assert_equal "1.0.0", bump("0.1.0.pre.2", :major)
  end

  def test_a_label_counts_up_toward_the_same_release
    assert_equal "0.1.0.pre.2", bump("0.1.0.pre.1", :patch, "pre")
    assert_equal "0.1.0.pre.2", bump("0.1.0.pre.1", :minor, "pre")
    assert_equal "0.1.0.rc.1", bump("0.1.0.beta.3", :patch, "rc")
    assert_equal "0.2.0.pre.1", bump("0.1.0", :minor, "pre")
  end

  def test_a_label_that_sorts_backwards_is_refused
    error = assert_raises(ArgumentError) { bump("0.1.0.rc.1", :patch, "beta") }

    assert_equal "0.1.0.beta.1 would come before 0.1.0.rc.1; pick a label that sorts after rc", error.message
  end

  def test_bad_input_is_refused
    assert_raises(ArgumentError) { GemVersion.parse("0.1.0-pre.2") }
    assert_raises(ArgumentError) { GemVersion.parse("1.2.3.4") }
    assert_raises(ArgumentError) { GemVersion.parse("soon") }
    assert_raises(ArgumentError) { bump("0.1.0", :build) }
    assert_raises(ArgumentError) { bump("0.1.0", :patch, "pre-2") }
  end

  def test_versions_order_as_rubygems_orders_them
    assert_operator GemVersion.parse("0.1.0.pre.10"), :>, GemVersion.parse("0.1.0.pre.9")
    assert_operator GemVersion.parse("0.1.0"), :>, GemVersion.parse("0.1.0.pre.9")
  end

  def test_cargo_spells_a_prerelease_with_a_hyphen
    assert_equal "0.1.0-pre.2", GemVersion.parse("0.1.0.pre.2").cargo
    assert_equal "0.1.0", GemVersion.parse("0.1").cargo
  end

  def test_stable_means_one_point_oh_and_no_prerelease
    refute_predicate GemVersion.parse("0.9.0"), :stable?
    refute_predicate GemVersion.parse("1.0.0.rc.1"), :stable?
    assert_predicate GemVersion.parse("1.0.0"), :stable?
  end
end
