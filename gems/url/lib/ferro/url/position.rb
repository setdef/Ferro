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
    # SPDX-SnippetComment: Position, its variants, and its docs from url
    #   2.5.8 src/slicing.rs:64-122
    #++

    # Indicates a position within a URL based on its components.
    #
    # Url's getters return one component each, without its delimiters. To
    # get several at once, such as everything but the fragment, or the
    # authority with its <tt>//</tt>, you would rebuild the string piece by
    # piece and get the delimiters wrong.
    #
    # A range of positions slices the serialization instead, with Url#[]:
    #
    #   url[nil..nil]                                        # the serialization
    #   url[...Position::AfterQuery]                         # without the fragment
    #   url[Position::BeforeUsername...Position::AfterPort]  # the authority
    #   url[Position::BeforePath...Position::AfterQuery]     # a data URL's payload
    #   url[Position::BeforeUsername..]                      # scheme-relative
    #
    # In a pseudo-grammar (where <tt>[ ... ]?</tt> makes a sub-sequence
    # optional), URL components and delimiters that separate them are:
    #
    #   url =
    #       scheme ":"
    #       [ "//" [ username [ ":" password ]? "@" ]? host [ ":" port ]? ]?
    #       path [ "?" query ]? [ "#" fragment ]?
    #
    # When a given component is not present, its "before" and "after"
    # position are the same (so that <tt>url[BeforeFoo...AfterFoo]</tt> is
    # the empty string) and component ordering is preserved (so that a
    # missing query "is between" a path and a fragment).
    #
    # The end of a component and the start of the next are either the same
    # or separated by a delimiter. (Note that the initial <tt>/</tt> of a
    # path is considered part of the path here, not a delimiter.) For
    # example, <tt>url[...BeforeFragment]</tt> would include a <tt>#</tt>
    # delimiter (if present in +url+), so <tt>url[...AfterQuery]</tt> might
    # be desired instead.
    #
    # BeforeScheme and AfterFragment are always the start and end of the
    # entire URL, so <tt>url[BeforeScheme...x]</tt> is the same as
    # <tt>url[...x]</tt> and <tt>url[x...AfterFragment]</tt> is the same as
    # <tt>url[x..]</tt>.
    #
    # Ruby builds a bounded Range only from values that compare, so
    # positions compare in the order url declares them, which is also the
    # order they appear in a URL. url itself derives no ordering.
    #
    # Mirrors url's +Position+ (<tt>src/slicing.rs:64-122</tt>).
    #
    # === Example
    #
    #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
    #   url[Ferro::Url::Position::BeforeUsername...Ferro::Url::Position::AfterPort]
    #   # => "user:pass@example.com:8080"
    class Position
      include Comparable

      private_class_method :new

      # Creates the variant named +name+. The constants are the only
      # instances.
      #
      # [name] Symbol, the url variant's name.
      # [index] Integer, its place in url's declaration.
      def initialize(name, index)
        @name = name
        @index = index
        freeze
      end

      # The constant that holds this position.
      #
      # === Example
      #
      #   Ferro::Url::Position::BeforePath.inspect # => "Ferro::Url::Position::BeforePath"
      def inspect
        "Ferro::Url::Position::#{@name}"
      end

      # Orders positions as url declares them, which is the order they
      # appear in a URL. +nil+ for anything but a Position.
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::Url::Position::BeforeHost < Ferro::Url::Position::AfterHost # => true
      def <=>(other)
        @index <=> other.index if other.is_a?(Position)
      end

      # The position's place in url's declaration.
      protected attr_reader :index

      # The position's name, for the native layer.
      private attr_reader :name

      # The start of the URL.
      BeforeScheme = new(:BeforeScheme, 0)
      # The end of the scheme, before its <tt>:</tt>.
      AfterScheme = new(:AfterScheme, 1)
      # The start of the username, after <tt>//</tt>.
      BeforeUsername = new(:BeforeUsername, 2)
      # The end of the username.
      AfterUsername = new(:AfterUsername, 3)
      # The start of the password, after its <tt>:</tt>.
      BeforePassword = new(:BeforePassword, 4)
      # The end of the password, before <tt>@</tt>.
      AfterPassword = new(:AfterPassword, 5)
      # The start of the host.
      BeforeHost = new(:BeforeHost, 6)
      # The end of the host.
      AfterHost = new(:AfterHost, 7)
      # The start of the port, after its <tt>:</tt>.
      BeforePort = new(:BeforePort, 8)
      # The end of the port.
      AfterPort = new(:AfterPort, 9)
      # The start of the path, its initial <tt>/</tt> included.
      BeforePath = new(:BeforePath, 10)
      # The end of the path.
      AfterPath = new(:AfterPath, 11)
      # The start of the query, after <tt>?</tt>.
      BeforeQuery = new(:BeforeQuery, 12)
      # The end of the query.
      AfterQuery = new(:AfterQuery, 13)
      # The start of the fragment, after <tt>#</tt>.
      BeforeFragment = new(:BeforeFragment, 14)
      # The end of the URL.
      AfterFragment = new(:AfterFragment, 15)
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
