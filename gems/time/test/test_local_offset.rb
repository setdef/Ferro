# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The local offset comes from the system's time-zone rules, as Ruby's own
# Time#utc_offset does, and refresh_tz runs only where time can prove it
# sound (plan 007, decision 13).
class TestLocalOffset < Minitest::Test
  include TimeSuite

  def test_the_current_offset_is_the_one_ruby_reads
    assert_equal ::Time.now.utc_offset, T::UtcOffset.current_local_offset.whole_seconds
    assert_equal ::Time.now.utc_offset, T::OffsetDateTime.now_local.offset.whole_seconds
  end

  # time's own local_offset_success_when_multithreaded
  # (tests/integration/utc_offset.rs:186-192): since 0.3.37 a
  # multi-threaded process reads its offset, and a Ruby process always is
  # one on Linux.
  def test_the_offset_reads_with_other_threads_running
    threads = Array.new(4) { Thread.new { T::UtcOffset.current_local_offset } }
    threads.each { |thread| assert_kind_of T::UtcOffset, thread.value }
  end

  def test_the_offset_at_an_instant_follows_the_zone_rules
    [0, 1_000_000_000, 1_719_792_000].each do |seconds|
      instant = T::OffsetDateTime.from_unix_timestamp(seconds)
      assert_equal ::Time.at(seconds).utc_offset, T::UtcOffset.local_offset_at(instant).whole_seconds, seconds
    end
  end

  def test_a_zone_set_before_ruby_starts_is_read
    skip "TZ names a zone file only on Unix" if Gem.win_platform?

    offsets = in_child(<<~RUBY, env: { "TZ" => "Asia/Kolkata" })
      [Ferro::Time::UtcOffset.current_local_offset.whole_seconds, ::Time.now.utc_offset]
    RUBY
    assert_equal [19_800, 19_800], offsets
  end

  # time refreshes the zone cache only where it can prove tzset sound: on
  # macOS, whose environment is thread-safe, and in a single-threaded
  # process, which Ruby on Linux never is (it starts a timer thread). The
  # Windows build has no tzset and always answers.
  def test_refresh_tz_answers_where_time_proves_it_sound
    if RUBY_PLATFORM.include?("linux")
      assert_nil T::Util.refresh_tz
    else
      assert T::Util.refresh_tz
    end
  end
end
