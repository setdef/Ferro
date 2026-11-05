# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# time's extension traits are refinements, so a file that does not bring
# one in with +using+ sees Ruby's Integer, Float, and ::Time unchanged,
# even with the gem loaded and other files using them (ADR 001,
# 2026-11-05).
class TestExtScope < Minitest::Test
  def test_ruby_s_classes_are_unchanged_without_using
    assert_raises(NoMethodError) { 5.seconds }
    assert_raises(NoMethodError) { 1.5.weeks }
    assert_raises(NoMethodError) { 5.std_seconds }
    assert_raises(NoMethodError) { ::Time.now.signed_duration_since(::Time.now) }
    refute_respond_to 5, :seconds
    refute_respond_to ::Time.now, :checked_add_signed
  end
end
