# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: Jacob Pratt et al.
    # SPDX-SnippetComment: the format description parser and its docs from
    #   time 0.3.55 src/format_description/mod.rs and
    #   src/format_description/parse/mod.rs
    #++

    # Descriptions of how to format and parse dates and times.
    #
    # A format is easier to read and to keep right as a description than as
    # code: <tt>[year]-[month]-[day]</tt> says what a date looks like, and
    # the same description both formats a Date and parses one back. time
    # parses such descriptions and checks them before they are used, and it
    # ships the well-known formats (RFC 3339, RFC 2822, ISO 8601) ready-made
    # under WellKnown.
    #
    # FormatDescription.parse_owned and FormatDescription.parse_borrowed
    # parse a description in time's syntax
    # (https://time-rs.github.io/book/api/format-description.html). Pass
    # the result, or a well-known format, to +format+ and +parse+ on any of
    # the date and time types.
    #
    # Mirrors time's +format_description+ module
    # (<tt>src/format_description/mod.rs</tt>). This gem binds version 3
    # descriptions, which time recommends, whose representation time keeps
    # deliberately opaque. Versions 1 and 2, +strftime+ descriptions, and
    # the format items they return are deferred (plan 007, decision 1).
    #
    # === Examples
    #
    #   description = Ferro::Time::FormatDescription.parse_owned(3, "[year]-[month]-[day]")
    #   date = Ferro::Time::Date.parse("2020-01-02", description)
    #   date.format(description) # => "2020-01-02"
    #
    #   Ferro::Time::FormatDescription.parse_owned(3, "[year")
    #   # raises Ferro::Time::Error::InvalidFormatDescription::UnclosedOpeningBracket
    module FormatDescription
      # Parses a format description of +version+ from +input+, raising an
      # Error::InvalidFormatDescription variant when it is not valid.
      #
      # The version is Rust's const parameter. Version 3 returns a
      # FormatDescriptionV3. Versions 1 and 2 return time's format items,
      # which this gem defers, so they raise +ArgumentError+ naming plan
      # 007; any other version raises +TypeError+ with time's assertion,
      # "invalid version provided", which Rust's compiler would refuse. In
      # Rust the result borrows +input+ where it can; in Ruby it owns what
      # it holds, as parse_owned's does.
      #
      # Mirrors time's <tt>format_description::parse_borrowed</tt>
      # (<tt>src/format_description/parse/mod.rs:124-153</tt>).
      #
      # [version] Integer, 3.
      # [input] String, the description.
      #
      # === Example
      #
      #   description = Ferro::Time::FormatDescription.parse_borrowed(3, "[hour]:[minute]")
      #   Ferro::Time::Time.from_hms(9, 5, 0).format(description) # => "09:05"
      def self.parse_borrowed(version, input)
        Native.format_description_parse(version, false, input)
      end

      # Parses a format description of +version+ from +input+, as
      # parse_borrowed does, into a description that owns its contents.
      #
      # Mirrors time's <tt>format_description::parse_owned</tt>
      # (<tt>src/format_description/parse/mod.rs:155-187</tt>).
      #
      # [version] Integer, 3.
      # [input] String, the description.
      #
      # === Example
      #
      #   description = Ferro::Time::FormatDescription.parse_owned(3, "[weekday], [month repr:long] [day]")
      #   Ferro::Time::Date.from_ordinal_date(2026, 300).format(description) # => "Tuesday, October 27"
      def self.parse_owned(version, input)
        Native.format_description_parse(version, true, input)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
