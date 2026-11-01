# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# time's types are plain Copy data and the extension keeps no Ruby value
# in a static, so the extension is marked Ractor-safe and every value the
# gem makes is frozen and shareable (plan 007, decision 17). Without
# rb_ext_ractor_safe, every native call from a non-main Ractor raises
# Ractor::UnsafeError.
#
# On Windows the script runs in a child process, because of the Ruby 4.0
# barrier bug plan 001 found. Elsewhere it runs in this process.
class TestRactor < Minitest::Test
  include TimeSuite

  private def run_script(script)
    return in_child(script) if Gem.win_platform?

    experimental = Warning[:experimental]
    Warning[:experimental] = false
    # A fresh binding each time, so one script's locals are not another's
    # outer variables, which a Ractor's block may not touch.
    eval(script, Object.new.instance_eval { binding })
  ensure
    Warning[:experimental] = experimental unless Gem.win_platform?
  end

  def test_another_ractor_parses_formats_and_does_arithmetic
    result = run_script(<<~RUBY)
      Ractor.new do
        t = Ferro::Time
        iso = t::FormatDescription::WellKnown::Iso8601
        at = t::OffsetDateTime.parse("2026-10-26T12:00:00.000Z", iso::DEFAULT)
        later = at + t::Duration.days(1)
        [later.format(iso::DATE), later.weekday.to_s, t::UtcOffset.current_local_offset.is_a?(t::UtcOffset)]
      end.value
    RUBY

    assert_equal ["2026-10-27", "Tuesday", true], result
  end

  def test_every_value_is_shareable
    result = run_script(<<~RUBY)
      t = Ferro::Time
      values = [
        t::Date::MIN, t::Time::MIDNIGHT, t::PlainDateTime::MAX, t::UtcDateTime::UNIX_EPOCH,
        t::OffsetDateTime::UNIX_EPOCH, t::UtcOffset::UTC, t::Duration::DAY, t::Month::May, t::Weekday::Friday,
        t::FormatDescription.parse_owned(3, "[year]"), t::FormatDescription::WellKnown::Iso8601::DEFAULT,
        t::Timestamp::MAX,
      ]
      shareable = values.map { |value| Ractor.shareable?(value) }
      Ractor.new(values) do |shared|
        refused = begin
          shared[1].format(shared[10])
        rescue TypeError => e
          e.message
        end
        [shared[0].to_s, shared[6].to_s, shared[4].format(shared[9]), refused, (shared[11] - shared[11]).to_s]
      end.value => answers
      [shareable, answers]
    RUBY

    assert_equal [true] * 12, result.first
    assert_equal [
      "-9999-01-01",
      "1d",
      "1970",
      "this Iso8601 configuration formats date components, but this type cannot provide them",
      "0s",
], result.last
  end

  # Building an error's arguments must not touch Ruby's global state:
  # registering them with the collector (BoxValue) edits a VM-wide list
  # without a lock on Ruby 4.0.9 and crashed parallel Ractors. The child
  # segfaults if that comes back.
  def test_many_ractors_raise_errors_at_once
    counts = in_child(<<~RUBY)
      t = Ferro::Time
      ractors = 8.times.map do
        Ractor.new do
          raised = 0
          20_000.times do
            Ferro::Time::Timestamp.from_seconds(2**62)
          rescue Ferro::Time::Error::ComponentRange => e
            raised += 1 if e.name == "seconds"
          end
          raised
        end
      end
      ractors.map(&:value)
    RUBY

    assert_equal [20_000] * 8, counts
  end
end
