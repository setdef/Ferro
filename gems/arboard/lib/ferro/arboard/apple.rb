# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"
require_relative "set"

# arboard compiles this only for macOS (src/lib.rs:33-34), and the native
# extension reports which platform it was built for.
return unless Ferro::Arboard.const_get(:PLATFORM) == :macos

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: SetExtApple and its docs from arboard 3.7.0
    #   src/platform/osx.rs:410-438
    #++

    # macOS options for a Set.
    #
    # Clipboard history apps record everything you copy, including
    # passwords and one-time codes. macOS has no official way to opt out,
    # but those apps honor a community convention.
    #
    # This module adds that opt-out to Set on macOS alone, so
    # <tt>respond_to?(:exclude_from_history)</tt> tells you whether you
    # have it here.
    #
    # Mirrors arboard's +SetExtApple+ (<tt>src/platform/osx.rs:424-438</tt>).
    #
    # === Example
    #
    #   clipboard.set.exclude_from_history.text(password)
    module SetExtApple
      # Keeps the contents out of third-party clipboard history apps.
      # Returns the Set.
      #
      # arboard marks the contents with the
      # <tt>org.nspasteboard.ConcealedType</tt> type, as the community
      # standard at http://nspasteboard.org/ describes.
      #
      # === Example
      #
      #   clipboard.set.exclude_from_history.text(password)
      def exclude_from_history
        @exclude_from_history = true
        self
      end
    end

    class Set
      include SetExtApple
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
