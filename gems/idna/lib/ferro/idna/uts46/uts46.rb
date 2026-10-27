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
      # SPDX-SnippetComment: Uts46, its methods, and their docs from idna
      #   1.1.0 src/uts46.rs:488-1045
      #++

      # An implementation of UTS #46.
      #
      # The crate-level functions fix the options to the WHATWG URL
      # Standard's. Other callers need other answers: a registrar checks
      # hyphens and DNS lengths, a browser's address bar shows most labels
      # in Unicode but a misleading one as Punycode, and a form computes the
      # display form and the lookup form in one pass.
      #
      # An instance holds idna's Unicode data, compiled into the extension,
      # and nothing else; it is frozen and shareable between Ractors. Each
      # method takes the domain as bytes, whatever the String's encoding,
      # and treats bytes that are not well-formed UTF-8 as an error.
      #
      # Mirrors idna's <tt>uts46::Uts46</tt> (<tt>src/uts46.rs:488-1045</tt>).
      #
      # === Examples
      #
      #   uts46 = Ferro::Idna::Uts46
      #   idna = uts46::Uts46.new
      #
      #   idna.to_ascii("Bücher.example", uts46::AsciiDenyList::URL, uts46::Hyphens::Allow, uts46::DnsLength::Ignore)
      #   # => "xn--bcher-kva.example"
      #
      #   idna.to_unicode("xn--bcher-kva.example", uts46::AsciiDenyList::URL, uts46::Hyphens::Allow)
      #   # => ["bücher.example", nil]
      class Uts46
        # Constructor using data compiled into the binary. Mirrors idna's
        # <tt>Uts46::new</tt> (<tt>src/uts46.rs:500-508</tt>).
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::Uts46.new
        def initialize
          freeze
        end

        # The same as Uts46.new, as idna's +Default+ is
        # (<tt>src/uts46.rs:493-498</tt>).
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::Uts46.default
        def self.default
          new
        end

        # Performs the ToASCII (https://www.unicode.org/reports/tr46/#ToASCII)
        # operation from UTS #46 with the options indicated, and raises
        # Errors when the domain fails.
        #
        # Mirrors idna's <tt>Uts46::to_ascii</tt>
        # (<tt>src/uts46.rs:512-586</tt>).
        #
        # [domain_name] String, the input domain name as UTF-8 bytes. The
        #   UTF-8ness is checked, and input that is not well-formed UTF-8 is
        #   treated as an error.
        # [ascii_deny_list] AsciiDenyList: what ASCII deny list, if any, to
        #   apply. The UTS 46 <i>UseSTD3ASCIIRules</i> flag or the WHATWG
        #   URL Standard forbidden domain code point processing is handled
        #   via this argument. Most callers are probably best off using
        #   AsciiDenyList::URL here.
        # [hyphens] Hyphens, the UTS 46 <i>CheckHyphens</i> flag. Most
        #   callers are probably best off using Hyphens::Allow here.
        # [dns_length] DnsLength, the UTS 46 <i>VerifyDNSLength</i> flag.
        #
        # === Example
        #
        #   uts46 = Ferro::Idna::Uts46
        #   uts46::Uts46.new.to_ascii("☕.example", uts46::AsciiDenyList::URL, uts46::Hyphens::Allow,
        #     uts46::DnsLength::Verify) # => "xn--53h.example"
        def to_ascii(domain_name, ascii_deny_list, hyphens, dns_length)
          Native.uts46_to_ascii(Arguments.bytes(domain_name), Arguments.deny_list(ascii_deny_list),
            Arguments.variant(hyphens, Hyphens), Arguments.variant(dns_length, DnsLength))
        end

        # Performs the ToUnicode (https://www.unicode.org/reports/tr46/#ToUnicode)
        # operation from UTS #46 according to the options given.
        #
        # When there are errors, there is still output, which may be
        # rendered to the user, even though the output must not be used in
        # networking protocols. Errors are denoted by U+FFFD REPLACEMENT
        # CHARACTERs in the output. So this returns a pair, as idna's tuple:
        # the text, and +nil+ or an unraised Errors. When the second item is
        # an Errors, the text is guaranteed to contain at least one U+FFFD.
        #
        # Most applications probably shouldn't use this method and should
        # be using #to_user_interface instead.
        #
        # Mirrors idna's <tt>Uts46::to_unicode</tt>
        # (<tt>src/uts46.rs:588-617</tt>).
        #
        # [domain_name] String, the input domain name as UTF-8 bytes.
        # [ascii_deny_list] AsciiDenyList, as for #to_ascii.
        # [hyphens] Hyphens, as for #to_ascii.
        #
        # === Example
        #
        #   uts46 = Ferro::Idna::Uts46
        #   uts46::Uts46.new.to_unicode("xn--53h.example", uts46::AsciiDenyList::URL, uts46::Hyphens::Allow)
        #   # => ["☕.example", nil]
        def to_unicode(domain_name, ascii_deny_list, hyphens)
          Arguments.pair(Native.uts46_to_unicode(Arguments.bytes(domain_name),
            Arguments.deny_list(ascii_deny_list), Arguments.variant(hyphens, Hyphens)))
        end

        # Performs the ToUnicode operation from UTS #46 according to the
        # options given, with some error-free Unicode labels output
        # according to ToASCII instead, as decided by application policy
        # implemented via +output_as_unicode+. The purpose is to convert
        # user-visible domains to the Unicode form in general but to render
        # potentially misleading labels as Punycode.
        #
        # This is an imperfect security mechanism, because the Punycode form
        # itself may resemble a user-recognizable name
        # (https://www.unicode.org/reports/tr36/#TablePunycodeSpoofing).
        # However, since this mechanism is common practice, idna supports it.
        #
        # ASCII labels always pass through as ASCII and labels with errors
        # always pass through as Unicode. For non-erroneous labels that
        # contain at least one non-ASCII character, +output_as_unicode+ is
        # called with the Unicode form of the label, the TLD (possibly
        # empty), and whether the domain name as a whole is a bidi domain
        # name. If its result is truthy, the label passes through as
        # Unicode; otherwise it is converted to Punycode.
        #
        # Returns a pair, as #to_unicode does. Labels that contain errors are
        # not converted to Punycode.
        #
        # Pass +output_as_unicode+ as a block or as any object that responds
        # to +call+, not both. It runs inside idna's processing. An exception
        # it raises stops later calls (each later label becomes Punycode) and
        # is raised again once idna returns, so the text idna computed is
        # dropped. Mirrors idna's <tt>Uts46::to_user_interface</tt>
        # (<tt>src/uts46.rs:619-691</tt>).
        #
        # [domain_name] String, the input domain name as UTF-8 bytes.
        # [ascii_deny_list] AsciiDenyList, as for #to_ascii.
        # [hyphens] Hyphens, as for #to_ascii.
        # [output_as_unicode] Callable, or +nil+ with a block: decides for a
        #   label (always a non-empty String) whether it is shown as
        #   Unicode. The second argument is the TLD, and the third whether
        #   the domain name is a bidi domain name. The second and third
        #   stay the same during a single call.
        #
        # === Example
        #
        #   uts46 = Ferro::Idna::Uts46
        #   uts46::Uts46.new.to_user_interface("xn--53h.xn--bcher-kva.example", uts46::AsciiDenyList::URL,
        #     uts46::Hyphens::Allow) { |label, _tld, _bidi| label != "☕" }
        #   # => ["xn--53h.bücher.example", nil]
        def to_user_interface(domain_name, ascii_deny_list, hyphens, output_as_unicode = nil, &block)
          decide = callback(output_as_unicode, block)
          Arguments.pair(Native.uts46_to_user_interface(Arguments.bytes(domain_name),
            Arguments.deny_list(ascii_deny_list), Arguments.variant(hyphens, Hyphens), decide))
        end

        # The lower-level function that #to_ascii, #to_unicode, and
        # #to_user_interface are built on, writing its output to +sink+ and,
        # optionally, the ToASCII form to +ascii_sink+.
        #
        # To perform the ToASCII operation, pass <tt>-> (*) { false }</tt> as
        # +output_as_unicode+. To perform the ToUnicode operation, pass
        # <tt>-> (*) { true }</tt>. A more complex callable may be used to
        # prepare a domain name for display in a user interface so that
        # labels are converted to the Unicode form in general but
        # potentially misleading labels are converted to the Punycode form.
        #
        # Returns ProcessingSuccess::Passthrough, when the caller must treat
        # the input as the output (which is then ASCII), or
        # ProcessingSuccess::WroteToSink, when the caller must treat what was
        # written to +sink+ as the output. If +ascii_sink+ was given but did
        # not receive output, the caller must treat what was written to
        # +sink+ also as the ToASCII output. Otherwise, if +ascii_sink+
        # received output, the caller must treat what was written to
        # +ascii_sink+ as the ToASCII output.
        #
        # Raises ProcessingError::ValidityError when the input was in error
        # and must not be used for DNS lookup or otherwise in a network
        # protocol. If +error_policy+ was ErrorPolicy::MarkErrors, the
        # output written to +sink+ may be displayed to the user as an
        # illustration of where the error was or the errors were.
        #
        # Punycode processing is quadratic, so to avoid denial of service,
        # idna imposes length limits on Punycode, treating especially long
        # inputs as being in error. These limits are well higher than the
        # DNS length limits and are not more restrictive than the limits
        # imposed by ICU4C.
        #
        # The sinks are Strings, and idna's output is appended to them once
        # it returns, whether it succeeded or raised. A String never fails,
        # so ProcessingError::SinkError never arises. +output_as_unicode+ is
        # positional here, since the sinks follow it; it runs as it does
        # for #to_user_interface. Mirrors idna's <tt>Uts46::process</tt>
        # (<tt>src/uts46.rs:693-1045</tt>).
        #
        # [domain_name] String, the input domain name as UTF-8 bytes.
        # [ascii_deny_list] AsciiDenyList, as for #to_ascii.
        # [hyphens] Hyphens, as for #to_ascii.
        # [error_policy] ErrorPolicy: whether to fail fast or to produce
        #   output that may be rendered for the user to examine in case of
        #   errors.
        # [output_as_unicode] Callable, as for #to_user_interface.
        # [sink] String that receives the output (in the non-passthrough
        #   case).
        # [ascii_sink] String or +nil+: a second sink that receives the
        #   ToASCII form only if there were no errors and +sink+ received at
        #   least one character of non-ASCII output. It computes a user
        #   interface display form and the ToASCII form of the domain
        #   together.
        #
        # === Example
        #
        #   uts46 = Ferro::Idna::Uts46
        #   display = +""
        #   lookup = +""
        #   uts46::Uts46.new.process("Bücher.example", uts46::AsciiDenyList::URL, uts46::Hyphens::Allow,
        #     uts46::ErrorPolicy::MarkErrors, -> (*) { true }, display, lookup)
        #   # => Ferro::Idna::Uts46::ProcessingSuccess::WroteToSink
        #   display # => "bücher.example"
        #   lookup # => "xn--bcher-kva.example"
        def process(domain_name, ascii_deny_list, hyphens, error_policy, output_as_unicode, sink, ascii_sink)
          check_sink(sink)
          check_sink(ascii_sink) unless ascii_sink.nil?
          outcome, written, ascii_written = Native.uts46_process(Arguments.bytes(domain_name),
            Arguments.deny_list(ascii_deny_list), Arguments.variant(hyphens, Hyphens),
            Arguments.variant(error_policy, ErrorPolicy), callback(output_as_unicode, nil), !ascii_sink.nil?)
          sink << written
          ascii_sink << ascii_written if ascii_sink && ascii_written
          settle(outcome)
        end

        # The callable that decides for each label: +output_as_unicode+ or
        # +block+, exactly one of them.
        private def callback(output_as_unicode, block)
          raise ArgumentError, "give output_as_unicode or a block, not both" if output_as_unicode && block

          decide = output_as_unicode || block
          raise ArgumentError, "give output_as_unicode or a block" if decide.nil?
          raise TypeError, "output_as_unicode must respond to call" unless decide.respond_to?(:call)

          decide
        end

        # Refuses a sink that is not a String, or is frozen, before idna
        # runs.
        private def check_sink(sink)
          raise TypeError, "no implicit conversion of #{sink.class} into String" unless sink.is_a?(String)
          raise FrozenError.new("can't modify frozen String: #{sink.inspect}", receiver: sink) if sink.frozen?
        end

        # The ProcessingSuccess a native outcome names, or the
        # ProcessingError it raises.
        private def settle(outcome)
          kind, variant = outcome.split("::")
          case kind
          when "ProcessingSuccess" then ProcessingSuccess.const_get(variant.to_s, false)
          else raise ProcessingError.const_get(variant.to_s, false)
          end
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
