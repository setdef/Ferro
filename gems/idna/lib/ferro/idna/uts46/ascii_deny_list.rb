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
      # SPDX-SnippetComment: AsciiDenyList, its constants, and their docs
      #   from idna 1.1.0 src/uts46.rs:269-352
      #++

      # The ASCII deny list to be applied.
      #
      # UTS 46 checks Unicode, but which ASCII characters a domain may hold
      # depends on who asks. DNS proper allows letters, digits, and
      # hyphens; a URL also allows the underscore and much else, and the
      # WHATWG URL Standard forbids its own short list of delimiters.
      # Writing that check yourself, after idna, costs a second pass and
      # misses the cases idna's internals could skip.
      #
      # A deny list is that check, handed to idna. Pick one of the three
      # constants, or build your own with AsciiDenyList.new. Upper-case
      # ASCII is always on the list internally, since UTS 46 maps it to
      # lower case first.
      #
      # A deny list is frozen and shareable between Ractors. Two compare
      # equal when idna's +PartialEq+ says they deny the same characters;
      # idna derives no +Hash+, so +eql?+ and +hash+ stay Ruby's identity.
      #
      # Mirrors idna's <tt>uts46::AsciiDenyList</tt>
      # (<tt>src/uts46.rs:269-352</tt>), which idna also re-exports as
      # <tt>idna::AsciiDenyList</tt>.
      #
      # === Examples
      #
      #   list = Ferro::Idna::Uts46::AsciiDenyList
      #   list.new(true, "%#/:<>?@[\\]^|") == list::URL # => true
      #
      #   Ferro::Idna.domain_to_ascii_cow("a_b.example", list::STD3)
      #   # raises Ferro::Idna::Errors
      class AsciiDenyList
        class << self
          # Computes an ASCII deny list.
          #
          # Setting +deny_glyphless+ to +true+ denies U+0020 SPACE and
          # below as well as U+007F DELETE for convenience, without having
          # to list these characters in +deny_list+.
          #
          # +deny_list+ is the list of ASCII characters to deny. This list
          # must not contain any of: letters, digits, the hyphen, the dot
          # (period, full stop), or non-ASCII. idna panics on any of them;
          # this gem raises +ArgumentError+ with idna's assertion message
          # instead, checking each byte in idna's order.
          #
          # Mirrors idna's <tt>AsciiDenyList::new</tt>
          # (<tt>src/uts46.rs:277-322</tt>).
          #
          # [deny_glyphless] +true+ or +false+.
          # [deny_list] String, the ASCII characters to deny.
          #
          # === Example
          #
          #   Ferro::Idna::Uts46::AsciiDenyList.new(false, "_")
          #   Ferro::Idna::Uts46::AsciiDenyList.new(false, "a")
          #   # raises ArgumentError: ASCII deny list must not contain letters.
          def new(deny_glyphless, deny_list)
            from_native(Native.ascii_deny_list_new(deny_glyphless, deny_list))
          end

          # The deny list holding +native+.
          private def from_native(native)
            list = allocate
            list.__send__(:initialize, native)
            list
          end
        end

        # Holds +native+, idna's value, and freezes both.
        #
        # [native] The native deny list.
        def initialize(native)
          @native = native.freeze
          freeze
        end

        # Whether +other+ denies the same characters, by idna's
        # +PartialEq+. +false+ for anything but an AsciiDenyList.
        #
        # [other] Object.
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::AsciiDenyList.new(false, "") == Ferro::Idna::Uts46::AsciiDenyList::EMPTY # => true
        def ==(other)
          other.is_a?(AsciiDenyList) && Native.ascii_deny_list_eq(@native, other.__send__(:native))
        end

        # The native deny list, for the native layer.
        private attr_reader :native

        # No ASCII deny list. This corresponds to
        # <i>UseSTD3ASCIIRules=false</i>. Equivalent to
        # <tt>AsciiDenyList.new(false, "")</tt>.
        #
        # Note: not denying the space and control characters can result
        # in strange behavior. Without a deny list provided to the UTS 46
        # operation, the caller is expected to perform filtering
        # afterwards, but it's more efficient to use an AsciiDenyList than
        # post-processing, because the internals of idna can optimize
        # away checks in certain cases.
        EMPTY = from_native(Native.ascii_deny_list_constant(:EMPTY))

        # The STD3 deny list. This corresponds to
        # <i>UseSTD3ASCIIRules=true</i>.
        #
        # Note that this deny list rejects the underscore, which occurs in
        # pseudo-hosts used by various TXT record-based protocols, and also
        # characters that may occur in non-DNS naming, such as NetBIOS.
        STD3 = from_native(Native.ascii_deny_list_constant(:STD3))

        # The forbidden domain code points
        # (https://url.spec.whatwg.org/#forbidden-domain-code-point) from
        # the WHATWG URL Standard. Equivalent to
        # <tt>AsciiDenyList.new(true, "%#/:<>?@[\\]^|")</tt>.
        #
        # Note that this deny list rejects IPv6 addresses, so (as in URL
        # parsing) you need to check for IPv6 addresses first and not put
        # them through UTS 46 processing.
        URL = from_native(Native.ascii_deny_list_constant(:URL))
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
