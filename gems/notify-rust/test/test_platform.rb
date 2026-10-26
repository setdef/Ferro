# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# notify-rust compiles some items for one platform only, and the gem
# defines each exactly where the extension's cfg says, so respond_to? and
# defined? answer.
class TestPlatform < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def test_linux_items_exist_only_on_linux
    linux = PLATFORM == :linux
    notification = NotifyRust::Notification.new

    %i[hint hints image_data image show_async show_async_at_bus].each do |name|
      assert_equal linux, notification.respond_to?(name), name
    end
    %i[get_capabilities get_server_information handle_action dbus_stack].each do |name|
      assert_equal linux, NotifyRust.respond_to?(name), name
    end
    %i[Image DbusStack Future].each { |name| assert_equal linux, NotifyRust.const_defined?(name, false), name }
    assert_equal linux, NotifyRust::Hint.const_defined?(:ImageData, false)
    assert_equal linux, NotifyRust::Notification.respond_to?(:at_bus)
    %i[close close_async update wait_for_action_async].each do |name|
      assert_equal linux, NotifyRust::NotificationHandle.method_defined?(name), name
    end
  end

  # notify-rust's Linux handle has an id of its own, the server's
  # (src/xdg/mod.rs:319-327), which shadows Notification's id(u32) setter
  # its Deref reaches. Windows' handle has none (src/windows.rs:109-144),
  # so there id is that setter, through Deref; macOS's handle has neither.
  def test_a_handles_id_is_the_servers_on_linux_and_the_setter_on_windows
    owner = NotifyRust::NotificationHandle.method_defined?(:id) && NotifyRust::NotificationHandle.instance_method(:id)

    case PLATFORM
    when :linux then assert_equal [NotifyRust::NotificationHandle, 0], [owner.owner, owner.arity]
    when :windows then assert_equal [NotifyRust::Builder, 1], [owner.owner, owner.arity]
    else refute owner
    end
  end

  def test_macos_items_exist_only_on_macos
    macos = PLATFORM == :macos

    %i[schedule schedule_raw].each do |name|
      assert_equal macos, NotifyRust::Notification.method_defined?(name), name
    end
    %i[set_application get_bundle_identifier_or_default].each do |name|
      assert_equal macos, NotifyRust.respond_to?(name), name
    end
  end

  def test_windows_items_exist_only_on_windows
    assert_equal PLATFORM == :windows, NotifyRust::Notification.method_defined?(:app_id)
  end

  def test_urgency_exists_where_notify_rust_has_it
    assert_equal PLATFORM != :macos, NotifyRust::Notification.method_defined?(:urgency)
    assert_equal PLATFORM != :macos, NotifyRust::NotificationHandle.method_defined?(:summary),
      "a handle answers the setters where notify-rust's derefs to the notification"
  end

  def test_every_platform_has_the_common_api
    %i[
      appname
      summary
      subtitle
      body
      icon
      auto_icon
      image_path
      sound_name
      timeout
      actions
      action
      id
      finalize
      show
].each { |name| assert NotifyRust::Notification.method_defined?(name), name }
    %i[wait_for_action wait_for_response on_close].each do |name|
      assert NotifyRust::NotificationHandle.method_defined?(name), name
    end
    assert_includes %i[linux macos windows], PLATFORM
  end
end
