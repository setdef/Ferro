# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ferro/time"
require "minitest/autorun"
require "open3"
require "rbconfig"

# What the time tests share: shorthands for building values the way
# time's own tests do with its macros, the time source the gem's
# Cargo.lock pins, and a child Ruby for the Ractor tests on Windows.
module TimeSuite
  # The gem's directory.
  ROOT = File.expand_path("..", __dir__)

  # The gem's lib directory, for child processes.
  LIB = File.join(ROOT, "lib")

  # A child runs outside Bundler: it needs only the gem's lib directory.
  UNBUNDLED = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP BUNDLER_VERSION RUBYOPT RUBYLIB]
    .to_h { |name| [name, nil] }.freeze

  T = Ferro::Time
  Month = Ferro::Time::Month
  Weekday = Ferro::Time::Weekday
  Duration = Ferro::Time::Duration
  WellKnown = Ferro::Time::FormatDescription::WellKnown
  Iso8601 = Ferro::Time::FormatDescription::WellKnown::Iso8601

  # The directory of the time crate Cargo unpacked to build this gem, at
  # the version its Cargo.lock pins. Cargo unpacks every crate it builds
  # under its home's <tt>registry/src</tt>; this reads it there, offline.
  def self.crate_dir
    @crate_dir ||= begin
      version = File.read(File.join(ROOT, "Cargo.lock"))[/^name = "time"\nversion = "([^"]+)"$/, 1]
      home = ENV.fetch("CARGO_HOME", File.join(Dir.home, ".cargo"))
      # A pattern treats backslashes as escapes, and a Windows CARGO_HOME
      # has them, so the home is the glob's base rather than its pattern.
      found = Dir.glob(File.join("registry", "src", "*", "time-#{version}"), base: home).first
      (found && File.join(home, found)) ||
        raise("time #{version} is not unpacked under #{home}; compile the gem first")
    end
  end

  # time's <tt>date!(year-month-day)</tt>.
  private def date(year, month, day)
    T::Date.from_calendar_date(year, Month.try_from(month), day)
  end

  # time's <tt>time!(hour:minute:second.nanosecond)</tt>. Not +time+,
  # which Minitest already uses.
  private def clock(hour, minute, second = 0, nanosecond = 0)
    T::Time.from_hms_nano(hour, minute, second, nanosecond)
  end

  # time's <tt>offset!(hours:minutes:seconds)</tt>.
  private def offset(hours, minutes = 0, seconds = 0)
    T::UtcOffset.from_hms(hours, minutes, seconds)
  end

  # time's <tt>datetime!(date time)</tt>, a PlainDateTime.
  private def datetime(year, month, day, hour = 0, minute = 0, second = 0, nanosecond = 0)
    date(year, month, day).with_hms_nano(hour, minute, second, nanosecond)
  end

  # time's <tt>datetime!(date time offset)</tt>, an OffsetDateTime.
  private def odt(year, month, day, hour, minute, second, nanosecond, offset_value)
    datetime(year, month, day, hour, minute, second, nanosecond).assume_offset(offset_value)
  end

  # time's <tt>utc_datetime!(date time)</tt>.
  private def utc(year, month, day, hour = 0, minute = 0, second = 0, nanosecond = 0)
    datetime(year, month, day, hour, minute, second, nanosecond).as_utc
  end

  # A version 3 format description.
  private def fd(text)
    T::FormatDescription.parse_owned(3, text)
  end

  # How long a child may run before it is killed, in seconds: well under
  # the watchdog's limit.
  CHILD_LIMIT = 40

  # Runs +script+ in a fresh Ruby with the gem loaded, and returns the
  # value its last expression marshals to standard output. A child still
  # running after CHILD_LIMIT seconds is killed and the test fails.
  private def in_child(script, env: {})
    child = <<~RUBY
      require "ferro/time"
      Warning[:experimental] = false
      value = eval(#{script.dump}, TOPLEVEL_BINDING)
      $stdout.binmode.write(Marshal.dump(value))
    RUBY
    Open3.popen3(UNBUNDLED.merge(env), RbConfig.ruby, "-I", LIB, "-e", child) do |stdin, stdout, stderr, thread|
      stdin.close
      output = Thread.new { stdout.binmode.read }
      errors = Thread.new { stderr.read }
      unless thread.join(CHILD_LIMIT)
        Process.kill(:KILL, thread.pid)
        flunk "the child Ruby ran past #{CHILD_LIMIT} s and was killed: #{errors.value}"
      end
      raise "the child Ruby failed: #{errors.value}" unless thread.value.success?

      Marshal.load(output.value)
    end
  end
end
