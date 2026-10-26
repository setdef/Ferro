# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"
require_relative "test_file_dialog"

# AsyncFileDialog wraps a FileDialog, as rfd's does
# (src/file_dialog.rs:182-185), and rfd's Debug shows it.
class TestAsyncFileDialog < Minitest::Test
  include RfdSuite

  private def dialog
    Ferro::Rfd::AsyncFileDialog.new
  end

  def test_a_new_dialog_wraps_a_default_file_dialog
    assert_equal "AsyncFileDialog { file_dialog: #{TestFileDialog::DEFAULT} }", dialog.inspect
  end

  def test_every_setter_reaches_rfd
    configured = dialog
      .add_filter("text", ["txt"])
      .set_directory("docs")
      .set_file_name("notes.txt")
      .set_title("Open notes")
      .set_can_create_directories(false)
      .set_parent(Parent.new(nil, nil))

    assert_equal 'AsyncFileDialog { file_dialog: FileDialog { filters: [Filter { name: "text", extensions: ' \
      '["txt"] }], starting_directory: Some("docs"), file_name: Some("notes.txt"), title: Some("Open notes"), ' \
      "parent: None, parent_display: None, can_create_directories: Some(false) } }", configured.inspect
  end

  def test_each_setter_returns_the_dialog
    subject = dialog

    assert_same subject, subject.add_filter("a", ["b"])
    assert_same subject, subject.set_directory("d")
    assert_same subject, subject.set_file_name("f")
    assert_same subject, subject.set_title("t")
    assert_same subject, subject.set_can_create_directories(true)
    assert_same subject, subject.set_parent(Parent.new(nil, nil))
  end

  def test_a_copy_is_independent
    original = dialog.set_title("original")
    copy = original.dup.set_title("copy")

    assert_includes original.inspect, 'title: Some("original")'
    assert_includes copy.inspect, 'title: Some("copy")'
  end

  # Its setters replace the inner FileDialog rather than change it, so a
  # frozen dialog refuses them even though its inner one is not frozen.
  def test_a_frozen_dialog_refuses_its_setters
    [dialog.set_title("kept").freeze, dialog.set_title("kept").clone(freeze: true)].each do |frozen|
      assert_raises(FrozenError) { frozen.set_title("changed") }
      assert_raises(FrozenError) { frozen.add_filter("text", ["txt"]) }
      assert_includes frozen.inspect, 'title: Some("kept")'
    end
  end

  def test_a_shareable_dialog_refuses_its_setters
    shared = Ractor.make_shareable(dialog.set_title("kept"))

    assert_raises(FrozenError) { shared.set_title("changed") }
    assert_includes shared.inspect, 'title: Some("kept")'
  end

  def test_a_nul_byte_in_a_filter_is_refused
    assert_raises(ArgumentError) { dialog.add_filter("te\0xt", ["txt"]) }
  end
end
