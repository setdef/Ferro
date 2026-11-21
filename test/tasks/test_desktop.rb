# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "rbconfig"
require "tasks/desktop"

# Tests Desktop (plan 014): the variable that lets a test process use the
# desktop, the guard that refuses the desktop to every other process, the
# skip where there is no desktop session, and launchd's answer on macOS.
class TestDesktop < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_only_one_lets_a_process_use_the_desktop
    assert Desktop.allowed?("FERRO_DESKTOP" => "1")
    refute Desktop.allowed?({})
    refute Desktop.allowed?("FERRO_DESKTOP" => "0")
    refute Desktop.allowed?("FERRO_DESKTOP" => "true")
  end

  def test_a_test_process_gets_the_variable_only_for_desktop_tests
    assert_equal({ "FERRO_DESKTOP" => "1" }, Desktop.run_env(true))
    assert_equal({ "FERRO_DESKTOP" => nil }, Desktop.run_env(false))
  end

  # A stand-in for a binding's class, whose method stands for a way onto
  # the desktop.
  private def binding_class
    Class.new do
      def self.open(name, size: 1)
        "opened #{name} at #{size}"
      end
    end
  end

  def test_outside_a_desktop_run_a_guarded_method_raises_naming_what_it_does
    klass = binding_class
    Desktop.guard(klass.singleton_class, :open, "open shows a window", {})

    error = assert_raises(Desktop::Outside) { klass.open("a", size: 2) }
    assert_equal "open shows a window, so only a desktop test may call it. Move the test to the gem's test/desktop/, " \
      "which the desktop tasks run with FERRO_DESKTOP=1 (doc/contributors/plan/014.md).", error.message
    assert Desktop.guarded?(klass.singleton_class, :open)
  end

  def test_in_a_desktop_run_a_guarded_method_runs
    klass = binding_class
    Desktop.guard(klass.singleton_class, :open, "open shows a window", "FERRO_DESKTOP" => "1")

    assert_equal "opened a at 2", klass.open("a", size: 2)
    refute Desktop.guarded?(klass.singleton_class, :open)
  end

  def test_a_method_no_guard_refused_is_not_guarded
    refute Desktop.guarded?(binding_class.singleton_class, :open)
    refute Desktop.guarded?(String, :upcase)
  end

  # Runs a throwaway suite in its own process, which loads the desktop
  # tasks' prelude, with launchd's answer replaced by +reason+.
  private def run_suite(reason, body)
    script = <<~RUBY
      require "tasks/desktop"
      require "minitest/autorun"
      Desktop.define_singleton_method(:session_unavailable_reason) { #{reason.inspect} }
      Desktop.skip_each_test_without_a_session
      class TestFixture < Minitest::Test
        #{body}
      end
    RUBY
    Open3.capture2e(RbConfig.ruby, "-I", ROOT, "-e", script, "--", "--verbose", chdir: ROOT)
  end

  # Each test skips before its setup, so a teardown that needs what setup
  # made does not run either, and the skip names the reason.
  def test_without_a_session_each_test_skips_before_its_setup_naming_the_reason
    body = <<~RUBY
      def setup; puts "setup ran"; end
      def teardown; puts "teardown ran"; end
      def test_one; puts "test ran"; end
      def test_two; puts "test ran"; end
    RUBY
    output, status = run_suite("no desktop here", body)

    assert_predicate status, :success?, output
    assert_includes output, "2 runs, 0 assertions, 0 failures, 0 errors, 2 skips"
    assert_equal 2, output.scan("no desktop here").size, output
    refute_match(/setup ran|teardown ran|test ran/, output)
  end

  def test_with_a_session_each_test_runs
    output, status = run_suite(nil, "def setup; puts 'setup ran'; end; def test_one; assert true; end")

    assert_predicate status, :success?, output
    assert_includes output, "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    assert_includes output, "setup ran"
  end

  # A daemon's session, as a build machine's, has no window server.
  def test_a_session_that_is_not_aqua_is_named
    assert_equal 'no macOS GUI session (launchctl managername is "System", not "Aqua")', Desktop.no_session_reason("System")
    assert_equal 'no macOS GUI session (launchctl managername is "", not "Aqua")', Desktop.no_session_reason("")
    assert_nil Desktop.no_session_reason("Aqua")
  end

  def test_off_macos_no_session_is_missing
    skip "Desktop asks launchd here" if Desktop.macos?

    assert_nil Desktop.session_unavailable_reason
  end

  def test_on_macos_the_answer_is_launchds_and_is_asked_once
    skip "Desktop asks launchd only on macOS" unless Desktop.macos?

    session = IO.popen(["launchctl", "managername"], &:read).strip
    reason = Desktop.session_unavailable_reason

    if session == "Aqua"
      assert_nil reason
    else
      assert_equal Desktop.no_session_reason(session), reason
    end
    assert_same reason, Desktop.session_unavailable_reason
  end
end
