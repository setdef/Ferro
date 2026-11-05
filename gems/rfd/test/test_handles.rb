# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# set_parent reads a parent's window_handle and display_handle, and only
# handles rfd never dereferences are bound (plan 002, decision 6).
class TestHandles < Minitest::Test
  include RfdSuite

  WIN32 = Ferro::Rfd::Win32WindowHandle.new(hwnd: 0x40A2C, hinstance: nil)
  XLIB = Ferro::Rfd::XlibWindowHandle.new(window: 0x3A00007, visual_id: 0)
  XCB = Ferro::Rfd::XcbWindowHandle.new(window: 0x3A00007, visual_id: 33)
  APPKIT = Ferro::Rfd::AppKitWindowHandle.new(window_number: 4242)

  # Handles from another gem, named for raw-window-handle's structs as
  # Tokra's are (plan 008, decision 8).
  module Elsewhere
    Win32WindowHandle = Data.define(:hwnd, :hinstance)
    XcbWindowHandle = Data.define(:window, :visual_id)
    XlibDisplayHandle = Data.define(:display, :screen)
    WindowsDisplayHandle = Data.define
    AppKitWindowHandle = Data.define(:ns_view)
    WaylandWindowHandle = Data.define(:surface)
  end

  # A subclass keeps its kind through its ancestor's name.
  class MyWin32 < Ferro::Rfd::Win32WindowHandle
  end

  # What rfd panics with for a handle it cannot use here
  # (src/backend/win_cid/file_dialog/dialog_ffi.rs:157,
  # src/backend/macos/utils.rs:43), verbatim, as std's unreachable! words
  # it; a Rust test in handles.rs drives the real panic.
  # SPDX-SnippetBegin
  # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
  # SPDX-License-Identifier: MIT
  # SPDX-SnippetComment: rfd 0.17.2's unreachable! messages, verbatim
  REFUSED = {
    windows: "internal error: entered unreachable code: unsupported window handle, expected: Windows",
    macos: "internal error: entered unreachable code: unsupported window handle, expected: MacOS",
  }.freeze
  # SPDX-SnippetEnd

  # raw-window-handle's structs have public fields, so the values are
  # Data with every field (ADR 001's table).
  def test_the_handles_are_data_with_raw_window_handles_fields
    assert_equal %i[hwnd hinstance], Ferro::Rfd::Win32WindowHandle.members
    assert_equal %i[window visual_id], Ferro::Rfd::XlibWindowHandle.members
    assert_equal %i[window visual_id], Ferro::Rfd::XcbWindowHandle.members
    assert_empty Ferro::Rfd::WindowsDisplayHandle.members
    assert_equal %i[display screen], Ferro::Rfd::XlibDisplayHandle.members
    assert_equal %i[connection screen], Ferro::Rfd::XcbDisplayHandle.members
    assert_equal %i[window_number], Ferro::Rfd::AppKitWindowHandle.members
    assert_empty Ferro::Rfd::AppKitDisplayHandle.members
    assert_predicate WIN32, :frozen?
  end

  # The structs are #[non_exhaustive], so new is how Rust makes one, and
  # it fills the optional fields (raw-window-handle 0.6.2
  # src/windows.rs:83-88, src/unix.rs:71-76, :145-150).
  def test_the_short_constructors_take_raw_window_handles_defaults
    assert_equal Ferro::Rfd::Win32WindowHandle.new(hwnd: 7, hinstance: nil), Ferro::Rfd::Win32WindowHandle.new(7)
    assert_nil Ferro::Rfd::Win32WindowHandle.new(hwnd: 7).hinstance
    assert_equal Ferro::Rfd::XlibWindowHandle.new(window: 5, visual_id: 0), Ferro::Rfd::XlibWindowHandle.new(5)
    assert_equal 0, Ferro::Rfd::XlibWindowHandle.new(window: 5).visual_id
    assert_equal Ferro::Rfd::XcbWindowHandle.new(window: 5, visual_id: nil), Ferro::Rfd::XcbWindowHandle.new(5)
    assert_nil Ferro::Rfd::XcbWindowHandle.new(window: 5).visual_id
    assert_equal 9, Ferro::Rfd::Win32WindowHandle.new(7, 9).hinstance
    assert_raises(ArgumentError) { Ferro::Rfd::Win32WindowHandle.new }
  end

  def test_a_win32_parent_reaches_rfd_where_rfd_takes_it
    skip "rfd takes no Win32 handle on macOS" if PLATFORM == :macos
    parent = Parent.new(Ferro::Rfd::Win32WindowHandle.new(hwnd: 7, hinstance: 9), Ferro::Rfd::WindowsDisplayHandle.new)

    debug = Ferro::Rfd::FileDialog.new.set_parent(parent).debug

    assert_includes debug, "parent: Some(Win32(Win32WindowHandle { hwnd: 7, hinstance: Some(9) })), " \
      "parent_display: Some(Windows(WindowsDisplayHandle))"
    assert_includes Ferro::Rfd::FileDialog.new.set_parent(Parent.new(Ferro::Rfd::Win32WindowHandle.new(7), nil)).debug,
      "parent: Some(Win32(Win32WindowHandle { hwnd: 7, hinstance: None }))"
  end

  def test_x11_parents_reach_rfd_on_linux
    skip_unless_platform(:linux)
    xlib = Parent.new(XLIB, Ferro::Rfd::XlibDisplayHandle.new(display: nil, screen: 0))
    xcb = Parent.new(XCB, Ferro::Rfd::XcbDisplayHandle.new(connection: 0x10, screen: 1))

    assert_includes Ferro::Rfd::FileDialog.new.set_parent(xlib).debug,
      "parent: Some(Xlib(XlibWindowHandle { window: 60817415, visual_id: 0 })), " \
        "parent_display: Some(Xlib(XlibDisplayHandle { display: None, screen: 0 }))"
    assert_includes Ferro::Rfd::MessageDialog.new.set_parent(xcb).debug,
      "parent: Some(Xcb(XcbWindowHandle { window: 60817415, visual_id: Some(33) }))"
    assert_includes Ferro::Rfd::FileDialog.new.set_parent(Parent.new(Ferro::Rfd::XlibWindowHandle.new(5), nil)).debug,
      "parent: Some(Xlib(XlibWindowHandle { window: 5, visual_id: 0 }))"
    assert_includes Ferro::Rfd::FileDialog.new.set_parent(Parent.new(Ferro::Rfd::XcbWindowHandle.new(5), nil)).debug,
      "parent: Some(Xcb(XcbWindowHandle { window: 5, visual_id: None }))"
  end

  def test_a_handle_rfd_would_panic_on_is_refused_with_rfds_message
    message = REFUSED[PLATFORM]
    skip "rfd's portal backend ignores a handle it cannot use" unless message

    refused = (PLATFORM == :windows) ? [XLIB, XCB, APPKIT] : [WIN32, XLIB, XCB]
    refused.each do |handle|
      [
        Ferro::Rfd::FileDialog,
        Ferro::Rfd::AsyncFileDialog,
        Ferro::Rfd::MessageDialog,
        Ferro::Rfd::AsyncMessageDialog,
].each do |builder|
        error = assert_raises(ArgumentError) { builder.new.set_parent(Parent.new(handle, nil)) }
        assert_equal message, error.message
      end
    end
  end

  # A nil handle is rfd's None, which every platform takes.
  def test_a_parent_without_handles_leaves_rfd_with_none
    debug = Ferro::Rfd::FileDialog.new.set_parent(Parent.new(nil, nil)).debug

    assert_includes debug, "parent: None, parent_display: None"
  end

  # raw-window-handle holds these as NonZero integers. The handle is
  # converted before the platform's refusal, so every platform says so.
  def test_a_zero_where_rust_needs_non_zero_raises_range_error
    zeroes = [
      Ferro::Rfd::Win32WindowHandle.new(hwnd: 0, hinstance: nil),
      Ferro::Rfd::Win32WindowHandle.new(hwnd: 1, hinstance: 0),
      Ferro::Rfd::XcbWindowHandle.new(window: 0, visual_id: nil),
      Ferro::Rfd::XcbWindowHandle.new(window: 1, visual_id: 0),
    ]

    zeroes.each do |handle|
      error = assert_raises(RangeError) { Ferro::Rfd::FileDialog.new.set_parent(Parent.new(handle, nil)) }
      assert_equal "number would be zero for non-zero type", error.message
    end
  end

  def test_a_value_that_is_no_handle_raises_type_error
    assert_raises(TypeError) { Ferro::Rfd::FileDialog.new.set_parent(Parent.new(0x40A2C, nil)) }
    assert_raises(TypeError) { Ferro::Rfd::FileDialog.new.set_parent(Parent.new(nil, WIN32)) }
  end

  # The portal ignores an AppKit window, so it is no parent there, and
  # nothing looks it up (plan 008, decision 6).
  def test_an_appkit_window_is_no_parent_on_linux
    skip_unless_platform(:linux)
    debug = Ferro::Rfd::FileDialog.new.set_parent(Parent.new(APPKIT, Ferro::Rfd::AppKitDisplayHandle.new)).debug

    assert_includes debug, "parent: None, parent_display: Some(AppKit(AppKitDisplayHandle))"
  end

  # On macOS rfd refuses these kinds, and the refusal names the kind the
  # gem read: rfd's message, not a TypeError.
  def test_handles_from_another_gem_are_read_by_kind
    win32 = Parent.new(Elsewhere::Win32WindowHandle.new(hwnd: 7, hinstance: nil), Elsewhere::WindowsDisplayHandle.new)
    subclass = Parent.new(MyWin32.new(hwnd: 8, hinstance: 9), nil)
    xcb = Parent.new(Elsewhere::XcbWindowHandle.new(window: 5, visual_id: nil),
      Elsewhere::XlibDisplayHandle.new(display: nil, screen: 2))

    case PLATFORM
    when :windows
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(win32).debug,
        "parent: Some(Win32(Win32WindowHandle { hwnd: 7, hinstance: None })), " \
          "parent_display: Some(Windows(WindowsDisplayHandle))"
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(subclass).debug,
        "Win32WindowHandle { hwnd: 8, hinstance: Some(9) }"
    when :macos
      [win32, subclass, xcb].each do |parent|
        error = assert_raises(ArgumentError) { Ferro::Rfd::FileDialog.new.set_parent(parent) }
        assert_equal REFUSED[:macos], error.message
      end
    else
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(xcb).debug,
        "parent: Some(Xcb(XcbWindowHandle { window: 5, visual_id: None })), " \
          "parent_display: Some(Xlib(XlibDisplayHandle { display: None, screen: 2 }))"
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(subclass).debug,
        "parent: Some(Win32(Win32WindowHandle { hwnd: 8, hinstance: Some(9) })), parent_display: None"
    end
  end

  # Wayland is not bound (plan 008, decision 7), and a kind needs a name.
  def test_a_handle_of_an_unbound_kind_or_no_name_raises_type_error
    unnamed = Data.define(:hwnd, :hinstance).new(hwnd: 7, hinstance: nil)

    [Elsewhere::WaylandWindowHandle.new(surface: 0x10), unnamed].each do |handle|
      error = assert_raises(TypeError) { Ferro::Rfd::FileDialog.new.set_parent(Parent.new(handle, nil)) }
      assert_equal "wrong argument type #{handle.class} (expected a window handle)", error.message
    end
    error = assert_raises(TypeError) { Ferro::Rfd::FileDialog.new.set_parent(Parent.new(nil, BasicObject.new)) }
    assert_equal "wrong argument type BasicObject (expected a display handle)", error.message
  end

  # Tokra's AppKit value answers ns_view; ferro-rfd reads window_number.
  def test_a_handle_missing_a_field_of_its_kind_raises_no_method_error
    handle = Elsewhere::AppKitWindowHandle.new(ns_view: 0x10)

    error = assert_raises(NoMethodError) { Ferro::Rfd::FileDialog.new.set_parent(Parent.new(handle, nil)) }
    assert_equal :window_number, error.name
  end

  def test_a_parent_must_answer_both_handles
    assert_raises(NoMethodError) { Ferro::Rfd::FileDialog.new.set_parent(Object.new) }
  end

  # raw-window-handle derives Debug for each struct (src/windows.rs:11,
  # :51, src/unix.rs:7, :47, :81, :121, src/appkit.rs:8), and debug is
  # that text, formatted by Rust, on every platform; inspect stays Data's.
  def test_handles_debug_as_raw_window_handle_derives
    {
      WIN32 => "Win32WindowHandle { hwnd: 264748, hinstance: None }",
      Ferro::Rfd::Win32WindowHandle.new(7, 9) => "Win32WindowHandle { hwnd: 7, hinstance: Some(9) }",
      XLIB => "XlibWindowHandle { window: 60817415, visual_id: 0 }",
      XCB => "XcbWindowHandle { window: 60817415, visual_id: Some(33) }",
      Ferro::Rfd::XcbWindowHandle.new(5) => "XcbWindowHandle { window: 5, visual_id: None }",
      MyWin32.new(hwnd: 8, hinstance: nil) => "Win32WindowHandle { hwnd: 8, hinstance: None }",
      Ferro::Rfd::WindowsDisplayHandle.new => "WindowsDisplayHandle",
      Ferro::Rfd::XlibDisplayHandle.new(display: nil, screen: 0) => "XlibDisplayHandle { display: None, screen: 0 }",
      Ferro::Rfd::XcbDisplayHandle.new(connection: 0x10, screen: 1) =>
        "XcbDisplayHandle { connection: Some(0x10), screen: 1 }",
      Ferro::Rfd::AppKitDisplayHandle.new => "AppKitDisplayHandle",
    }.each do |handle, debug|
      assert_equal debug, handle.debug
      assert_match(/\A#<data /, handle.inspect)
    end
  end

  # The AppKit window's Debug shows the content view, which only macOS can
  # look up (test_appkit_parent.rb); elsewhere the value has no debug.
  def test_an_appkit_window_has_debug_only_on_macos
    assert_equal PLATFORM == :macos, APPKIT.respond_to?(:debug)
  end

  def test_a_handle_debugs_only_what_its_struct_can_hold
    assert_raises(RangeError) { Ferro::Rfd::Win32WindowHandle.new(0).debug }
    assert_raises(TypeError) { Ferro::Rfd::XlibDisplayHandle.new(display: nil, screen: "0").debug }
  end
end
