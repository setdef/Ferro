# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Linux API that needs no notification server. desktop/test_linux.rb
# shows notifications to a real one.
class TestLinuxWithoutServer < Minitest::Test
  include NotifySuite

  def setup
    skip_unless_platform(:linux)
  end

  # Without a server notify-rust's static falls back to 1.1. The child
  # names it first from another Ractor, which Ruby loads on the main one.
  def test_spec_version_falls_back_to_one_one_and_loads_from_any_ractor
    outcome, = in_child(<<~RUBY, "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/nonexistent/bus")
      pending = Ferro::NotifyRust.autoload?(:SPEC_VERSION)
      version = Ractor.new { Ferro::NotifyRust::SPEC_VERSION }.value
      [pending.nil?, version.major, version.minor, Ferro::NotifyRust.autoload?(:SPEC_VERSION)]
    RUBY

    assert_equal [false, 1, 1, nil], outcome
  end
end
