# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Idna
    module Uts46
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
      # SPDX-SnippetComment: DnsLength, its variants, and their docs from
      #   idna 1.1.0 src/uts46.rs:378-389
      #++

      # The UTS 46 <i>VerifyDNSLength</i> flag.
      #
      # DNS limits a label to 63 bytes and a name to 253, but a URL's host
      # need not be a DNS name at all. Whether to enforce the limits is the
      # caller's call.
      #
      # Pass one of the three constants to Uts46#to_ascii. idna marks the
      # enum +non_exhaustive+, so a later idna may add more. Variants
      # compare by identity, as idna derives +PartialEq+.
      #
      # Mirrors idna's <tt>uts46::DnsLength</tt>
      # (<tt>src/uts46.rs:378-389</tt>).
      #
      # === Example
      #
      #   Ferro::Idna::Uts46::Uts46.new.to_ascii("example.com.", Ferro::Idna::AsciiDenyList::URL,
      #     Ferro::Idna::Uts46::Hyphens::Allow, Ferro::Idna::Uts46::DnsLength::VerifyAllowRootDot)
      #   # => "example.com."
      class DnsLength
        private_class_method :new

        # Creates the variant named +name+. The constants are the only
        # instances.
        #
        # [name] Symbol, the idna variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        # The constant that holds this variant.
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::DnsLength::Ignore.inspect # => "Ferro::Idna::Uts46::DnsLength::Ignore"
        def inspect
          "Ferro::Idna::Uts46::DnsLength::#{@name}"
        end

        # The variant's name, for the native layer.
        private attr_reader :name

        # <i>VerifyDNSLength=false</i>. (Possibly relevant for allowing
        # non-DNS naming systems.)
        Ignore = new(:Ignore)

        # <i>VerifyDNSLength=true</i> with the exception that the trailing root
        # label dot is allowed.
        VerifyAllowRootDot = new(:VerifyAllowRootDot)

        # <i>VerifyDNSLength=true</i>. (The trailing root label dot is not
        # allowed.)
        Verify = new(:Verify)
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
