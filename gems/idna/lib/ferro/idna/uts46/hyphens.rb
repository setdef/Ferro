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
      # SPDX-SnippetComment: Hyphens, its variants, and their docs from
      #   idna 1.1.0 src/uts46.rs:354-376
      #++

      # The <i>CheckHyphens</i> mode.
      #
      # UTS 46 can refuse a label that starts or ends with a hyphen, or has
      # hyphens in its third and fourth places, the mark Punycode labels
      # (<tt>xn--</tt>) and other encodings use. Browsers check none of
      # that, and some real names break the rules.
      #
      # Pass one of the three constants to Uts46#to_ascii, #to_unicode,
      # #to_user_interface, or #process. idna marks the enum
      # +non_exhaustive+ in case a middle mode that prohibits only the first
      # and last position needs to be added, so a later idna may add more.
      # Variants compare by identity, as idna derives +PartialEq+.
      #
      # Mirrors idna's <tt>uts46::Hyphens</tt>
      # (<tt>src/uts46.rs:354-376</tt>).
      #
      # === Example
      #
      #   Ferro::Idna::Uts46::Uts46.new.to_ascii("-a.example", Ferro::Idna::AsciiDenyList::URL,
      #     Ferro::Idna::Uts46::Hyphens::Check, Ferro::Idna::Uts46::DnsLength::Ignore)
      #   # raises Ferro::Idna::Errors
      class Hyphens
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
        #   Ferro::Idna::Uts46::Hyphens::Allow.inspect # => "Ferro::Idna::Uts46::Hyphens::Allow"
        def inspect
          "Ferro::Idna::Uts46::Hyphens::#{@name}"
        end

        # The variant's name, for the native layer.
        private attr_reader :name

        # <i>CheckHyphens=false</i>: do not place positional restrictions on
        # hyphens.
        #
        # This mode is used by the WHATWG URL Standard for normal user agent
        # processing (that is, not conformance checking).
        Allow = new(:Allow)

        # Prohibit hyphens in the first and last position in the label but
        # allow in the third and fourth position.
        #
        # Note that this mode rejects real-world names, including some
        # GitHub user pages.
        CheckFirstLast = new(:CheckFirstLast)

        # <i>CheckHyphens=true</i>: prohibit hyphens in the first, third,
        # fourth, and last position in the label.
        #
        # Note that this mode rejects real-world names, including YouTube
        # CDN nodes and some GitHub user pages.
        Check = new(:Check)
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
