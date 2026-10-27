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
    # SPDX-SnippetComment: SyntaxViolation, its variants, and their
    #   descriptions from url 2.5.8 src/parser.rs:107-157
    #++

    # Non-fatal syntax violations that can occur during parsing.
    #
    # The URL Standard forgives a lot: a backslash for a slash, a missing
    # pair of slashes, a stray tab. url fixes each and parses on, so the
    # result never says what it forgave. A linter, or a form that wants to
    # warn its user, needs to know.
    #
    # Pass a callable to ParseOptions#syntax_violation_callback and url
    # calls it with one of these constants for each violation it forgives.
    # url may add variants in the future. Each compares by identity, as url
    # derives +PartialEq+, and has url's #description.
    #
    # Mirrors url's +SyntaxViolation+ (<tt>src/parser.rs:107-157</tt>).
    #
    # === Example
    #
    #   violations = []
    #   url = Ferro::Url::Url.options
    #     .syntax_violation_callback(->(violation) { violations << violation })
    #     .parse("https:////example.com")
    #   url.as_str # => "https://example.com/"
    #   violations # => [Ferro::Url::SyntaxViolation::ExpectedDoubleSlash]
    class SyntaxViolation
      private_class_method :new

      # Creates the variant named +name+. The constants are the only
      # instances.
      #
      # [name] Symbol, the url variant's name.
      def initialize(name)
        @name = name
        @description = Native.syntax_violation_description(name)
        freeze
      end

      # What the violation is, in url's words. Mirrors
      # <tt>SyntaxViolation::description</tt> (<tt>src/parser.rs:124-132</tt>).
      #
      # === Example
      #
      #   Ferro::Url::SyntaxViolation::Backslash.description # => "backslash"
      attr_reader :description

      # The same as #description, as url's +Display+ is
      # (<tt>src/parser.rs:153-157</tt>).
      #
      # === Example
      #
      #   Ferro::Url::SyntaxViolation::ExpectedDoubleSlash.to_s # => "expected //"
      def to_s
        @description
      end

      # The constant that holds this variant.
      #
      # === Example
      #
      #   Ferro::Url::SyntaxViolation::Backslash.inspect # => "Ferro::Url::SyntaxViolation::Backslash"
      def inspect
        "Ferro::Url::SyntaxViolation::#{@name}"
      end

      # backslash
      Backslash = new(:Backslash)

      # leading or trailing control or space character are ignored in URLs
      C0SpaceIgnored = new(:C0SpaceIgnored)

      # embedding authentication information (username or password) in an
      # URL is not recommended
      EmbeddedCredentials = new(:EmbeddedCredentials)

      # expected //
      ExpectedDoubleSlash = new(:ExpectedDoubleSlash)

      # expected // after file:
      ExpectedFileDoubleSlash = new(:ExpectedFileDoubleSlash)

      # file: with host and Windows drive letter
      FileWithHostAndWindowsDrive = new(:FileWithHostAndWindowsDrive)

      # non-URL code point
      NonUrlCodePoint = new(:NonUrlCodePoint)

      # NULL characters are ignored in URL fragment identifiers
      NullInFragment = new(:NullInFragment)

      # expected 2 hex digits after %
      PercentDecode = new(:PercentDecode)

      # tabs or newlines are ignored in URLs
      TabOrNewlineIgnored = new(:TabOrNewlineIgnored)

      # unencoded @ sign in username or password
      UnencodedAtSign = new(:UnencodedAtSign)
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
