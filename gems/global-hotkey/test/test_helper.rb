# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

require "ferro/global_hotkey"
require "minitest/autorun"
require "open3"
require "rbconfig"

# A registered hotkey belongs to the whole desktop while it is registered,
# and an event needs a key press, so these tests take care with both:
#
# - They register only combinations nobody uses, Control, Alt, Shift,
#   and Meta with F19 or F24, and always unregister them.
# - On Linux, everything that talks to X runs against a private Xvfb
#   server the suite starts (HotkeySuite::XServer), never the desktop's
#   display, so keys xdotool presses and keymap changes reach nothing of
#   the user's.
# - global-hotkey's event handler is set once per process, so the tests
#   that deliver events run in child processes (HotkeySuite#in_child).
module HotkeySuite
  # The platform the extension was built for, as global-hotkey's cfg
  # decides.
  PLATFORM = Ferro::GlobalHotkey.const_get(:PLATFORM)

  # The gem's lib directory, for child processes.
  LIB = File.expand_path("../lib", __dir__)

  # A child runs outside Bundler: it needs only the gem's lib directory and
  # Ruby's own libraries.
  UNBUNDLED = %w[BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP BUNDLER_VERSION RUBYOPT RUBYLIB]
    .to_h { |name| [name, nil] }.freeze

  # Load paths a child needs from the bundle: Fiddle, which the Windows
  # tests use to press keys and pump messages, is a bundled gem in Ruby 4.0.
  BUNDLED_PATHS = %w[fiddle].flat_map { |name| Gem.loaded_specs[name]&.full_require_paths || [] }.freeze

  # How long a child may run before it is killed, in seconds: well under
  # the watchdog's limit.
  CHILD_LIMIT = 40

  GlobalHotkey = Ferro::GlobalHotkey
  Hotkey = Ferro::GlobalHotkey::Hotkey

  private def skip_unless_platform(platform)
    skip "#{platform} only; this extension was built for #{PLATFORM}" unless PLATFORM == platform
  end

  # A hotkey nobody uses: Control, Alt, Shift, and Meta with +key+.
  private def unusual(key = Hotkey::Code::F19)
    mods = Hotkey::Modifiers
    Hotkey::HotKey.new(mods::CONTROL | mods::ALT | mods::SHIFT | mods::META, key)
  end

  # Names a deprecated constant quietly, since the tests run under -w.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

  # Runs +script+ in a fresh Ruby with the gem loaded, with +env+ added to
  # its environment, and returns the value its last expression marshals to
  # standard output, and what it printed to standard error. A child still
  # running after CHILD_LIMIT seconds is killed and the test fails.
  private def in_child(script, env = {})
    child = <<~RUBY
      require "ferro/global_hotkey"
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

  # A private X server for the Linux tests: Xvfb on a display of its own,
  # with F17 to F19 and F24 mapped to spare keycodes, since Xvfb's default
  # keymap stops at F12. It needs Xvfb, xdotool, and xmodmap; without them
  # the tests that need it skip.
  module XServer
    # The programs the server needs.
    PROGRAMS = %w[Xvfb xdotool xmodmap].freeze

    # The keys the tests register, which the server's keymap gains.
    KEYS = %w[F17 F18 F19 F24].freeze

    class << self
      # Starts Xvfb, once, and returns why it cannot, or nil.
      def start
        return @missing if defined?(@missing)

        @missing = missing_reason
        launch unless @missing
        @missing
      end

      # The private server's display, such as <tt>:3</tt>.
      attr_reader :display

      # The environment that points a program at the private server.
      def env
        { "DISPLAY" => display, "WAYLAND_DISPLAY" => nil }
      end

      # Runs +arguments+ against the private server and returns its
      # standard output.
      def run(*arguments)
        output, status = Open3.capture2e(env, *arguments)
        raise "#{arguments.join(' ')} failed: #{output}" unless status.success?

        output
      end

      private def missing_reason
        return "needs Linux" unless HotkeySuite::PLATFORM == :linux

        absent = PROGRAMS.reject { |program| which(program) }
        absent.empty? ? nil : "needs #{absent.join(', ')}"
      end

      private def which(program)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, program)) }
      end

      private def launch
        reader, writer = IO.pipe
        # -noreset keeps the keymap when the last client disconnects, which
        # would otherwise reset the server.
        @pid = spawn("Xvfb", "-displayfd", writer.fileno.to_s, "-nolisten", "tcp", "-noreset",
          "-screen", "0", "640x480x24", writer => writer, :out => File::NULL, :err => File::NULL)
        writer.close
        number = reader.gets or raise "Xvfb did not report its display"
        reader.close
        @display = ":#{number.strip}"
        map_keys
        Minitest.after_run { stop }
      end

      # Gives each of KEYS one of the keycodes the keymap leaves empty.
      private def map_keys
        spare = run("xmodmap", "-pke").lines.filter_map { |line| line[/\Akeycode\s+(\d+) =\s*\z/, 1] }
          .map { |code| Integer(code) }.select { |code| code >= 9 }
        raise "the private X server has too few spare keycodes" if spare.size < KEYS.size

        KEYS.zip(spare).each { |key, code| run("xmodmap", "-e", "keycode #{code} = #{key}") }
      end

      private def stop
        Process.kill(:TERM, @pid)
        Process.wait(@pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end

  # Skips unless the private X server runs, and points this process at it,
  # so a manager made here grabs keys on that server.
  private def require_x_server
    missing = XServer.start
    skip "the private X server #{missing}" if missing
    ENV["DISPLAY"] = XServer.display
  end
end
