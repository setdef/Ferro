# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "test_helper"

# Registering real hotkeys with the real system. Each hotkey is one nobody
# uses, and each test unregisters what it registered. On Linux the
# manager grabs keys on the suite's private X server.
class TestManager < Minitest::Test
  include HotkeySuite

  Error = GlobalHotkey::Error
  Code = Hotkey::Code

  # One manager for the suite: on macOS a second cannot exist while the
  # first lives, and Ruby frees a test's manager only when the garbage
  # collector runs.
  def self.manager
    @manager ||= GlobalHotkey::GlobalHotKeyManager.new
  end

  def setup
    require_x_server if PLATFORM == :linux
    @manager = self.class.manager
    @registered = []
  end

  def teardown
    @registered.each do |hotkey|
      @manager.unregister(hotkey)
    rescue Error
      nil
    end
  end

  private def register(hotkey)
    @manager.register(hotkey).tap { @registered << hotkey }
  end

  def test_a_hotkey_registers_and_unregisters
    hotkey = unusual

    assert_nil register(hotkey)
    assert_nil @manager.unregister(hotkey)
    assert_nil register(hotkey), "an unregistered hotkey registers again"
  end

  def test_register_all_and_unregister_all
    keys = [unusual(Code::F19), unusual(Code::F18)]

    assert_nil @manager.register_all(keys)
    @registered.concat(keys)
    assert_nil @manager.unregister_all(keys)
    assert_raises(TypeError) { @manager.register_all(unusual) }
    assert_raises(TypeError) { @manager.register("ctrl+F19") }
  end

  # The same hotkey twice: macOS's RegisterEventHotKey refuses it
  # (macos/mod.rs:126-131); Windows and Linux report AlreadyRegistered
  # (windows/mod.rs:101-111, x11/mod.rs:173-185).
  def test_a_second_registration_is_refused
    hotkey = unusual
    register(hotkey)

    if PLATFORM == :macos
      error = assert_raises(Error::FailedToRegister) { @manager.register(hotkey) }
      assert_equal "Unable to register hotkey: RegisterEventHotKey failed for F19", error.message
    else
      error = assert_raises(Error::AlreadyRegistered) { @manager.register(hotkey) }
      assert_equal hotkey, error.hotkey
      assert_match(/\AHotKey already registered: HotKey \{ mods: Modifiers\(/, error.message)
    end
  end

  # A key the platform has no code for. macOS has none for F24
  # (macos/mod.rs:412-528); Windows none for Fn (windows/mod.rs:205-350);
  # global-hotkey's X11 keysym table none for Fn (x11/mod.rs:330-494).
  def test_a_key_the_platform_lacks_fails_to_register
    case PLATFORM
    when :macos
      error = assert_raises(Error::FailedToRegister) { register(unusual(Code::F24)) }
      assert_equal "Unable to register hotkey: Unknown scancode for F24", error.message
    when :windows
      error = assert_raises(Error::FailedToRegister) { register(unusual(Code::Fn)) }
      assert_equal "Unable to register hotkey: Unknown VKCode for Fn", error.message
    else
      error = assert_raises(Error::FailedToRegister) { register(unusual(Code::Fn)) }
      assert_equal "Unable to register hotkey: Unknown scancode for key: Fn", error.message
    end
  end

  # Unregistering a hotkey nobody registered: macOS and Linux find nothing
  # to remove; Windows' UnregisterHotKey fails (windows/mod.rs:125-131).
  def test_unregistering_an_unknown_hotkey
    hotkey = unusual(Code::F17)

    if PLATFORM == :windows
      error = assert_raises(Error::FailedToUnRegister) { @manager.unregister(hotkey) }
      assert_equal hotkey, error.hotkey
    else
      assert_nil @manager.unregister(hotkey)
    end
  end

  # Carbon refuses to install the same handler twice, so while one manager
  # lives, a second fails to install its own (macos/mod.rs:55-69).
  def test_macos_has_one_manager_at_a_time
    skip_unless_platform(:macos)

    error = assert_raises(Error::OsError) { GlobalHotkey::GlobalHotKeyManager.new }
    assert_match(/\(os error \d+\)\z/, error.message)
  end

  # A manager the garbage collector frees runs global-hotkey's Drop, which
  # removes the Carbon handler, so a new manager can install its own. The
  # collector may free it on another thread; then the drop waits for the
  # main thread's next manager call (owned.rs), which the second new is.
  def test_macos_a_freed_manager_makes_room_for_a_new_one
    skip_unless_platform(:macos)

    made, = in_child(<<~RUBY)
      def make
        Ferro::GlobalHotkey::GlobalHotKeyManager.new
        nil
      end

      def make_again
        Ferro::GlobalHotkey::GlobalHotKeyManager.new.class.name
      rescue Ferro::GlobalHotkey::Error::OsError => e
        e.class.name
      end

      make
      3.times { GC.start }
      on_main = make_again
      3.times { GC.start }
      make
      3.times { Thread.new { GC.start }.join }
      [on_main, make_again]
    RUBY
    assert_equal ["Ferro::GlobalHotkey::GlobalHotKeyManager"] * 2, made
  end

  # A freed manager's Drop ends its X11 thread and closes its connection,
  # which releases its grabs, so another manager can grab the same keys.
  def test_linux_a_freed_managers_grab_is_released
    skip_unless_platform(:linux)

    registered, = in_child(<<~RUBY, XServer.env)
      HOTKEY = Ferro::GlobalHotkey::Hotkey::HotKey.from_str("ctrl+alt+shift+super+F19")
      def grab
        Ferro::GlobalHotkey::GlobalHotKeyManager.new.register(HOTKEY)
        nil
      end
      grab
      other = Ferro::GlobalHotkey::GlobalHotKeyManager.new
      # Ruby's collector scans the stack conservatively, so the first
      # manager may outlive one GC; try again until a deadline.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      begin
        GC.start
        sleep 0.2
        other.register(HOTKEY).inspect.tap { other.unregister(HOTKEY) }
      rescue Ferro::GlobalHotkey::Error::AlreadyRegistered => e
        retry if Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        e.class.name
      end
    RUBY
    assert_equal "nil", registered
  end

  # Another X client's grab of the same keys is X's BadAccess, which
  # global-hotkey reports as AlreadyRegistered (x11/mod.rs:153-169).
  def test_linux_another_managers_grab_is_already_registered
    skip_unless_platform(:linux)
    hotkey = unusual
    register(hotkey)
    other = GlobalHotkey::GlobalHotKeyManager.new

    error = assert_raises(Error::AlreadyRegistered) { other.register(hotkey) }
    assert_equal hotkey, error.hotkey
  end

  # Without an X server global-hotkey's thread stops at once, and every
  # call returns as if it had worked (x11/mod.rs:31-53, 227-231).
  def test_linux_without_an_x_server_registering_returns
    skip_unless_platform(:linux)

    value, = in_child(<<~RUBY, "DISPLAY" => ":9999", "WAYLAND_DISPLAY" => nil)
      hotkey = Ferro::GlobalHotkey::Hotkey::HotKey.from_str("ctrl+alt+shift+super+F19")
      Ferro::GlobalHotkey::GlobalHotKeyManager.new.register(hotkey).inspect
    RUBY
    assert_equal "nil", value
  end
end
