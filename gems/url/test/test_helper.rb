# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ferro/url"
require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"

# What the url tests share: the url source the gem's Cargo.lock pins,
# whose own test data are the answer key, and a child Ruby for the
# Ractor tests on Windows.
module UrlSuite
  # The gem's directory.
  ROOT = File.expand_path("..", __dir__)

  # The gem's lib directory, for child processes.
  LIB = File.join(ROOT, "lib")

  # A child runs outside Bundler: it needs only the gem's lib directory.
  UNBUNDLED = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP BUNDLER_VERSION RUBYOPT RUBYLIB]
    .to_h { |name| [name, nil] }.freeze

  U = Ferro::Url
  Url = Ferro::Url::Url
  Position = Ferro::Url::Position

  # The directory of the url crate Cargo unpacked to build this gem, at
  # the version its Cargo.lock pins, so the tests read url's own test data
  # at the version the gem binds. Cargo unpacks every crate it builds under
  # its home's <tt>registry/src</tt>; this reads it there, offline, rather
  # than through cargo metadata, which wants every platform's crates.
  def self.crate_dir
    @crate_dir ||= begin
      version = File.read(File.join(ROOT, "Cargo.lock"))[/^name = "url"\nversion = "([^"]+)"$/, 1]
      home = ENV.fetch("CARGO_HOME", File.join(Dir.home, ".cargo"))
      Dir.glob(File.join(home, "registry", "src", "*", "url-#{version}")).first ||
        raise("url #{version} is not unpacked under #{home}; compile the gem first")
    end
  end

  # The contents of +name+ in url's tests directory.
  def self.crate_test_file(name)
    File.read(File.join(crate_dir, "tests", name), encoding: "UTF-8")
  end

  private def url(input)
    Url.parse(input)
  end

  # How long a child may run before it is killed, in seconds: well under
  # the watchdog's limit.
  CHILD_LIMIT = 40

  # Runs +script+ in a fresh Ruby with the gem loaded, and returns the
  # value its last expression marshals to standard output. A child still
  # running after CHILD_LIMIT seconds is killed and the test fails, so a
  # deadlock fails rather than hangs.
  private def in_child(script)
    child = <<~RUBY
      require "ferro/url"
      Warning[:experimental] = false
      value = eval(#{script.dump}, TOPLEVEL_BINDING)
      $stdout.binmode.write(Marshal.dump(value))
    RUBY
    Open3.popen3(UNBUNDLED, RbConfig.ruby, "-I", LIB, "-e", child) do |stdin, stdout, stderr, thread|
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
