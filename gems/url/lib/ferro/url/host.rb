# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ipaddr"
require "socket"

module Ferro
  module Url
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    # SPDX-SnippetComment: Host, its variants, their docs, and its methods
    #   from url 2.5.8 src/host.rs:43-212
    #++

    # The host name of an URL.
    #
    # A host is a domain, an IPv4 address, or an IPv6 address, and each
    # has its own rules: a domain goes through IDNA, an address through
    # its own parser and canonical form. A String would lose which one url
    # found.
    #
    # Url#host returns one of the three variants, each a value class that
    # includes this module. Hosts compare by value, as url derives +Eq+,
    # +Ord+, and +Hash+: by variant (Domain, then Ipv4, then Ipv6), then by
    # value. #to_s is url's +Display+: an IPv6 address comes in brackets.
    #
    # Mirrors url's +Host+ (<tt>src/host.rs:43-212</tt>).
    #
    # === Examples
    #
    #   Ferro::Url::Url.parse("https://github.com/rust-lang").host
    #   # => #<data Ferro::Url::Host::Domain domain="github.com">
    #
    #   Ferro::Url::Host.parse("[::1]").to_s # => "[::1]"
    #   Ferro::Url::Host.parse("127.0.0.1").address # => #<IPAddr: IPv4:127.0.0.1/255.255.255.255>
    module Host
      include Comparable

      # Parses a host: either an IPv6 address in <tt>[]</tt> square
      # brackets, or a domain, which may turn out to be an IPv4 address. A
      # host that does not parse raises ParseError. Mirrors url's
      # <tt>Host::parse</tt> (<tt>src/host.rs:78-83</tt>), the URL
      # Standard's host parser (https://url.spec.whatwg.org/#host-parsing).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Url::Host.parse("Bücher.example") # => #<data Ferro::Url::Host::Domain domain="xn--bcher-kva.example">
      def self.parse(input)
        Arguments.host(Native.host_parse(input))
      end

      # Parses an opaque host, the host of a URL whose scheme is not
      # special: percent-encoded rather than IDNA-processed. Mirrors url's
      # <tt>Host::parse_opaque</tt> (<tt>src/host.rs:85-88</tt>), the URL
      # Standard's opaque host parser
      # (https://url.spec.whatwg.org/#concept-opaque-host-parser).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Url::Host.parse_opaque("Bücher") # => #<data Ferro::Url::Host::Domain domain="B%C3%BCcher">
      def self.parse_opaque(input)
        Arguments.host(Native.host_parse_opaque(input))
      end

      # The host as a URL writes it: a domain as is, an IPv4 address as
      # four decimal numbers, an IPv6 address between <tt>[</tt> and
      # <tt>]</tt> in RFC 5952 form. Mirrors url's +Display+ for +Host+
      # (<tt>src/host.rs:186-198</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Host.parse("[0:0:0:0:0:0:0:1]").to_s # => "[::1]"
      def to_s
        Native.host_to_s(Arguments.host_parts(self))
      end

      # Orders hosts as url derives +Ord+: Domain before Ipv4 before Ipv6,
      # then by value. +nil+ for anything but a Host.
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::Url::Host.parse("example.com") < Ferro::Url::Host.parse("1.2.3.4") # => true
      def <=>(other)
        Native.host_cmp(Arguments.host_parts(self), Arguments.host_parts(other)) if other.is_a?(Host)
      end

      # A DNS domain name, as <tt>.</tt> dot-separated labels. Non-ASCII
      # labels are encoded in Punycode per IDNA if this is the host of a
      # special URL, or percent encoded for non-special URLs. Hosts for
      # non-special URLs are also called opaque hosts.
      #
      # === Example
      #
      #   Ferro::Url::Host::Domain.new("example.com").to_s # => "example.com"
      class Domain < Data.define(:domain)
        include Host

        ##
        # :attr_reader: domain
        # The domain, a String.
      end

      # An IPv4 address. Url#host_str returns the serialization of this
      # address, as four decimal integers separated by <tt>.</tt> dots.
      #
      # === Example
      #
      #   Ferro::Url::Host::Ipv4.new(IPAddr.new("127.0.0.1")).to_s # => "127.0.0.1"
      class Ipv4 < Data.define(:address)
        include Host

        ##
        # :attr_reader: address
        # The address, an IPv4 IPAddr.
      end

      # An IPv6 address. Url#host_str returns the serialization of that
      # address between <tt>[</tt> and <tt>]</tt> brackets, in the format
      # per RFC 5952 (A Recommendation for IPv6 Address Text
      # Representation): lowercase hexadecimal with maximal <tt>::</tt>
      # compression.
      #
      # === Example
      #
      #   Ferro::Url::Host::Ipv6.new(IPAddr.new("::1")).to_s # => "[::1]"
      class Ipv6 < Data.define(:address)
        include Host

        ##
        # :attr_reader: address
        # The address, an IPv6 IPAddr.
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
