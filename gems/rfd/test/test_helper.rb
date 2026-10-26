# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "ferro/rfd"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

# Dialogs wait for a person, so most of these tests drive what runs
# without one: the builders, read back through rfd's own Debug text, the
# values, and the refusals. The few that open a real dialog close it
# themselves (test_linux_dialogs.rb, test_macos_dialogs.rb).
module RfdSuite
  # The platform the extension was built for, as rfd's cfg decides it.
  PLATFORM = Ferro::Rfd.const_get(:PLATFORM)

  # The gem's lib directory, for child processes.
  LIB = File.expand_path("../lib", __dir__)

  private def skip_unless_platform(platform)
    skip "#{platform} only; this extension was built for #{PLATFORM}" unless PLATFORM == platform
  end

  # A parent window for set_parent: anything that answers window_handle
  # and display_handle.
  Parent = Data.define(:window_handle, :display_handle)

  # A child runs outside Bundler: it needs only the gem's lib directory and
  # Ruby's own libraries, so a test may give it a PATH without git.
  UNBUNDLED = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP BUNDLER_VERSION RUBYOPT RUBYLIB]
    .to_h { |name| [name, nil] }.freeze

  # How long a child may run before it is killed, in seconds: well under
  # the watchdog's limit, so a dialog left open never outlives the test.
  CHILD_LIMIT = 30

  # Runs +script+ in a fresh Ruby with the gem loaded, with +env+ added to
  # its environment, and returns the value its last expression marshals to
  # standard output, and what it printed to standard error. A dialog test
  # runs in a child, so whatever it leaves queued on the platform's event
  # loop dies with it; a child still running after CHILD_LIMIT seconds is
  # killed and the test fails.
  private def in_child(script, env = {})
    child = <<~RUBY
      require "ferro/rfd"
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

      [Marshal.load(output.value), errors.value]
    end
  end
end
