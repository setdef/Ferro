# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# global-hotkey's public API is the same on every platform: its backends
# sit behind one platform_impl (src/platform_impl/mod.rs), so the gem has
# no platform-only item. Only CMD_OR_CTRL's value differs (test_hotkey.rb).
class TestPlatform < Minitest::Test
  include HotkeySuite

  def test_the_extension_reports_one_of_global_hotkeys_platforms
    assert_includes %i[linux macos windows], PLATFORM
  end

  def test_every_platform_has_the_whole_api
    %i[register unregister register_all unregister_all].each do |name|
      assert GlobalHotkey::GlobalHotKeyManager.method_defined?(name), name
    end
    %i[receiver set_event_handler].each { |name| assert GlobalHotkey::GlobalHotKeyEvent.respond_to?(name), name }
    %i[try_recv recv recv_timeout iter try_iter is_empty is_full len capacity same_channel].each do |name|
      assert GlobalHotkey::GlobalHotKeyEventReceiver.method_defined?(name), name
    end
    %i[matches into_string to_s].each { |name| assert Hotkey::HotKey.method_defined?(name), name }
  end

  def test_the_native_layer_is_private
    refute_includes GlobalHotkey.constants, :Native
    assert_raises(NameError) { Ferro::GlobalHotkey::Native }
    assert_raises(NoMethodError) { GlobalHotkey.settle([:ok, 1]) }
  end
end
