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
      # SPDX-SnippetComment: ErrorPolicy, its variants, and their docs from
      #   idna 1.1.0 src/uts46.rs:391-401
      #++

      # Policy for customizing behavior in case of an error.
      #
      # A lookup wants to stop at the first error and use nothing. A
      # settings screen wants the whole domain back, with each error marked,
      # to show the person what is wrong.
      #
      # Pass one of the two constants to Uts46#process. idna marks the enum
      # +non_exhaustive+, so a later idna may add more. Variants compare by
      # identity, as idna derives +PartialEq+.
      #
      # Mirrors idna's <tt>uts46::ErrorPolicy</tt>
      # (<tt>src/uts46.rs:391-401</tt>).
      #
      # === Example
      #
      #   policy = Ferro::Idna::Uts46::ErrorPolicy::MarkErrors
      class ErrorPolicy
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
        #   Ferro::Idna::Uts46::ErrorPolicy::FailFast.inspect # => "Ferro::Idna::Uts46::ErrorPolicy::FailFast"
        def inspect
          "Ferro::Idna::Uts46::ErrorPolicy::#{@name}"
        end

        # The variant's name, for the native layer.
        private attr_reader :name

        # Return as early as possible without producing output in case of error.
        FailFast = new(:FailFast)

        # In case of error, mark errors with the REPLACEMENT CHARACTER. (The
        # output containing REPLACEMENT CHARACTERs may be shown to the user to
        # illustrate what was wrong but must not be used for naming in a
        # network protocol.)
        MarkErrors = new(:MarkErrors)
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
