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
  # src/backend/macos/utils.rs:43).
  # SPDX-SnippetBegin
  # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
  # SPDX-License-Identifier: MIT
  # SPDX-SnippetComment: rfd 0.17.2's unreachable! messages, verbatim
  REFUSED = {
    windows: "unsupported window handle, expected: Windows",
    macos: "unsupported window handle, expected: MacOS",
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

  def test_a_win32_parent_reaches_rfd_where_rfd_takes_it
    skip "rfd takes no Win32 handle on macOS" if PLATFORM == :macos
    parent = Parent.new(Ferro::Rfd::Win32WindowHandle.new(hwnd: 7, hinstance: 9), Ferro::Rfd::WindowsDisplayHandle.new)

    debug = Ferro::Rfd::FileDialog.new.set_parent(parent).inspect

    assert_includes debug, "parent: Some(Win32(Win32WindowHandle { hwnd: 7, hinstance: Some(9) })), " \
      "parent_display: Some(Windows(WindowsDisplayHandle))"
  end

  def test_x11_parents_reach_rfd_on_linux
    skip_unless_platform(:linux)
    xlib = Parent.new(XLIB, Ferro::Rfd::XlibDisplayHandle.new(display: nil, screen: 0))
    xcb = Parent.new(XCB, Ferro::Rfd::XcbDisplayHandle.new(connection: 0x10, screen: 1))

    assert_includes Ferro::Rfd::FileDialog.new.set_parent(xlib).inspect,
      "parent: Some(Xlib(XlibWindowHandle { window: 60817415, visual_id: 0 })), " \
        "parent_display: Some(Xlib(XlibDisplayHandle { display: None, screen: 0 }))"
    assert_includes Ferro::Rfd::MessageDialog.new.set_parent(xcb).inspect,
      "parent: Some(Xcb(XcbWindowHandle { window: 60817415, visual_id: Some(33) }))"
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
    debug = Ferro::Rfd::FileDialog.new.set_parent(Parent.new(nil, nil)).inspect

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
    debug = Ferro::Rfd::FileDialog.new.set_parent(Parent.new(APPKIT, Ferro::Rfd::AppKitDisplayHandle.new)).inspect

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
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(win32).inspect,
        "parent: Some(Win32(Win32WindowHandle { hwnd: 7, hinstance: None })), " \
          "parent_display: Some(Windows(WindowsDisplayHandle))"
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(subclass).inspect,
        "Win32WindowHandle { hwnd: 8, hinstance: Some(9) }"
    when :macos
      [win32, subclass, xcb].each do |parent|
        error = assert_raises(ArgumentError) { Ferro::Rfd::FileDialog.new.set_parent(parent) }
        assert_equal REFUSED[:macos], error.message
      end
    else
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(xcb).inspect,
        "parent: Some(Xcb(XcbWindowHandle { window: 5, visual_id: None })), " \
          "parent_display: Some(Xlib(XlibDisplayHandle { display: None, screen: 2 }))"
      assert_includes Ferro::Rfd::FileDialog.new.set_parent(subclass).inspect,
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
end
