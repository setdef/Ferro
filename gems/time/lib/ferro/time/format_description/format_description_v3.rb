# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    module FormatDescription
      #--
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: MIT OR Apache-2.0
      # SPDX-SnippetCopyrightText: Jacob Pratt et al.
      # SPDX-SnippetComment: FormatDescriptionV3 and its docs from time 0.3.55
      #   src/format_description/format_description_v3.rs:1-51
      #++

      # A complete description of how to format and parse a type.
      #
      # A description written as text has to be read, checked, and turned
      # into something a formatter can follow, and doing that on every call
      # wastes the work. A FormatDescriptionV3 is a description time has
      # already parsed and checked, ready to use as often as you like.
      #
      # Both for forwards compatibility and to enable optimizations, time
      # keeps this type deliberately opaque: it cannot be built from parts
      # or taken apart, only made by FormatDescription.parse_owned or
      # FormatDescription.parse_borrowed and passed to +format+ and +parse+.
      # It has no equality of its own, as time derives none.
      #
      # A FormatDescriptionV3 is frozen and shareable between Ractors.
      #
      # Mirrors time's +FormatDescriptionV3+
      # (<tt>src/format_description/format_description_v3.rs:11-51</tt>).
      #
      # === Examples
      #
      #   description = Ferro::Time::FormatDescription.parse_owned(3, "[hour]:[minute]")
      #   Ferro::Time::Time.parse("09:05", description).to_s # => "9:05:00.0"
      #   Ferro::Time::Time.from_hms(23, 0, 0).format(description) # => "23:00"
      class FormatDescriptionV3
        # The description itself. Rust's +to_owned+ turns a description
        # that borrows its input into one that owns it; a Ruby description
        # always owns what it holds. Mirrors time's
        # <tt>FormatDescriptionV3::to_owned</tt>
        # (<tt>src/format_description/format_description_v3.rs:35-48</tt>).
        #
        # === Example
        #
        #   description = Ferro::Time::FormatDescription.parse_borrowed(3, "[year]")
        #   description.to_owned.equal?(description) # => true
        def to_owned
          self
        end

        # time's +Debug+ text for the description.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[day]").inspect # => "Day { padding: Zero }"
        def inspect
          Native.format_description_debug(self)
        end

        # The description itself, which is frozen, as #to_owned is.
        #
        # === Example
        #
        #   description = Ferro::Time::FormatDescription.parse_owned(3, "[day]")
        #   description.dup.equal?(description) # => true
        def dup
          self
        end

        # The description itself, as #dup is. Asking for an unfrozen clone
        # raises +ArgumentError+, as it does for an Integer.
        #
        # [freeze] +true+, +false+, or +nil+, as Object#clone takes it.
        #
        # === Example
        #
        #   description = Ferro::Time::FormatDescription.parse_owned(3, "[day]")
        #   description.clone.equal?(description) # => true
        def clone(freeze: true)
          raise ArgumentError, "can't unfreeze Ferro::Time::FormatDescription::FormatDescriptionV3" if freeze == false

          self
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
