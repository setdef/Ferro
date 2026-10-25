# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"
require_relative "error"

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: Clear's method and its docs from arboard 3.7.0
    #   src/lib.rs:266-278
    #++

    # A clear of the clipboard, waiting for you to say which clipboard.
    #
    # Clipboard#clear empties the platform's default clipboard. On Linux
    # you may want to empty another selection instead, and a separate
    # method for each would clutter Clipboard.
    #
    # So Clipboard#clear_with returns this builder. Finish it with
    # #default, or on Linux with ClearExtLinux#clipboard.
    #
    # Mirrors arboard's +Clear+ (<tt>src/lib.rs:266-278</tt>).
    #
    # === Examples
    #
    #   clipboard = Ferro::Arboard::Clipboard.new
    #   clipboard.clear_with.default
    #
    #   # On Linux, empty the middle-click selection.
    #   clipboard.clear_with.clipboard(Ferro::Arboard::LinuxClipboardKind::Primary)
    class Clear
      private_class_method :new

      # Creates a clear of +clipboard+. Use Clipboard#clear_with.
      #
      # [clipboard] Clipboard, the clipboard to clear.
      def initialize(clipboard)
        @clipboard = clipboard
      end

      # Removes whatever the default clipboard holds, in any format.
      #
      # Mirrors arboard's <tt>Clear::default</tt>
      # (<tt>src/lib.rs:272-277</tt>).
      #
      # === Example
      #
      #   clipboard.clear_with.default
      def default
        @clipboard.__send__(:native_clear, nil)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
