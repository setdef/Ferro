# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Every call that blocks runs with Ruby's global VM lock released, and
# never with it held (plan 003, decision 6). These tests count the
# releases (gvl.rs RELEASES) rather than time a spinning thread: a
# released lock does not promise another thread runs, since from Ruby
# 4.0.6 on a thread back from a short blocking region takes the lock
# straight back when the thread it woke has not started yet
# (thread_pthread.c:846-867 and :1055-1066 at v4.0.9). test_linux.rb shows
# other threads running during a wait, against a real server.
#
# Each test makes a call that blocks without showing a notification: on
# macOS mac-notification-sys asks AppleScript for an app's bundle
# identifier; on Linux notify-rust asks the session bus for the server's
# specification version, which, with no bus, fails and falls back to 1.1.
# Windows has no such call: every one shows a toast.
class TestGvl < Minitest::Test
  include NotifySuite

  # The call, as Ruby source for a child, and what it returns there.
  CALLS = {
    macos: ['Ferro::NotifyRust.get_bundle_identifier_or_default("Finder")', "com.apple.finder"],
    linux: ["Ferro::NotifyRust.const_get(:Native).spec_version", [1, 1]],
  }.freeze

  # A bus nobody serves, so the Linux call fails fast and falls back.
  NO_BUS = { "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/nonexistent/bus" }.freeze

  def setup
    skip "every blocking call on Windows shows a toast" if PLATFORM == :windows
  end

  # In a child: the Linux call reads notify-rust's SPEC_VERSION, a
  # lazy_static (src/lib.rs:227-233) that keeps the first answer for the
  # process, so made here it would fix the 1.1 fallback for every later
  # test in this process, such as test_spec_version_is_the_servers.
  def test_a_blocking_call_releases_the_lock_once
    call, expected = CALLS.fetch(PLATFORM)
    outcome, = in_child(<<~RUBY, NO_BUS)
      native = Ferro::NotifyRust.const_get(:Native)
      before = native.gvl_releases
      value = #{call}
      [value, native.gvl_releases - before]
    RUBY

    assert_equal [expected, 1], outcome
  end

  # Ruby asks an exception for its backtrace while raising it, with the
  # thread marked as raising (setup_exception, eval.c:542-543, and
  # rb_get_backtrace, error.c:1929, at v4.0.9). A thread so marked runs no
  # interrupts (thread.c:2625), so one made pending there (Thread#wakeup
  # sets the flag, thread.c:2969-2982) stays pending.
  # rb_thread_call_without_gvl2 skips its work while any interrupt is
  # pending (thread.c:320-327), so the gem used to retry three times and
  # then run the call with the lock held, stalling every thread. The
  # plain rb_thread_call_without_gvl runs the pending interrupts, which
  # return at once here, and proceeds (thread.c:328-334), so the call runs
  # released, once. The child keeps Ruby's raising state out of this run;
  # a gem that skipped the work forever would spin until the child is
  # killed.
  def test_a_call_made_while_raising_with_an_interrupt_pending_runs_with_the_lock_released
    call, expected = CALLS.fetch(PLATFORM)
    outcome, = in_child(<<~RUBY, NO_BUS)
      class CallWhileRaising < StandardError
        attr_reader :value, :releases

        def initialize(&call)
          super("call while raising")
          @call = call
        end

        def backtrace
          call, @call = @call, nil
          if call
            native = Ferro::NotifyRust.const_get(:Native)
            before = native.gvl_releases
            @value = call.call
            @releases = native.gvl_releases - before
          end
          super
        end
      end

      begin
        raise CallWhileRaising.new { Thread.current.wakeup; #{call} }
      rescue CallWhileRaising => e
        [e.value, e.releases]
      end
    RUBY

    assert_equal [expected, 1], outcome
  end
end
