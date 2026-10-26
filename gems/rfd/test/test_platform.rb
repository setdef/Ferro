# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# rfd compiles pick_file_or_folder and pick_files_or_folders only for
# macOS (src/file_dialog.rs:141-155, :293-307), so respond_to? answers
# truthfully.
class TestPlatform < Minitest::Test
  include RfdSuite

  MACOS_ONLY = %i[pick_file_or_folder pick_files_or_folders].freeze

  def test_the_macos_pickers_exist_only_on_macos
    [Ferro::Rfd::FileDialog.new, Ferro::Rfd::AsyncFileDialog.new].each do |dialog|
      MACOS_ONLY.each do |name|
        assert_equal PLATFORM == :macos, dialog.respond_to?(name), "#{dialog.class}##{name} on #{PLATFORM}"
      end
    end
  end

  # The native layer refuses them elsewhere, so a call that bypasses the
  # builder cannot reach a method rfd lacks.
  def test_the_native_layer_refuses_the_macos_pickers_elsewhere
    skip "macOS has them" if PLATFORM == :macos
    native = Ferro::Rfd.const_get(:Native)
    settings = [[], nil, nil, nil, nil, nil]

    MACOS_ONLY.each do |name|
      error = assert_raises(ArgumentError) { native.file_dialog(name, settings) }
      assert_equal "#{name} is not available on this platform", error.message
    end
  end
end
