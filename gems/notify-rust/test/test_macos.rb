# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# macOS, through mac-notification-sys. Its application hook is set once per
# process, so the tests that touch it run in a child. A notification sent
# from a process the notification center does not know is never confirmed
# delivered: mac-notification-sys then gives up after two seconds and
# reports it auto-dismissed (objc/notify.m:161-209), which is what lets
# these tests wait without a person. The child also removes any delivered
# notification each half second, so a Mac that does show one still ends the
# wait.
class TestMacOS < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  # The title every test notification carries, so the sweeper removes
  # only these.
  TITLE = "ferro-notify-rust test"

  # Removes this suite's delivered notifications, found by TITLE, every
  # half second, so a wait on a Mac that shows the notification still
  # ends. The app the notifications come from (Finder by default) may hold
  # notifications of the user's own, so it leaves every other one alone.
  # Uses AppKit through Fiddle, inside an autorelease pool, from a Ruby
  # thread, while the wait runs the main thread's loop.
  SWEEPER = <<~RUBY
    require "fiddle"
    objc = Fiddle.dlopen("/usr/lib/libobjc.A.dylib")
    Fiddle.dlopen("/System/Library/Frameworks/Foundation.framework/Foundation")
    pointer = Fiddle::TYPE_VOIDP
    message = objc["objc_msgSend"]
    send = Fiddle::Function.new(message, [pointer, pointer], pointer)
    count = Fiddle::Function.new(message, [pointer, pointer], Fiddle::TYPE_LONG)
    at = Fiddle::Function.new(message, [pointer, pointer, Fiddle::TYPE_LONG], pointer)
    remove = Fiddle::Function.new(message, [pointer, pointer, pointer], Fiddle::TYPE_VOID)
    get_class = Fiddle::Function.new(objc["objc_getClass"], [pointer], pointer)
    selector = Fiddle::Function.new(objc["sel_registerName"], [pointer], pointer)
    push = Fiddle::Function.new(objc["objc_autoreleasePoolPush"], [], pointer)
    pop = Fiddle::Function.new(objc["objc_autoreleasePoolPop"], [pointer], Fiddle::TYPE_VOID)
    sweep = lambda do
      pool = push.call
      center = send.call(get_class.call("NSUserNotificationCenter"), selector.call("defaultUserNotificationCenter"))
      delivered = send.call(center, selector.call("deliveredNotifications"))
      count.call(delivered, selector.call("count")).times.map { |index| at.call(delivered, selector.call("objectAtIndex:"), index) }
        .select do |each|
          title = send.call(each, selector.call("title"))
          !title.null? && send.call(title, selector.call("UTF8String")).to_s == #{TITLE.dump}
        end
        .each { |each| remove.call(center, selector.call("removeDeliveredNotification:"), each) }
    ensure
      pop.call(pool)
    end
    $ticks = 0
    Thread.new do
      loop do
        sleep 0.05
        $ticks += 1
        sweep.call if ($ticks % 10).zero?
      end
    end
  RUBY

  def setup
    skip_unless_platform(:macos)
  end

  def test_the_first_set_application_wins
    outcome, = in_child(<<~RUBY)
      first = Ferro::NotifyRust.set_application("com.apple.finder")
      second = begin
        Ferro::NotifyRust.set_application("com.apple.finder")
      rescue Ferro::NotifyRust::Error::MacNotificationSys::Application::AlreadySet => e
        [e.class.name, e.message, e.name, e.debug]
      end
      [first, second]
    RUBY

    assert_nil outcome.first
    # set_application returns mac-notification-sys's own error, and the
    # exception keeps its Debug text.
    assert_equal [
      "Ferro::NotifyRust::Error::MacNotificationSys::Application::AlreadySet",
      "Application 'com.apple.finder' can only be set once.",
      "com.apple.finder",
      'Application(AlreadySet("com.apple.finder"))',
], outcome.last
  end

  def test_an_unknown_bundle_cannot_be_set
    outcome, = in_child(<<~RUBY)
      begin
        Ferro::NotifyRust.set_application("no.such.bundle.ferro")
      rescue Ferro::NotifyRust::Error::MacNotificationSys::Application => e
        [e.class.name, e.message, e.name]
      end
    RUBY

    assert_equal [
      "Ferro::NotifyRust::Error::MacNotificationSys::Application::CouldNotSet",
      %(Could not set application 'no.such.bundle.ferro', using default "com.apple.Terminal"),
      "no.such.bundle.ferro",
],
      outcome
  end

  def test_get_bundle_identifier_or_default_asks_applescript
    assert_equal "com.apple.finder", NotifyRust.get_bundle_identifier_or_default("Finder")
    assert_equal "com.apple.Finder", NotifyRust.get_bundle_identifier_or_default("No Such App Ferro")
  end

  def test_scheduling_in_the_past_raises_mac_notification_sys_error
    notification = NotifyRust::Notification.new.summary("too late")
    error = assert_raises(NotifyRust::Error::MacNotificationSys::Notification::ScheduleInThePast) do
      notification.schedule_raw(0.0)
    end

    assert_equal "Can not schedule notification in the past", error.message
    assert_raises(NotifyRust::Error::MacNotificationSys::Notification) { notification.schedule(Time.now - 60) }
    assert_raises(TypeError) { notification.schedule(0) }
  end

  def test_macos_has_no_hints_or_urgency_and_urgency_is_deprecated
    notification = NotifyRust::Notification.new

    refute_respond_to notification, :hint
    refute_respond_to notification, :urgency
    refute_respond_to notification, :app_id
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    _, warnings = capture_io { NotifyRust::Urgency }

    assert_includes warnings, "constant Ferro::NotifyRust::Urgency is deprecated"
  ensure
    Warning[:deprecated] = deprecated
  end

  # show without a block drops the handle, which sends at once, as Rust
  # drops a handle it never binds; the handle is then used up, and every
  # call on it raises IOError, as a closed IO does, before it waits. A wait
  # without a block raises ArgumentError before it takes the handle.
  def test_show_without_a_block_sends_and_leaves_a_spent_handle
    outcome, = in_child(<<~RUBY)
      handle = Ferro::NotifyRust::Notification.new.summary(#{TITLE.dump}).show
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raised = [
        -> { handle.wait_for_action { |action| action } },
        -> { handle.wait_for_response { |response| response } },
        -> { handle.on_close { |reason| reason } },
        -> { handle.debug },
        -> { handle.wait_for_action },
      ].map do |call|
        call.call
        nil
      rescue IOError, ArgumentError => e
        [e.class.name, e.message]
      end
      [handle.class.name, raised, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
    RUBY

    assert_equal "Ferro::NotifyRust::NotificationHandle", outcome[0]
    spent = ["IOError", "Ferro::NotifyRust::NotificationHandle consumed by Builder#show"]

    assert_equal [spent, spent, spent, spent], outcome[1].first(4)
    assert_equal "ArgumentError", outcome[1].last.first
    assert_operator outcome[2], :<, 0.5
  end

  # A wait on the main thread runs the main run loop itself, with Ruby's
  # lock released, so another Ruby thread counts on meanwhile. The wait
  # takes the handle, as notify-rust's takes self, so a second raises
  # IOError, and the end of the block does not send again.
  def test_waits_on_the_main_thread_release_the_gvl_and_spend_the_handle
    outcome, = in_child(<<~RUBY)
      #{SWEEPER}
      Ferro::NotifyRust::Notification.new.summary(#{TITLE.dump}).action("ok", "OK").show do |handle|
        debug = handle.debug
        before = $ticks
        actions = []
        handle.wait_for_action { |action| actions << action }
        ticked = $ticks - before
        second = begin
          handle.wait_for_action { |action| actions << action }
        rescue IOError => e
          e.message
        end
        [actions, ticked, second, debug]
      end
    RUBY

    assert_equal ["__closed"], outcome[0]
    assert_operator outcome[1], :>=, 10, "the other thread ran while the wait blocked"
    assert_equal "Ferro::NotifyRust::NotificationHandle consumed by NotificationHandle#wait_for_action", outcome[2]
    assert_match(/\ANotificationHandle \{ notification: Some\(Notification \{ appname: /, outcome[3])
  end

  def test_wait_for_response_and_on_close_report_an_unanswered_notification
    outcome, = in_child(<<~RUBY)
      #{SWEEPER}
      notification = Ferro::NotifyRust::Notification.new.summary(#{TITLE.dump})
      responses = []
      notification.show { |handle| handle.wait_for_response { |response| responses << response } }
      notification.show { |handle| handle.on_close { |reason| responses << reason } }
      responses.map(&:debug)
    RUBY

    assert_equal 2, outcome.size
    assert_match(/\AClosed\((Expired|Dismissed)\)\z/, outcome.first)
    assert_match(/\A(Expired|Dismissed)\z/, outcome.last)
  end
end
