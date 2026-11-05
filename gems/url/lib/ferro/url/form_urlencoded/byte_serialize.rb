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
      # SPDX-SnippetComment: ByteSerialize and its docs from form_urlencoded
      #   1.2.2 src/lib.rs:117-172
      #++

      # The return value of FormUrlencoded.byte_serialize: an iterator of
      # String slices, which join into the
      # <tt>application/x-www-form-urlencoded</tt> encoding of the input.
      #
      # A large body need not be encoded whole before it is written out:
      # this encodes one run of bytes each time you ask, as Rust's iterator
      # does.
      #
      # #next answers the next slice, or +nil+ at the end, as Rust's +next+
      # answers +None+. #each yields the slices that remain and leaves the
      # iterator at the end, so it includes +Enumerable+. #size_hint and
      # #debug are form_urlencoded's. Rust's value is neither +Copy+ nor
      # +Clone+, so +dup+ and +clone+ raise +TypeError+. It reads its own
      # copy of the input.
      #
      # Mirrors form_urlencoded's +ByteSerialize+ (<tt>src/lib.rs:125-172</tt>).
      #
      # === Example
      #
      #   slices = Ferro::Url::FormUrlencoded.byte_serialize("bar & baz")
      #   slices.next # => "bar"
      #   slices.to_a # => ["+", "%26", "+", "baz"]
      class ByteSerialize
        include Enumerable

        private_class_method :new

        # Holds +native+, form_urlencoded's iterator.
        #
        # [native] The native ByteSerialize.
        def initialize(native)
          @native = native
        end

        # The next slice, or +nil+ when there are no more. Mirrors
        # +ByteSerialize+'s +Iterator::next+ (<tt>src/lib.rs:138-163</tt>).
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded.byte_serialize("a b").next # => "a"
        def next
          Native.byte_serialize_next(@native)
        end

        # Yields each slice that remains, then leaves the iterator at the
        # end, as Rust's <tt>for slice in slices.by_ref()</tt> does. Without
        # a block, returns an Enumerator.
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded.byte_serialize("a b").each { |slice| print slice } # prints a+b
        def each
          return enum_for(:each) unless block_given?

          while (slice = self.next)
            yield slice
          end
          self
        end

        # The bounds on the number of slices that remain, as
        # <tt>[lower, upper]</tt>: <tt>[0, 0]</tt> at the end, and otherwise
        # at least one and at most one per byte left. Mirrors
        # +ByteSerialize+'s +Iterator::size_hint+ (<tt>src/lib.rs:165-171</tt>).
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded.byte_serialize("a b").size_hint # => [1, 3]
        def size_hint
          Native.byte_serialize_size_hint(@native)
        end

        # form_urlencoded's +Debug+ text, formatted by Rust: the bytes that
        # remain. +inspect+ stays Ruby's. Mirrors form_urlencoded's
        # <tt>#[derive(Debug)]</tt> on +ByteSerialize+
        # (<tt>src/lib.rs:126</tt>).
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded.byte_serialize("a b").debug # => "ByteSerialize { bytes: [97, 32, 98] }"
        def debug
          Native.byte_serialize_debug(@native)
        end

        # Refuses a copy, as Rust's value has neither +Copy+ nor +Clone+.
        private def initialize_copy(_source)
          raise TypeError, "can't copy #{self.class}: form_urlencoded's ByteSerialize is not Clone"
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
