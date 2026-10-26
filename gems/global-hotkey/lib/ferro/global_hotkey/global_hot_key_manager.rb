# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

module Ferro
  module GlobalHotkey
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
    # SPDX-SnippetComment: GlobalHotKeyManager, its platform notes, and the
    #   crate example from global-hotkey 0.9.0 src/lib.rs:15-33, 135-163
    #++

    # Registers global hotkeys with the operating system.
    #
    # A hotkey only fires once the system knows it: a Carbon hot key on
    # macOS, a +RegisterHotKey+ on a hidden window on Windows, an X11 key
    # grab on Linux. Each needs its own setup and cleanup, and each
    # reports a taken combination its own way.
    #
    # A manager does that setup once. Register a Hotkey::HotKey and the
    # system sends a GlobalHotKeyEvent for each press and release until
    # you unregister it; read them from GlobalHotKeyEvent.receiver.
    #
    # Events need an event loop. On Windows a win32 event loop must be
    # running on the thread; it doesn't need to be the main thread, but
    # you have to create the manager on the same thread as the event loop.
    # On macOS an event loop must be running on the main thread, so you
    # also need to create the manager on the main thread. A windowed app's
    # loop, such as Tokra's tao loop, does this. Without one, registering
    # works and no event ever arrives. On Linux the manager starts an X11
    # thread of its own, so events arrive with no loop; without an X
    # server (Wayland with no XWayland) that thread stops at once, and
    # every call returns as if it had worked, as global-hotkey's do.
    #
    # In Rust a manager unregisters everything when it goes out of scope.
    # Ruby frees it when the garbage collector next runs, which may be much
    # later, so call #unregister_all when you are done with your hotkeys.
    # On macOS and Windows that cleanup runs only on the thread that made
    # the manager, since Carbon and the hidden window belong to it. When the
    # collector frees the manager on another thread, the cleanup waits, and
    # the hotkeys keep firing, until that thread next makes or uses a
    # manager.
    #
    # Mirrors global-hotkey's +GlobalHotKeyManager+ (<tt>src/lib.rs:135-163</tt>).
    #
    # === Examples
    #
    #   hotkey = Ferro::GlobalHotkey::Hotkey
    #   manager = Ferro::GlobalHotkey::GlobalHotKeyManager.new
    #   shift_d = hotkey::HotKey.new(hotkey::Modifiers::SHIFT, hotkey::Code::KeyD)
    #   manager.register(shift_d)
    #
    #   keys = [hotkey::HotKey.from_str("ctrl+alt+F19"), hotkey::HotKey.from_str("ctrl+alt+F20")]
    #   manager.register_all(keys)
    #   # ...
    #   manager.unregister_all(keys)
    class GlobalHotKeyManager
      # Creates the manager: on macOS it installs the Carbon handler, on
      # Windows it makes the hidden window that receives hotkeys, on Linux
      # it starts the X11 thread. Raises Error::OsError when the system
      # refuses. On macOS that includes a second manager while the first
      # lives: Carbon will not install global-hotkey's handler twice, so
      # keep one manager for the process. Mirrors
      # <tt>GlobalHotKeyManager::new</tt>.
      #
      # === Example
      #
      #   manager = Ferro::GlobalHotkey::GlobalHotKeyManager.new
      def initialize
        @manager = GlobalHotkey.__send__(:settle, Native.manager_new)
      end

      # Registers +hotkey+. Raises Error::AlreadyRegistered when another
      # registration holds it (another program's on Windows and Linux,
      # this manager's own on Linux), and Error::FailedToRegister or
      # Error::OsError when the system refuses, such as for a key this
      # platform has no code for. Mirrors <tt>GlobalHotKeyManager::register</tt>.
      #
      # Registering holds Ruby's global VM lock and cannot be interrupted.
      # On Linux it waits for global-hotkey's X11 thread, which looks for
      # work every 50 ms and then asks the X server, so it usually takes up
      # to about 50 ms; if the X connection hangs, it blocks with no limit,
      # as global-hotkey's does (<tt>x11/mod.rs:42-53</tt>).
      #
      # [hotkey] Hotkey::HotKey.
      #
      # === Example
      #
      #   manager.register(Ferro::GlobalHotkey::Hotkey::HotKey.from_str("ctrl+alt+F19"))
      def register(hotkey)
        GlobalHotkey.__send__(:settle, Native.manager_register(@manager, GlobalHotkey.__send__(:parts, hotkey)))
      end

      # Unregisters +hotkey+. A hotkey this manager never registered is no
      # error on macOS and Linux; on Windows it raises
      # Error::FailedToUnRegister. Mirrors <tt>GlobalHotKeyManager::unregister</tt>.
      #
      # [hotkey] Hotkey::HotKey.
      #
      # === Example
      #
      #   manager.unregister(hotkey)
      def unregister(hotkey)
        GlobalHotkey.__send__(:settle, Native.manager_unregister(@manager, GlobalHotkey.__send__(:parts, hotkey)))
      end

      # Registers each hotkey in +hotkeys+, in order, and raises the first
      # error. On macOS and Windows it stops at that hotkey, and the ones
      # before it stay registered; on Linux it registers every one it can
      # and still raises the first error, as global-hotkey's X11 thread
      # does (<tt>x11/mod.rs:301-308</tt>). Mirrors
      # <tt>GlobalHotKeyManager::register_all</tt>.
      #
      # [hotkeys] Array of Hotkey::HotKey.
      #
      # === Example
      #
      #   manager.register_all([quit, show])
      def register_all(hotkeys)
        GlobalHotkey.__send__(:settle, Native.manager_register_all(@manager, list(hotkeys)))
      end

      # Unregisters each hotkey in +hotkeys+, in order, as #unregister
      # does, and raises the first error: stopping there on macOS and
      # Windows, going on through the rest on Linux. Mirrors
      # <tt>GlobalHotKeyManager::unregister_all</tt>.
      #
      # [hotkeys] Array of Hotkey::HotKey.
      #
      # === Example
      #
      #   manager.unregister_all([quit, show])
      def unregister_all(hotkeys)
        GlobalHotkey.__send__(:settle, Native.manager_unregister_all(@manager, list(hotkeys)))
      end

      private def list(hotkeys)
        array = Array.try_convert(hotkeys)
        raise TypeError, "no implicit conversion of #{hotkeys.class} into Array" unless array

        array.map { |hotkey| GlobalHotkey.__send__(:parts, hotkey) }
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
