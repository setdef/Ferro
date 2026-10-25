# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# Each platform extension exists only where arboard compiles it
# (src/lib.rs:24-34), so defined? and respond_to? answer truthfully.
class TestPlatform < Minitest::Test
  include ClipboardSuite

  EXTENSIONS = {
    linux: %i[LinuxClipboardKind GetExtLinux SetExtLinux ClearExtLinux],
    macos: %i[SetExtApple],
    windows: %i[SetExtWindows],
  }.freeze

  LINUX_SET = %i[wait wait_until wait_once clipboard exclude_from_history].freeze
  WINDOWS_SET = %i[exclude_from_monitoring exclude_from_cloud exclude_from_history].freeze

  METHODS = {
    linux: { Get: %i[clipboard], Set: LINUX_SET, Clear: %i[clipboard] },
    macos: { Set: %i[exclude_from_history] },
    windows: { Set: WINDOWS_SET },
  }.freeze

  def test_only_this_platforms_extensions_are_defined
    EXTENSIONS.each do |platform, names|
      names.each do |name|
        assert_equal platform == PLATFORM, Ferro::Arboard.const_defined?(name, false), "#{name} on #{PLATFORM}"
      end
    end
  end

  def test_the_builders_include_this_platforms_extensions
    { Get: :GetExtLinux, Set: :SetExtLinux, Clear: :ClearExtLinux }.each do |builder, extension|
      next unless Ferro::Arboard.const_defined?(extension, false)

      assert_includes Ferro::Arboard.const_get(builder).ancestors, Ferro::Arboard.const_get(extension)
    end
    %i[SetExtApple SetExtWindows].each do |extension|
      next unless Ferro::Arboard.const_defined?(extension, false)

      assert_includes Ferro::Arboard::Set.ancestors, Ferro::Arboard.const_get(extension)
    end
  end

  def test_the_builders_answer_only_this_platforms_methods
    builders = { Get: clipboard.get, Set: clipboard.set, Clear: clipboard.clear_with }
    METHODS.each do |platform, by_builder|
      by_builder.each do |builder, names|
        names.each do |name|
          # exclude_from_history exists on all three platforms.
          expected = platform == PLATFORM || (name == :exclude_from_history && builder == :Set)
          assert_equal expected, builders.fetch(builder).respond_to?(name), "#{builder}##{name} on #{PLATFORM}"
        end
      end
    end
  end

  # The native layer refuses a setting this platform's arboard lacks, so a
  # call that bypasses the builders cannot be silently ignored.
  def test_the_native_layer_refuses_another_platforms_settings
    off_linux = PLATFORM != :linux
    off_windows = PLATFORM != :windows
    set_with = -> (options) { -> { clipboard.__send__(:native_set_text, "x", options) } }
    cases = {
      "clipboard" => [off_linux, -> { clipboard.__send__(:native_get_text, :Primary) }],
      "wait" => [off_linux, set_with.call([nil, :forever, false, false, false])],
      "exclude_from_monitoring" => [off_windows, set_with.call([nil, nil, false, true, false])],
      "exclude_from_cloud" => [off_windows, set_with.call([nil, nil, false, false, true])],
    }
    cases.each do |setting, (refused, call)|
      next unless refused

      error = assert_raises(ArgumentError, setting, &call)
      assert_equal "#{setting} is not available on this platform", error.message
    end
  end

  def test_the_platform_constant_is_private
    assert_raises(NameError) { Ferro::Arboard::PLATFORM }
    assert_includes %i[linux macos windows], PLATFORM
  end
end
