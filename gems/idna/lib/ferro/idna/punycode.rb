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
    # SPDX-SnippetComment: the punycode module and its functions' docs from
    #   idna 1.1.0 src/punycode.rs:9-14, :42-70, :318-345
    #++

    # Punycode (RFC 3492, https://tools.ietf.org/html/rfc3492).
    #
    # A non-ASCII label reaches DNS as Punycode: <tt>bücher</tt> becomes
    # <tt>bcher-kva</tt>, behind the <tt>xn--</tt> prefix UTS 46 adds. The
    # encoding works one label at a time and knows nothing of domains,
    # mapping, or the prefix; Uts46 does that part.
    #
    # Since Punycode fundamentally works on Unicode code points, Punycode.encode
    # and Punycode.decode take and return Arrays of characters, each a
    # one-character String, as String#chars returns. Punycode.encode_str and
    # Punycode.decode_to_string are convenience wrappers that take and return
    # Strings.
    #
    # Mirrors idna's <tt>punycode</tt> module (<tt>src/punycode.rs</tt>).
    #
    # === Examples
    #
    #   Ferro::Idna::Punycode.encode_str("bücher") # => "bcher-kva"
    #   Ferro::Idna::Punycode.decode_to_string("bcher-kva") # => "bücher"
    module Punycode
      # Converts Punycode to a Unicode String, or +nil+ on malformed input
      # or overflow. Overflow can only happen on inputs that take more than
      # 63 encoded bytes, the DNS limit on domain name labels. Mirrors
      # idna's <tt>punycode::decode_to_string</tt>
      # (<tt>src/punycode.rs:42-56</tt>).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Idna::Punycode.decode_to_string("53h") # => "☕"
      def self.decode_to_string(input)
        Native.punycode_decode_to_string(input)
      end

      # Converts Punycode to Unicode characters, or +nil+ on malformed
      # input or overflow, which can only happen on inputs that take more
      # than 63 encoded bytes. Mirrors idna's <tt>punycode::decode</tt>
      # (<tt>src/punycode.rs:57-70</tt>).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Idna::Punycode.decode("bcher-kva") # => ["b", "ü", "c", "h", "e", "r"]
      def self.decode(input)
        Native.punycode_decode(input)
      end

      # Converts a Unicode String to Punycode, or +nil+ on overflow. This is
      # a convenience wrapper around Punycode.encode. Mirrors idna's
      # <tt>punycode::encode_str</tt> (<tt>src/punycode.rs:318-330</tt>).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Idna::Punycode.encode_str("☕") # => "53h"
      def self.encode_str(input)
        Native.punycode_encode_str(input)
      end

      # Converts Unicode characters to Punycode, or +nil+ on overflow, which
      # can only happen on inputs that would take more than 63 encoded
      # bytes. Each element is a one-character String; anything else raises
      # +TypeError+, as converting it to Rust's +char+ does. Mirrors idna's
      # <tt>punycode::encode</tt> (<tt>src/punycode.rs:332-345</tt>).
      #
      # [input] Array of one-character Strings.
      #
      # === Example
      #
      #   Ferro::Idna::Punycode.encode("bücher".chars) # => "bcher-kva"
      def self.encode(input)
        Native.punycode_encode(input)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
