# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Arboard
    # What Get, Set, and Clear share as arboard's builders: Rust's
    # terminal methods take +self+ (<tt>src/lib.rs:189-212</tt>,
    # <tt>:227-263</tt>, <tt>:275</tt>), so a builder works once, and here
    # any call on a builder a terminal method has used raises +IOError+, as
    # a closed IO does (ADR 001, 2026-11-05). arboard has no such type, so
    # the module is private.
    module Builder # :nodoc:
      # Marks this builder used up by +name+, its terminal method; raises
      # +IOError+ if one already did.
      private def consume(name)
        live!
        @consumed_by = name
      end

      # Raises +IOError+ once a terminal method has used this builder up.
      private def live!
        raise IOError, "#{self.class} consumed by #{@consumed_by}" if @consumed_by
      end
    end

    private_constant :Builder
  end
end
