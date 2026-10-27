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
    # SPDX-SnippetComment: time 0.3.55's error types, their variants, and
    #   their Display texts and docs (src/error/*.rs)
    #++

    # A unified error type for anything time raises.
    #
    # time reports each kind of failure with its own type: a component out
    # of range, a parse that went wrong, a format description that does not
    # parse. Its +Error+ enum holds any of them, for code that does not care
    # which.
    #
    # In Ruby each of those types is a class under this one, so
    # <tt>rescue Ferro::Time::Error</tt> catches everything time raises,
    # and <tt>rescue Ferro::Time::Error::Parse</tt> only failed parses. An
    # error type that is itself an enum has a subclass per variant, nested
    # as Rust nests them (plan 007, decision 14). Every message is time's
    # +Display+ text.
    #
    # A panic inside time that the gem did not foresee raises this class
    # itself, with <tt>time panicked: ...</tt>, which would otherwise end
    # the Ruby process. The inputs time is known to panic on raise
    # +RangeError+ with time's message before time runs.
    #
    # Mirrors time's +Error+ (<tt>src/error/mod.rs:40-132</tt>).
    #
    # === Examples
    #
    #   begin
    #     Ferro::Time::Date.from_ordinal_date(2019, 366)
    #   rescue Ferro::Time::Error => e
    #     e.message # => "ordinal was not in range"
    #   end
    class Error < StandardError
      # Creates the error with +message+.
      #
      # [message] String, or +nil+ for the class name.
      def initialize(message = nil)
        super
      end

      # An error type indicating that a conversion failed because the
      # target type could not store the initial value.
      #
      # Mirrors time's <tt>error::ConversionRange</tt>
      # (<tt>src/error/conversion_range.rs</tt>). Its only sources are
      # time's conversions with std's +Duration+, which this gem defers
      # (plan 007, decision 9), so nothing raises it yet.
      #
      # === Example
      #
      #   Ferro::Time::Error::ConversionRange.new.message # => "Source value is out of range for the target type"
      class ConversionRange < Error
        # Creates the error, with time's message by default.
        #
        # [message] String, or +nil+ for time's.
        def initialize(message = nil)
          super(message || "Source value is out of range for the target type")
        end
      end

      # An error type indicating that a component provided to a method was
      # out of range, causing a failure.
      #
      # A day of 32, an hour of 24, February 29 of a common year: time
      # names the component and says whether it could have been valid had
      # other components been different. The message is time's,
      # <tt>"day was not in range"</tt>.
      #
      # Mirrors time's <tt>error::ComponentRange</tt>
      # (<tt>src/error/component_range.rs:6-57</tt>).
      #
      # === Example
      #
      #   begin
      #     Ferro::Time::Date.from_calendar_date(2019, Ferro::Time::Month::February, 29)
      #   rescue Ferro::Time::Error::ComponentRange => e
      #     [e.name, e.is_conditional] # => ["day", true]
      #   end
      class ComponentRange < Error
        # The name of the component whose value was out of range.
        attr_reader :name

        # Whether the value's permitted range is conditional, i.e. whether
        # an input with this value could have succeeded if the values of
        # other components were different.
        attr_reader :is_conditional

        # Creates the error for the component +name+.
        #
        # [name] String.
        # [is_conditional] +true+ or +false+.
        def initialize(name, is_conditional)
          @name = name
          @is_conditional = is_conditional
          super("#{name} was not in range")
        end
      end

      # The system's UTC offset could not be determined at the given
      # datetime.
      #
      # Mirrors time's <tt>error::IndeterminateOffset</tt>
      # (<tt>src/error/indeterminate_offset.rs</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Error::IndeterminateOffset.new.message # => "The system's UTC offset could not be determined"
      class IndeterminateOffset < Error
        # Creates the error, with time's message by default.
        #
        # [message] String, or +nil+ for time's.
        def initialize(message = nil)
          super(message || "The system's UTC offset could not be determined")
        end
      end

      # An error type indicating that a +TryFrom+ call failed because the
      # original value was of a different variant.
      #
      # Mirrors time's <tt>error::DifferentVariant</tt>
      # (<tt>src/error/different_variant.rs</tt>). Its only sources are the
      # conversions between time's error types, which Ruby's +rescue+ and
      # +is_a?+ replace (plan 007, decision 14), so nothing raises it.
      #
      # === Example
      #
      #   Ferro::Time::Error::DifferentVariant.new.message # => "value was of a different variant than required"
      class DifferentVariant < Error
        # Creates the error, with time's message by default.
        #
        # [message] String, or +nil+ for time's.
        def initialize(message = nil)
          super(message || "value was of a different variant than required")
        end
      end

      # An error type indicating that a +FromStr+ call failed because the
      # value was not a valid variant.
      #
      # Mirrors time's <tt>error::InvalidVariant</tt>
      # (<tt>src/error/invalid_variant.rs</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Month.from_str("Smarch") # raises Ferro::Time::Error::InvalidVariant
      class InvalidVariant < Error
        # Creates the error, with time's message by default.
        #
        # [message] String, or +nil+ for time's.
        def initialize(message = nil)
          super(message || "value was not a valid variant")
        end
      end

      # An error occurred when formatting.
      #
      # Each variant is a subclass, and a variant a later time adds raises
      # this class with time's text, since the enum is non-exhaustive.
      # +StdIo+ cannot happen here: the gem formats into Strings, which
      # never fail to write.
      #
      # Mirrors time's <tt>error::Format</tt> (<tt>src/error/format.rs</tt>).
      #
      # === Example
      #
      #   hour = Ferro::Time::FormatDescription.parse_owned(3, "[hour]")
      #   Ferro::Time::Date::MIN.format(hour) # raises Ferro::Time::Error::Format::InsufficientTypeInformation
      class Format < Error
        # The type being formatted does not contain sufficient information
        # to format a component.
        #
        # === Example
        #
        #   Ferro::Time::Error::Format::InsufficientTypeInformation.new.message
        #   # => "The type being formatted does not contain sufficient information to format a component."
        class InsufficientTypeInformation < Format
          # Creates the error, with time's message by default.
          #
          # [message] String, or +nil+ for time's.
          def initialize(message = nil)
            super(message ||
              "The type being formatted does not contain sufficient information to format a component.")
          end
        end

        # The component named has a value that cannot be formatted into the
        # requested format. This variant is only returned when using
        # well-known formats.
        #
        # === Example
        #
        #   Ferro::Time::Error::Format::InvalidComponent.new("year").message
        #   # => "The year component cannot be formatted into the requested format."
        class InvalidComponent < Format
          # The name of the component.
          attr_reader :component

          # Creates the error for +component+.
          #
          # [component] String.
          def initialize(component)
            @component = component
            super("The #{component} component cannot be formatted into the requested format.")
          end
        end

        # A component provided was out of range.
        #
        # === Example
        #
        #   Ferro::Time::Error::Format::ComponentRange.new("year", false).message # => "year was not in range"
        class ComponentRange < Format
          # The name of the component whose value was out of range.
          attr_reader :name

          # Whether an input with this value could have succeeded if the
          # values of other components were different.
          attr_reader :is_conditional

          # Creates the error for the component +name+.
          #
          # [name] String.
          # [is_conditional] +true+ or +false+.
          def initialize(name, is_conditional)
            @name = name
            @is_conditional = is_conditional
            super("#{name} was not in range")
          end
        end

        # A value of <tt>std::io::Error</tt> was returned internally. The
        # gem never meets one (plan 007, decision 11).
        #
        # === Example
        #
        #   Ferro::Time::Error::Format::StdIo.new("broken pipe").message # => "broken pipe"
        class StdIo < Format
          # Creates the error with the I/O error's text.
          #
          # [message] String.
          def initialize(message = nil)
            super
          end
        end
      end

      # An error that occurred while parsing the input into time's
      # +Parsed+ struct.
      #
      # time raises it inside Error::Parse, as
      # Error::Parse::ParseFromDescription and its subclasses; on its own it
      # comes only from +Parsed+, which this gem defers (plan 007,
      # decision 1).
      #
      # Mirrors time's <tt>error::ParseFromDescription</tt>
      # (<tt>src/error/parse_from_description.rs</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Error::ParseFromDescription::InvalidComponent.new("year").message
      #   # => "the 'year' component could not be parsed"
      class ParseFromDescription < Error
        # A string literal was not what was expected.
        #
        # === Example
        #
        #   Ferro::Time::Error::ParseFromDescription::InvalidLiteral.new.message # => "a character literal was not valid"
        class InvalidLiteral < ParseFromDescription
          # Creates the error, with time's message by default.
          #
          # [message] String, or +nil+ for time's.
          def initialize(message = nil)
            super(message || "a character literal was not valid")
          end
        end

        # A dynamic component was not valid.
        #
        # === Example
        #
        #   Ferro::Time::Error::ParseFromDescription::InvalidComponent.new("year").name # => "year"
        class InvalidComponent < ParseFromDescription
          # The name of the component.
          attr_reader :name

          # Creates the error for the component +name+.
          #
          # [name] String.
          def initialize(name)
            @name = name
            super("the '#{name}' component could not be parsed")
          end
        end

        # The input was expected to have ended, but there are characters
        # that remain.
        #
        # === Example
        #
        #   Ferro::Time::Error::ParseFromDescription::UnexpectedTrailingCharacters.new.message
        #   # => "unexpected trailing characters; the end of input was expected"
        class UnexpectedTrailingCharacters < ParseFromDescription
          # Creates the error, with time's message by default.
          #
          # [message] String, or +nil+ for time's.
          def initialize(message = nil)
            super(message || "unexpected trailing characters; the end of input was expected")
          end
        end
      end

      # An error that occurred when converting time's +Parsed+ struct to
      # another type.
      #
      # time raises it inside Error::Parse, as Error::Parse::TryFromParsed
      # and its subclasses; on its own it comes only from +Parsed+, which
      # this gem defers (plan 007, decision 1).
      #
      # Mirrors time's <tt>error::TryFromParsed</tt>
      # (<tt>src/error/try_from_parsed.rs</tt>).
      #
      # === Example
      #
      #   Ferro::Time::Error::TryFromParsed::ComponentRange.new("hour", false).message # => "hour was not in range"
      class TryFromParsed < Error
        # The +Parsed+ struct did not include enough information to
        # construct the type.
        #
        # === Example
        #
        #   Ferro::Time::Error::TryFromParsed::InsufficientInformation.new.message
        #   # => "the `Parsed` struct did not include enough information to construct the type"
        class InsufficientInformation < TryFromParsed
          # Creates the error, with time's message by default.
          #
          # [message] String, or +nil+ for time's.
          def initialize(message = nil)
            super(message || "the `Parsed` struct did not include enough information to construct the type")
          end
        end

        # Some component contained an invalid value for the type.
        #
        # === Example
        #
        #   Ferro::Time::Error::TryFromParsed::ComponentRange.new("hour", false).name # => "hour"
        class ComponentRange < TryFromParsed
          # The name of the component whose value was out of range.
          attr_reader :name

          # Whether an input with this value could have succeeded if the
          # values of other components were different.
          attr_reader :is_conditional

          # Creates the error for the component +name+.
          #
          # [name] String.
          # [is_conditional] +true+ or +false+.
          def initialize(name, is_conditional)
            @name = name
            @is_conditional = is_conditional
            super("#{name} was not in range")
          end
        end
      end

      # An error that occurred at some stage of parsing.
      #
      # Every +parse+ raises one of its leaves: the input did not match the
      # description (Parse::ParseFromDescription's), or it matched but named
      # a value the type cannot hold (Parse::TryFromParsed's). Rescue this
      # class for either.
      #
      # Mirrors time's <tt>error::Parse</tt> (<tt>src/error/parse.rs</tt>).
      # Its deprecated +UnexpectedTrailingCharacters+ variant holds
      # +Infallible+ and can never exist, so it has no class.
      #
      # === Example
      #
      #   begin
      #     Ferro::Time::Date.parse("2019-02-30", Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE)
      #   rescue Ferro::Time::Error::Parse => e
      #     e.message # => "day was not in range"
      #   end
      class Parse < Error
        # The input matched the description but described a value the
        # type cannot hold, or not enough of one.
        #
        # === Example
        #
        #   year = Ferro::Time::FormatDescription.parse_owned(3, "[year]")
        #   Ferro::Time::Date.parse("2020", year) # raises Ferro::Time::Error::Parse::TryFromParsed::InsufficientInformation
        class TryFromParsed < Parse
          # The parsed input did not include enough information to
          # construct the type.
          #
          # === Example
          #
          #   Ferro::Time::Error::Parse::TryFromParsed::InsufficientInformation.new.message
          #   # => "the `Parsed` struct did not include enough information to construct the type"
          class InsufficientInformation < TryFromParsed
            # Creates the error, with time's message by default.
            #
            # [message] String, or +nil+ for time's.
            def initialize(message = nil)
              super(message || "the `Parsed` struct did not include enough information to construct the type")
            end
          end

          # Some component contained an invalid value for the type.
          #
          # === Example
          #
          #   Ferro::Time::Date.parse("2019-02-30", Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE)
          #   # raises Ferro::Time::Error::Parse::TryFromParsed::ComponentRange
          class ComponentRange < TryFromParsed
            # The name of the component whose value was out of range.
            attr_reader :name

            # Whether an input with this value could have succeeded if the
            # values of other components were different.
            attr_reader :is_conditional

            # Creates the error for the component +name+.
            #
            # [name] String.
            # [is_conditional] +true+ or +false+.
            def initialize(name, is_conditional)
              @name = name
              @is_conditional = is_conditional
              super("#{name} was not in range")
            end
          end
        end

        # The input did not match the description.
        #
        # === Example
        #
        #   Ferro::Time::Date.parse("x", Ferro::Time::FormatDescription::WellKnown::Iso8601::DATE)
        #   # raises Ferro::Time::Error::Parse::ParseFromDescription::InvalidComponent
        class ParseFromDescription < Parse
          # A string literal was not what was expected.
          #
          # === Example
          #
          #   Ferro::Time::Error::Parse::ParseFromDescription::InvalidLiteral.new.message
          #   # => "a character literal was not valid"
          class InvalidLiteral < ParseFromDescription
            # Creates the error, with time's message by default.
            #
            # [message] String, or +nil+ for time's.
            def initialize(message = nil)
              super(message || "a character literal was not valid")
            end
          end

          # A dynamic component was not valid.
          #
          # === Example
          #
          #   Ferro::Time::Error::Parse::ParseFromDescription::InvalidComponent.new("year").message
          #   # => "the 'year' component could not be parsed"
          class InvalidComponent < ParseFromDescription
            # The name of the component.
            attr_reader :name

            # Creates the error for the component +name+.
            #
            # [name] String.
            def initialize(name)
              @name = name
              super("the '#{name}' component could not be parsed")
            end
          end

          # The input was expected to have ended, but there are characters
          # that remain.
          #
          # === Example
          #
          #   Ferro::Time::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters.new.message
          #   # => "unexpected trailing characters; the end of input was expected"
          class UnexpectedTrailingCharacters < ParseFromDescription
            # Creates the error, with time's message by default.
            #
            # [message] String, or +nil+ for time's.
            def initialize(message = nil)
              super(message || "unexpected trailing characters; the end of input was expected")
            end
          end
        end
      end

      # The format description provided was not valid.
      #
      # Each variant is a subclass carrying the fields time names, among
      # them the zero-based byte +index+ where the problem is.
      #
      # Mirrors time's <tt>error::InvalidFormatDescription</tt>
      # (<tt>src/error/invalid_format_description.rs</tt>).
      #
      # === Example
      #
      #   begin
      #     Ferro::Time::FormatDescription.parse_owned(3, "[foo]")
      #   rescue Ferro::Time::Error::InvalidFormatDescription => e
      #     e.message # => "invalid component name `foo` at byte index 1"
      #   end
      class InvalidFormatDescription < Error
        # There was a bracket pair that was opened but not closed.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[foo") # raises Ferro::Time::Error::InvalidFormatDescription::UnclosedOpeningBracket
        class UnclosedOpeningBracket < InvalidFormatDescription
          # The zero-based index of the opening bracket.
          attr_reader :index

          # Creates the error.
          #
          # [index] Integer.
          def initialize(index)
            @index = index
            super("unclosed opening bracket at byte index #{index}")
          end
        end

        # A component name is not valid.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[foo]") # raises Ferro::Time::Error::InvalidFormatDescription::InvalidComponentName
        class InvalidComponentName < InvalidFormatDescription
          # The name of the invalid component name.
          attr_reader :name

          # The zero-based index the component name starts at.
          attr_reader :index

          # Creates the error.
          #
          # [name] String.
          # [index] Integer.
          def initialize(name, index)
            @name = name
            @index = index
            super("invalid component name `#{name}` at byte index #{index}")
          end
        end

        # A modifier is not valid.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[day bar]") # raises Ferro::Time::Error::InvalidFormatDescription::InvalidModifier
        class InvalidModifier < InvalidFormatDescription
          # The value of the invalid modifier.
          attr_reader :value

          # The zero-based index the modifier starts at.
          attr_reader :index

          # Creates the error.
          #
          # [value] String.
          # [index] Integer.
          def initialize(value, index)
            @value = value
            @index = index
            super("invalid modifier `#{value}` at byte index #{index}")
          end
        end

        # A component name is missing.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[]") # raises Ferro::Time::Error::InvalidFormatDescription::MissingComponentName
        class MissingComponentName < InvalidFormatDescription
          # The zero-based index where the component name should start.
          attr_reader :index

          # Creates the error.
          #
          # [index] Integer.
          def initialize(index)
            @index = index
            super("missing component name at byte index #{index}")
          end
        end

        # A required modifier is missing.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[ignore]") # raises Ferro::Time::Error::InvalidFormatDescription::MissingRequiredModifier
        class MissingRequiredModifier < InvalidFormatDescription
          # The name of the modifier that is missing.
          attr_reader :name

          # The zero-based index of the component.
          attr_reader :index

          # Creates the error.
          #
          # [name] String.
          # [index] Integer.
          def initialize(name, index)
            @name = name
            @index = index
            super("missing required modifier `#{name}` for component at byte index #{index}")
          end
        end

        # Something was expected, but not found.
        #
        # === Example
        #
        #   Ferro::Time::Error::InvalidFormatDescription::Expected.new("closing bracket", 3).message
        #   # => "expected closing bracket at byte index 3"
        class Expected < InvalidFormatDescription
          # What was expected to be present, but wasn't.
          attr_reader :what

          # The zero-based index the item was expected to be found at.
          attr_reader :index

          # Creates the error.
          #
          # [what] String.
          # [index] Integer.
          def initialize(what, index)
            @what = what
            @index = index
            super("expected #{what} at byte index #{index}")
          end
        end

        # Certain behavior is not supported in the given context.
        #
        # === Example
        #
        #   Ferro::Time::Error::InvalidFormatDescription::NotSupported.new("x", "", 0).message
        #   # => "x is not supported at byte index 0"
        class NotSupported < InvalidFormatDescription
          # The behavior that is not supported.
          attr_reader :what

          # The context in which the behavior is not supported.
          attr_reader :context

          # The zero-based index the error occurred at.
          attr_reader :index

          # Creates the error. An empty +context+ leaves the context out of
          # the message, as time's +Display+ does.
          #
          # [what] String.
          # [context] String.
          # [index] Integer.
          def initialize(what, context, index)
            @what = what
            @context = context
            @index = index
            super(context.empty? ? "#{what} is not supported at byte index #{index}" :
              "#{what} is not supported in #{context} at byte index #{index}")
          end
        end

        # A modifier was present more than once.
        #
        # === Example
        #
        #   Ferro::Time::FormatDescription.parse_owned(3, "[day padding:zero padding:zero]")
        #   # raises Ferro::Time::Error::InvalidFormatDescription::DuplicateModifier
        class DuplicateModifier < InvalidFormatDescription
          # The name of the modifier that is duplicated.
          attr_reader :name

          # The zero-based index of the second occurrence of the modifier.
          attr_reader :index

          # Creates the error.
          #
          # [name] String.
          # [index] Integer.
          def initialize(name, index)
            @name = name
            @index = index
            super("duplicate modifier `#{name}` at byte index #{index}")
          end
        end

        # A combination of modifiers is not valid.
        #
        # === Example
        #
        #   Ferro::Time::Error::InvalidFormatDescription::InvalidModifierCombination.new("a", "b", 0).message
        #   # => "the `a` modifier is not valid at byte index 0 b"
        class InvalidModifierCombination < InvalidFormatDescription
          # The modifier that is not valid in combination with the other
          # modifiers.
          attr_reader :modifier

          # The context in which the modifier is not valid.
          attr_reader :context

          # The zero-based index the error occurred at.
          attr_reader :index

          # Creates the error.
          #
          # [modifier] String.
          # [context] String.
          # [index] Integer.
          def initialize(modifier, context, index)
            @modifier = modifier
            @context = context
            @index = index
            super("the `#{modifier}` modifier is not valid at byte index #{index} #{context}")
          end
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
