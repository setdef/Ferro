# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# MessageDialog and AsyncMessageDialog keep their options and rfd replays
# them; rfd's Debug text shows each one.
class TestMessageDialog < Minitest::Test
  include RfdSuite

  DEFAULT = 'MessageDialog { title: "", description: "", level: Info, buttons: Ok, parent: None, ' \
    "parent_display: None }"

  def test_a_new_dialog_has_rfds_defaults
    assert_equal DEFAULT, Ferro::Rfd::MessageDialog.new.inspect
    assert_equal "AsyncMessageDialog(#{DEFAULT})", Ferro::Rfd::AsyncMessageDialog.new.inspect
  end

  # rfd derives Default for both message builders, and new is it
  # (src/message_dialog.rs:14, :29-31, :92, :96-98).
  def test_default_is_a_new_dialog
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      assert_instance_of builder, builder.default
      assert_equal builder.new.inspect, builder.default.inspect
      refute_same builder.default, builder.default
    end
  end

  def test_every_setter_reaches_rfd
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      configured = builder.new
        .set_title("Msg!")
        .set_description("Description!")
        .set_level(Ferro::Rfd::MessageLevel::Error)
        .set_buttons(Ferro::Rfd::MessageButtons::OkCancel)
        .set_parent(Parent.new(nil, nil))

      assert_includes configured.inspect, 'MessageDialog { title: "Msg!", description: "Description!", ' \
        "level: Error, buttons: OkCancel, parent: None, parent_display: None }"
    end
  end

  def test_each_level_reaches_rfd
    %i[Info Warning Error].each do |name|
      level = Ferro::Rfd::MessageLevel.const_get(name)

      assert_includes Ferro::Rfd::MessageDialog.new.set_level(level).inspect, "level: #{name},"
    end
  end

  def test_each_set_of_buttons_reaches_rfd
    buttons = Ferro::Rfd::MessageButtons
    {
      buttons::Ok => "Ok",
      buttons::OkCancel => "OkCancel",
      buttons::YesNo => "YesNo",
      buttons::YesNoCancel => "YesNoCancel",
      buttons::OkCustom.new("Got it") => 'OkCustom("Got it")',
      buttons::OkCancelCustom.new("Save", "Discard") => 'OkCancelCustom("Save", "Discard")',
      buttons::YesNoCancelCustom.new("A", "B", "C") => 'YesNoCancelCustom("A", "B", "C")',
    }.each do |value, debug|
      assert_includes Ferro::Rfd::MessageDialog.new.set_buttons(value).inspect, "buttons: #{debug},"
    end
  end

  # A subclass is still the variant it inherits, as a handle subclass is.
  def test_a_subclass_of_a_custom_set_reaches_rfd_as_its_variant
    buttons = Ferro::Rfd::MessageButtons
    {
      Class.new(buttons::OkCustom).new("x") => 'OkCustom("x")',
      Class.new(buttons::OkCancelCustom).new("a", "b") => 'OkCancelCustom("a", "b")',
      Class.new(buttons::YesNoCancelCustom).new("a", "b", "c") => 'YesNoCancelCustom("a", "b", "c")',
    }.each do |value, debug|
      assert_includes Ferro::Rfd::MessageDialog.new.set_buttons(value).inspect, "buttons: #{debug},"
    end
  end

  def test_each_setter_returns_the_dialog
    [Ferro::Rfd::MessageDialog.new, Ferro::Rfd::AsyncMessageDialog.new].each do |subject|
      assert_same subject, subject.set_title("t")
      assert_same subject, subject.set_description("d")
      assert_same subject, subject.set_level(Ferro::Rfd::MessageLevel::Warning)
      assert_same subject, subject.set_buttons(Ferro::Rfd::MessageButtons::YesNo)
      assert_same subject, subject.set_parent(Parent.new(nil, nil))
    end
  end

  # Rust's type checker would refuse anything else.
  def test_a_level_or_buttons_of_the_wrong_type_raise_type_error
    error = assert_raises(TypeError) { Ferro::Rfd::MessageDialog.new.set_level(:Error) }
    assert_equal "wrong argument type Symbol (expected Ferro::Rfd::MessageLevel)", error.message

    assert_raises(TypeError) { Ferro::Rfd::MessageDialog.new.set_buttons(Ferro::Rfd::MessageLevel::Info) }
    stranger = Object.new.extend(Ferro::Rfd::MessageButtons)
    error = assert_raises(TypeError) { Ferro::Rfd::MessageDialog.new.set_buttons(stranger) }
    assert_equal "wrong argument type Object (expected Ferro::Rfd::MessageButtons)", error.message
    assert_raises(TypeError) do
      Ferro::Rfd::MessageDialog.new.set_buttons(Ferro::Rfd::MessageButtons::OkCustom.new(:label))
    end
    assert_raises(TypeError) { Ferro::Rfd::MessageDialog.new.set_description(nil) }
  end

  def test_a_frozen_dialog_refuses_its_setters
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      [builder.new.set_title("kept").freeze, builder.new.set_title("kept").clone(freeze: true)].each do |frozen|
        assert_raises(FrozenError) { frozen.set_title("changed") }
        assert_raises(FrozenError) { frozen.set_level(Ferro::Rfd::MessageLevel::Error) }
        assert_includes frozen.inspect, 'title: "kept"'
      end
    end
  end

  def test_a_copy_is_independent
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      original = builder.new.set_title("original")
      copy = original.dup.set_title("copy")

      assert_includes original.inspect, 'title: "original"'
      assert_includes copy.inspect, 'title: "copy"'
    end
  end
end
