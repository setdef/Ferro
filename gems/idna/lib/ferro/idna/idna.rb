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
    # SPDX-SnippetComment: Idna, its methods, and their docs from idna 1.1.0
    #   src/deprecated.rs:64-129
    #++

    # Deprecated. Use the crate-level functions or Uts46::Uts46.
    #
    # Before idna 1.0, a caller made an Idna from a Config and asked it to
    # append a domain's ToASCII or ToUnicode form to a String it kept. idna
    # keeps the type to ease migration, and so does this gem.
    #
    # idna marks the type deprecated, so naming <tt>Ferro::Idna::Idna</tt>
    # warns when <tt>Warning[:deprecated]</tt> is on. An Idna holds its
    # Config and nothing else, so it is frozen and shareable.
    #
    # Mirrors idna's deprecated +Idna+ (<tt>src/deprecated.rs:64-129</tt>).
    #
    # === Example
    #
    #   out = +""
    #   Ferro::Idna::Idna.new(Ferro::Idna::Config.default).to_ascii("Bücher.example", out)
    #   out # => "xn--bcher-kva.example"
    class Idna
      # Creates the converter for +config+. Mirrors idna's
      # <tt>Idna::new</tt> (<tt>src/deprecated.rs:71-75</tt>).
      #
      # [config] Config.
      #
      # === Example
      #
      #   Ferro::Idna::Idna.new(Ferro::Idna::Config.default)
      def initialize(config)
        raise TypeError, "wrong argument type #{config.class} (expected Ferro::Idna::Config)" unless config.is_a?(ConfigType)

        @config = config
        freeze
      end

      # The converter with Config.default, as idna's +Default+ is
      # (<tt>src/deprecated.rs:65</tt>).
      #
      # === Example
      #
      #   Ferro::Idna::Idna.default
      def self.default
        new(ConfigType.default)
      end

      # UTS 46 ToASCII (http://www.unicode.org/reports/tr46/#ToASCII),
      # appended to +out+, or Errors raised.
      #
      # idna checks the DNS length, when its Config asks, against all of
      # +out+, not only the part it appended, and on that failure the
      # appended text stays. Mirrors idna's <tt>Idna::to_ascii</tt>
      # (<tt>src/deprecated.rs:76-106</tt>).
      #
      # [domain] String, UTF-8 text.
      # [out] String, which the result is appended to.
      #
      # === Example
      #
      #   out = +"host: "
      #   Ferro::Idna::Idna.default.to_ascii("☕.example", out)
      #   out # => "host: xn--53h.example"
      def to_ascii(domain, out)
        run(:idna_to_ascii, domain, out)
      end

      # UTS 46 ToUnicode (http://www.unicode.org/reports/tr46/#ToUnicode),
      # appended to +out+, or Errors raised. On an error, +out+ still gets
      # the text with each error marked by U+FFFD. Mirrors idna's
      # <tt>Idna::to_unicode</tt> (<tt>src/deprecated.rs:108-128</tt>).
      #
      # [domain] String, UTF-8 text.
      # [out] String, which the result is appended to.
      #
      # === Example
      #
      #   out = +""
      #   Ferro::Idna::Idna.default.to_unicode("xn--53h.example", out)
      #   out # => "☕.example"
      def to_unicode(domain, out)
        run(:idna_to_unicode, domain, out)
      end

      # Runs the native +function+ over +domain+ with +out+'s text, then
      # gives +out+ what idna left in it, raising Errors when idna failed.
      private def run(function, domain, out)
        raise TypeError, "no implicit conversion of #{out.class} into String" unless out.is_a?(String)
        raise FrozenError.new("can't modify frozen String: #{out.inspect}", receiver: out) if out.frozen?

        text, ok = Native.public_send(function, @config.__send__(:flags), domain, out)
        out.replace(text)
        raise Errors unless ok

        nil
      end
    end

    #--
    # SPDX-SnippetEnd
    #++

    deprecate_constant :Idna
  end
end
