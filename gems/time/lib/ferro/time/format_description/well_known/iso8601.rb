# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    module FormatDescription
      module WellKnown
        #--
        # SPDX-SnippetBegin
        # SPDX-License-Identifier: MIT OR Apache-2.0
        # SPDX-SnippetCopyrightText: Jacob Pratt et al.
        # SPDX-SnippetComment: Iso8601, its configuration, and their docs from
        #   time 0.3.55 src/format_description/well_known/iso8601.rs and
        #   iso8601/adt_hack.rs
        #++

        # The format described in ISO 8601 (https://www.iso.org/iso-8601-date-and-time-format.html).
        #
        # This implementation is of ISO 8601-1:2019. It may not be
        # compatible with other versions.
        #
        # Example: 1997-11-21T09:55:06.000000000-06:00
        #
        # ISO 8601 is a family of formats: with or without separators,
        # calendar, week, or ordinal dates, a fraction of an hour, a minute,
        # or a second. Parsing accepts the whole family. Formatting writes
        # the variant a Config describes: the constants cover the common
        # ones, and Iso8601.new takes any other.
        #
        # In Rust the configuration is a const parameter, so each one is its
        # own type; here it is the Config the Iso8601 holds (plan 007,
        # decision 11). Two Iso8601s with the same configuration are equal,
        # as time's derived +PartialEq+ says; time derives no +Hash+, so
        # +eql?+ and +hash+ stay Ruby's identity. The class itself, passed
        # as a description, is Iso8601::DEFAULT, as Rust's unit-struct value
        # +Iso8601+ is.
        #
        # Formatting a type with a configuration that needs a component the
        # type lacks raises +TypeError+ with time's assertion, which Rust's
        # compiler would refuse. Parsing ignores the configuration, as
        # time's parser does.
        #
        # Mirrors time's +Iso8601+
        # (<tt>src/format_description/well_known/iso8601.rs:11-90</tt>).
        #
        # === Examples
        #
        #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
        #   at = Ferro::Time::OffsetDateTime.parse("1997-11-12T09:55:06-06:00", iso::DEFAULT)
        #   at.format(iso::DEFAULT) # => "1997-11-12T09:55:06.000000000-06:00"
        #
        #   config = iso::Config::DEFAULT.set_time_precision(iso::TimePrecision::Second.new(decimal_digits: 3))
        #   at.format(iso.new(config)) # => "1997-11-12T09:55:06.000-06:00"
        #
        #   # time's serde writes six-digit years, and so can you:
        #   serde = iso.new(iso::Config::DEFAULT.set_year_is_six_digits(true))
        #   at.format(serde) # => "+001997-11-12T09:55:06.000000000-06:00"
        class Iso8601
          # Creates the format with +config+, as Rust's
          # <tt>Iso8601::<{ config.encode() }></tt> names one.
          #
          # [config] Config.
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   iso.new(iso::Config::DEFAULT) == iso::DEFAULT # => true
          def initialize(config)
            raise TypeError, "no implicit conversion of #{config.class} into #{Config}" unless config.is_a?(Config)

            @config = config
            freeze
          end

          # Whether +other+ is an Iso8601 with the same configuration, as
          # time's derived +PartialEq+ says.
          #
          # [other] Object.
          #
          # === Example
          #
          #   iso = Ferro::Time::FormatDescription::WellKnown::Iso8601
          #   iso::DATE_TIME_OFFSET == iso::DEFAULT # => true
          #   iso::DATE == iso::DEFAULT # => false
          def ==(other)
            other.is_a?(Iso8601) && other.config.__send__(:settings) == @config.__send__(:settings)
          end

          # time's +Debug+ text: the format and its configuration.
          #
          # === Example
          #
          #   Ferro::Time::FormatDescription::WellKnown::Iso8601::PARSING.inspect
          #   # => "Iso8601 { config: Config { formatted_components: None, use_separators: false, year_is_six_digits: false, date_kind: Calendar, time_precision: Hour { decimal_digits: None }, offset_precision: Hour } }"
          def inspect
            Native.iso8601_debug(@config.__send__(:settings))
          end

          # The configuration, for the gem: Rust offers no way to read it
          # back from the type.
          protected attr_reader :config

          # An Iso8601 with the default configuration.
          #
          # The following is the default behavior: the configuration can be
          # used for both formatting and parsing; the date, time, and UTC
          # offset are all formatted; separators (such as <tt>-</tt> and
          # <tt>:</tt>) are included; the year contains four digits, such
          # that the year must be between 0 and 9999; the date uses the
          # calendar format; the time has precision to the second and nine
          # decimal digits; the UTC offset has precision to the minute.
          #
          # If you need different behavior, use another constant. For full
          # customization, use Config::DEFAULT and Config's methods to create
          # a custom configuration.
          DEFAULT = new(Config::DEFAULT)

          # An Iso8601 that can only be used for parsing. Using this to
          # format a value raises +TypeError+ here, where Rust's compiler
          # refuses it.
          PARSING = new(Config.__send__(:with, [0, false, false, 0, 0, 0, 0]))

          # An Iso8601 that handles only the date, but is otherwise the same
          # as Config::DEFAULT.
          DATE = new(Config::DEFAULT.set_formatted_components(FormattedComponents::Date))

          # An Iso8601 that handles only the time, but is otherwise the same
          # as Config::DEFAULT.
          TIME = new(Config::DEFAULT.set_formatted_components(FormattedComponents::Time))

          # An Iso8601 that handles only the UTC offset, but is otherwise the
          # same as Config::DEFAULT.
          OFFSET = new(Config::DEFAULT.set_formatted_components(FormattedComponents::Offset))

          # An Iso8601 that handles the date and time, but is otherwise the
          # same as Config::DEFAULT.
          DATE_TIME = new(Config::DEFAULT.set_formatted_components(FormattedComponents::DateTime))

          # An Iso8601 that handles the date, time, and UTC offset. This is
          # the same as Config::DEFAULT.
          DATE_TIME_OFFSET = new(Config::DEFAULT)

          # An Iso8601 that handles the time and UTC offset, but is otherwise
          # the same as Config::DEFAULT.
          TIME_OFFSET = new(Config::DEFAULT.set_formatted_components(FormattedComponents::TimeOffset))
        end

        #--
        # SPDX-SnippetEnd
        #++
      end
    end
  end
end
