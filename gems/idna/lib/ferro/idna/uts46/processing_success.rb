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
      # SPDX-SnippetComment: ProcessingSuccess, its variants, and their docs from
      #   idna 1.1.0 src/uts46.rs:403-419
      #++

      # The success outcome of Uts46#process.
      #
      # #process writes to a sink only when the output differs from the
      # input, so a caller learns which of the two to use from this value.
      #
      # Uts46#process returns one of the two constants. They compare by
      # identity, as idna derives +PartialEq+.
      #
      # Mirrors idna's <tt>uts46::ProcessingSuccess</tt>
      # (<tt>src/uts46.rs:403-419</tt>).
      #
      # === Example
      #
      #   sink = +""
      #   Ferro::Idna::Uts46::Uts46.new.process("example.com", Ferro::Idna::AsciiDenyList::URL,
      #     Ferro::Idna::Uts46::Hyphens::Allow, Ferro::Idna::Uts46::ErrorPolicy::FailFast,
      #     -> (*) { false }, sink, nil)
      #   # => Ferro::Idna::Uts46::ProcessingSuccess::Passthrough
      class ProcessingSuccess
        private_class_method :new

        # Creates the variant named +name+. The constants are the only
        # instances.
        #
        # [name] Symbol, the idna variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        # The constant that holds this variant.
        #
        # === Example
        #
        #   Ferro::Idna::Uts46::ProcessingSuccess::Passthrough.inspect # => "Ferro::Idna::Uts46::ProcessingSuccess::Passthrough"
        def inspect
          "Ferro::Idna::Uts46::ProcessingSuccess::#{@name}"
        end

        # The variant's name, for the native layer.
        private attr_reader :name

        # There were no errors. The caller must consider the input to be the
        # output. (The input is then ASCII.)
        Passthrough = new(:Passthrough)

        # There were no errors. The caller must consider what was written to
        # the sink to be the output.
        WroteToSink = new(:WroteToSink)
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
