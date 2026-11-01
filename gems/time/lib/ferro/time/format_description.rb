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
    # Version 3, which time recommends, returns a FormatDescriptionV3
    # whose insides time keeps to itself. Versions 1 and 2, and +strftime+
    # descriptions (FormatDescription.parse_strftime_borrowed), return the
    # description as a tree you can read and build by hand: format items
    # (BorrowedFormatItem, OwnedFormatItem) holding literals and
    # components (Component), each component holding its modifier
    # (Modifier). A tree is a description too: pass an item, or an Array
    # of items, wherever a description goes.
    #
    # Mirrors time's +format_description+ module
    # (<tt>src/format_description/mod.rs</tt>), plans 007 and 009.
    #
    # === Examples
    #
    #   description = Ferro::Time::FormatDescription.parse_owned(3, "[year]-[month]-[day]")
    #   date = Ferro::Time::Date.parse("2020-01-02", description)
    #   date.format(description) # => "2020-01-02"
    #
    #   Ferro::Time::FormatDescription.parse_owned(3, "[year")
    #   # raises Ferro::Time::Error::InvalidFormatDescription::UnclosedOpeningBracket
    #
    #   items = Ferro::Time::FormatDescription.parse_strftime_borrowed("%Y-%m-%d")
    #   Ferro::Time::Date.from_ordinal_date(2026, 32).format(items) # => "2026-02-01"
    module FormatDescription
      # Parses a format description of +version+ from +input+, raising an
      # Error::InvalidFormatDescription variant when it is not valid.
      #
      # The version is Rust's const parameter. Version 3 returns a
      # FormatDescriptionV3; versions 1 and 2 return an Array of
      # BorrowedFormatItem, Rust's +Vec+, which is yours to change. A
      # borrowed item cannot hold the nested items of version 2's
      # <tt>[optional]</tt> and <tt>[first]</tt>, so time refuses them here
      # with Error::InvalidFormatDescription::NotSupported; parse_owned
      # reads them. Any
      # other version raises +TypeError+ with time's assertion, "invalid
      # version provided", which Rust's compiler would refuse. In Rust the
      # result borrows +input+ where it can; in Ruby it owns what it holds,
      # as parse_owned's does.
      #
      # Mirrors time's <tt>format_description::parse_borrowed</tt>
      # (<tt>src/format_description/parse/mod.rs:124-153</tt>).
      #
      # [version] Integer, 1, 2, or 3.
      # [input] String, the description.
      #
      # === Example
      #
      #   description = Ferro::Time::FormatDescription.parse_borrowed(3, "[hour]:[minute]")
      #   Ferro::Time::Time.from_hms(9, 5, 0).format(description) # => "09:05"
      #
      #   items = Ferro::Time::FormatDescription.parse_borrowed(2, "[day]")
      #   items.first.component # => Ferro::Time::FormatDescription::Component::Day.new(Ferro::Time::FormatDescription::Modifier::Day.default)
      def self.parse_borrowed(version, input)
        return Native.format_description_parse(version, false, input) unless [1, 2].include?(version)

        Native.format_description_items(version, input).map { |item| Arguments.decode_borrowed(item) }
      end

      # Parses a format description of +version+ from +input+, as
      # parse_borrowed does, into a description that owns its contents.
      # Versions 1 and 2 return one OwnedFormatItem: the description's one
      # item, or a Compound of its items
      # (<tt>src/format_description/parse/lexer_ast.rs:296-301</tt>).
      #
      # Mirrors time's <tt>format_description::parse_owned</tt>
      # (<tt>src/format_description/parse/mod.rs:155-187</tt>).
      #
      # [version] Integer, 1, 2, or 3.
      # [input] String, the description.
      #
      # === Example
      #
      #   description = Ferro::Time::FormatDescription.parse_owned(3, "[weekday], [month repr:long] [day]")
      #   Ferro::Time::Date.from_ordinal_date(2026, 300).format(description) # => "Tuesday, October 27"
      def self.parse_owned(version, input)
        return Native.format_description_parse(version, true, input) unless [1, 2].include?(version)

        Arguments.decode_owned(Native.format_description_item(version, input))
      end

      # Parses a version 1 format description from +input+, as
      # <tt>parse_borrowed(1, input)</tt> does.
      #
      # Deprecated since time 0.3.48: use parse_borrowed with the version
      # for clarity. It warns in Ruby's +:deprecated+ category, which Ruby
      # shows when <tt>Warning[:deprecated]</tt> is on. Mirrors time's
      # <tt>format_description::parse</tt>
      # (<tt>src/format_description/parse/mod.rs:96-117</tt>).
      #
      # [input] String, the description.
      def self.parse(input)
        warn("Ferro::Time::FormatDescription.parse is deprecated since time 0.3.48; use parse_borrowed with the version",
          category: :deprecated, uplevel: 1)
        parse_borrowed(1, input)
      end

      # Parses a +strftime+ description from +input+ into an Array of
      # BorrowedFormatItem, raising an Error::InvalidFormatDescription
      # variant when it is not valid.
      #
      # +strftime+ is the C library's format language
      # (https://man7.org/linux/man-pages/man3/strftime.3.html), which
      # Ruby's <tt>::Time#strftime</tt> speaks too, though not to the
      # letter: time reads it by its own rules, and the items it returns
      # say exactly what each directive means here.
      #
      # Mirrors time's <tt>format_description::parse_strftime_borrowed</tt>
      # (<tt>src/format_description/parse/strftime.rs:12-29</tt>).
      #
      # [input] String, the description.
      #
      # === Example
      #
      #   items = Ferro::Time::FormatDescription.parse_strftime_borrowed("%H:%M")
      #   Ferro::Time::Time.from_hms(16, 5, 0).format(items) # => "16:05"
      def self.parse_strftime_borrowed(input)
        Native.format_description_strftime_items(input).map { |item| Arguments.decode_borrowed(item) }
      end

      # Parses a +strftime+ description from +input+, as
      # parse_strftime_borrowed does, into one OwnedFormatItem: a Compound
      # of the items.
      #
      # Mirrors time's <tt>format_description::parse_strftime_owned</tt>
      # (<tt>src/format_description/parse/strftime.rs:31-40</tt>).
      #
      # [input] String, the description.
      #
      # === Example
      #
      #   item = Ferro::Time::FormatDescription.parse_strftime_owned("%Y")
      #   item.compound.length # => 1
      def self.parse_strftime_owned(input)
        Arguments.decode_owned(Native.format_description_strftime_item(input))
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
