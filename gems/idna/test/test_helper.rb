# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ferro/idna"
require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"

# What the idna tests share: the idna source the gem's Cargo.lock pins,
# whose own test data are the answer key, and a child Ruby for the
# Ractor tests on Windows.
module IdnaSuite
  # The gem's directory.
  ROOT = File.expand_path("..", __dir__)

  # The gem's lib directory, for child processes.
  LIB = File.join(ROOT, "lib")

  # A child runs outside Bundler: it needs only the gem's lib directory.
  UNBUNDLED = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP BUNDLER_VERSION RUBYOPT RUBYLIB]
    .to_h { |name| [name, nil] }.freeze

  Idna = Ferro::Idna
  Uts46 = Ferro::Idna::Uts46

  # The directory of the idna crate Cargo unpacked to build this gem, at
  # the version its Cargo.lock pins, so the tests read idna's own test data
  # at the version the gem binds. Cargo unpacks every crate it builds under
  # its home's <tt>registry/src</tt>; this reads it there, offline, rather
  # than through cargo metadata, which wants every platform's crates.
  def self.crate_dir
    @crate_dir ||= begin
      version = File.read(File.join(ROOT, "Cargo.lock"))[/^name = "idna"\nversion = "([^"]+)"$/, 1]
      home = ENV.fetch("CARGO_HOME", File.join(Dir.home, ".cargo"))
      # A pattern treats backslashes as escapes, and a Windows CARGO_HOME
      # has them, so the home is the glob's base rather than its pattern.
      found = Dir.glob(File.join("registry", "src", "*", "idna-#{version}"), base: home).first
      (found && File.join(home, found)) ||
        raise("idna #{version} is not unpacked under #{home}; compile the gem first")
    end
  end

  # The contents of +name+ in idna's tests directory.
  def self.crate_test_file(name)
    File.read(File.join(crate_dir, "tests", name), encoding: "UTF-8")
  end

  # Names a deprecated constant quietly, since the tests run under -w.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

  # The deprecated Config and Idna, named quietly.
  private def config_class
    quietly { Idna::Config }
  end

  private def idna_class
    quietly { Idna::Idna }
  end

  # Runs +script+ in a fresh Ruby with the gem loaded, and returns the
  # value its last expression marshals to standard output.
  private def in_child(script)
    child = <<~RUBY
      require "ferro/idna"
      Warning[:experimental] = false
      value = eval(#{script.dump}, TOPLEVEL_BINDING)
      $stdout.binmode.write(Marshal.dump(value))
    RUBY
    output, errors, status = Open3.capture3(UNBUNDLED, RbConfig.ruby, "-I", LIB, "-e", child)
    raise "the child Ruby failed: #{errors}" unless status.success?

    Marshal.load(output)
  end
end
