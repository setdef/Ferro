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
    # SPDX-SnippetCopyrightText: 2013-2016 The rust-url developers
    # SPDX-SnippetComment: the form_urlencoded crate's docs and functions
    #   from form_urlencoded 1.2.2 src/lib.rs:9-172
    #++

    # Parser and serializer for the
    # <tt>application/x-www-form-urlencoded</tt> syntax
    # (http://url.spec.whatwg.org/#application/x-www-form-urlencoded), as
    # used by HTML forms.
    #
    # Converts between a string (such as an URL's query string) and a
    # sequence of (name, value) pairs. Ruby's +URI.encode_www_form+ is
    # close, but its rules are not the URL Standard's: which bytes it
    # leaves alone, and how it decodes bad percent escapes, differ.
    #
    # url re-exports the form_urlencoded crate whole, as
    # <tt>url::form_urlencoded</tt>, so this module is that crate's API.
    #
    # Mirrors form_urlencoded 1.2.2 (<tt>src/lib.rs</tt>).
    #
    # === Examples
    #
    #   Ferro::Url::FormUrlencoded.parse("%23first=%25try%25").to_a # => [["#first", "%try%"]]
    #
    #   Ferro::Url::FormUrlencoded::Serializer.new(+"")
    #     .append_pair("foo", "bar & baz")
    #     .append_pair("saison", "Été+hiver")
    #     .finish # => "foo=bar+%26+baz&saison=%C3%89t%C3%A9%2Bhiver"
    module FormUrlencoded
      # Converts a byte string in the
      # <tt>application/x-www-form-urlencoded</tt> syntax into an Enumerator
      # of <tt>[name, value]</tt> pairs.
      #
      # The names and values are percent-decoded, with <tt>+</tt> as a
      # space, and bytes that are not UTF-8 become U+FFFD. For instance,
      # <tt>%23first=%25try%25</tt> will be converted to
      # <tt>[["#first", "%try%"]]</tt>. Rust's +into_owned+ has no Ruby
      # meaning: the Strings are already the caller's. Mirrors
      # form_urlencoded's +parse+ (<tt>src/lib.rs:31-115</tt>).
      #
      # [input] String, taken as bytes whatever its encoding.
      #
      # === Example
      #
      #   Ferro::Url::FormUrlencoded.parse("a=1&b=two+words").to_a # => [["a", "1"], ["b", "two words"]]
      def self.parse(input)
        Native.form_parse(input).each
      end

      # The <tt>application/x-www-form-urlencoded</tt> byte serializer
      # (https://url.spec.whatwg.org/#concept-urlencoded-byte-serializer):
      # an Enumerator of String slices, which join into the encoding.
      # Mirrors form_urlencoded's +byte_serialize+
      # (<tt>src/lib.rs:117-172</tt>).
      #
      # [input] String, taken as bytes whatever its encoding.
      #
      # === Example
      #
      #   Ferro::Url::FormUrlencoded.byte_serialize("bar & baz").to_a.join # => "bar+%26+baz"
      def self.byte_serialize(input)
        Native.form_byte_serialize(input).each
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end

require_relative "form_urlencoded/serializer"
