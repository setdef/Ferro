# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    module FormUrlencoded
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: 2013-2016 The rust-url developers
      # SPDX-SnippetComment: Parse and its docs from form_urlencoded 1.2.2
      #   src/lib.rs:31-115
      #++

      # The return type of FormUrlencoded.parse and Url#query_pairs: an
      # iterator of <tt>[name, value]</tt> pairs, percent-decoded.
      #
      # A form body or a query string can be long, and a program often
      # wants only the first pair that matches. An Array would decode every
      # pair first; this decodes one pair each time you ask, as Rust's
      # iterator does.
      #
      # #next answers the next pair, or +nil+ at the end, as Rust's +next+
      # answers +None+. #each yields the pairs that remain and leaves the
      # iterator at the end, so it includes +Enumerable+: <tt>to_a</tt>,
      # +find+, and the rest read from where the iterator is. Like Rust's
      # +Copy+ value, +dup+ copies it where it stands, and the copy goes on
      # alone. It reads its own copy of the input, so a later change to the
      # String or the Url it came from does not reach it. Rust's
      # +into_owned+ and +ParseIntoOwned+ have no Ruby meaning: the
      # Strings are already the caller's.
      #
      # Mirrors form_urlencoded's +Parse+ (<tt>src/lib.rs:42-115</tt>).
      #
      # === Example
      #
      #   pairs = Ferro::Url::FormUrlencoded.parse("a=1&b=2")
      #   pairs.next # => ["a", "1"]
      #   pairs.to_a # => [["b", "2"]]
      #   pairs.next # => nil
      class Parse
        include Enumerable

        private_class_method :new

        # Holds +native+, form_urlencoded's iterator.
        #
        # [native] The native Parse.
        def initialize(native)
          @native = native
        end

        # The next <tt>[name, value]</tt> pair, or +nil+ when there are no
        # more. Mirrors +Parse+'s +Iterator::next+
        # (<tt>src/lib.rs:48-71</tt>).
        #
        # === Example
        #
        #   pairs = Ferro::Url::FormUrlencoded.parse("a=1")
        #   pairs.next # => ["a", "1"]
        #   pairs.next # => nil
        def next
          Native.parse_next(@native)
        end

        # Yields each pair that remains, then leaves the iterator at the
        # end, as Rust's <tt>for pair in pairs.by_ref()</tt> does. Without a
        # block, returns an Enumerator.
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded.parse("a=1&b=2").each { |name, value| puts "#{name}: #{value}" }
        def each
          return enum_for(:each) unless block_given?

          while (pair = self.next)
            yield pair
          end
          self
        end

        # +dup+ and +clone+ copy the iterator where it stands, as Rust's
        # +Copy+ does.
        private def initialize_copy(source)
          super
          @native = Native.parse_copy(source.__send__(:native))
        end

        # The native Parse, for the native layer.
        private attr_reader :native
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
