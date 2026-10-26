# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "json"

# notify-rust against a real notification server: dunst, on the suite's own
# session bus (NotifySuite::Server). dunstctl stands in for the user: it
# invokes a notification's default action or dismisses it. An action with
# another key, which dunst can offer only through a menu, comes as the
# signal a server sends, through dbus-send. Ports notify-rust 4.18.2's
# tests/realworld.rs (burst, closing, capabilities, init, urgency,
# category, persistent, imagedata).
class TestLinux < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def setup
    skip_unless_platform(:linux)
    require_server
    Server.run("dunstctl", "close-all")
  end

  private def notification(summary = name)
    NotifyRust::Notification.new.summary(summary)
  end

  private def displayed
    Integer(Server.run("dunstctl", "count", "displayed").strip)
  end

  # Runs +action+ on another thread once a wait started after this call is
  # listening: notify-rust adds its match rules for NotificationClosed when
  # the wait first polls (zbus_rs.rs:127-147), and a signal sent before
  # then is lost. Call it just before the wait.
  private def once_listening(&action)
    before = Server.match_rules("NotificationClosed")
    Thread.new do
      Thread.current.report_on_exception = false
      200.times { Server.listening_since?("NotificationClosed", before) ? break : sleep(0.05) }
      raise "no wait started listening" unless Server.listening_since?("NotificationClosed", before)

      action.call
    end
  end

  # Sends NotificationClosed for +handle+ with the specification's
  # +reason+ code, as the server does when a notification expires.
  private def closed(handle, reason)
    Server.signal("NotificationClosed", "uint32:#{handle.id}", "uint32:#{reason}")
  end

  def test_the_server_is_dunst_and_says_what_it_can_do
    info = NotifyRust.get_server_information

    assert_equal "dunst", info.name
    assert_equal "knopwob", info.vendor
    assert_equal "1.2", info.spec_version
    assert_includes NotifyRust.get_capabilities, "actions"
    assert_same NotifyRust::DbusStack::Zbus, NotifyRust.dbus_stack
  end

  def test_show_sends_the_notification_and_answers_its_id
    handle = notification("burst").appname("These should each").body("come in their own pop up.")
      .icon("media-floppy").show

    assert_kind_of NotifyRust::NotificationHandle, handle
    assert_operator handle.id, :>, 0
    assert_equal 1, displayed
    assert_equal "burst", handle.summary
  end

  def test_show_with_a_block_yields_the_handle_and_returns_the_blocks_value
    id = notification.show(&:id)

    assert_operator id, :>, 0
  end

  def test_every_kind_of_hint_reaches_the_server
    hint = NotifyRust::Hint
    [
      hint::Urgency.new(urgency::Low),
      hint::Urgency.new(urgency::Critical),
      hint::Category.new("email"),
      hint::Resident.new(true),
      hint::Transient.new(true),
      hint::X.new(10),
      hint::Y.new(10),
      hint::CustomInt.new("value", 40),
      hint::Custom.new("x-dunst-stack-tag", "volume"),
      hint::ImageData.new(NotifyRust::Image.from_rgb(64, 64, "\x80".b * (64 * 64 * 3))),
].each do |each|
      notification("hint #{each.inspect}").hint(each).show
    end

    assert_operator displayed, :>=, 1
  end

  def test_wait_for_action_passes_the_default_action
    handle = notification("click me").action("default", "default").timeout(NotifyRust::Timeout::Never).show
    clicker = once_listening { Server.run("dunstctl", "action", "0") }
    actions = []
    handle.wait_for_action { |action| actions << action }
    clicker.join

    assert_equal ["default"], actions
  end

  def test_wait_for_action_passes_a_named_action_and_closed
    handle = notification("click me").action("clicked_a", "button a").show
    sender = once_listening { Server.signal("ActionInvoked", "uint32:#{handle.id}", "string:clicked_a") }
    actions = []
    handle.wait_for_action { |action| actions << action }
    sender.join
    closer = once_listening { Server.run("dunstctl", "close") }
    handle.wait_for_action { |action| actions << action }
    closer.join

    assert_equal %w[clicked_a __closed], actions
  end

  def test_wait_for_response_tells_a_click_from_an_action
    handle = notification("click me").action("default", "default").show
    clicker = once_listening { Server.run("dunstctl", "action", "0") }
    responses = []
    handle.wait_for_response { |response| responses << response }
    clicker.join

    assert_equal [NotifyRust::NotificationResponse::Default], responses
  end

  def test_on_close_passes_each_reason
    reasons = []
    expiring = notification("Time is running out").show
    expiry = once_listening { closed(expiring, 1) }
    expiring.on_close { |reason| reasons << reason }
    expiry.join
    expiring.close
    dismissed = notification("dismiss me").show
    closer = once_listening { Server.run("dunstctl", "close") }
    dismissed.on_close { |reason| reasons << reason }
    closer.join

    assert_equal [NotifyRust::CloseReason::Expired, NotifyRust::CloseReason::Dismissed], reasons
  end

  def test_on_close_takes_a_block_without_arguments
    closed = false
    handle = notification.show
    closer = once_listening { Server.run("dunstctl", "close") }
    handle.on_close { closed = true }
    closer.join

    assert closed
  end

  # A setter needs the handle mutably, which a wait borrows; Rust refuses
  # that at compile time, and the gem raises at once rather than queue
  # behind the wait, so a close from a third thread still ends it.
  def test_a_setter_during_a_wait_raises_and_close_still_ends_the_wait
    handle = notification("borrowed").timeout(NotifyRust::Timeout::Never).show
    refused = nil
    closer = once_listening do
      refused = assert_raises(NotifyRust::Error) { handle.summary("changed") }
      Thread.new { handle.close }.join
    end
    responses = []
    handle.wait_for_response { |response| responses << response }
    closer.join

    assert_match(/\Aalready borrowed: /, refused.message)
    assert_equal [NotifyRust::NotificationResponse::Closed.new(NotifyRust::CloseReason::CloseAction)], responses
    assert_equal "borrowed", handle.summary
    assert_same handle, handle.summary("free again"), "the borrow ends with the wait"
  end

  # notify-rust's close_async example (src/xdg/mod.rs:155-178) closes while
  # it waits; the handle's wait and close borrow it together.
  def test_close_while_waiting_closes_with_close_action
    handle = notification("I'll be here till you close me!").hint(NotifyRust::Hint::Resident.new(true))
      .timeout(NotifyRust::Timeout::Never).show
    closer = once_listening { handle.close }
    responses = []
    handle.wait_for_response { |response| responses << response }
    closer.join

    assert_equal [NotifyRust::NotificationResponse::Closed.new(NotifyRust::CloseReason::CloseAction)], responses
    assert_equal 0, displayed
  end

  def test_update_replaces_the_notification_the_server_shows
    handle = notification("Latest News").body("Bayern Dortmund 3:2").show
    id = handle.id
    handle.summary("Latest News (Correction)").body("Bayern Dortmund 3:3")
    handle.update

    assert_equal id, handle.id
    assert_equal 1, displayed
    assert_equal "Latest News (Correction)", handle.summary
  end

  def test_an_id_set_ahead_replaces_that_notification
    first = notification("Volume 40%").show
    notification("Volume 50%").id(first.id).show

    assert_equal 1, displayed
  end

  def test_a_wait_lets_other_threads_run_and_an_interrupt_ends_it
    handle = notification("never answered").timeout(NotifyRust::Timeout::Never).show
    ticks = 0
    waiter = Thread.new do
      Thread.current.report_on_exception = false
      handle.wait_for_action { flunk "no action was taken" }
    end
    20.times do
      ticks += 1
      sleep 0.01
    end
    waiter.raise(Interrupt)

    assert_raises(Interrupt) { waiter.join(5) || flunk("the interrupt did not end the wait") }
    assert_equal 20, ticks
    closer = once_listening { Server.run("dunstctl", "close") }
    reasons = []
    handle.on_close { |reason| reasons << reason }
    closer.join

    assert_equal [NotifyRust::CloseReason::Dismissed], reasons, "the handle still works after an interrupted wait"
  end

  def test_handle_action_yields_an_action_response
    id = notification("click me").action("clicked_a", "button a").show.id
    sender = once_listening { Server.signal("ActionInvoked", "uint32:#{id}", "string:clicked_a") }
    responses = []
    NotifyRust.handle_action(id) { |response| responses << response }
    sender.join

    assert_equal [NotifyRust::ActionResponse::Custom.new("clicked_a")], responses
  end

  def test_async_methods_run_when_their_value_is_asked
    future = notification("simple async").show_async

    assert_equal 0, displayed, "nothing is sent until value runs"
    handle = future.value
    assert_same handle, future.value
    assert_equal 1, displayed

    responses = []
    waiting = handle.wait_for_action_async { |response| responses << response }
    closing = handle.close_async
    closer = once_listening { closing.value }

    assert_nil waiting.value
    closer.join
    assert_equal [NotifyRust::NotificationResponse::Closed.new(NotifyRust::CloseReason::CloseAction)], responses
  end

  def test_wait_for_action_async_needs_a_block
    handle = notification.show

    assert_raises(ArgumentError) { handle.wait_for_action_async }
  end

  def test_a_bus_nobody_serves_raises_zbus_errors
    future = notification.show_async_at_bus("nobody_listens")
    error = assert_raises(NotifyRust::Error::Zbus) { future.value }

    assert_includes error.message, "org.freedesktop.DBus.Error.ServiceUnknown"
    assert_same error, assert_raises(NotifyRust::Error::Zbus) { future.value }
    assert_raises(NotifyRust::Error::Msg) { notification.show_async_at_bus("9").value }
  end

  def test_at_bus_refuses_an_invalid_sub_bus_with_notify_rusts_message
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    error = assert_raises(NotifyRust::Error::Msg) { NotifyRust::Notification.at_bus("9") }

    assert_equal "invalid subpath", error.message
    assert_raises(NotifyRust::Error::Zbus) { NotifyRust::Notification.at_bus("nobody_listens").summary("x").show }
  ensure
    Warning[:deprecated] = deprecated
  end

  def test_without_a_session_bus_show_raises_zbus_and_handle_action_a_caught_panic
    outcome, = in_child(<<~RUBY, "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/nonexistent/bus")
      show = begin
        Ferro::NotifyRust::Notification.new.summary("x").show
      rescue Ferro::NotifyRust::Error => e
        e.class.name
      end
      handle = begin
        Ferro::NotifyRust.handle_action(1) { }
      rescue Ferro::NotifyRust::Error => e
        [e.class.name, e.message]
      end
      [show, handle]
    RUBY

    assert_equal "Ferro::NotifyRust::Error::Zbus", outcome.first
    assert_equal "Ferro::NotifyRust::Error", outcome.last.first
    assert_match(/\Anotify-rust panicked: /, outcome.last.last)
  end
end
