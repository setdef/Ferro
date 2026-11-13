# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    module FormatDescription
      # What every format item and component variant shares: each is a
      # tuple variant in time, holding one field Rust reaches by position,
      # as in <tt>Component::Day(modifier) => ...</tt>.
      #
      # So +new+ takes the field by position, #deconstruct and #to_a give
      # it back, and no reader names it, since time names none (ADR 001,
      # amendment of 2026-11-05: tuple variants). Ruby's +Data+ would name
      # it in a reader, a keyword, +to_h+, and +with+, so a variant is a
      # plain class. It is frozen, compares by class and field as time's
      # derived +PartialEq+ and +Eq+ do, and hashes the same way; +dup+ and
      # +clone+ stay frozen, as a +Data+ value's do.
      #
      # The family module (an item family, or Component) defines a private
      # +check+, which refuses a field of the wrong type as Rust's type
      # checker would and returns the field to keep. Private to the gem.
      module TupleVariant # :nodoc:
        # Creates the variant holding +field+, checked by the family.
        #
        # [field] The variant's one field.
        def initialize(field)
          @field = __send__(:check, field)
          freeze
        end

        # The variant's one field, in an Array of one, for Ruby's array
        # patterns: <tt>in StringLiteral[text]</tt>.
        def deconstruct
          [@field]
        end

        # The variant's fields as an Array, as #deconstruct gives them.
        def to_a
          deconstruct
        end

        # Whether +other+ is the same variant with an equal field.
        #
        # [other] Object.
        def ==(other)
          other.instance_of?(self.class) && (_ = other).deconstruct == deconstruct
        end

        # Whether +other+ is the same variant with an +eql?+ field, so
        # variants work as Hash keys.
        #
        # [other] Object.
        def eql?(other)
          other.instance_of?(self.class) && (_ = other).deconstruct.eql?(deconstruct)
        end

        # A hash of the variant and its field, agreeing with #eql?.
        def hash
          [self.class, @field].hash
        end

        # Keeps a copy frozen, as +dup+ and +clone+ keep a +Data+ value.
        private def initialize_copy(original)
          super
          freeze
        end
      end
      private_constant :TupleVariant
    end
  end
end
