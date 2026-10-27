# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Idna
    # Converts the gem's Ruby arguments to what the native layer takes, and
    # its results back. Private to the gem.
    module Arguments # :nodoc:
      # A String's bytes, whatever its encoding, for an idna function that
      # takes bytes (plan 006, decision 4). Anything but a String raises
      # +TypeError+ as Ruby words a wrong argument type.
      def self.bytes(domain)
        raise TypeError, "no implicit conversion of #{domain.class} into String" unless domain.is_a?(String)

        domain
      end

      # The native deny list +list+ holds. Anything but an AsciiDenyList
      # raises +TypeError+.
      def self.deny_list(list)
        unless list.is_a?(Uts46::AsciiDenyList)
          raise TypeError, "wrong argument type #{list.class} (expected #{Uts46::AsciiDenyList})"
        end

        list.__send__(:native)
      end

      # The variant name of +value+, an instance of the enum +enum+, for the
      # native layer. Anything else raises +TypeError+.
      def self.variant(value, enum)
        raise TypeError, "wrong argument type #{value.class} (expected #{enum})" unless value.is_a?(enum)

        value.__send__(:name)
      end

      # idna's <tt>(String, Result<(), Errors>)</tt>, from the native
      # <tt>[text, ok]</tt>: the text, and +nil+ or an unraised Errors
      # (plan 006, decision 5).
      def self.pair(native)
        text, ok = native
        [text, ok ? nil : Errors.new]
      end
    end
  end
end
