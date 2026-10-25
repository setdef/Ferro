# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ferro/arboard"
require "minitest/autorun"
require "rbconfig"

# These tests drive the real system clipboard, so they overwrite whatever
# you had copied. The helper saves its text before the suite and puts it
# back after; anything other than text (an image, a file list) is lost.
module ClipboardSuite
  # The platform the extension was built for, as arboard's cfg decides it.
  PLATFORM = Ferro::Arboard.const_get(:PLATFORM)

  SAVED_TEXT = begin
    Ferro::Arboard::Clipboard.new.get_text
  rescue Ferro::Arboard::Error
    nil
  end

  Minitest.after_run do
    clipboard = Ferro::Arboard::Clipboard.new
    SAVED_TEXT ? clipboard.set_text(SAVED_TEXT) : clipboard.clear
  end

  # The messages arboard 3.7.0 displays (src/common.rs:58-62).
  NOT_AVAILABLE = "The clipboard contents were not available in the requested format or the clipboard is empty."
  NOT_SUPPORTED = "The selected clipboard is not supported with the current system configuration."
  OCCUPIED = "The native clipboard is not accessible due to being held by another party."
  CONVERSION_FAILURE = "The image or the text that was about the be transferred to/from the clipboard could not " \
    "be converted to the appropriate format."

  private def clipboard
    @clipboard ||= Ferro::Arboard::Clipboard.new
  end

  private def skip_unless_platform(platform)
    skip "#{platform} only; this extension was built for #{PLATFORM}" unless PLATFORM == platform
  end

  # +path+ as arboard returns it from a file list. On Windows that is the
  # path Windows resolves, with backslashes (src/platform/windows.rs:923-952),
  # where Ruby writes forward slashes.
  private def native_path(path)
    (PLATFORM == :windows) ? path.tr("/", "\\") : path
  end

  # Reading an empty clipboard either raises ContentNotAvailable or reads
  # back empty text, depending on the platform (arboard src/lib.rs:323-327).
  private def assert_no_text
    text = clipboard.get_text
    assert_empty text
  rescue Ferro::Arboard::Error::ContentNotAvailable => e
    assert_equal NOT_AVAILABLE, e.message
  end
end
