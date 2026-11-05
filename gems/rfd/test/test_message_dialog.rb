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
    assert_equal DEFAULT, Ferro::Rfd::MessageDialog.new.debug
    assert_equal "AsyncMessageDialog(#{DEFAULT})", Ferro::Rfd::AsyncMessageDialog.new.debug
  end

  # rfd derives Default for both message builders, and new is it
  # (src/message_dialog.rs:14, :29-31, :92, :96-98).
  def test_default_is_a_new_dialog
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      assert_instance_of builder, builder.default
      assert_equal builder.new.debug, builder.default.debug
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

      assert_includes configured.debug, 'MessageDialog { title: "Msg!", description: "Description!", ' \
        "level: Error, buttons: OkCancel, parent: None, parent_display: None }"
    end
  end

  def test_each_level_reaches_rfd
    %i[Info Warning Error].each do |name|
      level = Ferro::Rfd::MessageLevel.const_get(name)

      assert_includes Ferro::Rfd::MessageDialog.new.set_level(level).debug, "level: #{name},"
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
      assert_includes Ferro::Rfd::MessageDialog.new.set_buttons(value).debug, "buttons: #{debug},"
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
      assert_includes Ferro::Rfd::MessageDialog.new.set_buttons(value).debug, "buttons: #{debug},"
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
        assert_includes frozen.debug, 'title: "kept"'
      end
    end
  end

  def test_a_copy_is_independent
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      original = builder.new.set_title("original")
      copy = original.dup.set_title("copy")

      assert_includes original.debug, 'title: "original"'
      assert_includes copy.debug, 'title: "copy"'
    end
  end

  def test_inspect_stays_rubys
    [Ferro::Rfd::MessageDialog, Ferro::Rfd::AsyncMessageDialog].each do |builder|
      assert_match(/\A#<#{builder}:0x\h+ /, builder.new.inspect)
    end
  end

  # rfd's show takes self (src/message_dialog.rs:81-84, :147-150). On
  # Windows and Linux an async message starts nothing until its Future is
  # polled; on macOS a parent with a window, from a Ruby thread with no
  # running app, is refused before rfd runs (without a parent window, rfd
  # would open a real alert at once, from any thread).
  private def async_message_that_opens_nothing
    subject = Ferro::Rfd::AsyncMessageDialog.new
    return subject unless PLATFORM == :macos

    subject.set_parent(Parent.new(Ferro::Rfd::AppKitWindowHandle.new(window_number: 1), nil))
  end

  def test_show_uses_an_async_dialog_up
    subject = async_message_that_opens_nothing.set_title("once")

    messages = where_no_dialog_opens do
      if PLATFORM == :macos
        assert_raises(Ferro::Rfd::Error) { subject.show }
      else
        assert_instance_of Ferro::Rfd::Future, subject.show
      end
      %i[show debug].map { |call| assert_raises(IOError, call.to_s) { subject.public_send(call) }.message }
    end

    assert_equal ["Ferro::Rfd::AsyncMessageDialog consumed by AsyncMessageDialog#show"], messages.uniq
    assert_raises(IOError) { subject.set_title("again") }
    assert_raises(IOError) { subject.set_description("d") }
    assert_raises(IOError) { subject.set_level(Ferro::Rfd::MessageLevel::Error) }
    assert_raises(IOError) { subject.set_buttons(Ferro::Rfd::MessageButtons::YesNo) }
    assert_raises(IOError) { subject.set_parent(Parent.new(nil, nil)) }
  end

  def test_show_uses_a_sync_dialog_up
    skip_unless_platform(:macos)
    subject = Ferro::Rfd::MessageDialog.new

    messages = where_no_dialog_opens do
      assert_raises(Ferro::Rfd::Error) { subject.show }
      %i[show debug].map { |call| assert_raises(IOError, call.to_s) { subject.public_send(call) }.message }
    end

    assert_equal ["Ferro::Rfd::MessageDialog consumed by MessageDialog#show"], messages.uniq
    assert_raises(IOError) { subject.set_title("again") }
  end

  def test_a_frozen_dialog_cannot_be_shown
    dialogs = [async_message_that_opens_nothing.freeze]
    dialogs << Ferro::Rfd::MessageDialog.new.freeze if PLATFORM == :macos

    where_no_dialog_opens do
      dialogs.each { |frozen| assert_raises(FrozenError, frozen.class.name) { frozen.show } }
    end
  end
end
