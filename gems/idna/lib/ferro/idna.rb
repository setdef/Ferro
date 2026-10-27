# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "idna/version"
require_relative "idna/ferro_idna"
require_relative "idna/errors"
require_relative "idna/arguments"
require_relative "idna/uts46"
require_relative "idna/punycode"
require_relative "idna/config"
require_relative "idna/idna"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, such as internationalized domain names. Each Ferro gem binds one
# crate, keeps its names and behavior, and adds nothing of its own.
module Ferro
  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: MIT OR Apache-2.0
  # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
  # SPDX-SnippetComment: the crate overview and the crate-level functions'
  #   docs from idna 1.1.0 src/lib.rs:9-198
  #++

  # Internationalized domain names, through idna 1.1.0.
  #
  # A person types <tt>bücher.example</tt>; DNS only knows ASCII. Getting
  # from one to the other takes Unicode's IDNA rules (UTS #46): map each
  # character, normalize, check the bidi and joiner rules, and encode each
  # non-ASCII label in Punycode as <tt>xn--bcher-kva</tt>. The rules need
  # Unicode's data tables, which Ruby does not ship.
  #
  # This module binds idna (https://github.com/servo/rust-url/tree/main/idna),
  # the crate the url crate uses, one to one. It implements IDNA per the
  # WHATWG URL Standard (https://url.spec.whatwg.org/#idna), and exposes
  # the underlying algorithms from Unicode Technical Standard #46
  # (Uts46) and Punycode (RFC 3492, Punycode).
  #
  # Most applications want Idna.domain_to_ascii_cow with
  # Uts46::AsciiDenyList::URL: it runs the WHATWG URL Standard's domain to
  # ASCII algorithm and its forbidden domain code point check. Idna.domain_to_ascii
  # and Idna.domain_to_unicode exist for backward compatibility, and
  # Uts46::Uts46 offers every option.
  #
  # === Examples
  #
  #   require "ferro/idna"
  #
  #   Ferro::Idna.domain_to_ascii_cow("Bücher.example", Ferro::Idna::AsciiDenyList::URL)
  #   # => "xn--bcher-kva.example"
  #
  #   Ferro::Idna.domain_to_unicode("xn--bcher-kva.example") # => ["bücher.example", nil]
  #
  #   Ferro::Idna.domain_to_ascii_strict("a_b.example")
  #   # raises Ferro::Idna::Errors
  module Idna
    private_constant :Native, :Arguments

    # The WHATWG URL Standard's domain to ASCII
    # (https://url.spec.whatwg.org/#concept-domain-to-ascii), for a
    # domain's bytes.
    #
    # Most applications should be using this function or
    # domain_to_ascii_from_cow rather than the sibling functions, and
    # most applications should pass AsciiDenyList::URL as the second
    # argument. Passing AsciiDenyList::URL as the second argument makes
    # this function also perform the forbidden domain code point
    # (https://url.spec.whatwg.org/#forbidden-domain-code-point) check in
    # addition to the domain to ASCII algorithm.
    #
    # Returns the ASCII representation of a domain name, normalizing
    # characters (upper-case to lower-case and other kinds of
    # equivalence) and using Punycode as necessary. This process may fail,
    # and raises Errors when it does.
    #
    # +domain+ is taken as bytes, whatever its encoding; bytes that are
    # not UTF-8 are an error. Mirrors idna's <tt>domain_to_ascii_cow</tt>
    # (<tt>src/lib.rs:86-115</tt>).
    #
    # [domain] String, the domain.
    # [ascii_deny_list] Uts46::AsciiDenyList.
    #
    # === Example
    #
    #   Ferro::Idna.domain_to_ascii_cow("example.COM", Ferro::Idna::AsciiDenyList::URL) # => "example.com"
    def self.domain_to_ascii_cow(domain, ascii_deny_list)
      Native.domain_to_ascii_cow(Arguments.bytes(domain), Arguments.deny_list(ascii_deny_list))
    end

    # The same as domain_to_ascii_cow. Rust's version takes and returns a
    # borrowed-or-owned value to save a copy, which Ruby has no use for.
    # Mirrors idna's <tt>domain_to_ascii_from_cow</tt>
    # (<tt>src/lib.rs:117-142</tt>).
    #
    # [domain] String, the domain.
    # [ascii_deny_list] Uts46::AsciiDenyList.
    #
    # === Example
    #
    #   Ferro::Idna.domain_to_ascii_from_cow("☕.example", Ferro::Idna::AsciiDenyList::URL) # => "xn--53h.example"
    def self.domain_to_ascii_from_cow(domain, ascii_deny_list)
      Native.domain_to_ascii_from_cow(Arguments.bytes(domain), Arguments.deny_list(ascii_deny_list))
    end

    # The WHATWG URL Standard's domain to ASCII with no ASCII deny list
    # (<i>UseSTD3ASCIIRules=false</i>).
    #
    # This function exists for backward compatibility. Consider using
    # domain_to_ascii_cow instead. Raises Errors when the domain fails.
    # Mirrors idna's <tt>domain_to_ascii</tt> (<tt>src/lib.rs:144-157</tt>).
    #
    # [domain] String, UTF-8 text.
    #
    # === Example
    #
    #   Ferro::Idna.domain_to_ascii("a_b.example") # => "a_b.example"
    def self.domain_to_ascii(domain)
      Native.domain_to_ascii(domain)
    end

    # The WHATWG URL Standard's domain to ASCII with the +beStrict+ flag
    # set: the STD3 deny list, every hyphen check, and the DNS length
    # check.
    #
    # Note that this rejects various real-world names including YouTube
    # CDN nodes, some GitHub user pages, and pseudo-hosts used by various
    # TXT record-based protocols. Raises Errors when the domain fails.
    # Mirrors idna's <tt>domain_to_ascii_strict</tt>
    # (<tt>src/lib.rs:159-175</tt>).
    #
    # [domain] String, UTF-8 text.
    #
    # === Example
    #
    #   Ferro::Idna.domain_to_ascii_strict("bücher.example") # => "xn--bcher-kva.example"
    def self.domain_to_ascii_strict(domain)
      Native.domain_to_ascii_strict(domain)
    end

    # The WHATWG URL Standard's domain to Unicode
    # (https://url.spec.whatwg.org/#concept-domain-to-unicode), with no
    # ASCII deny list. It normalizes characters and decodes Punycode as
    # necessary.
    #
    # This function exists for backward compatibility. Consider using
    # Uts46::Uts46#to_user_interface or Uts46::Uts46#to_unicode.
    #
    # Returns a pair, as idna's tuple: the text, and +nil+ or an Errors.
    # Errors are not raised, because the text is still useful: it denotes
    # errors with REPLACEMENT CHARACTERs (U+FFFD) to illustrate them to the
    # user. When the second item is an Errors, the text must not be used
    # in a network protocol. Mirrors idna's <tt>domain_to_unicode</tt>
    # (<tt>src/lib.rs:177-198</tt>).
    #
    # [domain] String, UTF-8 text.
    #
    # === Example
    #
    #   text, errors = Ferro::Idna.domain_to_unicode("xn--53h.example")
    #   text # => "☕.example"
    #   errors # => nil
    def self.domain_to_unicode(domain)
      Arguments.pair(Native.domain_to_unicode(domain))
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
