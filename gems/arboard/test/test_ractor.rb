# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"

# arboard's Clipboard is Send and Sync (src/lib.rs:510-516), so the
# extension is marked Ractor-safe and a frozen clipboard may be shared
# (plan 001, decision 13). Without rb_ext_ractor_safe, every call from a
# non-main Ractor raises Ractor::UnsafeError.
#
# Each test is a script whose last value is what it checks. On Windows the
# script runs in a child process, because of a Ruby 4.0 bug there: a VM
# barrier (a GC inside a Ractor starts one) waits forever while the main
# Ractor has a thread asleep and its main thread waits in Ractor#value.
# Ruby's Windows barrier counts a Ractor as stopped only when all its
# threads are in blocking regions, which a sleeping thread is not
# (thread_win32.c:932-963, ractor.c:781-790, thread.c:170-178 and :1535 at
# v4.0.9), and Minitest and the test watchdog always keep threads asleep
# here. A child process has only its main thread. Elsewhere the script runs
# in this process. Plan 001 has the evidence.
class TestRactor < Minitest::Test
  include ClipboardSuite

  # The child: reads a script on stdin and writes its value, marshaled.
  CHILD = <<~RUBY
    require "ferro/arboard"
    Warning[:experimental] = false
    $stdout.binmode.write(Marshal.dump(eval($stdin.read, TOPLEVEL_BINDING)))
  RUBY

  # The value of +script+, run as the comment above says.
  private def run_script(script)
    return in_child(script) if PLATFORM == :windows

    experimental = Warning[:experimental]
    Warning[:experimental] = false
    eval(script, TOPLEVEL_BINDING)
  ensure
    Warning[:experimental] = experimental unless PLATFORM == :windows
  end

  private def in_child(script)
    Dir.mktmpdir("ferro-ractor") do |dir|
      child = File.join(dir, "child.rb")
      File.write(child, CHILD)
      output, errors, status = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__), child,
        stdin_data: script, binmode: true)
      raise "the child Ruby failed: #{errors}" unless status.success?

      Marshal.load(output)
    end
  end

  def test_another_ractor_round_trips_text_through_a_shared_clipboard
    read, read_here = run_script(<<~RUBY)
      shared = Ractor.make_shareable(Ferro::Arboard::Clipboard.new)
      read = Ractor.new(shared) do |clipboard|
        clipboard.set_text("from a Ractor")
        clipboard.get_text
      end.value
      [read, Ferro::Arboard::Clipboard.new.get_text]
    RUBY

    assert_equal "from a Ractor", read
    assert_equal "from a Ractor", read_here
  end

  def test_another_ractor_opens_its_own_clipboard_and_rescues_arboards_errors
    raised = run_script(<<~RUBY)
      Ractor.new do
        clipboard = Ferro::Arboard::Clipboard.new
        clipboard.clear
        clipboard.get_text
      rescue Ferro::Arboard::Error::ContentNotAvailable => e
        e.message
      end.value
    RUBY

    assert_equal NOT_AVAILABLE, raised
  end
end
