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
    assert_equal DEFAULT, dialog.debug
  end

  # rfd derives Default for both file builders, and new is it
  # (src/file_dialog.rs:19, :38-40, :182, :189-191).
  def test_default_is_a_new_dialog
    [Ferro::Rfd::FileDialog, Ferro::Rfd::AsyncFileDialog].each do |builder|
      assert_instance_of builder, builder.default
      assert_equal builder.new.debug, builder.default.debug
      refute_same builder.default, builder.default
    end
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
      "parent_display: None, can_create_directories: Some(true) }", configured.debug
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

    assert_includes configured.debug, 'filters: [Filter { name: "text", extensions: ["txt"] }, ' \
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
  # "*.extension" (src/backend/xdg_desktop_portal.rs:47-65), so on Linux a
  # NUL byte panics there, and add_filter refuses it with that panic's
  # text; a Rust test drives the real panic. Elsewhere rfd takes the byte,
  # and so does the gem.
  def test_a_nul_byte_in_a_filter_is_refused_only_where_rfd_panics
    subject = dialog
    {
      ["te\0xt", ["txt"]] => "NulError(2, [116, 101, 0, 120, 116])",
      ["text", ["t\0xt"]] => "NulError(3, [42, 46, 116, 0, 120, 116])",
    }.each do |(name, extensions), nul_error|
      if PLATFORM == :linux
        error = assert_raises(ArgumentError) { subject.add_filter(name, extensions) }
        assert_equal "called `Result::unwrap()` on an `Err` value: #{nul_error}", error.message
      else
        assert_same subject, subject.add_filter(name, extensions)
      end
    end

    if PLATFORM == :linux
      assert_equal DEFAULT, subject.debug
    else
      assert_includes subject.debug, 'Filter { name: "te\\0xt", extensions: ["txt"] }'
    end
  end

  # The native layer refuses it too, so a call that bypasses the builder
  # cannot reach rfd.
  def test_the_native_layer_refuses_a_nul_byte_in_a_filter_on_linux
    skip_unless_platform(:linux)
    native = Ferro::Rfd.const_get(:Native)
    settings = [[["te\0xt", ["txt"]]], nil, nil, nil, nil, nil]

    error = assert_raises(ArgumentError) { native.file_dialog_debug(settings) }
    assert_equal "called `Result::unwrap()` on an `Err` value: NulError(2, [116, 101, 0, 120, 116])", error.message
  end

  # rfd clears the directory for an empty path (src/file_dialog.rs:63-71).
  def test_an_empty_directory_clears_it_as_rfd_does
    assert_includes dialog.set_directory("docs").set_directory("").debug, "starting_directory: None"
  end

  def test_a_directory_may_be_any_object_with_to_path
    assert_includes dialog.set_directory(Pathname.new("docs")).debug, 'starting_directory: Some("docs")'
  end

  def test_a_later_setting_replaces_an_earlier_one
    assert_includes dialog.set_title("first").set_title("second").debug, 'title: Some("second")'
  end

  def test_titles_and_file_names_must_be_strings
    assert_raises(TypeError) { dialog.set_title(nil) }
    assert_raises(TypeError) { dialog.set_file_name(42) }
  end

  # rfd takes a bool (src/file_dialog.rs:105-110), and Rust's type
  # checker would refuse anything else.
  def test_can_create_directories_takes_true_or_false
    assert_includes dialog.set_can_create_directories(false).debug, "can_create_directories: Some(false)"
    assert_includes dialog.set_can_create_directories(true).debug, "can_create_directories: Some(true)"
    [nil, "yes", 1].each do |value|
      [dialog, Ferro::Rfd::AsyncFileDialog.new].each do |subject|
        error = assert_raises(TypeError) { subject.set_can_create_directories(value) }
        named = value.nil? ? "nil" : value.class
        assert_equal "no implicit conversion of #{named} into true or false", error.message
      end
    end
  end

  # rfd's builder is Clone; a copy's setters leave the original alone.
  def test_a_copy_is_independent
    original = dialog.add_filter("text", ["txt"])
    copy = original.dup.add_filter("rust", ["rs"]).set_title("copy")

    refute_includes original.debug, "rust"
    refute_includes original.debug, "copy"
    assert_includes copy.debug, 'Filter { name: "text", extensions: ["txt"] }'
  end

  def test_a_frozen_dialog_refuses_its_setters
    frozen = dialog.set_title("kept").freeze

    assert_raises(FrozenError) { frozen.set_title("changed") }
    assert_raises(FrozenError) { frozen.add_filter("text", ["txt"]) }
    assert_includes frozen.debug, 'title: Some("kept")'
  end

  # inspect is Ruby's, naming the class (ADR 001, 2026-11-05); rfd's
  # Debug text is debug.
  def test_inspect_stays_rubys
    subject = dialog.set_title("Open")

    assert_match(/\A#<Ferro::Rfd::FileDialog:0x\h+ /, subject.inspect)
    refute_includes subject.inspect, "FileDialog {"
  end

  # rfd's terminal methods take self (src/file_dialog.rs:121-174), so a
  # dialog works once. On macOS a Ruby thread with no running app is
  # refused before rfd runs; the refusal still uses the dialog up, as
  # Rust's move would. Every terminal call runs on that thread, so one the
  # gem failed to refuse meets rfd's refusal, never a real dialog. Linux's
  # dialogs show the same with a stand-in zenity (test_linux_dialogs.rb).
  def test_a_terminal_method_uses_the_dialog_up_even_when_it_raises
    skip_unless_platform(:macos)
    subject = dialog.set_title("once")

    messages = where_no_dialog_opens do
      assert_raises(Ferro::Rfd::Error) { subject.pick_file }
      %i[
        pick_file
        pick_files
        pick_folder
        pick_folders
        save_file
        pick_file_or_folder
        pick_files_or_folders
        debug
].map { |call| assert_raises(IOError, call.to_s) { subject.public_send(call) }.message }
    end

    assert_equal ["Ferro::Rfd::FileDialog consumed by FileDialog#pick_file"], messages.uniq
    assert_raises(IOError) { subject.set_title("again") }
    assert_raises(IOError) { subject.add_filter("text", ["txt"]) }
    assert_raises(IOError) { subject.set_directory("d") }
    assert_raises(IOError) { subject.set_file_name("f") }
    assert_raises(IOError) { subject.set_parent(Parent.new(nil, nil)) }
    assert_raises(IOError) { subject.set_can_create_directories(true) }
    assert_raises(IOError) { subject.dup.debug }
  end

  # A copy made before the terminal call is unused, as rfd's Clone is.
  def test_a_copy_made_first_shows_again
    skip_unless_platform(:macos)
    subject = dialog.set_title("twice")
    copy = subject.dup

    where_no_dialog_opens { assert_raises(Ferro::Rfd::Error) { subject.save_file } }
    assert_includes copy.debug, 'title: Some("twice")'
  end

  # A frozen dialog cannot be used up, so its terminal methods raise
  # FrozenError, Ruby's own, before rfd runs. Only macOS can call a sync
  # one without risking a real dialog (where_no_dialog_opens).
  def test_a_frozen_dialog_refuses_its_terminal_methods
    skip_unless_platform(:macos)
    frozen = dialog.freeze

    where_no_dialog_opens do
      %i[pick_file pick_files pick_folder pick_folders save_file].each do |call|
        assert_raises(FrozenError, call.to_s) { frozen.public_send(call) }
      end
    end
    assert_equal DEFAULT, frozen.debug
  end

  def test_the_native_module_and_platform_are_private
    assert_raises(NameError) { Ferro::Rfd::Native }
    assert_raises(NameError) { Ferro::Rfd::PLATFORM }
    assert_includes %i[linux macos windows], PLATFORM
  end
end
