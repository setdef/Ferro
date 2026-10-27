# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    module Quirks
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
      # SPDX-SnippetComment: InternalComponents and its docs from url 2.5.8
      #   src/quirks.rs:19-42
      #++

      # Internal components / offsets of a URL.
      #
      #   https://user@pass:example.com:1234/foo/bar?baz#quux
      #        |      |    |          | ^^^^|       |   |
      #        |      |    |          | |   |       |   `----- fragment_start
      #        |      |    |          | |   |       `--------- query_start
      #        |      |    |          | |   `----------------- path_start
      #        |      |    |          | `--------------------- port
      #        |      |    |          `----------------------- host_end
      #        |      |    `---------------------------------- host_start
      #        |      `--------------------------------------- username_end
      #        `---------------------------------------------- scheme_end
      #
      # Its fields are public in url, so this is a Data; Quirks.internal_components
      # makes one from a Url. The offsets are bytes of Url#as_str.
      #
      # Mirrors url's <tt>quirks::InternalComponents</tt>
      # (<tt>src/quirks.rs:19-42</tt>).
      #
      # === Example
      #
      #   parts = Ferro::Url::Quirks.internal_components(Ferro::Url::Url.parse("https://example.com:8080/?q"))
      #   parts.port # => 8080
      #   parts.query_start # => 25
      class InternalComponents < Data.define(:scheme_end, :username_end, :host_start, :host_end, :port, :path_start,
        :query_start, :fragment_start)
        ##
        # :attr_reader: scheme_end
        # The offset of the scheme's end, before its <tt>:</tt>, an Integer.

        ##
        # :attr_reader: username_end
        # The offset of the username's end, an Integer.

        ##
        # :attr_reader: host_start
        # The offset of the host's start, an Integer.

        ##
        # :attr_reader: host_end
        # The offset of the host's end, an Integer.

        ##
        # :attr_reader: port
        # The port, an Integer, or +nil+.

        ##
        # :attr_reader: path_start
        # The offset of the path's start, an Integer.

        ##
        # :attr_reader: query_start
        # The offset of the query's <tt>?</tt>, an Integer, or +nil+.

        ##
        # :attr_reader: fragment_start
        # The offset of the fragment's <tt>#</tt>, an Integer, or +nil+.
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
