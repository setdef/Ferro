# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

module Ferro
  module Rfd
    # What the four dialogs share as rfd's builders: rfd's terminal methods
    # take +self+ (<tt>src/file_dialog.rs:121-174</tt>, <tt>:266-330</tt>,
    # <tt>src/message_dialog.rs:81-84</tt>, <tt>:147-150</tt>), so a
    # builder works once, and here any call on a builder a terminal method
    # has used raises +IOError+, as a closed IO does (ADR 001, 2026-11-05).
    # rfd has no such type, so the module is private.
    module Builder # :nodoc:
      # Marks this builder used up by +name+, its terminal method; raises
      # +IOError+ if one already did, and +FrozenError+ for a frozen
      # builder, which cannot be used up.
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
