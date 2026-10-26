# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

module Ferro
  module Rfd
    # A Win32 window, by its +HWND+, for a dialog's +set_parent+.
    #
    # A dialog that knows its parent window stays in front of it, and the
    # system can center it there and keep the user from losing it behind
    # another window. Windows names each window by an +HWND+, and your
    # window library can tell you your window's.
    #
    # This value carries that +HWND+ (and, optionally, the module that made
    # the window) as plain Integers, so it crosses from any gem. Return one
    # from your parent object's +window_handle+; FileDialog#set_parent
    # explains the protocol.
    #
    # An +HWND+ is a handle Windows checks, not a pointer, so a wrong or
    # stale one cannot corrupt memory: the dialog fails, and rfd returns
    # +nil+ or MessageDialogResult::Cancel. A window owned by another
    # thread keeps its dialog waiting on that thread's message loop.
    #
    # Mirrors raw-window-handle's +Win32WindowHandle+
    # (raw-window-handle 0.6.2, <tt>src/windows.rs:52-57</tt>), which rfd
    # takes.
    #
    # === Example
    #
    #   handle = Ferro::Rfd::Win32WindowHandle.new(hwnd: 0x0004_0A2C, hinstance: nil)
    class Win32WindowHandle < Data.define(:hwnd, :hinstance)
      ##
      # :attr_reader: hwnd
      # The window's +HWND+, a non-zero Integer. Zero raises +RangeError+
      # from +set_parent+.

      ##
      # :attr_reader: hinstance
      # The +HINSTANCE+ of the module that created the window, a non-zero
      # Integer, or +nil+.
    end

    # An X11 window, through Xlib, for a dialog's +set_parent+.
    #
    # On Linux under X11, every window has a numeric ID, and your window
    # library can tell you your window's. rfd's portal backend passes it to
    # the desktop as text, <tt>x11:</tt> and the ID in hex, so the portal
    # can place the dialog over your window.
    #
    # This value carries the ID as a plain Integer. rfd never reads the
    # window through it, so a wrong ID cannot corrupt memory; the desktop
    # just ignores it. Return one from your parent object's
    # +window_handle+; FileDialog#set_parent explains the protocol.
    #
    # Mirrors raw-window-handle's +XlibWindowHandle+
    # (raw-window-handle 0.6.2, <tt>src/unix.rs:48-53</tt>).
    #
    # === Example
    #
    #   Ferro::Rfd::XlibWindowHandle.new(window: 0x3a0_0007, visual_id: 0)
    class XlibWindowHandle < Data.define(:window, :visual_id)
      ##
      # :attr_reader: window
      # The window's X11 ID, an Integer.

      ##
      # :attr_reader: visual_id
      # The window's X11 visual ID, an Integer; 0 when unknown.
    end

    # An X11 window, through XCB, for a dialog's +set_parent+.
    #
    # The same window ID as XlibWindowHandle carries, as XCB names it: a
    # non-zero 32-bit Integer. rfd's portal backend treats both alike.
    #
    # Mirrors raw-window-handle's +XcbWindowHandle+
    # (raw-window-handle 0.6.2, <tt>src/unix.rs:122-127</tt>).
    #
    # === Example
    #
    #   Ferro::Rfd::XcbWindowHandle.new(window: 0x3a0_0007, visual_id: nil)
    class XcbWindowHandle < Data.define(:window, :visual_id)
      ##
      # :attr_reader: window
      # The window's X11 ID, a non-zero Integer. Zero raises +RangeError+
      # from +set_parent+.

      ##
      # :attr_reader: visual_id
      # The window's visual ID, a non-zero Integer, or +nil+.
    end

    # The Windows display, for a parent's +display_handle+.
    #
    # raw-window-handle pairs every window with the display it lives on.
    # Windows has one, and this value names it; it carries nothing.
    #
    # Mirrors raw-window-handle's +WindowsDisplayHandle+
    # (raw-window-handle 0.6.2, <tt>src/windows.rs:12</tt>).
    #
    # === Example
    #
    #   Ferro::Rfd::WindowsDisplayHandle.new
    class WindowsDisplayHandle < Data.define
    end

    # An X11 display, through Xlib, for a parent's +display_handle+.
    #
    # Pairs with XlibWindowHandle. rfd reads no X11 display, so +display+
    # may be +nil+; an Integer address is kept but never followed.
    #
    # Mirrors raw-window-handle's +XlibDisplayHandle+
    # (raw-window-handle 0.6.2, <tt>src/unix.rs:8-21</tt>).
    #
    # === Example
    #
    #   Ferro::Rfd::XlibDisplayHandle.new(display: nil, screen: 0)
    class XlibDisplayHandle < Data.define(:display, :screen)
      ##
      # :attr_reader: display
      # The address of Xlib's +Display+, a non-zero Integer, or +nil+.

      ##
      # :attr_reader: screen
      # The X11 screen number, an Integer.
    end

    # An X11 display, through XCB, for a parent's +display_handle+.
    #
    # Pairs with XcbWindowHandle. rfd reads no X11 display, so
    # +connection+ may be +nil+; an Integer address is kept but never
    # followed.
    #
    # Mirrors raw-window-handle's +XcbDisplayHandle+
    # (raw-window-handle 0.6.2, <tt>src/unix.rs:82-95</tt>).
    #
    # === Example
    #
    #   Ferro::Rfd::XcbDisplayHandle.new(connection: nil, screen: 0)
    class XcbDisplayHandle < Data.define(:connection, :screen)
      ##
      # :attr_reader: connection
      # The address of the +xcb_connection_t+, a non-zero Integer, or +nil+.

      ##
      # :attr_reader: screen
      # The X11 screen number, an Integer.
    end

    # The <tt>[window, display]</tt> pair the native layer takes for a
    # parent: each a tagged Array, or +nil+ where the parent answered
    # +nil+. A parent that lacks +window_handle+ or +display_handle+ raises
    # +NoMethodError+, and one that returns anything but a handle or +nil+
    # raises +TypeError+, as Rust's trait bound would refuse it at compile
    # time.
    def self.parent_pair(parent) # :nodoc:
      # @type var window: native_window?
      window = case (handle = parent.window_handle)
      when nil then nil
      when Win32WindowHandle then [:Win32, handle.hwnd, handle.hinstance]
      when XlibWindowHandle then [:Xlib, handle.window, handle.visual_id]
      when XcbWindowHandle then [:Xcb, handle.window, handle.visual_id]
      else raise TypeError, "wrong argument type #{handle.class} (expected a window handle)"
      end
      # @type var display: native_display?
      display = case (handle = parent.display_handle)
      when nil then nil
      when WindowsDisplayHandle then [:Windows]
      when XlibDisplayHandle then [:Xlib, handle.display, handle.screen]
      when XcbDisplayHandle then [:Xcb, handle.connection, handle.screen]
      else raise TypeError, "wrong argument type #{handle.class} (expected a display handle)"
      end
      # @type var pair: native_parent
      pair = [window, display]
      Native.check_parent(pair)
      pair.freeze
    end
    private_class_method :parent_pair
  end
end
