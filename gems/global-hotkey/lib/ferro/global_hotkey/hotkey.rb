# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

module Ferro
  module GlobalHotkey
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
    # SPDX-SnippetComment: the hotkey module's docs and CMD_OR_CTRL from
    #   global-hotkey 0.9.0 src/hotkey.rs:5-36
    #++

    # Hotkeys describe keyboard global shortcuts.
    #
    # A shortcut is a combination: zero or more modifier keys held down,
    # then one key. Writing that as raw key codes ties you to one platform,
    # and writing it as text needs a parser that agrees with every other
    # program's idea of "Shift+Alt+Q".
    #
    # A HotKey holds an optional combination of modifier keys (Modifiers)
    # and one key (Code). Build one directly, or parse one from text, where
    # all modifiers have to be listed before the non-modifier key:
    # <tt>shift+alt+KeyQ</tt> is legal, whereas <tt>shift+q+alt</tt> is
    # not.
    #
    # This module mirrors global-hotkey's +hotkey+ module
    # (<tt>src/hotkey.rs</tt>). Code and Modifiers are keyboard-types'
    # types, which global-hotkey re-exports here.
    #
    # === Examples
    #
    #   hotkey = Ferro::GlobalHotkey::Hotkey
    #   hotkey::HotKey.new(hotkey::Modifiers::SHIFT, hotkey::Code::KeyQ)
    #   hotkey::HotKey.new(nil, hotkey::Code::KeyQ)
    #   hotkey::HotKey.from_str("shift+alt+KeyQ")
    #   hotkey::HotKey.from_str("shift+KeyQ+alt") # raises HotKeyParseError::InvalidFormat
    module Hotkey
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end

require_relative "hotkey/hot_key_parse_error"
require_relative "hotkey/modifiers"
require_relative "hotkey/code"
require_relative "hotkey/hot_key"

module Ferro
  module GlobalHotkey
    module Hotkey
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: Apache-2.0 OR MIT
      # SPDX-SnippetCopyrightText: 2022-2022 Tauri Programme within The Commons Conservancy
      # SPDX-SnippetComment: CMD_OR_CTRL from global-hotkey 0.9.0
      #   src/hotkey.rs:33-36
      #++

      # The modifier a shortcut uses for "Command on a Mac, Control
      # elsewhere": Modifiers::META on macOS, Modifiers::CONTROL on Windows
      # and Linux. <tt>CmdOrCtrl</tt> in a parsed hotkey means the same.
      # Mirrors global-hotkey's +CMD_OR_CTRL+ (<tt>src/hotkey.rs:33-36</tt>).
      CMD_OR_CTRL = Modifiers.from_bits_retain(Native.cmd_or_ctrl)

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
