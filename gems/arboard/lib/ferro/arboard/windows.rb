# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"
require_relative "set"

# arboard compiles this only for Windows (src/lib.rs:30-31), and the native
# extension reports which platform it was built for.
return unless Ferro::Arboard.const_get(:PLATFORM) == :windows

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: SetExtWindows and its docs from arboard 3.7.0
    #   src/platform/windows.rs:845-880
    #++

    # Windows options for a Set.
    #
    # Windows keeps a clipboard history, and can sync the clipboard to
    # your other devices through the cloud. A password or one-time code
    # should go to neither.
    #
    # This module adds those opt-outs to Set on Windows alone. Each
    # returns the Set for chaining.
    #
    # Mirrors arboard's +SetExtWindows+
    # (<tt>src/platform/windows.rs:845-880</tt>).
    #
    # === Example
    #
    #   clipboard.set.exclude_from_cloud.exclude_from_history.text(password)
    module SetExtWindows
      # Keeps the contents from being processed at all: neither the local
      # clipboard history nor the cloud clipboard sees them. Returns the
      # Set.
      #
      # With this set, #exclude_from_cloud and #exclude_from_history are
      # not recommended.
      #
      # === Example
      #
      #   clipboard.set.exclude_from_monitoring.text(password)
      def exclude_from_monitoring
        @exclude_from_monitoring = true
        self
      end

      # Keeps the contents from being uploaded to the Windows 10 and 11
      # cloud clipboard
      # (https://support.microsoft.com/en-us/windows/clipboard-in-windows-c436501e-985d-1c8d-97ea-fe46ddf338c6).
      # Returns the Set.
      #
      # === Example
      #
      #   clipboard.set.exclude_from_cloud.text(password)
      def exclude_from_cloud
        @exclude_from_cloud = true
        self
      end

      # Keeps the contents out of the system's clipboard history list
      # (https://support.microsoft.com/en-us/windows/get-help-with-clipboard-30375039-ce71-9fe4-5b30-21b7aab6b13f).
      # Returns the Set.
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
      include SetExtWindows
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
