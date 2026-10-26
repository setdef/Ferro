# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# FileDialog keeps its options and rfd replays them (plan 002, decision 1).
# Each test reads the options back through rfd's own Debug text, so an
# option that never reached rfd fails it.
class TestFileDialog < Minitest::Test
  include RfdSuite

  DEFAULT = "FileDialog { filters: [], starting_directory: None, file_name: None, title: None, parent: None, " \
    "parent_display: None, can_create_directories: None }"

  private def dialog
    Ferro::Rfd::FileDialog.new
  end

  def test_a_new_dialog_has_rfds_defaults
    assert_equal DEFAULT, dialog.inspect
  end

  def test_every_setter_reaches_rfd
    configured = dialog
      .add_filter("text", ["txt", "rs"])
      .set_directory("docs")
      .set_file_name("notes.txt")
      .set_title("Open notes")
      .set_can_create_directories(true)

    assert_equal 'FileDialog { filters: [Filter { name: "text", extensions: ["txt", "rs"] }], ' \
      'starting_directory: Some("docs"), file_name: Some("notes.txt"), title: Some("Open notes"), parent: None, ' \
      "parent_display: None, can_create_directories: Some(true) }", configured.inspect
  end

  def test_each_setter_returns_the_dialog
    subject = dialog
    calls = [
      -> { subject.add_filter("a", ["b"]) },
      -> { subject.set_directory("d") },
      -> { subject.set_file_name("f") },
      -> { subject.set_title("t") },
      -> { subject.set_can_create_directories(false) },
      -> { subject.set_parent(Parent.new(nil, nil)) },
    ]

    calls.each { |call| assert_same subject, call.call }
  end

  # Each extension is impl ToString in rfd, so any value formats.
  def test_filters_accumulate_in_order_and_extensions_become_strings
    configured = dialog.add_filter("text", ["txt"]).add_filter("rust", [:rs, 1])

    assert_includes configured.inspect, 'filters: [Filter { name: "text", extensions: ["txt"] }, ' \
      'Filter { name: "rust", extensions: ["rs", "1"] }]'
  end

  def test_a_filter_name_must_be_a_string
    error = assert_raises(TypeError) { dialog.add_filter(:rust, ["rs"]) }

    assert_equal "no implicit conversion of Symbol into String", error.message
  end

  def test_extensions_must_be_an_array
    assert_raises(TypeError) { dialog.add_filter("text", "txt") }
  end

  # rfd's portal backend unwraps CString::new on each filter name and
  # extension (src/backend/xdg_desktop_portal.rs:47-65), so a NUL byte
  # panics there. It is refused on every platform.
  def test_a_nul_byte_in_a_filter_is_refused_before_rfd_sees_it
    subject = dialog
    ["te\0xt", "text"].product([["txt"], ["t\0xt"]]).each do |name, extensions|
      next if !name.include?("\0") && !extensions.first.include?("\0")

      error = assert_raises(ArgumentError) { subject.add_filter(name, extensions) }
      assert_equal "string contains null byte", error.message
    end

    assert_equal DEFAULT, subject.inspect
  end

  # The native layer refuses it too, so a call that bypasses the builder
  # cannot reach rfd.
  def test_the_native_layer_refuses_a_nul_byte_in_a_filter
    native = Ferro::Rfd.const_get(:Native)
    settings = [[["te\0xt", ["txt"]]], nil, nil, nil, nil, nil]

    error = assert_raises(ArgumentError) { native.file_dialog_debug(settings) }
    assert_equal "string contains null byte", error.message
  end

  # rfd clears the directory for an empty path (src/file_dialog.rs:63-71).
  def test_an_empty_directory_clears_it_as_rfd_does
    assert_includes dialog.set_directory("docs").set_directory("").inspect, "starting_directory: None"
  end

  def test_a_directory_may_be_any_object_with_to_path
    assert_includes dialog.set_directory(Pathname.new("docs")).inspect, 'starting_directory: Some("docs")'
  end

  def test_a_later_setting_replaces_an_earlier_one
    assert_includes dialog.set_title("first").set_title("second").inspect, 'title: Some("second")'
  end

  def test_titles_and_file_names_must_be_strings
    assert_raises(TypeError) { dialog.set_title(nil) }
    assert_raises(TypeError) { dialog.set_file_name(42) }
  end

  def test_can_create_directories_takes_ruby_truthiness
    assert_includes dialog.set_can_create_directories(nil).inspect, "can_create_directories: Some(false)"
    assert_includes dialog.set_can_create_directories("yes").inspect, "can_create_directories: Some(true)"
  end

  # rfd's builder is Clone; a copy's setters leave the original alone.
  def test_a_copy_is_independent
    original = dialog.add_filter("text", ["txt"])
    copy = original.dup.add_filter("rust", ["rs"]).set_title("copy")

    refute_includes original.inspect, "rust"
    refute_includes original.inspect, "copy"
    assert_includes copy.inspect, 'Filter { name: "text", extensions: ["txt"] }'
  end

  def test_a_frozen_dialog_refuses_its_setters
    frozen = dialog.set_title("kept").freeze

    assert_raises(FrozenError) { frozen.set_title("changed") }
    assert_raises(FrozenError) { frozen.add_filter("text", ["txt"]) }
    assert_includes frozen.inspect, 'title: Some("kept")'
  end

  def test_the_native_module_and_platform_are_private
    assert_raises(NameError) { Ferro::Rfd::Native }
    assert_raises(NameError) { Ferro::Rfd::PLATFORM }
    assert_includes %i[linux macos windows], PLATFORM
  end
end
