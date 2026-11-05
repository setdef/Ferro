# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: Apache-2.0 OR MIT
# SPDX-SnippetCopyrightText: 2022 The Arboard contributors
# SPDX-SnippetComment: The selection and wait tests ported from arboard 3.7.0
#   src/lib.rs:424-480
#++

# The Linux extensions, ported from arboard's selection and wait tests
# (src/lib.rs:424-480). They run only where arboard compiles them.
class TestLinux < Minitest::Test
  include ClipboardSuite

  def setup
    skip_unless_platform(:linux)
  end

  private def kinds
    Ferro::Arboard::LinuxClipboardKind
  end

  # The Secondary selection does not exist under Wayland; ferro-arboard
  # always builds arboard's Wayland support.
  private def secondary?
    ENV["WAYLAND_DISPLAY"].nil?
  end

  def test_each_selection_holds_its_own_text
    clipboard.set.clipboard(kinds::Clipboard).text("I'm a little teapot,")
    clipboard.set.clipboard(kinds::Primary).text("short and stout,")
    clipboard.set.clipboard(kinds::Secondary).text("here is my handle") if secondary?

    assert_equal "I'm a little teapot,", clipboard.get.clipboard(kinds::Clipboard).text
    assert_equal "short and stout,", clipboard.get.clipboard(kinds::Primary).text
    assert_equal "here is my handle", clipboard.get.clipboard(kinds::Secondary).text if secondary?
  end

  # As in arboard's test, another thread replaces the text: the wait
  # releases Ruby's global lock, so the thread runs. A watchdog process
  # replaces it too, later, so a setter that fails cannot hang the suite.
  def test_wait_returns_once_another_thread_replaces_the_text
    lib = File.expand_path("../lib", __dir__)
    watchdog_script = %(sleep 30; require "ferro/arboard"; Ferro::Arboard::Clipboard.new.set_text("watchdog"))
    watchdog = spawn(RbConfig.ruby, "-I", lib, "-e", watchdog_script)
    replaced = false
    setter = Thread.new do
      sleep 0.1
      Ferro::Arboard::Clipboard.new.set_text("replacement text")
      replaced = true
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    clipboard.set.wait.text("initial text")

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 30, "only the watchdog ended the wait"
    setter.join
    assert replaced
  ensure
    Process.kill(:KILL, watchdog) if watchdog
    Process.wait(watchdog) if watchdog
  end

  #--
  # SPDX-SnippetEnd
  #++

  # A write that waits once returns after another program reads it
  # (src/platform/linux/x11.rs:293-296). On X11 a read from this process is
  # served without a request (x11.rs:307-308), so a subprocess reads. On
  # Wayland arboard copies in the background unless it waits forever
  # (src/platform/linux/wayland.rs:63-68), and wl-clipboard-rs serves the
  # one request from a thread of its own (wl-clipboard-rs 0.9.4
  # src/copy.rs:1043-1050), so the write returns at once there.
  #
  # The order is proven without a clock. A second Clipboard polls until it
  # reads the text; the setter must still be waiting then. The probe owns
  # the selection first, so each of its reads is served in process
  # (x11.rs:307-308), never as another program's request: a read made
  # while ownership changes hands would be served over X and end the wait.
  # Only the subprocess's read may end the wait. A watchdog process
  # replaces the text after 30 seconds, so a wait that nothing ended cannot
  # hang the suite; it prints a mark first, so the mark is there by the
  # time its write could wake the setter, and the test fails on it. A
  # narrow window inside arboard (x11.rs:258-286) remains between the text
  # becoming readable and the setter starting to wait; the subprocess's
  # startup covers it.
  def test_wait_once_returns_after_another_program_reads_the_text
    skip "X11 only: on Wayland, wait_once returns before the read" if ENV["WAYLAND_DISPLAY"]
    lib = File.expand_path("../lib", __dir__)
    fired, marker = IO.pipe
    watchdog_script = %(sleep 30; puts "fired"; $stdout.flush; require "ferro/arboard"; Ferro::Arboard::Clipboard.new.set_text("watchdog"))
    watchdog = spawn(RbConfig.ruby, "-I", lib, "-e", watchdog_script, out: marker)
    marker.close
    probe = Ferro::Arboard::Clipboard.new
    probe.set_text("probe owns the selection")
    setter = Thread.new { clipboard.set.wait_once.text("served once") }
    Thread.pass until (probe.get_text rescue nil) == "served once" # rubocop:disable Style/RescueModifier

    assert_predicate setter, :alive?, "wait_once returned before anything else read the text"
    reader = %(require "ferro/arboard"; print Ferro::Arboard::Clipboard.new.get_text)
    assert_equal "served once", IO.popen([RbConfig.ruby, "-I", lib, "-e", reader], &:read)
    setter.join
    Process.kill(:KILL, watchdog)
    Process.wait(watchdog)

    assert_empty fired.read, "only the watchdog ended the wait"
  ensure
    if watchdog
      begin
        Process.kill(:KILL, watchdog)
        Process.wait(watchdog)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
    fired&.close
  end

  def test_a_past_deadline_returns_at_once
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    clipboard.set.wait_until(started - 1).text("no waiting")

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end

  def test_a_deadline_an_instant_cannot_hold_raises_range_error
    error = assert_raises(RangeError) { clipboard.set.wait_until(Float::NAN).text("never") }

    assert_equal "cannot convert float seconds to Duration: value is either too big or NaN", error.message
  end

  # arboard's wait_until takes an Instant (src/platform/linux/mod.rs:344);
  # any Numeric number of seconds on the monotonic clock stands for one
  # (ADR 001, 2026-11-05, the Duration row).
  def test_wait_until_takes_any_numeric
    error = assert_raises(TypeError) { clipboard.set.wait_until("soon") }
    assert_equal "wrong argument type String (expected Numeric)", error.message

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    [now.floor - 1, Rational(now.floor - 1), now - 1].each do |past|
      set = clipboard.set
      assert_same set, set.wait_until(past)
      set.text("no waiting")
    end
  end

  def test_a_consumed_builder_refuses_the_linux_options
    clipboard.set_text("read once")
    get = clipboard.get
    get.clipboard(kinds::Clipboard).text
    set = clipboard.set
    set.clipboard(kinds::Primary).text("once")
    clear = clipboard.clear_with
    clear.clipboard(kinds::Primary)

    assert_raises(IOError) { get.clipboard(kinds::Primary) }
    %i[wait wait_once exclude_from_history].each do |option|
      error = assert_raises(IOError, option.to_s) { set.public_send(option) }
      assert_equal "Ferro::Arboard::Set consumed by Set#text", error.message
    end
    assert_raises(IOError) { set.wait_until(0) }
    assert_raises(IOError) { set.clipboard(kinds::Clipboard) }
    error = assert_raises(IOError) { clear.clipboard(kinds::Primary) }
    assert_equal "Ferro::Arboard::Clear consumed by ClearExtLinux#clipboard", error.message
    assert_raises(IOError) { clear.default }
  end

  def test_clear_with_a_selection_clears_only_it
    clipboard.set.clipboard(kinds::Clipboard).text("kept")
    clipboard.set.clipboard(kinds::Primary).text("cleared")

    clipboard.clear_with.clipboard(kinds::Primary)

    assert_equal "kept", clipboard.get.clipboard(kinds::Clipboard).text
    assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get.clipboard(kinds::Primary).text }
  end

  # Wayland has no Secondary selection, so arboard refuses it
  # (src/platform/linux/wayland.rs:30-54). With DISPLAY set, arboard could
  # fall back to X11 (src/platform/linux/mod.rs:133-150), so the test runs
  # only where CI's sway pass runs it: Wayland with DISPLAY unset.
  def test_secondary_is_not_supported_on_wayland
    skip "Wayland with DISPLAY unset only" unless ENV["WAYLAND_DISPLAY"] && ENV["DISPLAY"].nil?
    calls = {
      get: -> { clipboard.get.clipboard(kinds::Secondary).text },
      set: -> { clipboard.set.clipboard(kinds::Secondary).text("x") },
      clear: -> { clipboard.clear_with.clipboard(kinds::Secondary) },
    }

    calls.each do |name, call|
      error = assert_raises(Ferro::Arboard::Error::ClipboardNotSupported, name.to_s, &call)
      assert_equal NOT_SUPPORTED, error.message
    end
  end

  # With no display server, arboard's X11 connection fails with an Unknown
  # error (src/platform/linux/x11.rs:139-145). A subprocess without
  # WAYLAND_DISPLAY or DISPLAY opens the clipboard, so the suite's own keeps
  # its display.
  def test_no_display_server_raises_unknown
    lib = File.expand_path("../lib", __dir__)
    script = <<~RUBY
      require "ferro/arboard"
      begin
        Ferro::Arboard::Clipboard.new
      rescue Ferro::Arboard::Error::Unknown => e
        puts e.description, e.message
      end
    RUBY
    output = IO.popen({ "WAYLAND_DISPLAY" => nil, "DISPLAY" => nil }, [RbConfig.ruby, "-I", lib, "-e", script], &:read)

    description = "X11 server connection timed out because it was unreachable"
    assert_equal [description, "Unknown error while interacting with the clipboard: #{description}"],
      output.lines(chomp: true)
  end

  def test_the_kinds_are_three_frozen_values
    refute_respond_to kinds::Primary, :to_sym, "arboard's enum has no such method"
    assert Ractor.shareable?(kinds::Primary)
    assert_raises(NoMethodError) { kinds.new(:Tertiary) }
  end

  # LinuxClipboardKind derives Debug (src/platform/linux/mod.rs:104), which
  # Rust formats; inspect stays Ruby's (ADR 001, 2026-11-05).
  def test_the_kinds_debug_as_arboards_variants
    assert_equal %w[Clipboard Primary Secondary], [kinds::Clipboard, kinds::Primary, kinds::Secondary].map(&:debug)
    assert_match(/\A#<Ferro::Arboard::LinuxClipboardKind[ :]/, kinds::Primary.inspect)
    refute_equal "Ferro::Arboard::LinuxClipboardKind::Primary", kinds::Primary.inspect
  end

  def test_a_selection_must_be_a_kind
    error = assert_raises(TypeError) { clipboard.get.clipboard(:Primary) }

    assert_equal "wrong argument type Symbol (expected Ferro::Arboard::LinuxClipboardKind)", error.message
  end
end
