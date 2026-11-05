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
      # SPDX-SnippetComment: BorrowedFormatItem, OwnedFormatItem, their variants,
      #   conversions, and docs from time 0.3.55
      #   src/format_description/borrowed_format_item.rs and
      #   src/format_description/owned_format_item.rs
      #++

      # What every format item shares: the checks +new+ makes, and
      # +inspect+. Private to the gem.
      module Item # :nodoc:
        # Checks each field's type as Rust's type checker would, and keeps
        # a frozen copy: a binary String for +Literal+, a UTF-8 one for
        # +StringLiteral+ (raising +EncodingError+ when it is not valid
        # UTF-8, as Rust's +str+ must be), and frozen Arrays of items of the
        # same family.
        def initialize(**fields)
          super(**Arguments.item_fields(_ = self, fields))
        end

        # time's +Debug+ for the item: a literal as is, a component as its
        # variant, a compound as a list.
        def debug
          Native.format_item_debug(0, Arguments.encode_item(_ = self))
        end
      end
      private_constant :Item

      # A complete description of how to format and parse a type, as
      # versions 1 and 2 and +strftime+ descriptions spell it out.
      #
      # time recommends version 3 descriptions, whose insides it keeps to
      # itself. The older versions give you the description as a tree of
      # items you can read and build by hand: literal text, components,
      # compounds, optional parts, and alternatives.
      #
      # BorrowedFormatItem is a module, and each variant is a +Data+ class
      # that includes it. FormatDescription.parse_borrowed with version 1
      # or 2, and FormatDescription.parse_strftime_borrowed, return an
      # Array of them. Pass an item, or an Array of items, to +format+ and
      # +parse+ on any date and time type. In Rust a borrowed item points
      # into the string it was parsed from; in Ruby it holds its own
      # frozen copy, so it differs from an OwnedFormatItem only by class.
      # time never compares the two, and neither does this gem.
      #
      # Mirrors time's <tt>format_description::BorrowedFormatItem</tt>
      # (<tt>src/format_description/borrowed_format_item.rs:12-144</tt>),
      # plan 009. Its +Literal+ variant, of raw bytes, is deprecated since
      # time 0.3.48 in favor of StringLiteral, and naming it warns.
      #
      # === Example
      #
      #   items = Ferro::Time::FormatDescription.parse_borrowed(2, "[hour]:[minute]")
      #   items.length # => 3
      #   items[1] # => Ferro::Time::FormatDescription::BorrowedFormatItem::StringLiteral.new(":")
      #   Ferro::Time::Time.from_hms(9, 5, 0).format(items) # => "09:05"
      module BorrowedFormatItem
        include Item

        # The item that holds +value+: a Component item for a component,
        # and a Compound for an Array of borrowed items. Mirrors time's
        # <tt>From<Component></tt> and <tt>From<&[BorrowedFormatItem]></tt>
        # for +BorrowedFormatItem+
        # (<tt>src/format_description/borrowed_format_item.rs:80-104</tt>).
        #
        # [value] Component, or an Array of BorrowedFormatItem.
        #
        # === Example
        #
        #   day = Ferro::Time::FormatDescription::Component::Day.new(Ferro::Time::FormatDescription::Modifier::Day.default)
        #   Ferro::Time::FormatDescription::BorrowedFormatItem.from(day)
        #   # => Ferro::Time::FormatDescription::BorrowedFormatItem::Component.new(day)
        def self.from(value)
          case value
          when FormatDescription::Component then Component.new(value)
          when Array then Compound.new(value)
          else raise TypeError, "no implicit conversion of #{value.class} into #{name}"
          end
        end

        # Bytes that are formatted as-is.
        #
        # These bytes should be UTF-8, but need not be; time passes them
        # through <tt>String::from_utf8_lossy</tt> when it has to. The
        # literal is a frozen binary copy of the String given.
        #
        # Deprecated since time 0.3.48: use StringLiteral instead; raw
        # bytes are not recommended. Naming it warns, in the :deprecated
        # category.
        #
        # Mirrors time's <tt>BorrowedFormatItem::Literal</tt>
        # (<tt>src/format_description/borrowed_format_item.rs:16-24</tt>).
        class Literal < Data.define(:literal)
          include BorrowedFormatItem

          ##
          # :attr_reader: literal
          # The bytes, a frozen binary String.

          # Whether +other+ is the same item, or a StringLiteral of the same
          # bytes, as time's +PartialEq+ has it
          # (<tt>src/format_description/borrowed_format_item.rs:59-78</tt>).
          #
          # [other] Object.
          def ==(other)
            super || (other.is_a?(BorrowedFormatItem::StringLiteral) && literal.b == other.literal.b)
          end
        end

        # A string that is formatted as-is.
        #
        # Mirrors time's <tt>BorrowedFormatItem::StringLiteral</tt>
        # (<tt>src/format_description/borrowed_format_item.rs:25-26</tt>).
        #
        # === Example
        #
        #   dash = Ferro::Time::FormatDescription::BorrowedFormatItem::StringLiteral.new("-")
        #   Ferro::Time::Date::MIN.format(dash) # => "-"
        class StringLiteral < Data.define(:literal)
          include BorrowedFormatItem

          ##
          # :attr_reader: literal
          # The text, a frozen UTF-8 String.

          # Whether +other+ is the same item, or a deprecated Literal of the same
          # bytes, as time's +PartialEq+ has it
          # (<tt>src/format_description/borrowed_format_item.rs:59-78</tt>).
          #
          # [other] Object.
          def ==(other)
            super || (other.is_a?(LITERALS.fetch(:Literal)) && literal.b == other.literal.b)
          end
        end

        # A minimal representation of a single non-literal item.
        #
        # Mirrors time's <tt>BorrowedFormatItem::Component</tt>
        # (<tt>src/format_description/borrowed_format_item.rs:27-28</tt>).
        #
        # === Example
        #
        #   minute = Ferro::Time::FormatDescription::Component::Minute.new(Ferro::Time::FormatDescription::Modifier::Minute.default)
        #   item = Ferro::Time::FormatDescription::BorrowedFormatItem::Component.new(minute)
        #   item == minute # => true
        class Component < Data.define(:component)
          include BorrowedFormatItem

          ##
          # :attr_reader: component
          # The FormatDescription::Component.

          # Whether +other+ is the same item, or the component this item
          # holds, as time's <tt>PartialEq<Component></tt> has it
          # (<tt>src/format_description/borrowed_format_item.rs:118-123</tt>).
          #
          # [other] Object.
          def ==(other)
            other.is_a?(FormatDescription::Component) ? component.eql?(other) : super
          end
        end

        # A series of literals or components that collectively form a
        # partial or complete description.
        #
        # Mirrors time's <tt>BorrowedFormatItem::Compound</tt>
        # (<tt>src/format_description/borrowed_format_item.rs:29-31</tt>).
        # Rust's <tt>TryFrom<BorrowedFormatItem></tt> for a slice is
        # #compound here: Ruby's Array gains no conversion.
        #
        # === Example
        #
        #   literal = Ferro::Time::FormatDescription::BorrowedFormatItem::StringLiteral.new("")
        #   compound = Ferro::Time::FormatDescription::BorrowedFormatItem::Compound.new([literal])
        #   compound == [literal] # => true
        class Compound < Data.define(:compound)
          include BorrowedFormatItem

          ##
          # :attr_reader: compound
          # The items, a frozen Array of BorrowedFormatItem.

          # Whether +other+ is the same item, or an Array of the same items,
          # as time's <tt>PartialEq<&[Self]></tt> has it
          # (<tt>src/format_description/borrowed_format_item.rs:132-137</tt>). <tt>array ==
          # compound</tt> stays Ruby's +false+: Array's equality is not
          # this gem's to change.
          #
          # [other] Object.
          def ==(other)
            other.is_a?(Array) ? compound == other : super
          end
        end

        # A FormatItem that may or may not be present when parsing. If
        # parsing fails, there will be no effect on the resulting value.
        #
        # This variant has no effect on formatting, as the value is
        # guaranteed to be present.
        #
        # Mirrors time's <tt>BorrowedFormatItem::Optional</tt>
        # (<tt>src/format_description/borrowed_format_item.rs:32-36</tt>).
        #
        # === Example
        #
        #   fd = Ferro::Time::FormatDescription
        #   second = fd::BorrowedFormatItem.from(fd::Component::Second.new(fd::Modifier::Second.default))
        #   optional = fd::BorrowedFormatItem::Optional.new(second)
        #   Ferro::Time::Time.from_hms(9, 5, 7).format(optional) # => "07"
        class Optional < Data.define(:item)
          include BorrowedFormatItem

          ##
          # :attr_reader: item
          # The BorrowedFormatItem that may be absent.
        end

        # A series of FormatItems where, when parsing, the first successful
        # parse is used. When formatting, the first element of the slice is
        # used. An empty slice is a no-op when formatting or parsing.
        #
        # Mirrors time's <tt>BorrowedFormatItem::First</tt>
        # (<tt>src/format_description/borrowed_format_item.rs:37-41</tt>).
        #
        # === Example
        #
        #   fd = Ferro::Time::FormatDescription
        #   first = fd::BorrowedFormatItem::First.new([fd::BorrowedFormatItem::StringLiteral.new("a"), fd::BorrowedFormatItem::StringLiteral.new("b")])
        #   Ferro::Time::Date::MIN.format(first) # => "a"
        class First < Data.define(:items)
          include BorrowedFormatItem

          ##
          # :attr_reader: items
          # The alternatives, a frozen Array of BorrowedFormatItem.
        end

        # The deprecated variant by name, so the gem reaches it without
        # warning. Private to the gem.
        LITERALS = { Literal: Literal }.freeze
        private_constant :LITERALS

        deprecate_constant :Literal
      end

      # A complete description of how to format and parse a type, holding
      # its contents.
      #
      # The same tree as BorrowedFormatItem, in a class of its own.
      # FormatDescription.parse_owned with version 1 or 2 returns one
      # OwnedFormatItem: the item itself when the description has exactly
      # one, and a Compound of its items otherwise, as time shapes it
      # (<tt>src/format_description/parse/lexer_ast.rs:296-301</tt>).
      # FormatDescription.parse_strftime_owned always returns a Compound.
      # In Rust the owned form needs no lifetime; in Ruby both forms hold
      # their own frozen contents.
      #
      # Mirrors time's <tt>format_description::OwnedFormatItem</tt>
      # (<tt>src/format_description/owned_format_item.rs:12-190</tt>),
      # plan 009. Its +Literal+ variant is deprecated since time 0.3.48 in
      # favor of StringLiteral, and naming it warns.
      #
      # === Example
      #
      #   item = Ferro::Time::FormatDescription.parse_owned(2, "[year]-[month]")
      #   item.compound.length # => 3
      #   Ferro::Time::Date.from_ordinal_date(2026, 1).format(item) # => "2026-01"
      module OwnedFormatItem
        include Item

        # The owned item for +value+: a Component item for a component, the
        # owned copy of a borrowed item, or a Compound for an Array of
        # borrowed or of owned items (an empty Array is an empty Compound).
        # Mirrors time's +From+ impls for +OwnedFormatItem+
        # (<tt>src/format_description/owned_format_item.rs:78-131</tt>,
        # <tt>:145-150</tt>).
        #
        # [value] Component, BorrowedFormatItem, or an Array of
        #         BorrowedFormatItem or of OwnedFormatItem.
        #
        # === Example
        #
        #   borrowed = Ferro::Time::FormatDescription::BorrowedFormatItem::StringLiteral.new("T")
        #   Ferro::Time::FormatDescription::OwnedFormatItem.from(borrowed)
        #   # => Ferro::Time::FormatDescription::OwnedFormatItem::StringLiteral.new("T")
        def self.from(value)
          case value
          when FormatDescription::Component then Component.new(value)
          when BorrowedFormatItem then Arguments.owned_item(value)
          when Array then Compound.new(Arguments.owned_items(value))
          else raise TypeError, "no implicit conversion of #{value.class} into #{name}"
          end
        end

        # Bytes that are formatted as-is.
        #
        # These bytes should be UTF-8, but need not be; time passes them
        # through <tt>String::from_utf8_lossy</tt> when it has to.
        #
        # Deprecated since time 0.3.48: use StringLiteral instead; raw
        # bytes are not recommended. Naming it warns, in the :deprecated
        # category.
        #
        # Mirrors time's <tt>OwnedFormatItem::Literal</tt>
        # (<tt>src/format_description/owned_format_item.rs:15-23</tt>).
        class Literal < Data.define(:literal)
          include OwnedFormatItem

          ##
          # :attr_reader: literal
          # The bytes, a frozen binary String.

          # Whether +other+ is the same item, or a StringLiteral of the same
          # bytes, as time's +PartialEq+ has it
          # (<tt>src/format_description/owned_format_item.rs:57-76</tt>).
          #
          # [other] Object.
          def ==(other)
            super || (other.is_a?(OwnedFormatItem::StringLiteral) && literal.b == other.literal.b)
          end
        end

        # A string that is formatted as-is.
        #
        # Mirrors time's <tt>OwnedFormatItem::StringLiteral</tt>
        # (<tt>src/format_description/owned_format_item.rs:24-25</tt>).
        class StringLiteral < Data.define(:literal)
          include OwnedFormatItem

          ##
          # :attr_reader: literal
          # The text, a frozen UTF-8 String.

          # Whether +other+ is the same item, or a deprecated Literal of the same
          # bytes, as time's +PartialEq+ has it
          # (<tt>src/format_description/owned_format_item.rs:57-76</tt>).
          #
          # [other] Object.
          def ==(other)
            super || (other.is_a?(LITERALS.fetch(:Literal)) && literal.b == other.literal.b)
          end
        end

        # A minimal representation of a single non-literal item.
        #
        # Mirrors time's <tt>OwnedFormatItem::Component</tt>
        # (<tt>src/format_description/owned_format_item.rs:26-27</tt>).
        class Component < Data.define(:component)
          include OwnedFormatItem

          ##
          # :attr_reader: component
          # The FormatDescription::Component.

          # Whether +other+ is the same item, or the component this item
          # holds, as time's <tt>PartialEq<Component></tt> has it
          # (<tt>src/format_description/owned_format_item.rs:164-169</tt>).
          #
          # [other] Object.
          def ==(other)
            other.is_a?(FormatDescription::Component) ? component.eql?(other) : super
          end
        end

        # A series of literals or components that collectively form a
        # partial or complete description.
        #
        # Mirrors time's <tt>OwnedFormatItem::Compound</tt>
        # (<tt>src/format_description/owned_format_item.rs:28-30</tt>).
        # Rust's <tt>TryFrom<OwnedFormatItem></tt> for a +Vec+ is #compound
        # here: Ruby's Array gains no conversion.
        class Compound < Data.define(:compound)
          include OwnedFormatItem

          ##
          # :attr_reader: compound
          # The items, a frozen Array of OwnedFormatItem.

          # Whether +other+ is the same item, or an Array of the same items,
          # as time's <tt>PartialEq<&[Self]></tt> has it
          # (<tt>src/format_description/owned_format_item.rs:178-183</tt>). <tt>array ==
          # compound</tt> stays Ruby's +false+: Array's equality is not
          # this gem's to change.
          #
          # [other] Object.
          def ==(other)
            other.is_a?(Array) ? compound == other : super
          end
        end

        # A FormatItem that may or may not be present when parsing. If
        # parsing fails, there will be no effect on the resulting value.
        #
        # This variant has no effect on formatting, as the value is
        # guaranteed to be present.
        #
        # Mirrors time's <tt>OwnedFormatItem::Optional</tt>
        # (<tt>src/format_description/owned_format_item.rs:31-35</tt>).
        class Optional < Data.define(:item)
          include OwnedFormatItem

          ##
          # :attr_reader: item
          # The OwnedFormatItem that may be absent.
        end

        # A series of FormatItems where, when parsing, the first successful
        # parse is used. When formatting, the first element is used. An
        # empty Array is a no-op when formatting or parsing.
        #
        # Mirrors time's <tt>OwnedFormatItem::First</tt>
        # (<tt>src/format_description/owned_format_item.rs:36-39</tt>).
        class First < Data.define(:items)
          include OwnedFormatItem

          ##
          # :attr_reader: items
          # The alternatives, a frozen Array of OwnedFormatItem.
        end

        # The deprecated variant by name, so the gem reaches it without
        # warning. Private to the gem.
        LITERALS = { Literal: Literal }.freeze
        private_constant :LITERALS

        deprecate_constant :Literal
      end

      # The old name of BorrowedFormatItem, the same module. Deprecated
      # since time 0.3.37: use BorrowedFormatItem for clarity. Naming it
      # warns. Mirrors time's hidden <tt>FormatItem</tt> alias
      # (<tt>src/format_description/mod.rs:44-47</tt>).
      FormatItem = BorrowedFormatItem
      deprecate_constant :FormatItem

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
