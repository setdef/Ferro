# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Windows exclusions (src/platform/windows.rs:845-880). Windows
# records them as clipboard formats no arboard API reads back, so these
# tests check that each option chains and the write still lands.
class TestWindows < Minitest::Test
  include ClipboardSuite

  def setup
    skip_unless_platform(:windows)
  end

  def test_each_exclusion_chains_and_the_text_lands
    set = clipboard.set

    assert_same set, set.exclude_from_monitoring
    assert_same set, set.exclude_from_cloud
    assert_same set, set.exclude_from_history
    set.text("excluded everywhere")
    assert_equal "excluded everywhere", clipboard.get_text
  end

  def test_a_consumed_set_refuses_every_exclusion
    set = clipboard.set
    set.text("once")

    %i[exclude_from_monitoring exclude_from_cloud exclude_from_history].each do |option|
      error = assert_raises(IOError, option.to_s) { set.public_send(option) }
      assert_equal "Ferro::Arboard::Set consumed by Set#text", error.message
    end
  end
end
