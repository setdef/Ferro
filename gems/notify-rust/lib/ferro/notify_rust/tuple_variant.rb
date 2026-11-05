# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module NotifyRust
    # The methods of a Data class whose Rust variant is a tuple, such as
    # <tt>Timeout::Milliseconds(u32)</tt> or <tt>Hint::Custom(String,
    # String)</tt>.
    #
    # Rust reaches a tuple variant's fields by position, with a pattern:
    # <tt>Timeout::Milliseconds(ms) => ...</tt>. Data answers
    # +deconstruct+ already; #to_a returns the same Array, so
    # <tt>ms, = timeout.to_a</tt> and the pattern
    # <tt>in Timeout::Milliseconds[ms]</tt> both read as Rust's does
    # (ADR 001, amendment of 2026-11-05: tuple variants).
    #
    # === Example
    #
    #   Ferro::NotifyRust::Timeout::Milliseconds.new(6000).to_a # => [6000]
    module TupleVariant # :nodoc:
      # The variant's fields, in order, as +deconstruct+ gives them.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Custom.new("k", "v").to_a # => ["k", "v"]
      def to_a
        deconstruct
      end
    end

    private_constant :TupleVariant
  end
end
