# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rbconfig"

# Which test processes may use the desktop of the session that runs them
# (plan 014).
#
# Some of each gem's tests use the session's desktop: they write the
# clipboard, show notifications and dialogs, and register hotkeys for
# everyone. Run where you work, they do it to you. So they live apart, in
# each gem's <tt>test/desktop/</tt>, and run only in the desktop test tasks
# (tasks/test.rake), which run nothing unless FERRO_DESKTOP is 1. The gate
# sets it. The other tasks remove it from their test processes, whatever
# your shell exported.
#
# A Mac can run a process outside any login session, as a build machine's
# daemon does. There is no window server there, and no pasteboard,
# notification center, or file panel, so every desktop test would fail or
# hang. The desktop tasks load #skip_each_test_without_a_session, which
# skips each test there instead, naming the reason.
#
# A gem's test helper loads this too, and calls #guard on the gem's own
# ways onto the desktop. Outside a desktop run, each then raises Outside,
# so a desktop test filed with the others fails, instead of reaching your
# desktop.
module Desktop
  # The variable that lets a test process use the desktop.
  VARIABLE = "FERRO_DESKTOP"

  # Raised where a test outside a desktop run reaches the desktop.
  class Outside < StandardError; end

  # Skips each test before its setup runs, where there is no desktop
  # session, so a teardown that needs what setup made never runs either.
  module SkipWithoutSession
    # Runs the test, or records it as skipped, naming the reason.
    def run
      reason = Desktop.session_unavailable_reason
      return super unless reason

      time_it { capture_exceptions { skip reason } }
      Minitest::Result.from(self)
    end
  end

  class << self
    # Whether +env+ lets this process use the desktop.
    def allowed?(env = ENV)
      env[VARIABLE] == "1"
    end

    # The environment for a test process: FERRO_DESKTOP=1 if +desktop+,
    # and unset otherwise.
    def run_env(desktop)
      { VARIABLE => (desktop ? "1" : nil) }
    end

    # Why this Mac has no GUI session, or +nil+ when it has one or this is
    # not a Mac. launchd names the session a process runs in: Aqua for a
    # person's login, System for a daemon's.
    def session_unavailable_reason
      return nil unless macos?
      return @session if defined?(@session)

      @session = no_session_reason(IO.popen(["launchctl", "managername"], err: File::NULL, &:read).to_s.strip)
    end

    # Why launchd's session +name+ is not a GUI session, or +nil+ for Aqua.
    def no_session_reason(name)
      "no macOS GUI session (launchctl managername is #{name.inspect}, not \"Aqua\")" unless name == "Aqua"
    end

    # Makes every test in this process skip, naming the reason, where
    # there is no desktop session. The desktop tasks load it.
    def skip_each_test_without_a_session
      Minitest::Test.prepend(SkipWithoutSession)
    end

    # Unless +env+ lets this process use the desktop, makes the method
    # +name+ of +owner+ raise Outside, saying that +what+. +owner+ is a
    # class or module, or a singleton class for a class method:
    #
    #   Desktop.guard(Ferro::Arboard::Clipboard.singleton_class, :new,
    #     "Clipboard.new opens the session's clipboard")
    def guard(owner, name, what, env = ENV)
      return if allowed?(env)

      message = "#{what}, so only a desktop test may call it. Move the test to the gem's test/desktop/, " \
        "which the desktop tasks run with #{VARIABLE}=1 (doc/contributors/plan/014.md)."
      guard = Module.new do
        define_method(name) { |*| raise Outside, message }
      end
      owner.prepend(guard)
    end

    # Whether #guard refused the method +name+ of +owner+.
    def guarded?(owner, name)
      owner.instance_method(name).source_location&.first == __FILE__
    end

    # Whether this is a Mac.
    def macos?
      RbConfig::CONFIG["host_os"].include?("darwin")
    end
  end
end
