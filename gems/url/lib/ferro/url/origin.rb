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
    # SPDX-SnippetComment: Origin, its variants, their docs, and its
    #   methods from url 2.5.8 src/origin.rs:38-111
    #++

    # The origin of an URL.
    #
    # Two URLs with the same origin are considered to originate from the
    # same entity and can therefore trust each other.
    #
    # The origin is determined based on the scheme as follows:
    #
    # - If the scheme is +blob+ the origin is the origin of the URL
    #   contained in the path component. If parsing fails, it is an opaque
    #   origin.
    # - If the scheme is +ftp+, +http+, +https+, +ws+, or +wss+, then the
    #   origin is a tuple of the scheme, host, and port.
    # - If the scheme is anything else, the origin is opaque, meaning the
    #   URL does not have the same origin as any other URL.
    #
    # For more information see https://url.spec.whatwg.org/#origin.
    #
    # Url#origin returns one of the two variants, each a value class that
    # includes this module. Origins compare by value, as url derives +Eq+
    # and +Hash+.
    #
    # Mirrors url's +Origin+ (<tt>src/origin.rs:38-111</tt>).
    #
    # === Examples
    #
    #   url = Ferro::Url::Url.parse("https://example.com:8443/index.html")
    #   url.origin.ascii_serialization # => "https://example.com:8443"
    #
    #   Ferro::Url::Url.parse("file:///tmp/foo").origin.is_tuple # => false
    module Origin
      # Creates a new opaque origin that is only equal to itself. Mirrors
      # url's <tt>Origin::new_opaque</tt> (<tt>src/origin.rs:65-69</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Origin.new_opaque.is_tuple # => false
      def self.new_opaque
        Arguments.origin(Native.origin_new_opaque)
      end

      # Whether this origin is a (scheme, host, port) tuple (as opposed to
      # an opaque origin). Mirrors url's <tt>Origin::is_tuple</tt>
      # (<tt>src/origin.rs:71-75</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://example.com").origin.is_tuple # => true
      def is_tuple
        is_a?(Tuple)
      end

      # The ASCII serialization of an origin
      # (https://html.spec.whatwg.org/multipage/#ascii-serialisation-of-an-origin):
      # <tt>null</tt> for an opaque origin, and the port only when it is not
      # the scheme's default. Mirrors url's
      # <tt>Origin::ascii_serialization</tt> (<tt>src/origin.rs:77-89</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://Bücher.example/").origin.ascii_serialization
      #   # => "https://xn--bcher-kva.example"
      def ascii_serialization
        Native.origin_ascii_serialization(Arguments.origin_parts(self))
      end

      # The Unicode serialization of an origin
      # (https://html.spec.whatwg.org/multipage/#unicode-serialisation-of-an-origin):
      # as #ascii_serialization, with the domain turned back into Unicode.
      # Mirrors url's <tt>Origin::unicode_serialization</tt>
      # (<tt>src/origin.rs:91-110</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://Bücher.example/").origin.unicode_serialization
      #   # => "https://bücher.example"
      def unicode_serialization
        Native.origin_unicode_serialization(Arguments.origin_parts(self))
      end

      # A globally unique identifier.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("data:text/plain,hi").origin # => #<data Ferro::Url::Origin::Opaque value=OpaqueOrigin(0)>
      class Opaque < Data.define(:value)
        include Origin

        ##
        # :attr_reader: value
        # The OpaqueOrigin.
      end

      # Consists of the URL's scheme, host and port.
      #
      # === Example
      #
      #   Ferro::Url::Origin::Tuple.new("https", Ferro::Url::Host::Domain.new("example.com"), 443)
      #     .ascii_serialization # => "https://example.com"
      class Tuple < Data.define(:scheme, :host, :port)
        include Origin

        ##
        # :attr_reader: scheme
        # The scheme, a String.

        ##
        # :attr_reader: host
        # The Host.

        ##
        # :attr_reader: port
        # The port, an Integer: the scheme's default when the URL names
        # none.
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
