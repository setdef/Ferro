# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: ServerInformation and its field docs from
    #   notify-rust 4.18.2 src/lib.rs:235-246
    #++

    # Who is showing your notifications: the server's name, vendor,
    # version, and the specification version it follows.
    #
    # Notification servers differ in what they draw and which hints they
    # honor. Knowing which one runs helps you explain an odd result, or
    # work around a server you know.
    #
    # NotifyRust.get_server_information (Linux) returns one. notify-rust
    # defines the type on every platform.
    #
    # Mirrors notify-rust's +ServerInformation+ (<tt>src/lib.rs:235-246</tt>).
    #
    # === Example
    #
    #   info = Ferro::NotifyRust.get_server_information
    #   puts "#{info.name} #{info.version} by #{info.vendor}, spec #{info.spec_version}"
    class ServerInformation < Data.define(:name, :vendor, :version, :spec_version)
      ##
      # :attr_reader: name
      # The product name of the server, a String.

      ##
      # :attr_reader: vendor
      # The vendor name, a String.

      ##
      # :attr_reader: version
      # The server's version string.

      ##
      # :attr_reader: spec_version
      # The specification version the server is compliant with, a String.
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
