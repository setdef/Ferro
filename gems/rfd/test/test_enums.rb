# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# rfd's enums: unit variants are frozen constants, variants with data are
# Data classes, Default is .default (plan 002, decision 8).
class TestEnums < Minitest::Test
  include RfdSuite

  def test_the_unit_variants_are_frozen_constants_named_for_rfds
    {
      Ferro::Rfd::MessageLevel => %i[Info Warning Error],
      Ferro::Rfd::MessageButtons => %i[Ok OkCancel YesNo YesNoCancel],
      Ferro::Rfd::MessageDialogResult => %i[Yes No Ok Cancel],
    }.each do |enum, names|
      names.each do |name|
        value = enum.const_get(name, false)

        assert_kind_of enum, value
        assert_predicate value, :frozen?
        assert_equal "#{enum}::#{name}", value.inspect
      end
      assert_raises(NoMethodError) { enum.new(:Other) }
    end
  end

  # rfd derives Default with #[default] on Info, Ok, and Cancel
  # (src/message_dialog.rs:153-187).
  def test_defaults_are_rfds
    assert_same Ferro::Rfd::MessageLevel::Info, Ferro::Rfd::MessageLevel.default
    assert_same Ferro::Rfd::MessageButtons::Ok, Ferro::Rfd::MessageButtons.default
    assert_same Ferro::Rfd::MessageDialogResult::Cancel, Ferro::Rfd::MessageDialogResult.default
  end

  def test_the_custom_buttons_carry_their_labels
    buttons = Ferro::Rfd::MessageButtons

    assert_equal %i[ok_text], buttons::OkCustom.members
    assert_equal %i[ok_text cancel_text], buttons::OkCancelCustom.members
    assert_equal %i[yes_text no_text cancel_text], buttons::YesNoCancelCustom.members
    assert_equal "Save", buttons::OkCancelCustom.new("Save", "Discard").ok_text
  end

  # rfd's Display (src/message_dialog.rs:189-203).
  def test_results_display_as_rfd_does
    result = Ferro::Rfd::MessageDialogResult

    assert_equal %w[Yes No Ok Cancel], [result::Yes, result::No, result::Ok, result::Cancel].map(&:to_s)
    assert_equal "Custom(Save)", result::Custom.new("Save").to_s
    assert_equal "res: Ok", "res: #{result::Ok}"
  end

  # rfd derives PartialEq and Eq.
  def test_results_compare_as_rfds_do
    result = Ferro::Rfd::MessageDialogResult

    assert_equal result::Custom.new("Save"), result::Custom.new("Save")
    refute_equal result::Custom.new("Save"), result::Custom.new("Discard")
    refute_equal result::Ok, result::Custom.new("Ok")
    assert_equal result::Yes, result::Yes
  end
end
