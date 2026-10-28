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

    # A macOS window, by its window number, for a dialog's +set_parent+.
    #
    # On macOS a dialog with a parent opens as a sheet on that window, or
    # stays in front of it. rfd takes the window as raw-window-handle's
    # +AppKitWindowHandle+, which holds a pointer to the window's content
    # view. Ruby cannot prove an Integer points at a live view, and rfd
    # retains whatever it points at, so a wrong one would crash your
    # process.
    #
    # So this value names the window by its number instead, the Integer
    # <tt>-[NSWindow windowNumber]</tt> answers, which points at nothing.
    # When the dialog runs, ferro-rfd asks AppKit for the window with
    # <tt>-[NSApplication windowWithWindowNumber:]</tt>, on the main
    # thread, and hands rfd that window's content view: the same handle a
    # Rust caller would pass. A number that names none of your app's
    # windows raises Error instead of reaching rfd. From another thread,
    # the lookup and the dialog run on the main thread through your running
    # app, as rfd runs any dialog from another thread; FileDialog#set_parent
    # says more.
    #
    # Translates raw-window-handle's +AppKitWindowHandle+
    # (raw-window-handle 0.6.2, <tt>src/appkit.rs:46-110</tt>): the kind
    # is the same, and the field is a number AppKit checks in place of the
    # pointer (plan 008, decision 1).
    #
    # === Example
    #
    #   Ferro::Rfd::AppKitWindowHandle.new(window_number: 8213)
    class AppKitWindowHandle < Data.define(:window_number)
      ##
      # :attr_reader: window_number
      # The window's number in the window server, an Integer, as
      # <tt>-[NSWindow windowNumber]</tt> answers it.
    end

    # The macOS display, for a parent's +display_handle+.
    #
    # raw-window-handle pairs every window with the display it lives on.
    # macOS has one, and this value names it; it carries nothing. rfd keeps
    # it but reads only the window.
    #
    # Mirrors raw-window-handle's +AppKitDisplayHandle+
    # (raw-window-handle 0.6.2, <tt>src/appkit.rs:6-24</tt>).
    #
    # === Example
    #
    #   Ferro::Rfd::AppKitDisplayHandle.new
    class AppKitDisplayHandle < Data.define
    end

    # The raw-window-handle structs whose values +set_parent+ reads, by
    # name. A handle's kind is the name of its class, or of its nearest
    # named ancestor, without the namespace, so a value from another gem
    # named for the same struct works too (plan 008, decision 8).
    HANDLE_KINDS = %w[
      Win32WindowHandle
      XlibWindowHandle
      XcbWindowHandle
      AppKitWindowHandle
      WindowsDisplayHandle
      XlibDisplayHandle
      XcbDisplayHandle
      AppKitDisplayHandle
    ].freeze
    private_constant :HANDLE_KINDS

    # Kernel#class, unbound, for class_of.
    KERNEL_CLASS = Kernel.instance_method(:class)
    private_constant :KERNEL_CLASS

    # +handle+'s class, asked through Kernel so a BasicObject answers too.
    def self.class_of(handle) # :nodoc:
      KERNEL_CLASS.bind_call(handle)
    end
    private_class_method :class_of

    # The raw-window-handle struct +handle+ mirrors, or +nil+.
    def self.handle_kind(handle) # :nodoc:
      class_of(handle).ancestors.each do |ancestor|
        kind = ancestor.name&.split("::")&.last
        return kind if kind && HANDLE_KINDS.include?(kind)
      end
      nil
    end
    private_class_method :handle_kind

    # The tagged Array the native layer takes for a window handle.
    def self.native_window(handle) # :nodoc:
      # @type var fields: _HandleFields
      fields = _ = handle
      case handle_kind(handle)
      when "Win32WindowHandle" then [:Win32, fields.hwnd, fields.hinstance] #: native_window
      when "XlibWindowHandle" then [:Xlib, fields.window, _ = fields.visual_id] #: native_window
      when "XcbWindowHandle" then [:Xcb, fields.window, fields.visual_id] #: native_window
      when "AppKitWindowHandle" then [:AppKit, fields.window_number] #: native_window
      else raise TypeError, "wrong argument type #{class_of(handle)} (expected a window handle)"
      end
    end
    private_class_method :native_window

    # The tagged Array the native layer takes for a display handle.
    def self.native_display(handle) # :nodoc:
      # @type var fields: _HandleFields
      fields = _ = handle
      case handle_kind(handle)
      when "WindowsDisplayHandle" then [:Windows] #: native_display
      when "XlibDisplayHandle" then [:Xlib, fields.display, fields.screen] #: native_display
      when "XcbDisplayHandle" then [:Xcb, fields.connection, fields.screen] #: native_display
      when "AppKitDisplayHandle" then [:AppKit] #: native_display
      else raise TypeError, "wrong argument type #{class_of(handle)} (expected a display handle)"
      end
    end
    private_class_method :native_display

    # The <tt>[window, display]</tt> pair the native layer takes for a
    # parent: each a tagged Array, or +nil+ where the parent answered
    # +nil+. A parent that lacks +window_handle+ or +display_handle+ raises
    # +NoMethodError+, and one that returns anything but a handle or +nil+
    # raises +TypeError+, as Rust's trait bound would refuse it at compile
    # time. A handle is read by its kind and raw-window-handle's field
    # names, so one missing a field of its kind raises +NoMethodError+.
    def self.parent_pair(parent) # :nodoc:
      window_handle = parent.window_handle
      display_handle = parent.display_handle
      window = case window_handle
      when nil then nil
      else native_window(window_handle)
      end
      display = case display_handle
      when nil then nil
      else native_display(display_handle)
      end
      # @type var pair: native_parent
      pair = [window, display]
      Native.check_parent(pair)
      pair.freeze
    end
    private_class_method :parent_pair
  end
end
