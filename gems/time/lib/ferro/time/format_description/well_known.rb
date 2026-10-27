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
      # SPDX-SnippetComment: the well-known formats and their docs from time
      #   0.3.55 src/format_description/well_known/rfc2822.rs and rfc3339.rs
      #++

      # Well-known formats, typically standards.
      #
      # RFC 3339 for APIs and logs, RFC 2822 for mail headers, ISO 8601 for
      # nearly everything else: each has edge cases a hand-written
      # description gets wrong, from leap seconds to obsolete zone names.
      # time implements each standard directly, and so does this module, by
      # binding time's.
      #
      # Pass Rfc3339 or Rfc2822 itself, the class, wherever a description
      # goes, as Rust passes the unit struct; Iso8601 takes a configuration.
      #
      # Mirrors time's <tt>format_description::well_known</tt>
      # (<tt>src/format_description/mod.rs:20-29</tt>).
      #
      # === Examples
      #
      #   well_known = Ferro::Time::FormatDescription::WellKnown
      #   at = Ferro::Time::OffsetDateTime.parse("Sat, 12 Jun 1993 13:25:19 GMT", well_known::Rfc2822)
      #   at.format(well_known::Rfc3339) # => "1993-06-12T13:25:19Z"
      module WellKnown
        # The format described in RFC 2822 (https://tools.ietf.org/html/rfc2822#section-3.3).
        #
        # Example: Fri, 21 Nov 1997 09:55:06 -0600
        #
        # Mail and HTTP headers carry dates this way. Pass the class itself
        # as a description. Formatting needs a date, a time, and an offset,
        # so only UtcDateTime and OffsetDateTime format with it; the others
        # raise +TypeError+ with time's assertion, which Rust's compiler
        # would refuse. Any type parses with it, raising Error::Parse when
        # the input lacks what the type needs.
        #
        # Mirrors time's +Rfc2822+ (<tt>src/format_description/well_known/rfc2822.rs:1-30</tt>).
        #
        # === Examples
        #
        #   rfc2822 = Ferro::Time::FormatDescription::WellKnown::Rfc2822
        #   Ferro::Time::OffsetDateTime.parse("Sat, 12 Jun 1993 13:25:19 GMT", rfc2822).to_s
        #   # => "1993-06-12 13:25:19.0 +00:00:00"
        #
        #   Ferro::Time::UtcDateTime.from_unix_timestamp(0).format(rfc2822) # => "Thu, 01 Jan 1970 00:00:00 +0000"
        class Rfc2822
          private_class_method :new
        end

        # The format described in RFC 3339 (https://tools.ietf.org/html/rfc3339#section-5.6).
        #
        # Format example: 1985-04-12T23:20:50.52Z
        #
        # JSON APIs and logs carry instants this way. Pass the class itself
        # as a description. Formatting needs a date, a time, and an offset,
        # so only UtcDateTime and OffsetDateTime format with it; the others
        # raise +TypeError+ with time's assertion, which Rust's compiler
        # would refuse.
        #
        # Mirrors time's +Rfc3339+ (<tt>src/format_description/well_known/rfc3339.rs:1-30</tt>).
        #
        # === Examples
        #
        #   rfc3339 = Ferro::Time::FormatDescription::WellKnown::Rfc3339
        #   Ferro::Time::OffsetDateTime.parse("1985-04-12T23:20:50.52Z", rfc3339).to_s
        #   # => "1985-04-12 23:20:50.52 +00:00:00"
        #
        #   Ferro::Time::Date::MIN.format(rfc3339) # raises TypeError
        class Rfc3339
          private_class_method :new
        end
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
