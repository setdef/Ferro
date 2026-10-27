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
    # SPDX-SnippetComment: the uts46 module's docs and verify_dns_length
    #   from idna 1.1.0 src/uts46.rs:9-21 and :456-486
    #++

    # The lower-level API for UTS 46, Unicode IDNA Compatibility
    # Processing (https://www.unicode.org/reports/tr46/).
    #
    # The crate-level functions pick the WHATWG URL Standard's settings for
    # you. A conformance checker, a registrar, or a mail client needs
    # others: hyphen checks, the DNS length limits, or a display form that
    # shows misleading labels as Punycode. Uts46#process is the core that
    # the other convenience methods build on.
    #
    # UTS 46 flags map to this API as follows:
    #
    # - <i>CheckHyphens</i>: +true+ is Hyphens::Check, +false+
    #   Hyphens::Allow; the WHATWG URL Standard sets this to +false+ for
    #   normal (non-conformance-checker) user agents.
    # - <i>CheckBidi</i>: always +true+; cannot be configured, since this
    #   flag is +true+ even when the WHATWG URL Standard's +beStrict+ is
    #   +false+.
    # - <i>CheckJoiners</i>: always +true+; cannot be configured, for the
    #   same reason.
    # - <i>UseSTD3ASCIIRules</i>: +true+ is AsciiDenyList::STD3, +false+
    #   AsciiDenyList::EMPTY; however, the check the WHATWG URL Standard
    #   performs right after the UTS 46 invocation corresponds to
    #   AsciiDenyList::URL.
    # - <i>Transitional_Processing</i>: always +false+, but could be
    #   implemented as a preprocessing step. This flag is deprecated, and
    #   for Web purposes the transition is over in the sense that all of
    #   Firefox, Safari, and Chrome set this flag to +false+.
    # - <i>VerifyDnsLength</i>: +true+ is DnsLength::Verify, +false+
    #   DnsLength::Ignore; the WHATWG URL Standard sets this to +false+ for
    #   normal user agents.
    # - <i>IgnoreInvalidPunycode</i>: always +false+; cannot be configured.
    #   (Not yet covered by the WHATWG URL Standard, but two of three major
    #   browsers clearly behave as if this was +false+.)
    #
    # Mirrors idna's <tt>uts46</tt> module (<tt>src/uts46.rs</tt>).
    #
    # === Examples
    #
    #   uts46 = Ferro::Idna::Uts46
    #   uts46::Uts46.new.to_ascii("Bücher.example", uts46::AsciiDenyList::URL,
    #     uts46::Hyphens::Allow, uts46::DnsLength::Ignore) # => "xn--bcher-kva.example"
    #
    #   uts46.verify_dns_length("example.com.", true) # => true
    module Uts46
      # Performs the <i>VerifyDNSLength</i> check on the output of the
      # <i>ToASCII</i> operation: no label empty or over 63 bytes, and no
      # more than 253 bytes in all.
      #
      # If +allow_trailing_dot+ is +true+, the trailing root label dot is
      # allowed.
      #
      # idna asserts in debug builds that the argument is ASCII. This gem
      # builds idna in release mode, where that check is compiled out, so a
      # non-ASCII argument gets the same length verdict, counted in bytes.
      # Mirrors idna's <tt>uts46::verify_dns_length</tt>
      # (<tt>src/uts46.rs:456-486</tt>).
      #
      # [domain_name] String, the ASCII form of a domain.
      # [allow_trailing_dot] +true+ or +false+.
      #
      # === Example
      #
      #   Ferro::Idna::Uts46.verify_dns_length("example.com.", false) # => false
      def self.verify_dns_length(domain_name, allow_trailing_dot)
        Native.verify_dns_length(domain_name, allow_trailing_dot)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end

require_relative "uts46/ascii_deny_list"
require_relative "uts46/hyphens"
require_relative "uts46/dns_length"
require_relative "uts46/error_policy"
require_relative "uts46/processing_success"
require_relative "uts46/processing_error"
require_relative "uts46/uts46"

module Ferro
  module Idna
    # idna re-exports <tt>uts46::AsciiDenyList</tt> at its root
    # (<tt>src/lib.rs:53</tt>), so this is the same class as
    # Uts46::AsciiDenyList.
    AsciiDenyList = Uts46::AsciiDenyList
  end
end
