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
      # SPDX-SnippetComment: ProcessingError, its variants, and their docs
      #   from idna 1.1.0 src/uts46.rs:421-433
      #++

      # The failure outcome of Uts46#process.
      #
      # #process returns a success or a failure, and a failure still leaves
      # output in the sink when the error policy marks errors. Rescue the
      # class, read the sink, and show the person where the domain went
      # wrong.
      #
      # Each of idna's variants is a subclass. idna's +ProcessingError+ has
      # no +Display+ text, so each message is the variant's name, its
      # +Debug+ text.
      #
      # Mirrors idna's <tt>uts46::ProcessingError</tt>
      # (<tt>src/uts46.rs:421-433</tt>).
      #
      # === Example
      #
      #   sink = +""
      #   begin
      #     Ferro::Idna::Uts46::Uts46.new.process("xn--a.example", Ferro::Idna::AsciiDenyList::URL,
      #       Ferro::Idna::Uts46::Hyphens::Allow, Ferro::Idna::Uts46::ErrorPolicy::MarkErrors,
      #       -> (*) { true }, sink, nil)
      #   rescue Ferro::Idna::Uts46::ProcessingError::ValidityError
      #     sink # => "\u{FFFD}.example"
      #   end
      class ProcessingError < StandardError
        # There was a validity error according to the chosen options.
        #
        # With ErrorPolicy::FailFast, there is no output. Otherwise, output
        # was written to the sink and the output contains at least one
        # U+FFFD REPLACEMENT CHARACTER to denote an error.
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::ProcessingError::ValidityError.new.message # => "ValidityError"
        class ValidityError < ProcessingError
          # Creates the error. Without a +message+, or with +nil+, the
          # message is the variant's name.
          #
          # [message] String, the error message.
          #
          # === Example
          #
          #   Ferro::Idna::Uts46::ProcessingError::ValidityError.new
          def initialize(message = nil)
            super(message || "ValidityError")
          end
        end

        # The sink failed. The partial output written to the sinks must not
        # be used.
        #
        # This gem's sinks are Strings, which never fail, so #process never
        # raises it; the class exists because idna's enum has the variant.
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::ProcessingError::SinkError.new.message # => "SinkError"
        class SinkError < ProcessingError
          # Creates the error. Without a +message+, or with +nil+, the
          # message is the variant's name.
          #
          # [message] String, the error message.
          #
          # === Example
          #
          #   Ferro::Idna::Uts46::ProcessingError::SinkError.new
          def initialize(message = nil)
            super(message || "SinkError")
          end
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
