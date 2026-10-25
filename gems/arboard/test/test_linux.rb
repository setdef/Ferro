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

  def test_a_past_deadline_returns_at_once
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    clipboard.set.wait_until(started - 1).text("no waiting")

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end

  def test_a_deadline_an_instant_cannot_hold_raises_range_error
    error = assert_raises(RangeError) { clipboard.set.wait_until(Float::NAN).text("never") }

    assert_equal "cannot convert float seconds to Duration: value is either too big or NaN", error.message
  end

  def test_wait_until_takes_a_number
    assert_raises(TypeError) { clipboard.set.wait_until("soon") }
  end

  def test_clear_with_a_selection_clears_only_it
    clipboard.set.clipboard(kinds::Clipboard).text("kept")
    clipboard.set.clipboard(kinds::Primary).text("cleared")

    clipboard.clear_with.clipboard(kinds::Primary)

    assert_equal "kept", clipboard.get.clipboard(kinds::Clipboard).text
    assert_raises(Ferro::Arboard::Error::ContentNotAvailable) { clipboard.get.clipboard(kinds::Primary).text }
  end

  def test_the_kinds_are_three_frozen_values
    assert_equal %w[Clipboard Primary Secondary].map { |name| "Ferro::Arboard::LinuxClipboardKind::#{name}" },
      [kinds::Clipboard, kinds::Primary, kinds::Secondary].map(&:inspect)
    refute_respond_to kinds::Primary, :to_sym, "arboard's enum has no such method"
    assert Ractor.shareable?(kinds::Primary)
    assert_raises(NoMethodError) { kinds.new(:Tertiary) }
  end

  def test_a_selection_must_be_a_kind
    error = assert_raises(TypeError) { clipboard.get.clipboard(:Primary) }

    assert_equal "wrong argument type Symbol (expected Ferro::Arboard::LinuxClipboardKind)", error.message
  end
end

#--
# SPDX-SnippetEnd
#++
