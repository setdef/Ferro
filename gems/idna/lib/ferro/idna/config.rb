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
    # SPDX-SnippetComment: Config, its methods, and their docs from idna
    #   1.1.0 src/deprecated.rs:131-248
    #++

    # Deprecated configuration API.
    #
    # Before idna 1.0, a caller built a Config, flag by flag, and asked it
    # for ToASCII or ToUnicode. idna 1.0 replaced it with the crate-level
    # functions and Uts46::Uts46, and kept this API to ease migration. It
    # still works, with the defaults of <i>beStrict=false</i> in the WHATWG
    # URL Standard (https://url.spec.whatwg.org/#idna).
    #
    # idna marks the type deprecated, so naming <tt>Ferro::Idna::Config</tt>
    # warns when <tt>Warning[:deprecated]</tt> is on. A Config is a frozen
    # value: each setter returns a new Config and leaves the receiver as it
    # was, as Rust's setters do on a +Copy+ value.
    #
    # Mirrors idna's deprecated +Config+ (<tt>src/deprecated.rs:131-248</tt>).
    #
    # === Example
    #
    #   config = Ferro::Idna::Config.default.use_std3_ascii_rules(true).check_hyphens(true)
    #   config.to_ascii("Bücher.example") # => "xn--bcher-kva.example"
    class Config
      private_class_method :new

      # The configuration with the defaults of <i>beStrict=false</i> in the
      # WHATWG URL Standard: no STD3 rules, no transitional processing, no
      # hyphen checks, and no DNS length check. Mirrors idna's
      # <tt>Default for Config</tt> (<tt>src/deprecated.rs:142-153</tt>).
      #
      # === Example
      #
      #   Ferro::Idna::Config.default
      def self.default
        new(false, false, false, false)
      end

      # Creates the configuration with these flags, frozen.
      #
      # [use_std3_ascii_rules] +true+ or +false+.
      # [transitional_processing] +true+ or +false+.
      # [verify_dns_length] +true+ or +false+.
      # [check_hyphens] +true+ or +false+.
      def initialize(use_std3_ascii_rules, transitional_processing, verify_dns_length, check_hyphens)
        @flags = [use_std3_ascii_rules, transitional_processing, verify_dns_length, check_hyphens].freeze
        freeze
      end

      # Whether to enforce STD3 or WHATWG URL Standard ASCII deny list:
      # +true+ for STD3, +false+ for no deny list.
      #
      # Note that +true+ rejects pseudo-hosts used by various TXT
      # record-based protocols. Mirrors idna's
      # <tt>Config::use_std3_ascii_rules</tt> (<tt>src/deprecated.rs:156-165</tt>).
      #
      # [value] +true+ or +false+.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.use_std3_ascii_rules(true)
      def use_std3_ascii_rules(value)
        with(0, value)
      end

      # Whether to enable (deprecated) transitional processing.
      #
      # Note that Firefox, Safari, and Chrome do not use transitional
      # processing. Mirrors idna's <tt>Config::transitional_processing</tt>
      # (<tt>src/deprecated.rs:167-175</tt>).
      #
      # [value] +true+ or +false+.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.transitional_processing(true).to_ascii("faß.de") # => "fass.de"
      def transitional_processing(value)
        with(1, value)
      end

      # Whether the <i>VerifyDNSLength</i> operation should be performed by
      # #to_ascii.
      #
      # For compatibility with previous behavior, even when set to +true+,
      # the trailing root label dot is allowed contrary to the spec. Mirrors
      # idna's <tt>Config::verify_dns_length</tt>
      # (<tt>src/deprecated.rs:177-186</tt>).
      #
      # [value] +true+ or +false+.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.verify_dns_length(true)
      def verify_dns_length(value)
        with(2, value)
      end

      # Whether to enforce STD3 rules for hyphen placement: +true+ to deny
      # hyphens in the first and last positions, +false+ to not enforce
      # hyphen placement.
      #
      # Note that for backward compatibility this is not the same as UTS 46
      # <i>CheckHyphens</i>, which also disallows hyphens in the third and
      # fourth positions. Note that +true+ rejects real-world names,
      # including some GitHub user pages. Mirrors idna's
      # <tt>Config::check_hyphens</tt> (<tt>src/deprecated.rs:187-202</tt>).
      #
      # [value] +true+ or +false+.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.check_hyphens(true)
      def check_hyphens(value)
        with(3, value)
      end

      # Obsolete method retained to ease migration. The argument must be
      # +false+, and the configuration comes back unchanged.
      #
      # idna panics for +true+; this gem raises +ArgumentError+ with idna's
      # message, <tt>IDNA 2008 rules are no longer supported</tt>, instead.
      # Mirrors idna's <tt>Config::use_idna_2008_rules</tt>
      # (<tt>src/deprecated.rs:204-214</tt>).
      #
      # [value] +false+.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.use_idna_2008_rules(false)
      def use_idna_2008_rules(value)
        Native.config_use_idna_2008_rules(value)
        self
      end

      # UTS 46 ToASCII (http://www.unicode.org/reports/tr46/#ToASCII),
      # raising Errors when the domain fails. Mirrors idna's
      # <tt>Config::to_ascii</tt> (<tt>src/deprecated.rs:234-239</tt>).
      #
      # [domain] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.to_ascii("☕.example") # => "xn--53h.example"
      def to_ascii(domain)
        Native.config_to_ascii(@flags, domain)
      end

      # UTS 46 ToUnicode (http://www.unicode.org/reports/tr46/#ToUnicode):
      # the text, and +nil+ or an unraised Errors, as Idna.domain_to_unicode
      # returns them. Mirrors idna's <tt>Config::to_unicode</tt>
      # (<tt>src/deprecated.rs:241-247</tt>).
      #
      # [domain] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Idna::Config.default.to_unicode("xn--53h.example") # => ["☕.example", nil]
      def to_unicode(domain)
        Arguments.pair(Native.config_to_unicode(@flags, domain))
      end

      # The four flags, for Idna::Idna.
      private attr_reader :flags

      # A copy of this configuration with flag +index+ set to +value+.
      private def with(index, value)
        std3, transitional, dns_length, hyphens = @flags.each_with_index.map do |flag, place|
          (place == index) ? (value ? true : false) : flag
        end
        self.class.__send__(:new, std3, transitional, dns_length, hyphens)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++

    # Config, for the gem's own code, which names it without the warning.
    ConfigType = Config # :nodoc:
    private_constant :ConfigType
    deprecate_constant :Config
  end
end
