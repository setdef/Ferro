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
      # SPDX-SnippetComment: the modifiers, their defaults, and their docs from
      #   time 0.3.55 src/format_description/modifier.rs
      #++

      # Various modifiers for components.
      #
      # A component such as <tt>[day]</tt> says what to write, and its
      # modifiers say how: padded with zeroes or spaces, a sign always or
      # only when negative, a month's name in full or short. Each kind of
      # component has its own modifier, so a setting that means nothing
      # for it cannot be written.
      #
      # Each modifier is a frozen value. Start from its +default+ (or
      # Ignore.count, since an Ignore needs its count) and change one
      # setting at a time with its +with_+ builders, each of which returns
      # a new value. time builds its modifiers no other way outside the
      # crate, so +new+ is private. Where time keeps a modifier's fields to
      # itself, the reader is private too; +inspect+, which is time's
      # +Debug+, still shows them. Modifiers compare and hash by their
      # settings, as time derives +PartialEq+.
      #
      # Mirrors time's <tt>format_description::modifier</tt> module
      # (<tt>src/format_description/modifier.rs</tt>), plan 009.
      #
      # === Example
      #
      #   modifier = Ferro::Time::FormatDescription::Modifier
      #   day = modifier::Day.default.with_padding(modifier::Padding::Space)
      #   item = Ferro::Time::FormatDescription::BorrowedFormatItem::Component.new(
      #     Ferro::Time::FormatDescription::Component::Day.new(day)
      #   )
      #   Ferro::Time::Date.from_calendar_date(2026, Ferro::Time::Month::March, 7).format(item) # => " 7"
      module Modifier
        # What every modifier shares: type checks, the native encoding,
        # and +inspect+. Private to the gem.
        module Value # :nodoc:
          # Checks each setting against the type time gives its field.
          def initialize(**fields)
            kinds = self.class.const_get(:KINDS)
            fields.each { |name, value| Arguments.modifier_field(kinds.fetch(name), value) }
            super
          end

          # time's +Debug+ for this modifier.
          def debug
            Native.format_item_debug(2, __send__(:encode))
          end

          # The modifier as the native layer reads it: its name and its
          # fields in time's order.
          private def encode
            kinds = self.class.const_get(:KINDS)
            [self.class.name.to_s.split("::").last.to_s] + kinds.keys.map { |name| Arguments.encode_field(__send__(name)) }
          end
        end
        private_constant :Value

        # What every modifier enum shares. Private to the gem.
        class Enum # :nodoc:
          private_class_method :new

          # Creates the variant at +index+ named +name+. The constants are
          # the only instances.
          def initialize(index, name)
            @index = index
            @name = name
            freeze
          end

          # time's derived +Debug+ text for this variant, formatted by
          # Rust: its name. +inspect+ stays Ruby's (ADR 001, 2026-11-05).
          def debug
            Native.modifier_enum_debug(self.class.name.to_s.split("::").last.to_s.to_sym, @index)
          end

          # The variant's place in time's enum, for the native layer.
          private attr_reader :index
        end
        private_constant :Enum

        # The number of digits present in a subsecond representation.
        #
        # Mirrors time's <tt>modifier::SubsecondDigits</tt>
        # (<tt>src/format_description/modifier.rs:916-941</tt>). Variants
        # compare by identity, as time derives +PartialEq+.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::SubsecondDigits.default # => Ferro::Time::FormatDescription::Modifier::SubsecondDigits::OneOrMore
        class SubsecondDigits < Enum
          # Creates a modifier that indicates the stringified value contains
          # one or more digits. Mirrors time's <tt>Default</tt> for
          # <tt>SubsecondDigits</tt>.
          def self.default
            OneOrMore
          end

          # Exactly one digit.
          One = new(0, :One)

          # Exactly two digits.
          Two = new(1, :Two)

          # Exactly three digits.
          Three = new(2, :Three)

          # Exactly four digits.
          Four = new(3, :Four)

          # Exactly five digits.
          Five = new(4, :Five)

          # Exactly six digits.
          Six = new(5, :Six)

          # Exactly seven digits.
          Seven = new(6, :Seven)

          # Exactly eight digits.
          Eight = new(7, :Eight)

          # Exactly nine digits.
          Nine = new(8, :Nine)

          # Any number of digits (up to nine) that is at least one. When
          # formatting, the minimum digits necessary will be used.
          OneOrMore = new(9, :OneOrMore)

          ALL = [One, Two, Three, Four, Five, Six, Seven, Eight, Nine, OneOrMore].freeze
          private_constant :ALL
        end

        # Type of padding to ensure a minimum width.
        #
        # Mirrors time's <tt>modifier::Padding</tt>
        # (<tt>src/format_description/modifier.rs:1007-1018</tt>). Variants
        # compare by identity, as time derives +PartialEq+.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Padding.default # => Ferro::Time::FormatDescription::Modifier::Padding::Zero
        class Padding < Enum
          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>Default</tt> for <tt>Padding</tt>.
          def self.default
            Zero
          end

          # A space character (<tt> </tt>) should be used as padding.
          Space = new(0, :Space)

          # A zero character (+0+) should be used as padding.
          Zero = new(1, :Zero)

          # There is no padding. This can result in a width below the
          # otherwise minimum number of characters.
          None = new(2, :None)

          ALL = [Space, Zero, None].freeze
          private_constant :ALL
        end

        # Whether trailing input after the declared end is permitted.
        #
        # Mirrors time's <tt>modifier::TrailingInput</tt>
        # (<tt>src/format_description/modifier.rs:1145-1152</tt>). Variants
        # compare by identity, as time derives +PartialEq+.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::TrailingInput.default # => Ferro::Time::FormatDescription::Modifier::TrailingInput::Prohibit
        class TrailingInput < Enum
          # Indicate that any trailing characters after the end of input are
          # prohibited and will cause an error when used with +parse+. Mirrors
          # time's <tt>Default</tt> for <tt>TrailingInput</tt>.
          def self.default
            Prohibit
          end

          # Trailing input is not permitted and will cause an error.
          Prohibit = new(0, :Prohibit)

          # Trailing input is permitted but discarded.
          Discard = new(1, :Discard)

          # The variant's integer value, which Rust's <tt>as u8</tt> computes:
          # 0 for +Prohibit+, 1 for +Discard+. Only this modifier enum has
          # one, as the others are <tt>#[non_exhaustive]</tt> and Rust
          # forbids casting them outside the crate (ADR 001, 2026-11-05).
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::TrailingInput::Discard.to_i # => 1
          def to_i
            Native.trailing_input_to_i(index)
          end

          ALL = [Prohibit, Discard].freeze
          private_constant :ALL
        end

        # Day of the month.
        #
        # Mirrors time's <tt>modifier::Day</tt>
        # (<tt>src/format_description/modifier.rs:239-252</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Day.default.debug # => "Day { padding: Zero }"
        class Day < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>Day::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new Day, leaving this one as it
          # is. Mirrors time's <tt>Day::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Day.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "Day { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Month of the year using the short form of the month name (e.g.
        # "Jan").
        #
        # time keeps its field, +case_sensitive+ (is the value case sensitive
        # when parsing?), to itself, so its reader is private; the +with_+
        # builder sets it.
        #
        # Mirrors time's <tt>modifier::MonthShort</tt>
        # (<tt>src/format_description/modifier.rs:270-282</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::MonthShort.default.debug # => "MonthShort { case_sensitive: true }"
        class MonthShort < Data.define(:case_sensitive)
          include Value

          KINDS = { case_sensitive: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's <tt>MonthShort::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(case_sensitive: true)
          private_constant :DEFAULT

          # Set whether the value is case sensitive when parsing. Returns a
          # new MonthShort, leaving this one as it is. Mirrors time's
          # <tt>MonthShort::with_case_sensitive</tt>.
          #
          # [case_sensitive] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::MonthShort.default.with_case_sensitive(false).debug
          #   # => "MonthShort { case_sensitive: false }"
          def with_case_sensitive(case_sensitive)
            with(case_sensitive:)
          end

          private :case_sensitive
        end

        # Month of the year using the long form of the month name (e.g.
        # "January").
        #
        # time keeps its field, +case_sensitive+ (is the value case sensitive
        # when parsing?), to itself, so its reader is private; the +with_+
        # builder sets it.
        #
        # Mirrors time's <tt>modifier::MonthLong</tt>
        # (<tt>src/format_description/modifier.rs:284-296</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::MonthLong.default.debug # => "MonthLong { case_sensitive: true }"
        class MonthLong < Data.define(:case_sensitive)
          include Value

          KINDS = { case_sensitive: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's <tt>MonthLong::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(case_sensitive: true)
          private_constant :DEFAULT

          # Set whether the value is case sensitive when parsing. Returns a
          # new MonthLong, leaving this one as it is. Mirrors time's
          # <tt>MonthLong::with_case_sensitive</tt>.
          #
          # [case_sensitive] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::MonthLong.default.with_case_sensitive(false).debug
          #   # => "MonthLong { case_sensitive: false }"
          def with_case_sensitive(case_sensitive)
            with(case_sensitive:)
          end

          private :case_sensitive
        end

        # Month of the year using a numerical representation (e.g. "1" for
        # January).
        #
        # time keeps its field, +padding+ (the padding to obtain the minimum
        # width), to itself, so its reader is private; the +with_+ builder
        # sets it.
        #
        # Mirrors time's <tt>modifier::MonthNumerical</tt>
        # (<tt>src/format_description/modifier.rs:298-310</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::MonthNumerical.default.debug # => "MonthNumerical { padding: Zero }"
        class MonthNumerical < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>MonthNumerical::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          # Set the padding type. Returns a new MonthNumerical, leaving this
          # one as it is. Mirrors time's
          # <tt>MonthNumerical::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::MonthNumerical.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "MonthNumerical { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end

          private :padding
        end

        # Ordinal day of the year.
        #
        # Mirrors time's <tt>modifier::Ordinal</tt>
        # (<tt>src/format_description/modifier.rs:341-354</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Ordinal.default.debug # => "Ordinal { padding: Zero }"
        class Ordinal < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>Ordinal::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new Ordinal, leaving this one as
          # it is. Mirrors time's <tt>Ordinal::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Ordinal.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "Ordinal { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Day of the week using the short form of the weekday (e.g. "Mon").
        #
        # time keeps its field, +case_sensitive+ (is the value case sensitive
        # when parsing?), to itself, so its reader is private; the +with_+
        # builder sets it.
        #
        # Mirrors time's <tt>modifier::WeekdayShort</tt>
        # (<tt>src/format_description/modifier.rs:378-390</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekdayShort.default.debug # => "WeekdayShort { case_sensitive: true }"
        class WeekdayShort < Data.define(:case_sensitive)
          include Value

          KINDS = { case_sensitive: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekdayShort::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(case_sensitive: true)
          private_constant :DEFAULT

          # Set whether the value is case sensitive when parsing. Returns a
          # new WeekdayShort, leaving this one as it is. Mirrors time's
          # <tt>WeekdayShort::with_case_sensitive</tt>.
          #
          # [case_sensitive] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekdayShort.default.with_case_sensitive(false).debug
          #   # => "WeekdayShort { case_sensitive: false }"
          def with_case_sensitive(case_sensitive)
            with(case_sensitive:)
          end

          private :case_sensitive
        end

        # Day of the week using the long form of the weekday (e.g. "Monday").
        #
        # time keeps its field, +case_sensitive+ (is the value case sensitive
        # when parsing?), to itself, so its reader is private; the +with_+
        # builder sets it.
        #
        # Mirrors time's <tt>modifier::WeekdayLong</tt>
        # (<tt>src/format_description/modifier.rs:392-404</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekdayLong.default.debug # => "WeekdayLong { case_sensitive: true }"
        class WeekdayLong < Data.define(:case_sensitive)
          include Value

          KINDS = { case_sensitive: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekdayLong::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(case_sensitive: true)
          private_constant :DEFAULT

          # Set whether the value is case sensitive when parsing. Returns a
          # new WeekdayLong, leaving this one as it is. Mirrors time's
          # <tt>WeekdayLong::with_case_sensitive</tt>.
          #
          # [case_sensitive] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekdayLong.default.with_case_sensitive(false).debug
          #   # => "WeekdayLong { case_sensitive: false }"
          def with_case_sensitive(case_sensitive)
            with(case_sensitive:)
          end

          private :case_sensitive
        end

        # Day of the week using a numerical representation with Sunday as the
        # first day of the week.
        #
        # time keeps its field, +one_indexed+ (is the value zero or
        # one-indexed?), to itself, so its reader is private; the +with_+
        # builder sets it.
        #
        # Mirrors time's <tt>modifier::WeekdaySunday</tt>
        # (<tt>src/format_description/modifier.rs:406-418</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekdaySunday.default.debug # => "WeekdaySunday { one_indexed: true }"
        class WeekdaySunday < Data.define(:one_indexed)
          include Value

          KINDS = { one_indexed: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekdaySunday::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(one_indexed: true)
          private_constant :DEFAULT

          # Set whether the value is one-indexed. Returns a new WeekdaySunday,
          # leaving this one as it is. Mirrors time's
          # <tt>WeekdaySunday::with_one_indexed</tt>.
          #
          # [one_indexed] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekdaySunday.default.with_one_indexed(false).debug
          #   # => "WeekdaySunday { one_indexed: false }"
          def with_one_indexed(one_indexed)
            with(one_indexed:)
          end

          private :one_indexed
        end

        # Day of the week using a numerical representation with Monday as the
        # first day of the week.
        #
        # time keeps its field, +one_indexed+ (is the value zero or
        # one-indexed?), to itself, so its reader is private; the +with_+
        # builder sets it.
        #
        # Mirrors time's <tt>modifier::WeekdayMonday</tt>
        # (<tt>src/format_description/modifier.rs:420-432</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekdayMonday.default.debug # => "WeekdayMonday { one_indexed: true }"
        class WeekdayMonday < Data.define(:one_indexed)
          include Value

          KINDS = { one_indexed: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekdayMonday::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(one_indexed: true)
          private_constant :DEFAULT

          # Set whether the value is one-indexed. Returns a new WeekdayMonday,
          # leaving this one as it is. Mirrors time's
          # <tt>WeekdayMonday::with_one_indexed</tt>.
          #
          # [one_indexed] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekdayMonday.default.with_one_indexed(false).debug
          #   # => "WeekdayMonday { one_indexed: false }"
          def with_one_indexed(one_indexed)
            with(one_indexed:)
          end

          private :one_indexed
        end

        # Week within the year using the ISO week calendar.
        #
        # Week 1 is the week that contains January 4. All weeks begin on a
        # Monday.
        #
        # Mirrors time's <tt>modifier::WeekNumberIso</tt>
        # (<tt>src/format_description/modifier.rs:479-493</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekNumberIso.default.debug # => "WeekNumberIso { padding: Zero }"
        class WeekNumberIso < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekNumberIso::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new WeekNumberIso, leaving this
          # one as it is. Mirrors time's <tt>WeekNumberIso::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekNumberIso.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "WeekNumberIso { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Week within the calendar year.
        #
        # Week 1 begins on the first Sunday of the calendar year.
        #
        # Mirrors time's <tt>modifier::WeekNumberSunday</tt>
        # (<tt>src/format_description/modifier.rs:495-509</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekNumberSunday.default.debug # => "WeekNumberSunday { padding: Zero }"
        class WeekNumberSunday < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekNumberSunday::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new WeekNumberSunday, leaving this
          # one as it is. Mirrors time's
          # <tt>WeekNumberSunday::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekNumberSunday.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "WeekNumberSunday { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Week within the calendar year.
        #
        # Week 1 begins on the first Monday of the calendar year.
        #
        # Mirrors time's <tt>modifier::WeekNumberMonday</tt>
        # (<tt>src/format_description/modifier.rs:511-525</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::WeekNumberMonday.default.debug # => "WeekNumberMonday { padding: Zero }"
        class WeekNumberMonday < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>WeekNumberMonday::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new WeekNumberMonday, leaving this
          # one as it is. Mirrors time's
          # <tt>WeekNumberMonday::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::WeekNumberMonday.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "WeekNumberMonday { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Year of the date. All digits are included, the calendar year is
        # used, and the range of years supported is ±999,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::CalendarYearFullExtendedRange</tt>
        # (<tt>src/format_description/modifier.rs:587-605</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::CalendarYearFullExtendedRange.default.debug # => "CalendarYearFullExtendedRange { padding: Zero, sign_is_mandatory: false }"
        class CalendarYearFullExtendedRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>CalendarYearFullExtendedRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new CalendarYearFullExtendedRange,
          # leaving this one as it is. Mirrors time's
          # <tt>CalendarYearFullExtendedRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearFullExtendedRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "CalendarYearFullExtendedRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # years with more than four digits. Returns a new
          # CalendarYearFullExtendedRange, leaving this one as it is. Mirrors
          # time's
          # <tt>CalendarYearFullExtendedRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearFullExtendedRange.default.with_sign_is_mandatory(true).debug
          #   # => "CalendarYearFullExtendedRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. All digits are included, the calendar year is
        # used, and the range of years supported is ±9,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::CalendarYearFullStandardRange</tt>
        # (<tt>src/format_description/modifier.rs:607-625</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::CalendarYearFullStandardRange.default.debug # => "CalendarYearFullStandardRange { padding: Zero, sign_is_mandatory: false }"
        class CalendarYearFullStandardRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>CalendarYearFullStandardRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new CalendarYearFullStandardRange,
          # leaving this one as it is. Mirrors time's
          # <tt>CalendarYearFullStandardRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearFullStandardRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "CalendarYearFullStandardRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is present on non-negative years.
          # Returns a new CalendarYearFullStandardRange, leaving this one as
          # it is. Mirrors time's
          # <tt>CalendarYearFullStandardRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearFullStandardRange.default.with_sign_is_mandatory(true).debug
          #   # => "CalendarYearFullStandardRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. All digits are included, the ISO week-numbering
        # year is used, and the range of years supported is ±999,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::IsoYearFullExtendedRange</tt>
        # (<tt>src/format_description/modifier.rs:627-645</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::IsoYearFullExtendedRange.default.debug # => "IsoYearFullExtendedRange { padding: Zero, sign_is_mandatory: false }"
        class IsoYearFullExtendedRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>IsoYearFullExtendedRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new IsoYearFullExtendedRange,
          # leaving this one as it is. Mirrors time's
          # <tt>IsoYearFullExtendedRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearFullExtendedRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "IsoYearFullExtendedRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # years with more than four digits. Returns a new
          # IsoYearFullExtendedRange, leaving this one as it is. Mirrors
          # time's <tt>IsoYearFullExtendedRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearFullExtendedRange.default.with_sign_is_mandatory(true).debug
          #   # => "IsoYearFullExtendedRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. All digits are included, the ISO week-numbering
        # year is used, and the range of supported is ±9,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::IsoYearFullStandardRange</tt>
        # (<tt>src/format_description/modifier.rs:647-665</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::IsoYearFullStandardRange.default.debug # => "IsoYearFullStandardRange { padding: Zero, sign_is_mandatory: false }"
        class IsoYearFullStandardRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>IsoYearFullStandardRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new IsoYearFullStandardRange,
          # leaving this one as it is. Mirrors time's
          # <tt>IsoYearFullStandardRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearFullStandardRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "IsoYearFullStandardRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is present on non-negative years.
          # Returns a new IsoYearFullStandardRange, leaving this one as it is.
          # Mirrors time's
          # <tt>IsoYearFullStandardRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearFullStandardRange.default.with_sign_is_mandatory(true).debug
          #   # => "IsoYearFullStandardRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. Only the century is included (i.e. all digits
        # except the last two), the calendar year is used, and the range of
        # years supported is ±999,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::CalendarYearCenturyExtendedRange</tt>
        # (<tt>src/format_description/modifier.rs:667-685</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::CalendarYearCenturyExtendedRange.default.debug # => "CalendarYearCenturyExtendedRange { padding: Zero, sign_is_mandatory: false }"
        class CalendarYearCenturyExtendedRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>CalendarYearCenturyExtendedRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new
          # CalendarYearCenturyExtendedRange, leaving this one as it is.
          # Mirrors time's
          # <tt>CalendarYearCenturyExtendedRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearCenturyExtendedRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "CalendarYearCenturyExtendedRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # years with more than four digits. Returns a new
          # CalendarYearCenturyExtendedRange, leaving this one as it is.
          # Mirrors time's
          # <tt>CalendarYearCenturyExtendedRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearCenturyExtendedRange.default.with_sign_is_mandatory(true).debug
          #   # => "CalendarYearCenturyExtendedRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. Only the century is included (i.e. all digits
        # except the last two), the calendar year is used, and the range of
        # years supported is ±9,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::CalendarYearCenturyStandardRange</tt>
        # (<tt>src/format_description/modifier.rs:687-705</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::CalendarYearCenturyStandardRange.default.debug # => "CalendarYearCenturyStandardRange { padding: Zero, sign_is_mandatory: false }"
        class CalendarYearCenturyStandardRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>CalendarYearCenturyStandardRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new
          # CalendarYearCenturyStandardRange, leaving this one as it is.
          # Mirrors time's
          # <tt>CalendarYearCenturyStandardRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearCenturyStandardRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "CalendarYearCenturyStandardRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is present on non-negative years.
          # Returns a new CalendarYearCenturyStandardRange, leaving this one
          # as it is. Mirrors time's
          # <tt>CalendarYearCenturyStandardRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearCenturyStandardRange.default.with_sign_is_mandatory(true).debug
          #   # => "CalendarYearCenturyStandardRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. Only the century is included (i.e. all digits
        # except the last two), the ISO week-numbering year is used, and the
        # range of years supported is ±999,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::IsoYearCenturyExtendedRange</tt>
        # (<tt>src/format_description/modifier.rs:707-725</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::IsoYearCenturyExtendedRange.default.debug # => "IsoYearCenturyExtendedRange { padding: Zero, sign_is_mandatory: false }"
        class IsoYearCenturyExtendedRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>IsoYearCenturyExtendedRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new IsoYearCenturyExtendedRange,
          # leaving this one as it is. Mirrors time's
          # <tt>IsoYearCenturyExtendedRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearCenturyExtendedRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "IsoYearCenturyExtendedRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # years with more than four digits. Returns a new
          # IsoYearCenturyExtendedRange, leaving this one as it is. Mirrors
          # time's
          # <tt>IsoYearCenturyExtendedRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearCenturyExtendedRange.default.with_sign_is_mandatory(true).debug
          #   # => "IsoYearCenturyExtendedRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. Only the century is included (i.e. all digits
        # except the last two), the ISO week-numbering year is used, and the
        # range of years supported is ±9,999.
        #
        # time keeps its fields, +padding+ (the padding to obtain the minimum
        # width) and +sign_is_mandatory+ (whether the <tt>+</tt> sign is
        # present when a non-negative year contains fewer digits than
        # necessary), to itself, so their readers are private; the +with_+
        # builders set them.
        #
        # Mirrors time's <tt>modifier::IsoYearCenturyStandardRange</tt>
        # (<tt>src/format_description/modifier.rs:727-745</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::IsoYearCenturyStandardRange.default.debug # => "IsoYearCenturyStandardRange { padding: Zero, sign_is_mandatory: false }"
        class IsoYearCenturyStandardRange < Data.define(:padding, :sign_is_mandatory)
          include Value

          KINDS = { padding: Padding, sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>IsoYearCenturyStandardRange::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero, sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set the padding type. Returns a new IsoYearCenturyStandardRange,
          # leaving this one as it is. Mirrors time's
          # <tt>IsoYearCenturyStandardRange::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearCenturyStandardRange.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "IsoYearCenturyStandardRange { padding: Space, sign_is_mandatory: false }"
          def with_padding(padding)
            with(padding:)
          end

          # Set whether the <tt>+</tt> sign is present on non-negative years.
          # Returns a new IsoYearCenturyStandardRange, leaving this one as it
          # is. Mirrors time's
          # <tt>IsoYearCenturyStandardRange::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearCenturyStandardRange.default.with_sign_is_mandatory(true).debug
          #   # => "IsoYearCenturyStandardRange { padding: Zero, sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :padding, :sign_is_mandatory
        end

        # Year of the date. Only the last two digits are included, and the
        # calendar year is used.
        #
        # time keeps its field, +padding+ (the padding to obtain the minimum
        # width), to itself, so its reader is private; the +with_+ builder
        # sets it.
        #
        # Mirrors time's <tt>modifier::CalendarYearLastTwo</tt>
        # (<tt>src/format_description/modifier.rs:747-760</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::CalendarYearLastTwo.default.debug # => "CalendarYearLastTwo { padding: Zero }"
        class CalendarYearLastTwo < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>CalendarYearLastTwo::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          # Set the padding type. Returns a new CalendarYearLastTwo, leaving
          # this one as it is. Mirrors time's
          # <tt>CalendarYearLastTwo::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::CalendarYearLastTwo.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "CalendarYearLastTwo { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end

          private :padding
        end

        # Year of the date. Only the last two digits are included, and the ISO
        # week-numbering year is used.
        #
        # time keeps its field, +padding+ (the padding to obtain the minimum
        # width), to itself, so its reader is private; the +with_+ builder
        # sets it.
        #
        # Mirrors time's <tt>modifier::IsoYearLastTwo</tt>
        # (<tt>src/format_description/modifier.rs:762-776</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::IsoYearLastTwo.default.debug # => "IsoYearLastTwo { padding: Zero }"
        class IsoYearLastTwo < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>IsoYearLastTwo::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          # Set the padding type. Returns a new IsoYearLastTwo, leaving this
          # one as it is. Mirrors time's
          # <tt>IsoYearLastTwo::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::IsoYearLastTwo.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "IsoYearLastTwo { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end

          private :padding
        end

        # Hour of the day using a 12-hour clock.
        #
        # time keeps its field, +padding+ (the padding to obtain the minimum
        # width), to itself, so its reader is private; the +with_+ builder
        # sets it.
        #
        # Mirrors time's <tt>modifier::Hour12</tt>
        # (<tt>src/format_description/modifier.rs:816-828</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Hour12.default.debug # => "Hour12 { padding: Zero }"
        class Hour12 < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's <tt>Hour12::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          # Set the padding type. Returns a new Hour12, leaving this one as it
          # is. Mirrors time's <tt>Hour12::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Hour12.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "Hour12 { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end

          private :padding
        end

        # Hour of the day using a 24-hour clock.
        #
        # time keeps its field, +padding+ (the padding to obtain the minimum
        # width), to itself, so its reader is private; the +with_+ builder
        # sets it.
        #
        # Mirrors time's <tt>modifier::Hour24</tt>
        # (<tt>src/format_description/modifier.rs:830-842</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Hour24.default.debug # => "Hour24 { padding: Zero }"
        class Hour24 < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's <tt>Hour24::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          # Set the padding type. Returns a new Hour24, leaving this one as it
          # is. Mirrors time's <tt>Hour24::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Hour24.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "Hour24 { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end

          private :padding
        end

        # Minute within the hour.
        #
        # Mirrors time's <tt>modifier::Minute</tt>
        # (<tt>src/format_description/modifier.rs:865-878</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Minute.default.debug # => "Minute { padding: Zero }"
        class Minute < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>Minute::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new Minute, leaving this one as it
          # is. Mirrors time's <tt>Minute::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Minute.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "Minute { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # AM/PM part of the time.
        #
        # Mirrors time's <tt>modifier::Period</tt>
        # (<tt>src/format_description/modifier.rs:880-899</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Period.default.debug # => "Period { is_uppercase: true, case_sensitive: true }"
        class Period < Data.define(:is_uppercase, :case_sensitive)
          include Value

          KINDS = { is_uppercase: :bool, case_sensitive: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value uses the upper-case
          # representation and is case-sensitive when parsing. Mirrors time's
          # <tt>Period::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(is_uppercase: true, case_sensitive: true)
          private_constant :DEFAULT

          ##
          # :attr_reader: is_uppercase
          # Is the period uppercase or lowercase? true or false.

          ##
          # :attr_reader: case_sensitive
          # Is the value case sensitive when parsing? Note that when +false+,
          # the +is_uppercase+ field has no effect on parsing behavior. true
          # or false.

          # Set whether the period is uppercase. Returns a new Period, leaving
          # this one as it is. Mirrors time's
          # <tt>Period::with_is_uppercase</tt>.
          #
          # [is_uppercase] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Period.default.with_is_uppercase(false).debug
          #   # => "Period { is_uppercase: false, case_sensitive: true }"
          def with_is_uppercase(is_uppercase)
            with(is_uppercase:)
          end

          # Set whether the value is case sensitive when parsing. Returns a
          # new Period, leaving this one as it is. Mirrors time's
          # <tt>Period::with_case_sensitive</tt>.
          #
          # [case_sensitive] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Period.default.with_case_sensitive(false).debug
          #   # => "Period { is_uppercase: true, case_sensitive: false }"
          def with_case_sensitive(case_sensitive)
            with(case_sensitive:)
          end
        end

        # Second within the minute.
        #
        # Mirrors time's <tt>modifier::Second</tt>
        # (<tt>src/format_description/modifier.rs:901-914</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Second.default.debug # => "Second { padding: Zero }"
        class Second < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>Second::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new Second, leaving this one as it
          # is. Mirrors time's <tt>Second::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Second.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "Second { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Subsecond within the second.
        #
        # Mirrors time's <tt>modifier::Subsecond</tt>
        # (<tt>src/format_description/modifier.rs:943-956</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Subsecond.default.debug # => "Subsecond { digits: OneOrMore }"
        class Subsecond < Data.define(:digits)
          include Value

          KINDS = { digits: SubsecondDigits }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the stringified value contains
          # one or more digits. Mirrors time's <tt>Subsecond::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(digits: SubsecondDigits::OneOrMore)
          private_constant :DEFAULT

          ##
          # :attr_reader: digits
          # How many digits are present in the component? A SubsecondDigits.

          # Set the number of digits present in the subsecond representation.
          # Returns a new Subsecond, leaving this one as it is. Mirrors time's
          # <tt>Subsecond::with_digits</tt>.
          #
          # [digits] SubsecondDigits.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Subsecond.default.with_digits(Ferro::Time::FormatDescription::Modifier::SubsecondDigits::One).debug
          #   # => "Subsecond { digits: One }"
          def with_digits(digits)
            with(digits:)
          end
        end

        # Hour of the UTC offset.
        #
        # Mirrors time's <tt>modifier::OffsetHour</tt>
        # (<tt>src/format_description/modifier.rs:958-975</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::OffsetHour.default.debug # => "OffsetHour { sign_is_mandatory: false, padding: Zero }"
        class OffsetHour < Data.define(:sign_is_mandatory, :padding)
          include Value

          KINDS = { sign_is_mandatory: :bool, padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value only uses a sign for
          # negative values and is padded with zeroes. Mirrors time's
          # <tt>OffsetHour::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(sign_is_mandatory: false, padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: sign_is_mandatory
          # Whether the <tt>+</tt> sign is present on positive values. true or
          # false.

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set whether the <tt>+</tt> sign is mandatory for positive values.
          # Returns a new OffsetHour, leaving this one as it is. Mirrors
          # time's <tt>OffsetHour::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::OffsetHour.default.with_sign_is_mandatory(true).debug
          #   # => "OffsetHour { sign_is_mandatory: true, padding: Zero }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          # Set the padding type. Returns a new OffsetHour, leaving this one
          # as it is. Mirrors time's <tt>OffsetHour::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::OffsetHour.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "OffsetHour { sign_is_mandatory: false, padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Minute within the hour of the UTC offset.
        #
        # Mirrors time's <tt>modifier::OffsetMinute</tt>
        # (<tt>src/format_description/modifier.rs:977-990</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::OffsetMinute.default.debug # => "OffsetMinute { padding: Zero }"
        class OffsetMinute < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>OffsetMinute::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new OffsetMinute, leaving this one
          # as it is. Mirrors time's <tt>OffsetMinute::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::OffsetMinute.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "OffsetMinute { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Second within the minute of the UTC offset.
        #
        # Mirrors time's <tt>modifier::OffsetSecond</tt>
        # (<tt>src/format_description/modifier.rs:992-1005</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::OffsetSecond.default.debug # => "OffsetSecond { padding: Zero }"
        class OffsetSecond < Data.define(:padding)
          include Value

          KINDS = { padding: Padding }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier that indicates the value is padded with zeroes.
          # Mirrors time's <tt>OffsetSecond::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(padding: Padding::Zero)
          private_constant :DEFAULT

          ##
          # :attr_reader: padding
          # The padding to obtain the minimum width. A Padding.

          # Set the padding type. Returns a new OffsetSecond, leaving this one
          # as it is. Mirrors time's <tt>OffsetSecond::with_padding</tt>.
          #
          # [padding] Padding.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::OffsetSecond.default.with_padding(Ferro::Time::FormatDescription::Modifier::Padding::Space).debug
          #   # => "OffsetSecond { padding: Space }"
          def with_padding(padding)
            with(padding:)
          end
        end

        # Ignore some number of bytes.
        #
        # This has no effect when formatting.
        #
        # Mirrors time's <tt>modifier::Ignore</tt>
        # (<tt>src/format_description/modifier.rs:1020-1043</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::Ignore.count(1).debug # => "Ignore { count: 1 }"
        class Ignore < Data.define(:count)
          include Value

          KINDS = { count: :count }.freeze
          private_constant :KINDS

          private_class_method :new

          # Create an instance of +Ignore+ with the provided number of bytes
          # to ignore. Ignore has no +default+: time asks for the count.
          # Mirrors time's <tt>Ignore::count</tt>.
          #
          # [count] Integer, from 1 to 65,535 (Rust's <tt>NonZero<u16></tt>).
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Ignore.count(4).count # => 4
          #   Ferro::Time::FormatDescription::Modifier::Ignore.count(0) # raises RangeError
          def self.count(count)
            new(count:)
          end

          ##
          # :attr_reader: count
          # The number of bytes to ignore. An Integer from 1 to 65,535.

          # Set the number of bytes to ignore. Returns a new Ignore, leaving
          # this one as it is. Mirrors time's <tt>Ignore::with_count</tt>.
          #
          # [count] Integer, from 1 to 65,535.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::Ignore.count(1).with_count(2).debug
          #   # => "Ignore { count: 2 }"
          def with_count(count)
            with(count:)
          end
        end

        # A Unix timestamp in seconds.
        #
        # time keeps its field, +sign_is_mandatory+ (whether the <tt>+</tt>
        # sign must be present for a non-negative timestamp), to itself, so
        # its reader is private; the +with_+ builder sets it.
        #
        # Mirrors time's <tt>modifier::UnixTimestampSecond</tt>
        # (<tt>src/format_description/modifier.rs:1063-1075</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::UnixTimestampSecond.default.debug # => "UnixTimestampSecond { sign_is_mandatory: false }"
        class UnixTimestampSecond < Data.define(:sign_is_mandatory)
          include Value

          KINDS = { sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>UnixTimestampSecond::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # timestamps. Returns a new UnixTimestampSecond, leaving this one as
          # it is. Mirrors time's
          # <tt>UnixTimestampSecond::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::UnixTimestampSecond.default.with_sign_is_mandatory(true).debug
          #   # => "UnixTimestampSecond { sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :sign_is_mandatory
        end

        # A Unix timestamp in milliseconds.
        #
        # time keeps its field, +sign_is_mandatory+ (whether the <tt>+</tt>
        # sign must be present for a non-negative timestamp), to itself, so
        # its reader is private; the +with_+ builder sets it.
        #
        # Mirrors time's <tt>modifier::UnixTimestampMillisecond</tt>
        # (<tt>src/format_description/modifier.rs:1077-1089</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::UnixTimestampMillisecond.default.debug # => "UnixTimestampMillisecond { sign_is_mandatory: false }"
        class UnixTimestampMillisecond < Data.define(:sign_is_mandatory)
          include Value

          KINDS = { sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>UnixTimestampMillisecond::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # timestamps. Returns a new UnixTimestampMillisecond, leaving this
          # one as it is. Mirrors time's
          # <tt>UnixTimestampMillisecond::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::UnixTimestampMillisecond.default.with_sign_is_mandatory(true).debug
          #   # => "UnixTimestampMillisecond { sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :sign_is_mandatory
        end

        # A Unix timestamp in microseconds.
        #
        # time keeps its field, +sign_is_mandatory+ (whether the <tt>+</tt>
        # sign must be present for a non-negative timestamp), to itself, so
        # its reader is private; the +with_+ builder sets it.
        #
        # Mirrors time's <tt>modifier::UnixTimestampMicrosecond</tt>
        # (<tt>src/format_description/modifier.rs:1091-1103</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::UnixTimestampMicrosecond.default.debug # => "UnixTimestampMicrosecond { sign_is_mandatory: false }"
        class UnixTimestampMicrosecond < Data.define(:sign_is_mandatory)
          include Value

          KINDS = { sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>UnixTimestampMicrosecond::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # timestamps. Returns a new UnixTimestampMicrosecond, leaving this
          # one as it is. Mirrors time's
          # <tt>UnixTimestampMicrosecond::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::UnixTimestampMicrosecond.default.with_sign_is_mandatory(true).debug
          #   # => "UnixTimestampMicrosecond { sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :sign_is_mandatory
        end

        # A Unix timestamp in nanoseconds.
        #
        # time keeps its field, +sign_is_mandatory+ (whether the <tt>+</tt>
        # sign must be present for a non-negative timestamp), to itself, so
        # its reader is private; the +with_+ builder sets it.
        #
        # Mirrors time's <tt>modifier::UnixTimestampNanosecond</tt>
        # (<tt>src/format_description/modifier.rs:1105-1117</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::UnixTimestampNanosecond.default.debug # => "UnixTimestampNanosecond { sign_is_mandatory: false }"
        class UnixTimestampNanosecond < Data.define(:sign_is_mandatory)
          include Value

          KINDS = { sign_is_mandatory: :bool }.freeze
          private_constant :KINDS

          private_class_method :new

          # The default modifier. Mirrors time's
          # <tt>UnixTimestampNanosecond::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(sign_is_mandatory: false)
          private_constant :DEFAULT

          # Set whether the <tt>+</tt> sign is mandatory for non-negative
          # timestamps. Returns a new UnixTimestampNanosecond, leaving this
          # one as it is. Mirrors time's
          # <tt>UnixTimestampNanosecond::with_sign_is_mandatory</tt>.
          #
          # [sign_is_mandatory] true or false.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::UnixTimestampNanosecond.default.with_sign_is_mandatory(true).debug
          #   # => "UnixTimestampNanosecond { sign_is_mandatory: true }"
          def with_sign_is_mandatory(sign_is_mandatory)
            with(sign_is_mandatory:)
          end

          private :sign_is_mandatory
        end

        # The end of input.
        #
        # time keeps its field, +trailing_input+ (how to handle any input
        # after this component), to itself, so its reader is private; the
        # +with_+ builder sets it.
        #
        # Mirrors time's <tt>modifier::End</tt>
        # (<tt>src/format_description/modifier.rs:1154-1167</tt>).
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription::Modifier::End.default.debug # => "End { trailing_input: Prohibit }"
        class End < Data.define(:trailing_input)
          include Value

          KINDS = { trailing_input: TrailingInput }.freeze
          private_constant :KINDS

          private_class_method :new

          # Creates a modifier used to represent the end of input, not
          # allowing any trailing input (i.e. the input must be fully
          # consumed). Mirrors time's <tt>End::default</tt>.
          def self.default
            DEFAULT
          end

          # The one value +default+ answers.
          DEFAULT = new(trailing_input: TrailingInput::Prohibit)
          private_constant :DEFAULT

          # Set how to handle any input after this component. Returns a new
          # End, leaving this one as it is. Mirrors time's
          # <tt>End::with_trailing_input</tt>.
          #
          # [trailing_input] TrailingInput.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::Modifier::End.default.with_trailing_input(Ferro::Time::FormatDescription::Modifier::TrailingInput::Discard).debug
          #   # => "End { trailing_input: Discard }"
          def with_trailing_input(trailing_input)
            with(trailing_input:)
          end

          private :trailing_input
        end

        # Every modifier class by name, for the native encoding. Private to
        # the gem.
        CLASSES = { Day: Day, MonthShort: MonthShort, MonthLong: MonthLong, MonthNumerical: MonthNumerical, Ordinal: Ordinal, WeekdayShort: WeekdayShort, WeekdayLong: WeekdayLong, WeekdaySunday: WeekdaySunday, WeekdayMonday: WeekdayMonday, WeekNumberIso: WeekNumberIso, WeekNumberSunday: WeekNumberSunday, WeekNumberMonday: WeekNumberMonday, CalendarYearFullExtendedRange: CalendarYearFullExtendedRange, CalendarYearFullStandardRange: CalendarYearFullStandardRange, IsoYearFullExtendedRange: IsoYearFullExtendedRange, IsoYearFullStandardRange: IsoYearFullStandardRange, CalendarYearCenturyExtendedRange: CalendarYearCenturyExtendedRange, CalendarYearCenturyStandardRange: CalendarYearCenturyStandardRange, IsoYearCenturyExtendedRange: IsoYearCenturyExtendedRange, IsoYearCenturyStandardRange: IsoYearCenturyStandardRange, CalendarYearLastTwo: CalendarYearLastTwo, IsoYearLastTwo: IsoYearLastTwo, Hour12: Hour12, Hour24: Hour24, Minute: Minute, Period: Period, Second: Second, Subsecond: Subsecond, OffsetHour: OffsetHour, OffsetMinute: OffsetMinute, OffsetSecond: OffsetSecond, Ignore: Ignore, UnixTimestampSecond: UnixTimestampSecond, UnixTimestampMillisecond: UnixTimestampMillisecond, UnixTimestampMicrosecond: UnixTimestampMicrosecond, UnixTimestampNanosecond: UnixTimestampNanosecond, End: End }.freeze
        private_constant :CLASSES

        # Every enum class by name. Private to the gem.
        ENUMS = { SubsecondDigits: SubsecondDigits, Padding: Padding, TrailingInput: TrailingInput }.freeze
        private_constant :ENUMS
      end

      #--
      # SPDX-SnippetEnd
      #++
    end
  end
end
