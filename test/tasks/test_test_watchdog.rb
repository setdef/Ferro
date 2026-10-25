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
    assert_match(/in 'Kernel#sleep'/, output)
  end

  def test_tests_within_the_limit_pass
    output, status = run_suite("def test_quick; sleep 0.2; assert true; end; def test_also; assert true; end")

    assert_predicate status, :success?, output
    assert_includes output, "2 runs, 2 assertions, 0 failures"
  end
end
