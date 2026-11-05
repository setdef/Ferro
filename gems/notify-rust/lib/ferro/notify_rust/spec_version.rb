# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "linux"

# notify-rust compiles SPEC_VERSION only for its XDG platforms, and
# linux.rb autoloads this file only there.
return unless Ferro::NotifyRust.const_get(:PLATFORM) == :linux

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: SPEC_VERSION and its documentation from
    #   notify-rust 4.18.2 src/lib.rs:226-233
    #++

    major, minor = Native.spec_version

    # The notification specification version the running server speaks,
    # a Version, read once per process. notify-rust reads it the first
    # time it sends an image hint, to choose the hint's name, or the first
    # time this constant is named, whichever comes first: it asks the
    # server through get_server_information, with Ruby's global VM lock
    # released, and falls back to 1.1 when there is no server or its
    # answer does not parse. It is notify-rust's own value, the one its
    # image hints use, so it can differ from
    # <tt>get_server_information.spec_version</tt> when that call failed.
    # Defined only on Linux.
    #
    # Mirrors notify-rust's +SPEC_VERSION+ (<tt>src/lib.rs:226-233</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust::SPEC_VERSION # => #<data Ferro::NotifyRust::Version major=1, minor=2>
    SPEC_VERSION = Version.__send__(:new, major, minor)

    #--
    # SPDX-SnippetEnd
    #++
  end
end
