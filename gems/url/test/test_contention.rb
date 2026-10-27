# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Nothing of Ruby's runs, allocates, or is looked up while a Url's lock is
# held (plan 005, decision 20). Ruby code under the lock could switch to
# another thread, or start a garbage collection that waits for every
# Ractor, while another thread or Ractor sits in the lock holding the
# VM: the process would hang, past the reach of SIGTERM. These run in a
# child that is killed if it does not finish, so a deadlock fails.
class TestContention < Minitest::Test
  include UrlSuite

  def test_threads_raising_and_reading_on_one_url_finish
    result = in_child(<<~RUBY)
      url = Ferro::Url::Url.parse("mailto:x@y")
      # Long enough for Ruby's timer to switch threads many times over.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.5
      running = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline }
      raiser = Thread.new do
        while running.call
          begin
            url.set_port(1)
          rescue Ferro::Url::Error
            nil
          end
        end
      end
      reader = Thread.new { (url.to_s; url.host) while running.call }
      [raiser, reader].each(&:join)
      url.as_str
    RUBY

    assert_equal "mailto:x@y", result
  end

  def test_ractors_reading_one_shared_url_finish
    result = in_child(<<~RUBY)
      shared = Ractor.make_shareable(Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?q#f"))
      ractors = 4.times.map do
        Ractor.new(shared) do |url|
          5_000.times { url.host; url.origin; url.to_s; url.query_pairs.to_a; url.path_segments.to_a }
          url.host.to_s
        end
      end
      ractors.map(&:value)
    RUBY

    assert_equal ["example.com"] * 4, result
  end
end
