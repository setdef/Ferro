# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "rbconfig"

# Tests the watchdog every test process loads, on a throwaway suite run in
# its own process with a one-second limit.
class TestTestWatchdog < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  private def run_suite(body)
    script = %(require "tasks/test_watchdog"; require "minitest/autorun"; class TestFixture < Minitest::Test; #{body}; end)
    Open3.capture2e({ "FERRO_TEST_TIMEOUT" => "1" }, RbConfig.ruby, "-I", ROOT, "-e", script, chdir: ROOT)
  end

  def test_a_hanging_test_fails_by_name_with_every_threads_backtrace
    output, status = run_suite("def test_hangs; sleep 30; end")

    refute_predicate status, :success?
    assert_includes output, "TestFixture#test_hangs did not finish within 1 s"
    assert_operator Float(output[/it has run (\d+\.\d) s/, 1]), :>=, 1.0
    assert_match(/in 'Kernel#sleep'/, output)
  end

  # Each test gets the whole limit from its own start, however long the
  # tests before it took together.
  def test_the_limit_is_per_test_and_never_ends_one_early
    tests = Array.new(3) { |n| "def test_#{n}; sleep 0.7; assert true; end" }.join("; ")

    output, status = run_suite(tests)

    assert_predicate status, :success?, output
    assert_includes output, "3 runs, 3 assertions, 0 failures"
  end
end
