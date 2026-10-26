# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "ferro/notify_rust"
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# Showing a notification needs a desktop's notification server, so most of
# these tests drive what runs without one: the builder, read back through
# notify-rust's fields and Debug text, the values, and the errors. On
# Linux, NotifySuite::Server starts a real server, dunst, on a private
# session bus, and the tests that show notifications use it.
module NotifySuite
  # The platform the extension was built for, as notify-rust's cfg decides.
  PLATFORM = Ferro::NotifyRust.const_get(:PLATFORM)

  # The gem's lib directory, for child processes.
  LIB = File.expand_path("../lib", __dir__)

  # A child runs outside Bundler: it needs only the gem's lib directory and
  # Ruby's own libraries.
  UNBUNDLED = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP BUNDLER_VERSION RUBYOPT RUBYLIB]
    .to_h { |name| [name, nil] }.freeze

  # Load paths a child needs from the bundle: Fiddle, which the macOS
  # tests use to read AppKit, is a bundled gem in Ruby 4.0.
  BUNDLED_PATHS = %w[fiddle].flat_map { |name| Gem.loaded_specs[name]&.full_require_paths || [] }.freeze

  # How long a child may run before it is killed, in seconds: well under
  # the watchdog's limit.
  CHILD_LIMIT = 40

  private def skip_unless_platform(platform)
    skip "#{platform} only; this extension was built for #{PLATFORM}" unless PLATFORM == platform
  end

  # notify-rust deprecates Urgency on macOS, so naming the constant warns
  # there when Warning[:deprecated] is on, as it is under -w. The tests name
  # it through this, quietly.
  private def urgency
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    Ferro::NotifyRust.const_get(:Urgency)
  ensure
    Warning[:deprecated] = deprecated
  end

  # Runs +script+ in a fresh Ruby with the gem loaded, with +env+ added to
  # its environment, and returns the value its last expression marshals to
  # standard output, and what it printed to standard error. A child still
  # running after CHILD_LIMIT seconds is killed and the test fails.
  private def in_child(script, env = {})
    child = <<~RUBY
      require "ferro/notify_rust"
      Warning[:experimental] = false
      value = eval(#{script.dump}, TOPLEVEL_BINDING)
      $stdout.binmode.write(Marshal.dump(value))
    RUBY
    paths = [LIB, *BUNDLED_PATHS].flat_map { |path| ["-I", path] }
    Open3.popen3(UNBUNDLED.merge(env), RbConfig.ruby, *paths, "-e", child) do |stdin, stdout, stderr, thread|
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

  # A real notification server for the Linux tests: dunst, on a session bus
  # of the suite's own, so nothing reaches the user's desktop. It needs
  # dbus-daemon, dunst, and a display (X11 or Wayland) for dunst to draw
  # on; without them the tests that need it skip.
  module Server
    # The programs the server needs.
    PROGRAMS = %w[dbus-daemon dunst dunstctl dbus-send].freeze

    class << self
      # Starts the bus and dunst, once, and points this process at them.
      # Returns why it cannot, or nil.
      def start
        return @missing if defined?(@missing)

        @missing = missing_reason
        launch unless @missing
        @missing
      end

      # Runs +arguments+ against the suite's bus and returns its standard
      # output.
      def run(*arguments)
        output, status = Open3.capture2e(*arguments)
        raise "#{arguments.join(' ')} failed: #{output}" unless status.success?

        output
      end

      # Sends the signal +member+ of org.freedesktop.Notifications with
      # +arguments+ (dbus-send's typed arguments), as a server would.
      def signal(member, *)
        run("dbus-send", "--session", "--type=signal", "/org/freedesktop/Notifications",
          "org.freedesktop.Notifications.#{member}", *)
      end

      # How many match rules each connection on the bus has that name the
      # signal +member+ (dbus-daemon's Debug.Stats interface): a Hash of
      # unique name to count. Each wait adds its own.
      def match_rules(member)
        output = run("dbus-send", "--session", "--print-reply", "--dest=org.freedesktop.DBus",
          "/org/freedesktop/DBus", "org.freedesktop.DBus.Debug.Stats.GetAllMatchRules")
        output.split("dict entry(").drop(1).to_h do |entry|
          [entry[/string "(:[^"]+)"/, 1], entry.scan("member='#{member}'").size]
        end
      end

      # Whether some connection has more rules for +member+ than in
      # +before+, a Hash from #match_rules: a wait started listening. A
      # connection that closed meanwhile does not count.
      def listening_since?(member, before)
        match_rules(member).any? { |name, count| count > before.fetch(name, 0) }
      end

      private def missing_reason
        return "needs Linux" unless NotifySuite::PLATFORM == :linux

        absent = PROGRAMS.reject { |program| which(program) }
        return "needs #{absent.join(', ')}" unless absent.empty?
        return "needs a display (DISPLAY or WAYLAND_DISPLAY) for dunst" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]

        nil
      end

      private def which(program)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, program)) }
      end

      private def launch
        @dir = Dir.mktmpdir("notify-rust-test")
        output = run("dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1",
          "--address=unix:path=#{@dir}/bus")
        address, pid = output.lines.map(&:strip)
        @bus = Integer(pid)
        ENV["DBUS_SESSION_BUS_ADDRESS"] = address
        config = File.join(@dir, "dunstrc")
        File.write(config, "[global]\n    idle_threshold = 0\n    history_length = 50\n")
        @dunst = spawn("dunst", "-config", config, out: File::NULL, err: File.join(@dir, "dunst.log"))
        wait_for_dunst
        Minitest.after_run { stop }
      end

      private def wait_for_dunst
        50.times do
          return if Ferro::NotifyRust.get_server_information.name == "dunst"
        rescue Ferro::NotifyRust::Error
          sleep 0.1
        end
        raise "dunst did not start: #{File.read(File.join(@dir, 'dunst.log'))}"
      end

      private def stop
        [@dunst, @bus].compact.each do |pid|
          Process.kill(:TERM, pid)
        rescue Errno::ESRCH
          nil
        end
        Process.wait(@dunst) if @dunst
        FileUtils.remove_entry(@dir) if @dir
      end
    end
  end

  # Skips unless the Linux notification server runs.
  private def require_server
    missing = Server.start
    skip "the notification server #{missing}" if missing
  end
end
