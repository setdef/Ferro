# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    # SPDX-SnippetComment: UrlQuery and its docs from url 2.5.8
    #   src/lib.rs:3194-3231
    #++

    # Implementation detail of Url#query_pairs_mut. Typically not used
    # directly.
    #
    # A FormUrlencoded::Serializer writes pairs to a target. For a URL's
    # query, the target is this: it holds the Url, and each write changes
    # the URL's query while keeping its fragment after it. There is no
    # public constructor, as url gives none. FormUrlencoded::Serializer#finish
    # returns the Url.
    #
    # Mirrors url's +UrlQuery+ (<tt>src/lib.rs:3194-3231</tt>).
    #
    # === Example
    #
    #   url = Ferro::Url::Url.parse("https://example.net/#top")
    #   url.query_pairs_mut.append_pair("q", "1").finish # => the url, now https://example.net/?q=1#top
    class UrlQuery
      private_class_method :new

      # Holds +url+.
      #
      # [url] Url.
      def initialize(url)
        @url = url
        freeze
      end

      # The Url this target writes to, for the Serializer.
      private attr_reader :url
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
