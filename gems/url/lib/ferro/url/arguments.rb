# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ipaddr"
require "socket"

module Ferro
  module Url
    # Converts the gem's Ruby values to what the native layer takes, and its
    # results back (plan 005, decision 4). Private to the gem.
    module Arguments # :nodoc:
      # The Url holding +native+.
      def self.url(native)
        url = Url.allocate
        url.__send__(:initialize_native, native)
        url
      end

      # The native URL +url+ holds. Anything but a Url raises +TypeError+.
      def self.native(url)
        raise TypeError, "wrong argument type #{url.class} (expected #{Url})" unless url.is_a?(Url)

        url.__send__(:native)
      end

      # The Host a native <tt>[variant, value]</tt> describes.
      def self.host(parts)
        variant, value = parts
        case variant
        when "Domain" then Host::Domain.new(value.to_s)
        when "Ipv4" then Host::Ipv4.new(IPAddr.new_ntoh([Integer(value)].pack("N")))
        else Host::Ipv6.new(IPAddr.new_ntoh([Integer(value) >> 64, Integer(value) & 0xFFFF_FFFF_FFFF_FFFF].pack("Q>Q>")))
        end
      end

      # The native <tt>[variant, value]</tt> for +host+. Anything but a
      # Host, or a Host with the wrong value, raises +TypeError+.
      def self.host_parts(host)
        case host
        when Host::Domain then ["Domain", host.domain]
        when Host::Ipv4 then ["Ipv4", address(host.address, :ipv4?)]
        when Host::Ipv6 then ["Ipv6", address(host.address, :ipv6?)]
        else raise TypeError, "wrong argument type #{host.class} (expected #{Host})"
        end
      end

      # The number of +address+, an IPAddr of the family +family+ asks for.
      def self.address(address, family)
        expected = "expected an #{(family == :ipv4?) ? 'IPv4' : 'IPv6'} IPAddr"
        raise TypeError, "wrong argument type #{address.class} (#{expected})" unless address.is_a?(IPAddr)
        raise TypeError, "wrong address family (#{expected})" unless address.public_send(family)

        address.to_i
      end

      # The Origin a native origin describes.
      def self.origin(parts)
        case parts
        in ["Opaque", native]
          opaque = OpaqueOrigin.allocate
          opaque.__send__(:initialize, native)
          Origin::Opaque.new(opaque)
        in ["Tuple", scheme, host, port]
          Origin::Tuple.new(scheme, host(host), port)
        end
      end

      # The native origin for +origin+. Anything but an Origin raises
      # +TypeError+.
      def self.origin_parts(origin)
        case origin
        when Origin::Opaque
          raise TypeError, "wrong argument type #{origin.value.class} (expected #{OpaqueOrigin})" unless origin.value.is_a?(OpaqueOrigin)

          ["Opaque", origin.value.__send__(:native)]
        when Origin::Tuple then ["Tuple", origin.scheme, host_parts(origin.host), origin.port]
        else raise TypeError, "wrong argument type #{origin.class} (expected #{Origin})"
        end
      end

      # The bytes a callable returned for an encoding override: a String,
      # or +TypeError+.
      def self.encoded(bytes)
        raise TypeError, "an encoding override must return a String, not #{bytes.class}" unless bytes.is_a?(String)

        bytes
      end

      # A path's String: a String as it is, or another object through
      # File.path, as Ruby's file methods take one. A String is not passed
      # through File.path, which refuses a NUL byte that a Rust path may hold
      # (plan 005, decision 13).
      def self.path(path)
        case path
        when String then path
        else File.path(path)
        end
      end

      # +pairs+, any Enumerable of two-element pairs, as an Array of String
      # pairs for the native layer.
      def self.pairs(pairs)
        pairs.map do |pair|
          name, value = pair
          [name, value]
        end
      end
    end
  end
end
