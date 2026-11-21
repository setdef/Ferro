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

  def test_the_platform_constant_is_private
    assert_raises(NameError) { Ferro::Arboard::PLATFORM }
    assert_includes %i[linux macos windows], PLATFORM
  end
end
