# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    # SPDX-SnippetComment: OpaqueOrigin and its docs from url 2.5.8
    #   src/origin.rs:113-115
    #++

    # Opaque identifier for URLs that have file or other schemes.
    #
    # Two URLs with an opaque origin are never same-origin, even when they
    # are the same string, so the identifier cannot be the URL. url hands
    # out a fresh number each time instead, and an origin is equal only to
    # itself and its copies.
    #
    # You get one from Origin.new_opaque or Url#origin, inside an
    # Origin::Opaque; there is no other constructor, as url keeps the
    # number private. Two compare equal, and hash alike, by url's +Eq+ and
    # +Hash+. It is frozen and shareable between Ractors.
    #
    # Mirrors url's +OpaqueOrigin+ (<tt>src/origin.rs:113-115</tt>).
    #
    # === Example
    #
    #   a = Ferro::Url::Origin.new_opaque.value
    #   a == a.dup # => true
    #   a == Ferro::Url::Origin.new_opaque.value # => false
    class OpaqueOrigin
      private_class_method :new

      # Holds +native+, url's value, and freezes both.
      #
      # [native] The native opaque origin.
      def initialize(native)
        @native = native.freeze
        freeze
      end

      # Whether +other+ is the same opaque origin, by url's +Eq+.
      #
      # [other] Object.
      #
      # === Example
      #
      #   origin = Ferro::Url::Origin.new_opaque.value
      #   origin == origin # => true
      def ==(other)
        other.is_a?(OpaqueOrigin) && Native.opaque_origin_eq(@native, other.__send__(:native))
      end

      alias eql? ==

      # The hash of url's +Hash+, so equal origins hash alike.
      #
      # === Example
      #
      #   Ferro::Url::Origin.new_opaque.value.hash
      def hash
        [OpaqueOrigin, Native.opaque_origin_hash(@native)].hash
      end

      # url's +Debug+ text, such as <tt>OpaqueOrigin(3)</tt>.
      #
      # === Example
      #
      #   Ferro::Url::Origin.new_opaque.value.inspect # => "OpaqueOrigin(0)"
      def inspect
        Native.opaque_origin_inspect(@native)
      end

      # The native opaque origin, for the native layer.
      private attr_reader :native
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
