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
      # SPDX-SnippetComment: Serializer, its methods, their docs, and its
      #   panic messages from form_urlencoded 1.2.2 src/lib.rs:174-363
      #++

      # The <tt>application/x-www-form-urlencoded</tt> serializer
      # (https://url.spec.whatwg.org/#concept-urlencoded-serializer).
      #
      # A form or a query string is a list of pairs joined by <tt>&</tt>,
      # each encoded by rules that are easy to get almost right. The
      # serializer appends pairs to a target, separating and encoding them
      # as the URL Standard says.
      #
      # The target is a String, which the serializer changes in place, as
      # Rust's <tt>&mut String</tt> target is changed, or the UrlQuery that
      # Url#query_pairs_mut makes. Each method returns +self+ until #finish
      # returns the target: the String, or the Url. After #finish any call
      # raises Error with form_urlencoded's panic message, as Rust would
      # panic.
      #
      # Mirrors form_urlencoded's +Serializer+ (<tt>src/lib.rs:174-350</tt>).
      #
      # === Example
      #
      #   encoded = Ferro::Url::FormUrlencoded::Serializer.new(+"")
      #     .append_pair("foo", "bar & baz")
      #     .append_pair("saison", "Été+hiver")
      #     .finish
      #   encoded # => "foo=bar+%26+baz&saison=%C3%89t%C3%A9%2Bhiver"
      class Serializer
        class << self
          # Creates a new <tt>application/x-www-form-urlencoded</tt>
          # serializer for the given target.
          #
          # If the target is non-empty, its content is assumed to already be
          # in <tt>application/x-www-form-urlencoded</tt> syntax. Mirrors
          # form_urlencoded's <tt>Serializer::new</tt>
          # (<tt>src/lib.rs:209-215</tt>).
          #
          # [target] String, which the serializer appends to.
          #
          # === Example
          #
          #   Ferro::Url::FormUrlencoded::Serializer.new(+"a=1").append_pair("b", "2").finish # => "a=1&b=2"
          def new(target)
            for_suffix(target, 0)
          end

          # Creates a new <tt>application/x-www-form-urlencoded</tt>
          # serializer for a suffix of the given target, starting at byte
          # +start_position+.
          #
          # If that suffix is non-empty, its content is assumed to already be
          # in <tt>application/x-www-form-urlencoded</tt> syntax. A start past
          # the end of the target panics in form_urlencoded; here it raises
          # +ArgumentError+ with form_urlencoded's message. Mirrors
          # form_urlencoded's <tt>Serializer::for_suffix</tt>
          # (<tt>src/lib.rs:217-236</tt>).
          #
          # [target] String, which the serializer appends to.
          # [start_position] Integer, the byte where the pairs start.
          #
          # === Example
          #
          #   Ferro::Url::FormUrlencoded::Serializer.for_suffix(+"?", 1).append_pair("q", "1").finish # => "?q=1"
          def for_suffix(target, start_position)
            raise TypeError, "no implicit conversion of #{target.class} into String" unless target.is_a?(String)

            Native.form_check_suffix(target, start_position)
            serializer = allocate
            serializer.__send__(:initialize, target, start_position)
            serializer
          end

          # A serializer over a URL's query, for Url#query_pairs_mut.
          private def over_url_query(query)
            serializer = allocate
            serializer.__send__(:initialize, query, nil)
            serializer
          end
        end

        # Holds the target, the start of its suffix (+nil+ for a UrlQuery,
        # whose start is the URL's query), no encoding override, and not
        # finished.
        #
        # [target] String or UrlQuery.
        # [start_position] Integer, or +nil+ for a UrlQuery.
        def initialize(target, start_position)
          @target = target
          @start_position = start_position
          @encoding = nil
          @finished = false
        end

        # Removes any existing name/value pair. Raises Error if called after
        # #finish. Mirrors form_urlencoded's <tt>Serializer::clear</tt>
        # (<tt>src/lib.rs:238-244</tt>).
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"a=1").clear.append_pair("b", "2").finish # => "b=2"
        def clear
          run([:clear], [])
        end

        # Sets the character encoding to be used for names and values before
        # percent-encoding.
        #
        # +new+ is any object that responds to +call+: it takes each name and
        # value as a String and returns the String whose bytes are encoded.
        # The serializer calls it for every name and value of an operation,
        # in form_urlencoded's order, before form_urlencoded runs; an
        # exception it raises stops the operation with nothing written.
        # Mirrors form_urlencoded's <tt>Serializer::encoding_override</tt>
        # (<tt>src/lib.rs:246-250</tt>).
        #
        # [new] Callable from a String to a String, or +nil+ for UTF-8.
        #
        # === Example
        #
        #   latin1 = ->(text) { text.encode("ISO-8859-1").b }
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"").encoding_override(latin1)
        #     .append_pair("q", "é").finish # => "q=%E9"
        def encoding_override(new)
          raise TypeError, "#{new.class} does not respond to call" unless new.nil? || new.respond_to?(:call)

          @encoding = new
          self
        end

        # Serializes and appends a name/value pair. Raises Error if called
        # after #finish. Mirrors form_urlencoded's
        # <tt>Serializer::append_pair</tt> (<tt>src/lib.rs:252-264</tt>).
        #
        # [name] String.
        # [value] String.
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"").append_pair("a", "b c").finish # => "a=b+c"
        def append_pair(name, value)
          run([:append_pair, name, value], [name, value])
        end

        # Serializes and appends a name of parameter without any value.
        # Raises Error if called after #finish. Mirrors form_urlencoded's
        # <tt>Serializer::append_key_only</tt> (<tt>src/lib.rs:266-277</tt>).
        #
        # [name] String.
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"").append_key_only("flag").finish # => "flag"
        def append_key_only(name)
          run([:append_key_only, name], [name])
        end

        # Serializes and appends a number of name/value pairs. This simply
        # calls #append_pair repeatedly. Raises Error if called after
        # #finish. Mirrors form_urlencoded's
        # <tt>Serializer::extend_pairs</tt> (<tt>src/lib.rs:279-307</tt>).
        #
        # [iter] Enumerable of name and value pairs, such as a Hash.
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"").extend_pairs({ "a" => "1", "b" => "2" }).finish # => "a=1&b=2"
        def extend_pairs(iter)
          pairs = Arguments.pairs(iter)
          run([:extend_pairs, pairs], pairs.flatten(1))
        end

        # Serializes and appends a number of names without values. This
        # simply calls #append_key_only repeatedly. Raises Error if called
        # after #finish. Mirrors form_urlencoded's
        # <tt>Serializer::extend_keys_only</tt> (<tt>src/lib.rs:309-330</tt>).
        #
        # [iter] Enumerable of Strings.
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"").extend_keys_only(["a", "b"]).finish # => "a&b"
        def extend_keys_only(iter)
          names = iter.to_a
          run([:extend_keys_only, names], names)
        end

        # Returns the target: the String, or the Url for a serializer from
        # Url#query_pairs_mut. Raises Error if called more than once, where
        # form_urlencoded panics. Mirrors form_urlencoded's
        # <tt>Serializer::finish</tt> (<tt>src/lib.rs:332-350</tt>).
        #
        # === Example
        #
        #   Ferro::Url::FormUrlencoded::Serializer.new(+"").append_pair("a", "1").finish # => "a=1"
        def finish
          raise Error, "url::form_urlencoded::Serializer double finish" if @finished

          @finished = true
          target = @target
          target.is_a?(UrlQuery) ? target.__send__(:url) : target
        end

        # Runs one operation on the target, with the encodings of +texts+
        # computed first, and returns +self+.
        private def run(operation, texts)
          raise Error, "url::form_urlencoded::Serializer finished" if @finished

          encodings = encode(texts)
          target = @target
          if target.is_a?(UrlQuery)
            url = target.__send__(:url)
            url.__send__(:writable!)
            Native.url_query_pairs_mut(Arguments.native(url), operation, encodings)
          else
            target.replace(Native.form_serialize(target, @start_position || 0, operation, encodings))
          end
          self
        end

        # <tt>[[text, bytes], ...]</tt> for each of +texts+ through the
        # encoding override, or +nil+ without one.
        private def encode(texts)
          encoding = @encoding
          return unless encoding

          texts.map { |text| [text, Arguments.encoded(encoding.method(:call).call(text))] }
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
