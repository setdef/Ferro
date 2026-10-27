# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    module FormatDescription
      module WellKnown
        class Iso8601
          #--
          # SPDX-SnippetBegin
          # SPDX-License-Identifier: MIT OR Apache-2.0
          # SPDX-SnippetCopyrightText: Jacob Pratt et al.
          # SPDX-SnippetComment: Iso8601's Config, its enums, and their docs
          #   from time 0.3.55 src/format_description/well_known/iso8601.rs:92-264
          #   and iso8601/adt_hack.rs:11-62
          #++

          # Which components to format.
          #
          # Mirrors time's <tt>iso8601::FormattedComponents</tt>
          # (<tt>src/format_description/well_known/iso8601.rs:92-110</tt>).
          # Variants compare by identity, as time derives +PartialEq+.
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   config = iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::DateTime)
          #   Ferro::Time::Date.from_ordinal_date(2019, 1).midnight.format(iso.new(config)) # => "2019-01-01T00:00:00.000000000"
          class FormattedComponents
            private_class_method :new

            # Creates the variant at +index+ named +name+. The constants are
            # the only instances.
            #
            # [index] Integer, the variant's place in time's enum.
            # [name] Symbol, the variant's name.
            def initialize(index, name)
              @index = index
              @name = name
              freeze
            end

            # The constant that holds this variant.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::FormattedComponents::Date.inspect
            #   # => "Ferro::Time::FormatDescription::WellKnown::Iso8601::FormattedComponents::Date"
            def inspect
              "Ferro::Time::FormatDescription::WellKnown::Iso8601::FormattedComponents::#{@name}"
            end

            # The variant's place in time's enum, for the native layer.
            private attr_reader :index

            # The configuration can only be used for parsing. Using this to
            # format a value is unspecified behavior in time, and raises
            # +TypeError+ here.
            None = new(0, :None)
            # Format only the date.
            Date = new(1, :Date)
            # Format only the time.
            Time = new(2, :Time)
            # Format only the UTC offset.
            Offset = new(3, :Offset)
            # Format the date and time.
            DateTime = new(4, :DateTime)
            # Format the date, time, and UTC offset.
            DateTimeOffset = new(5, :DateTimeOffset)
            # Format the time and UTC offset.
            TimeOffset = new(6, :TimeOffset)
          end

          # Which format to use for the date.
          #
          # Mirrors time's <tt>iso8601::DateKind</tt>
          # (<tt>src/format_description/well_known/iso8601.rs:112-121</tt>).
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   config = iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Date)
          #   week = iso.new(config.set_date_kind(iso::DateKind::Week))
          #   Ferro::Time::Date.from_calendar_date(2021, Ferro::Time::Month::January, 5).format(week) # => "2021-W01-2"
          class DateKind
            private_class_method :new

            # Creates the variant at +index+ named +name+. The constants are
            # the only instances.
            #
            # [index] Integer, the variant's place in time's enum.
            # [name] Symbol, the variant's name.
            def initialize(index, name)
              @index = index
              @name = name
              freeze
            end

            # The constant that holds this variant.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::DateKind::Week.inspect
            #   # => "Ferro::Time::FormatDescription::WellKnown::Iso8601::DateKind::Week"
            def inspect
              "Ferro::Time::FormatDescription::WellKnown::Iso8601::DateKind::#{@name}"
            end

            # The variant's place in time's enum, for the native layer.
            private attr_reader :index

            # Use the year-month-day format.
            Calendar = new(0, :Calendar)
            # Use the year-week-weekday format.
            Week = new(1, :Week)
            # Use the week-ordinal format.
            Ordinal = new(2, :Ordinal)
          end

          # The precision and number of decimal digits present for the time.
          #
          # Each variant is a Data class holding +decimal_digits+: +nil+ for
          # none, or an Integer from 1 to 255, Rust's <tt>Option<NonZero<u8>></tt>.
          # Config#set_time_precision raises +RangeError+ for any other
          # value, which Rust's type cannot hold.
          #
          # Mirrors time's <tt>iso8601::TimePrecision</tt>
          # (<tt>src/format_description/well_known/iso8601.rs:123-146</tt>).
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   config = iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Time)
          #   minutes = iso.new(config.set_time_precision(iso::TimePrecision::Minute.new(decimal_digits: 1)))
          #   Ferro::Time::Time.from_hms(9, 30, 30).format(minutes) # => "09:30.5"
          module TimePrecision
            # Format the hour only. Minutes, seconds, and nanoseconds will be
            # represented with the specified number of decimal digits, if
            # any.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::TimePrecision::Hour.new(decimal_digits: nil)
            class Hour < Data.define(:decimal_digits)
              ##
              # :attr_reader: decimal_digits
              # The number of decimal digits, from 1 to 255, or +nil+ for
              # none.
            end

            # Format the hour and minute. Seconds and nanoseconds will be
            # represented with the specified number of decimal digits, if
            # any.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::TimePrecision::Minute.new(decimal_digits: 2)
            class Minute < Data.define(:decimal_digits)
              ##
              # :attr_reader: decimal_digits
              # The number of decimal digits, from 1 to 255, or +nil+ for
              # none.
            end

            # Format the hour, minute, and second. Nanoseconds will be
            # represented with the specified number of decimal digits, if
            # any.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::TimePrecision::Second.new(decimal_digits: 9)
            class Second < Data.define(:decimal_digits)
              ##
              # :attr_reader: decimal_digits
              # The number of decimal digits, from 1 to 255, or +nil+ for
              # none.
            end
          end

          # The precision for the UTC offset.
          #
          # Mirrors time's <tt>iso8601::OffsetPrecision</tt>
          # (<tt>src/format_description/well_known/iso8601.rs:148-155</tt>).
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   config = iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Offset)
          #   hours = iso.new(config.set_offset_precision(iso::OffsetPrecision::Hour))
          #   Ferro::Time::UtcOffset.from_hms(5, 0, 0).format(hours) # => "+05"
          class OffsetPrecision
            private_class_method :new

            # Creates the variant at +index+ named +name+. The constants are
            # the only instances.
            #
            # [index] Integer, the variant's place in time's enum.
            # [name] Symbol, the variant's name.
            def initialize(index, name)
              @index = index
              @name = name
              freeze
            end

            # The constant that holds this variant.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::OffsetPrecision::Hour.inspect
            #   # => "Ferro::Time::FormatDescription::WellKnown::Iso8601::OffsetPrecision::Hour"
            def inspect
              "Ferro::Time::FormatDescription::WellKnown::Iso8601::OffsetPrecision::#{@name}"
            end

            # The variant's place in time's enum, for the native layer.
            private attr_reader :index

            # Format only the offset hour. Requires the offset minute to be
            # zero.
            Hour = new(0, :Hour)
            # Format both the offset hour and minute.
            Minute = new(1, :Minute)
          end

          # Configuration for Iso8601.
          #
          # ISO 8601 has many variants, and an Iso8601 formats the one its
          # Config describes. Start from Config::DEFAULT and change what you
          # need with the +set_+ methods; each returns a new Config and
          # leaves the receiver as it was, as Rust's setters take +self+ by
          # value and return it. time keeps the settings private, so a
          # Config cannot be read back, and derives no +PartialEq+, so +==+
          # is identity; two Iso8601s built from equal settings are equal.
          #
          # Mirrors time's <tt>iso8601::Config</tt>
          # (<tt>src/format_description/well_known/iso8601.rs:157-264</tt>).
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   basic = iso::Config::DEFAULT.set_use_separators(false)
          #   Ferro::Time::UtcDateTime::UNIX_EPOCH.format(iso.new(basic)) # => "19700101T000000.000000000Z"
          class Config
            private_class_method :new

            # The settings as the native layer takes them, a Config of its
            # own.
            def self.with(settings)
              new(settings)
            end
            private_class_method :with

            # Creates the configuration with +settings+.
            #
            # [settings] Array, the settings in the native layer's order.
            def initialize(settings)
              @settings = settings.freeze
              freeze
            end

            # A copy that formats +formatted_components+.
            #
            # Mirrors time's <tt>Config::set_formatted_components</tt>
            # (<tt>src/format_description/well_known/iso8601.rs:212-220</tt>).
            #
            # [formatted_components] FormattedComponents.
            #
            # === Example
            #
            #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
            #   config = iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Date)
            #   iso.new(config) == iso::DATE # => true
            def set_formatted_components(formatted_components)
              replace(0, variant(formatted_components, FormattedComponents))
            end

            # A copy with or without separators (such as <tt>-</tt> and
            # <tt>:</tt>).
            #
            # Mirrors time's <tt>Config::set_use_separators</tt>
            # (<tt>src/format_description/well_known/iso8601.rs:222-229</tt>).
            #
            # [use_separators] +true+ or +false+.
            #
            # === Example
            #
            #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
            #   date = iso.new(iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Date)
            #     .set_use_separators(false))
            #   Ferro::Time::Date.from_ordinal_date(2019, 1).format(date) # => "20190101"
            def set_use_separators(use_separators)
              replace(1, boolean(use_separators))
            end

            # A copy whose years have six digits and a sign.
            #
            # Mirrors time's <tt>Config::set_year_is_six_digits</tt>
            # (<tt>src/format_description/well_known/iso8601.rs:231-238</tt>).
            #
            # [year_is_six_digits] +true+ or +false+.
            #
            # === Example
            #
            #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
            #   date = iso.new(iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Date)
            #     .set_year_is_six_digits(true))
            #   Ferro::Time::Date.from_ordinal_date(2019, 1).format(date) # => "+002019-01-01"
            def set_year_is_six_digits(year_is_six_digits)
              replace(2, boolean(year_is_six_digits))
            end

            # A copy that formats the date as +date_kind+.
            #
            # Mirrors time's <tt>Config::set_date_kind</tt>
            # (<tt>src/format_description/well_known/iso8601.rs:240-244</tt>).
            #
            # [date_kind] DateKind.
            #
            # === Example
            #
            #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
            #   date = iso.new(iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Date)
            #     .set_date_kind(iso::DateKind::Ordinal))
            #   Ferro::Time::Date.from_ordinal_date(2019, 32).format(date) # => "2019-032"
            def set_date_kind(date_kind)
              replace(3, variant(date_kind, DateKind))
            end

            # A copy that formats the time to +time_precision+. A
            # +decimal_digits+ that is not +nil+ or from 1 to 255 raises
            # +RangeError+, since Rust's <tt>Option<NonZero<u8>></tt> cannot
            # hold it.
            #
            # Mirrors time's <tt>Config::set_time_precision</tt>
            # (<tt>src/format_description/well_known/iso8601.rs:246-255</tt>).
            #
            # [time_precision] A TimePrecision variant.
            #
            # === Example
            #
            #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
            #   precision = iso::TimePrecision::Second.new(decimal_digits: nil)
            #   time = iso.new(iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Time)
            #     .set_time_precision(precision))
            #   Ferro::Time::Time.from_hms_milli(9, 5, 0, 500).format(time) # => "09:05:00"
            def set_time_precision(time_precision)
              index = [TimePrecision::Hour, TimePrecision::Minute, TimePrecision::Second]
                .index { |kind| time_precision.instance_of?(kind) }
              unless index
                raise TypeError, "no implicit conversion of #{time_precision.class} into #{TimePrecision}"
              end

              digits = time_precision.decimal_digits
              valid = digits.nil? || (digits.is_a?(Integer) && digits.between?(1, 255))
              raise RangeError, "decimal_digits must be nil or from 1 to 255, not #{digits.inspect}" unless valid

              replace(4, index).__send__(:replace, 5, digits || 0)
            end

            # A copy that formats the offset to +offset_precision+.
            #
            # Mirrors time's <tt>Config::set_offset_precision</tt>
            # (<tt>src/format_description/well_known/iso8601.rs:257-264</tt>).
            #
            # [offset_precision] OffsetPrecision.
            #
            # === Example
            #
            #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
            #   offset = iso.new(iso::Config::DEFAULT.set_formatted_components(iso::FormattedComponents::Offset)
            #     .set_offset_precision(iso::OffsetPrecision::Hour))
            #   Ferro::Time::UtcOffset.from_hms(-3, 0, 0).format(offset) # => "-03"
            def set_offset_precision(offset_precision)
              replace(6, variant(offset_precision, OffsetPrecision))
            end

            # time's encoding of the configuration, an Integer. In Rust it is
            # the const parameter of Iso8601, and "the value returned by this
            # method must only be used as a const parameter to Iso8601. Any
            # other usage is unspecified behavior."
            #
            # Mirrors time's <tt>Config::encode</tt>
            # (<tt>src/format_description/well_known/iso8601/adt_hack.rs:51-87</tt>).
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::Config::DEFAULT.encode.is_a?(Integer) # => true
            def encode
              Native.iso8601_encode(@settings)
            end

            # time's derived +Debug+ text for the configuration.
            #
            # === Example
            #
            #   Ferro::Time::FormatDescription::WellKnown::Iso8601::Config::DEFAULT.inspect
            #   # => "Config { formatted_components: DateTimeOffset, use_separators: true, year_is_six_digits: false, date_kind: Calendar, time_precision: Second { decimal_digits: Some(9) }, offset_precision: Minute }"
            def inspect
              Native.iso8601_config_debug(@settings)
            end

            # The settings, for the native layer.
            private attr_reader :settings

            # A copy with the setting at +index+ replaced by +value+.
            private def replace(index, value)
              settings = @settings.dup
              settings[index] = value
              Config.__send__(:with, settings)
            end

            # The place of +value+ in +enum+, refusing anything else as
            # Rust's type checker would.
            private def variant(value, enum)
              raise TypeError, "no implicit conversion of #{value.class} into #{enum}" unless value.is_a?(enum)

              value.__send__(:index)
            end

            # +value+, refusing anything but +true+ or +false+, as Rust's
            # +bool+ does.
            private def boolean(value)
              raise TypeError, "no implicit conversion of #{value.class} into true or false" unless [true, false].include?(value)

              value
            end

            # A configuration for Iso8601: the date, time, and UTC offset are
            # all formatted; separators are included; the year contains four
            # digits; the date uses the calendar format; the time has
            # precision to the second and nine decimal digits; the UTC offset
            # has precision to the minute.
            #
            # If you need different behavior, use the setter methods on this
            # class.
            DEFAULT = with([5, true, false, 0, 2, 9, 1])
          end

          #--
          # SPDX-SnippetEnd
          #++
        end
      end
    end
  end
end
