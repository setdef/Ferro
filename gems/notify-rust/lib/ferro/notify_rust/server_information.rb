# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: ServerInformation and its field docs from
    #   notify-rust 4.18.2 src/lib.rs:235-246, src/xdg/mod.rs:549-562
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
    # Mirrors notify-rust's +ServerInformation+ (<tt>src/lib.rs:235-246</tt>),
    # and on Linux the private copy get_server_information returns
    # (<tt>src/xdg/mod.rs:549-562</tt>), which has the same fields.
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

      # notify-rust's derived +Debug+ text (<tt>src/lib.rs:236</tt>),
      # formatted by Rust from the four fields. +inspect+ stays Data's.
      # Raises +TypeError+ for a field that is no String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::ServerInformation.new(name: "dunst", vendor: "knopwob", version: "1.12", spec_version: "1.2").debug
      #   # => "ServerInformation { name: \"dunst\", vendor: \"knopwob\", version: \"1.12\", spec_version: \"1.2\" }"
      def debug
        Native.server_information_debug(name, vendor, version, spec_version)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
