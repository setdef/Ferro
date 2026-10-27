# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "time/version"
require_relative "time/ferro_time"
require_relative "time/error"
require_relative "time/arguments"
require_relative "time/month"
require_relative "time/weekday"
require_relative "time/signed_duration"
require_relative "time/utc_offset"
require_relative "time/date"
require_relative "time/time"
require_relative "time/plain_date_time"
require_relative "time/utc_date_time"
require_relative "time/offset_date_time"
require_relative "time/format_description"
require_relative "time/format_description/format_description_v3"
require_relative "time/format_description/well_known"
require_relative "time/format_description/well_known/iso8601/config"
require_relative "time/format_description/well_known/iso8601"
require_relative "time/util"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, or does by other rules. Each Ferro gem binds one crate, keeps its
# names and behavior, and adds nothing of its own.
module Ferro
  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: MIT OR Apache-2.0
  # SPDX-SnippetCopyrightText: Jacob Pratt et al.
  # SPDX-SnippetComment: the crate overview and the type aliases' docs from
  #   time 0.3.55 src/lib.rs
  #++

  # Date and time, through time 0.3.55.
  #
  # Ruby's ::Time and ::Date answer most questions, by Ruby's rules. A
  # program that exchanges dates with a Rust service, or must agree with
  # Tauri, needs the Rust side's rules instead: which ISO 8601 strings
  # parse, what an RFC 2822 date looks like, how far a date may range, and
  # the words an error uses.
  #
  # This module binds time (https://github.com/time-rs/time), Rust's
  # date and time library, one to one: Date, Time, PlainDateTime,
  # UtcDateTime, OffsetDateTime, UtcOffset, SignedDuration, Month,
  # Weekday, the format descriptions and well-known formats, every error,
  # and Util. time's +large-dates+ feature is off, as Tauri builds it, so
  # years run from -9999 to 9999.
  #
  # Ferro::Time::Time and Ferro::Time::Date are time's types, not Ruby's.
  # Inside the Ferro namespace a bare +Time+ now names this module, so code
  # there writes <tt>::Time</tt> and <tt>::Date</tt> for Ruby's own.
  # OffsetDateTime and UtcDateTime convert to and from Ruby's ::Time, as
  # time's do with Rust's +SystemTime+; nothing converts to or from Ruby's
  # ::Date, as time has no such conversion.
  #
  # === Examples
  #
  #   require "ferro/time"
  #
  #   t = Ferro::Time
  #   at = t::OffsetDateTime.parse("2026-10-26T12:00:00.000Z", t::FormatDescription::WellKnown::Iso8601::DEFAULT)
  #   at.unix_timestamp # => 1_793_016_000
  #   (at + t::Duration.days(1)).weekday # => Ferro::Time::Weekday::Tuesday
  #
  #   t::OffsetDateTime.parse("2026-13-01T00:00:00Z", t::FormatDescription::WellKnown::Iso8601::DEFAULT)
  #   # raises Ferro::Time::Error::Parse::ParseFromDescription::UnexpectedTrailingCharacters
  module Time
    private_constant :Native, :Arguments

    # A PlainDateTime under its original name.
    #
    # This type is not currently deprecated, but it likely will be in the
    # future. Use PlainDateTime when writing new code. In time's next
    # breaking release, this alias will be removed. It is the same class.
    # Mirrors time's <tt>PrimitiveDateTime</tt> (<tt>src/lib.rs:155-166</tt>).
    PrimitiveDateTime = PlainDateTime

    # A SignedDuration under its original name.
    #
    # This type is not currently deprecated, but it likely will be in the
    # future. Use SignedDuration when writing new code. In time's next
    # breaking release, this alias will be removed. It is the same class.
    # Mirrors time's +Duration+ (<tt>src/lib.rs:167-173</tt>).
    Duration = SignedDuration
  end

  #--
  # SPDX-SnippetEnd
  #++
end
