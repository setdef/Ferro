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
    # SPDX-SnippetComment: ParseOptions, its methods, and their docs from
    #   url 2.5.8 src/lib.rs:252-316 and :607-632
    #++

    # Full configuration for the URL parser.
    #
    # Url.parse takes a string and nothing else. Parsing a link against
    # the page it came from, encoding a form's query in a legacy encoding,
    # or collecting the mistakes url forgave each needs one more setting.
    #
    # Start from Url.options, chain the settings you need, and call #parse.
    # A ParseOptions is a frozen value, as url's is +Copy+: each setter
    # returns a new one and leaves the receiver as it was, so one set of
    # options can serve many parses.
    #
    # Mirrors url's +ParseOptions+ (<tt>src/lib.rs:252-316</tt>).
    #
    # === Examples
    #
    #   api = Ferro::Url::Url.parse("https://api.example.com")
    #   options = Ferro::Url::Url.options.base_url(api)
    #   options.parse("version.json").as_str # => "https://api.example.com/version.json"
    #
    #   violations = []
    #   Ferro::Url::Url.options
    #     .syntax_violation_callback(->(violation) { violations << violation })
    #     .parse("https:////example.com")
    #   violations # => [Ferro::Url::SyntaxViolation::ExpectedDoubleSlash]
    class ParseOptions
      private_class_method :new

      # The options with no base URL, no encoding override, and no syntax
      # violation callback, as Url.options returns them.
      #
      # [base_url] Url or +nil+.
      # [encoding_override] Callable or +nil+.
      # [violation_fn] Callable or +nil+.
      def initialize(base_url, encoding_override, violation_fn)
        @base_url = base_url
        @encoding_override = encoding_override
        @violation_fn = violation_fn
        freeze
      end

      # Changes the base URL. See the notes of Url#join for more details
      # about how this base is considered when parsing. Mirrors url's
      # <tt>ParseOptions::base_url</tt> (<tt>src/lib.rs:262-269</tt>).
      #
      # [new] Url, or +nil+ for none.
      #
      # === Example
      #
      #   Ferro::Url::Url.options.base_url(Ferro::Url::Url.parse("https://example.net/a/"))
      def base_url(new)
        raise TypeError, "wrong argument type #{new.class} (expected #{Url})" unless new.nil? || new.is_a?(Url)

        self.class.__send__(:new, new, @encoding_override, @violation_fn)
      end

      # Overrides the character encoding of query strings. This is a legacy
      # concept only relevant for HTML.
      #
      # +new+ is any object that responds to +call+: url calls it with each
      # query string as UTF-8 text and percent-encodes the bytes of the
      # String it returns. It runs inside the parse; an exception it raises
      # stops later calls (url then encodes UTF-8) and is raised once url
      # returns. Mirrors url's <tt>ParseOptions::encoding_override</tt>
      # (<tt>src/lib.rs:271-276</tt>).
      #
      # [new] Callable from a String to a String, or +nil+ for UTF-8.
      #
      # === Example
      #
      #   latin1 = ->(text) { text.encode("ISO-8859-1").b }
      #   Ferro::Url::Url.options.encoding_override(latin1).parse("http://example.com/?q=é").query # => "q=%E9"
      def encoding_override(new)
        self.class.__send__(:new, @base_url, callable(new), @violation_fn)
      end

      # Calls +new+ for each non-fatal SyntaxViolation that occurs during
      # parsing, with the violation.
      #
      # It runs inside the parse, as #encoding_override's callable does. url
      # takes an +Fn+, which may not change its own state, so a Rust caller
      # collects violations through a +RefCell+; a Ruby callable may simply
      # push to an Array it closes over. Mirrors url's
      # <tt>ParseOptions::syntax_violation_callback</tt>
      # (<tt>src/lib.rs:278-303</tt>).
      #
      # [new] Callable taking a SyntaxViolation, or +nil+ for none.
      #
      # === Example
      #
      #   violations = []
      #   url = Ferro::Url::Url.options
      #     .syntax_violation_callback(->(violation) { violations << violation })
      #     .parse("https:////example.com")
      #   url.as_str # => "https://example.com/"
      #   violations # => [Ferro::Url::SyntaxViolation::ExpectedDoubleSlash]
      def syntax_violation_callback(new)
        self.class.__send__(:new, @base_url, @encoding_override, callable(new))
      end

      # Parses a URL string with the configuration so far, raising
      # ParseError when it fails. The base URL is copied first, so a
      # callback that changes it cannot change the parse under way. Mirrors
      # url's <tt>ParseOptions::parse</tt> (<tt>src/lib.rs:305-315</tt>).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Url::Url.options.parse("https://example.net").as_str # => "https://example.net/"
      def parse(input)
        base = @base_url
        Arguments.url(Native.url_options_parse(input, base && Arguments.native(base), encoder, reporter))
      end

      # +new+, a callable or +nil+; anything else raises +TypeError+.
      private def callable(new)
        raise TypeError, "#{new.class} does not respond to call" unless new.nil? || new.respond_to?(:call)

        new
      end

      # The callable the native layer calls for the encoding override:
      # text in, the bytes of the user's String out.
      private def encoder
        encoding = @encoding_override
        return unless encoding

        -> (text) { Arguments.encoded(encoding.method(:call).call(text)) }
      end

      # The callable the native layer calls for a violation, by variant
      # name.
      private def reporter
        report = @violation_fn
        return unless report

        -> (name) { report.method(:call).call(SyntaxViolation.const_get(name, false)) }
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
