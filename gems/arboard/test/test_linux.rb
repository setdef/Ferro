# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Linux values arboard compiles, and a clipboard with no display server
# at all, which opens nothing. desktop/test_linux.rb has the selection and
# wait tests ported from arboard.
class TestLinux < Minitest::Test
  include ClipboardSuite

  def setup
    skip_unless_platform(:linux)
  end

  private def kinds
    Ferro::Arboard::LinuxClipboardKind
  end

  # With no display server, arboard's X11 connection fails with an Unknown
  # error (src/platform/linux/x11.rs:139-145). A subprocess without
  # WAYLAND_DISPLAY or DISPLAY opens the clipboard, so the suite's own keeps
  # its display.
  def test_no_display_server_raises_unknown
    lib = File.expand_path("../lib", __dir__)
    script = <<~RUBY
      require "ferro/arboard"
      begin
        Ferro::Arboard::Clipboard.new
      rescue Ferro::Arboard::Error::Unknown => e
        puts e.description, e.message
      end
    RUBY
    output = IO.popen({ "WAYLAND_DISPLAY" => nil, "DISPLAY" => nil }, [RbConfig.ruby, "-I", lib, "-e", script], &:read)

    description = "X11 server connection timed out because it was unreachable"
    assert_equal [description, "Unknown error while interacting with the clipboard: #{description}"],
      output.lines(chomp: true)
  end

  def test_the_kinds_are_three_frozen_values
    refute_respond_to kinds::Primary, :to_sym, "arboard's enum has no such method"
    assert Ractor.shareable?(kinds::Primary)
    assert_raises(NoMethodError) { kinds.new(:Tertiary) }
  end

  # LinuxClipboardKind derives Debug (src/platform/linux/mod.rs:104), which
  # Rust formats; inspect stays Ruby's (doc/contributors/design/translation.md).
  def test_the_kinds_debug_as_arboards_variants
    assert_equal %w[Clipboard Primary Secondary], [kinds::Clipboard, kinds::Primary, kinds::Secondary].map(&:debug)
    assert_match(/\A#<Ferro::Arboard::LinuxClipboardKind[ :]/, kinds::Primary.inspect)
    refute_equal "Ferro::Arboard::LinuxClipboardKind::Primary", kinds::Primary.inspect
  end
end
