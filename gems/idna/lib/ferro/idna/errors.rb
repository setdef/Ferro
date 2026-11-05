# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Idna
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    # SPDX-SnippetComment: Errors and its Display text from idna 1.1.0
    #   src/lib.rs:63-84
    #++

    # Indicates that there were errors during UTS #46 processing.
    #
    # A domain fails UTS #46 for many reasons: a character it disallows, a
    # label that breaks the bidi rules, bad Punycode, a hyphen in the wrong
    # place, a name too long for DNS. idna reports none of them apart. It
    # answers only that the domain is not usable.
    #
    # So does this class. Its message is idna's text, <tt>Errors</tt>, and
    # it carries nothing else. The functions that return text even for a
    # bad domain (Idna.domain_to_unicode, Uts46::Uts46#to_unicode) return
    # an instance rather than raising one, beside text that marks each
    # error with U+FFFD.
    #
    # Only what idna returns raises this class. A panic inside idna raises
    # Error, with the message <tt>idna panicked: ...</tt>.
    #
    # Mirrors idna's +Errors+ (<tt>src/lib.rs:63-84</tt>).
    #
    # === Examples
    #
    #   begin
    #     Ferro::Idna.domain_to_ascii_strict("-bad-.example")
    #   rescue Ferro::Idna::Errors => e
    #     e.message # => "Errors"
    #   end
    #
    #   _text, errors = Ferro::Idna.domain_to_unicode("xn--a.example")
    #   errors # => #<Ferro::Idna::Errors: Errors>
    class Errors < StandardError
      # Creates the error. Without a +message+, or with +nil+, the message
      # is idna's.
      #
      # [message] String, the error message.
      #
      # === Example
      #
      #   Ferro::Idna::Errors.new.message # => "Errors"
      def initialize(message = nil)
        super(message || "Errors")
      end

      # idna's +Debug+ text for an +Errors+, <tt>Errors</tt>, which Rust
      # formats. Whatever the message, an +Errors+ is idna's one value.
      # +inspect+ stays Ruby's. Mirrors idna's <tt>#[derive(Debug)]</tt>
      # on +Errors+ (<tt>src/lib.rs:64</tt>).
      #
      # === Example
      #
      #   Ferro::Idna::Errors.new.debug # => "Errors"
      def debug
        Native.errors_debug
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
