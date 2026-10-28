# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# An AppKitWindowHandle names its window by number, and the gem looks the
# window up on the main thread when the dialog runs (plan 008, decisions
# 1-5). Each test runs in a child Ruby that makes, through Fiddle, an
# NSApplication with the Prohibited activation policy and an NSWindow it
# never orders front, so nothing appears on screen. Only refusals reach a
# terminal call, and each refuses before rfd opens anything.
class TestAppkitParent < Minitest::Test
  include RfdSuite

  # Defines AppKit in the child: just enough Objective-C, through Fiddle,
  # to make an app and a window and to read them back.
  APPKIT = <<~RUBY
    require "fiddle"
    module AppKit
      OBJC = Fiddle.dlopen("/usr/lib/libobjc.A.dylib")
      KIT = Fiddle.dlopen("/System/Library/Frameworks/AppKit.framework/AppKit")
      SEL = Fiddle::Function.new(OBJC["sel_registerName"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      CLASS = Fiddle::Function.new(OBJC["objc_getClass"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      SEND = Fiddle::Function.new(OBJC["objc_msgSend"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      SEND_LONG = Fiddle::Function.new(OBJC["objc_msgSend"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
      SEND_WITH = Fiddle::Function.new(OBJC["objc_msgSend"],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      PROHIBITED = 2

      def self.send(object, selector, argument = nil)
        argument.nil? ? SEND.call(object, SEL.call(selector)) : SEND_WITH.call(object, SEL.call(selector), argument)
      end

      # The app, made with no Dock icon or menu bar.
      def self.app
        app = send(CLASS.call("NSApplication"), "sharedApplication")
        send(app, "setActivationPolicy:", PROHIBITED)
        app
      end

      # A window that is never ordered front, and so never shown.
      def self.window
        send(send(CLASS.call("NSWindow"), "alloc"), "init")
      end

      def self.number(window)
        SEND_LONG.call(window, SEL.call("windowNumber"))
      end

      def self.content_view(window)
        send(window, "contentView").to_i
      end

      def self.app_exists?
        !Fiddle::Pointer.new(KIT["NSApp"]).ptr.null?
      end

      LIBC = Fiddle.dlopen(nil)
      MUTEX_INIT = Fiddle::Function.new(LIBC["pthread_mutex_init"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
      MUTEX_LOCK = Fiddle::Function.new(LIBC["pthread_mutex_lock"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
      MUTEX_UNLOCK = Fiddle::Function.new(LIBC["pthread_mutex_unlock"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
      DISPATCH_ASYNC = Fiddle::Function.new(LIBC["dispatch_async_f"],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)

      # A pthread mutex, for holding the main queue: 64 bytes is
      # pthread_mutex_t on macOS.
      def self.mutex
        mutex = Fiddle::Pointer.malloc(64)
        MUTEX_INIT.call(mutex, nil)
        mutex
      end

      # Keeps the main queue busy until +mutex+, which this thread holds,
      # is unlocked: dispatch_async_f(dispatch_get_main_queue(), mutex,
      # pthread_mutex_lock).
      def self.block_main_queue_on(mutex)
        DISPATCH_ASYNC.call(LIBC["_dispatch_main_q"], mutex, LIBC["pthread_mutex_lock"])
      end

      def self.running?
        (SEND_LONG.call(app, SEL.call("isRunning")) & 0xFF) == 1
      end
    end

    Parent = Data.define(:window_handle, :display_handle)

    def appkit_parent(number)
      Parent.new(Ferro::Rfd::AppKitWindowHandle.new(window_number: number), Ferro::Rfd::AppKitDisplayHandle.new)
    end

    def refusal
      yield
      nil
    rescue Ferro::Rfd::Error => error
      error.message
    end
  RUBY

  def setup
    skip_unless_platform(:macos)
  end

  def test_the_dialog_gets_the_windows_content_view_on_the_main_thread
    (debug, view, async_debug), = in_child(<<~RUBY)
      #{APPKIT}
      AppKit.app
      window = AppKit.window
      parent = appkit_parent(AppKit.number(window))
      [Ferro::Rfd::FileDialog.new.set_parent(parent).inspect, AppKit.content_view(window),
        Ferro::Rfd::AsyncMessageDialog.new.set_parent(parent).inspect]
    RUBY

    handle = "parent: Some(AppKit(AppKitWindowHandle { ns_view: 0x#{view.to_s(16)} })), " \
      "parent_display: Some(AppKit(AppKitDisplayHandle))"

    assert_includes debug, handle
    assert_includes async_debug, "parent: Some(AppKit(AppKitWindowHandle { ns_view: 0x#{view.to_s(16)} }))"
  end

  # Another thread reaches the window through the running app's main
  # thread, as rfd reaches it for a sync dialog. Fiddle releases the GVL
  # while -[NSApplication run] runs, so the thread runs meanwhile; it
  # writes its answer and ends the child itself, since run never returns.
  def test_another_thread_looks_the_window_up_through_the_running_app
    (running, debug, view), = in_child(<<~RUBY)
      #{APPKIT}
      app = AppKit.app
      window = AppKit.window
      Thread.new do
        sleep 0.1 until AppKit.running?
        debug = Ferro::Rfd::FileDialog.new.set_parent(appkit_parent(AppKit.number(window))).inspect
        $stdout.binmode.write(Marshal.dump([AppKit.running?, debug, AppKit.content_view(window)]))
        $stdout.flush
        exit!(0)
      end
      AppKit.send(app, "run")
    RUBY

    assert running
    assert_includes debug, "AppKitWindowHandle { ns_view: 0x#{view.to_s(16)} }"
  end

  # While inspect waits for the main queue, it holds no GVL, so another
  # Ruby thread runs (plan 008, decision 3). The proof is by order, not
  # by rate: the main queue stays blocked until a second Ruby thread
  # unlocks a mutex, and that thread waits to do so until inspect has
  # started. inspect can finish only if that thread ran meanwhile; a wait
  # that held the GVL would never end, and the child would be killed.
  def test_waiting_for_the_main_thread_releases_the_gvl
    (order, debug, view), = in_child(<<~RUBY)
      #{APPKIT}
      app = AppKit.app
      window = AppKit.window
      Thread.new do
        sleep 0.1 until AppKit.running?
        order = Queue.new
        mutex = AppKit.mutex
        locked = Queue.new
        inspecting = Queue.new
        releaser = Thread.new do
          AppKit::MUTEX_LOCK.call(mutex)
          locked << true
          inspecting.pop
          sleep 0.1
          order << :released
          AppKit::MUTEX_UNLOCK.call(mutex)
        end
        locked.pop
        AppKit.block_main_queue_on(mutex)
        inspecting << true
        debug = Ferro::Rfd::FileDialog.new.set_parent(appkit_parent(AppKit.number(window))).inspect
        order << :inspected
        releaser.join
        result = [[order.pop, order.pop], debug, AppKit.content_view(window)]
        $stdout.binmode.write(Marshal.dump(result))
        $stdout.flush
        exit!(0)
      end
      AppKit.send(app, "run")
    RUBY

    assert_equal %i[released inspected], order
    assert_includes debug, "AppKitWindowHandle { ns_view: 0x#{view.to_s(16)} }"
  end

  def test_a_number_that_names_no_window_is_refused_before_any_dialog
    messages, = in_child(<<~RUBY)
      #{APPKIT}
      AppKit.app
      number = AppKit.number(AppKit.window) + 1000
      parent = appkit_parent(number)
      [
        refusal { Ferro::Rfd::FileDialog.new.set_parent(parent).inspect },
        refusal { Ferro::Rfd::FileDialog.new.set_parent(parent).pick_file },
        refusal { Ferro::Rfd::AsyncFileDialog.new.set_parent(parent).pick_file },
        refusal { Ferro::Rfd::MessageDialog.new.set_parent(parent).show },
        refusal { Ferro::Rfd::AsyncMessageDialog.new.set_parent(parent).show },
        refusal { Ferro::Rfd::MessageDialog.new.set_parent(appkit_parent(0)).show },
        number,
      ]
    RUBY
    number = messages.pop

    assert_equal (["no window of this app has window number #{number}"] * 5) +
      ["no window of this app has window number 0"], messages
  end

  def test_a_window_without_a_content_view_is_refused
    (message, number), = in_child(<<~RUBY)
      #{APPKIT}
      AppKit.app
      window = AppKit.window
      AppKit.send(window, "setContentView:", Fiddle::NULL)
      [refusal { Ferro::Rfd::FileDialog.new.set_parent(appkit_parent(AppKit.number(window))).pick_file },
        AppKit.number(window)]
    RUBY

    assert_equal "window number #{number} has no content view", message
  end

  # Without an NSApplication there is no window to find, and the lookup
  # does not make one, as +[NSApplication sharedApplication] would.
  def test_without_an_app_no_number_names_a_window
    (message, app_exists), = in_child(<<~RUBY)
      #{APPKIT}
      [refusal { Ferro::Rfd::FileDialog.new.set_parent(appkit_parent(1)).inspect }, AppKit.app_exists?]
    RUBY

    assert_equal "no window of this app has window number 1", message
    refute app_exists
  end

  def test_another_thread_without_a_running_app_is_refused
    (inspect_message, pick_message), = in_child(<<~RUBY)
      #{APPKIT}
      AppKit.app
      parent = appkit_parent(AppKit.number(AppKit.window))
      Thread.new do
        [refusal { Ferro::Rfd::FileDialog.new.set_parent(parent).inspect },
          refusal { Ferro::Rfd::FileDialog.new.set_parent(parent).pick_file }]
      end.value
    RUBY

    assert_equal "an AppKitWindowHandle is looked up on the main thread, " \
      "and no NSApplication runs to reach it from this one", inspect_message
    assert_match(/\AYou are running RFD in NonWindowed environment/, pick_message)
  end
end
