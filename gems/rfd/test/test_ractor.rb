# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# rfd's builders are Send (src/file_dialog.rs:30-33,
# src/message_dialog.rs:24-26), so the extension is marked Ractor-safe and
# a shareable builder or FileHandle may cross Ractors (plan 002, decision
# 12). Without rb_ext_ractor_safe, every native call from a non-main
# Ractor raises Ractor::UnsafeError.
#
# On Windows the script runs in a child process, because of the Ruby 4.0
# barrier bug plan 001 found: a GC inside a Ractor waits forever while the
# main Ractor has a sleeping thread, and Minitest and the watchdog keep
# some. Elsewhere it runs in this process.
class TestRactor < Minitest::Test
  include RfdSuite

  private def run_script(script)
    return in_child(script).first if PLATFORM == :windows

    experimental = Warning[:experimental]
    Warning[:experimental] = false
    eval(script, TOPLEVEL_BINDING)
  ensure
    Warning[:experimental] = experimental unless PLATFORM == :windows
  end

  def test_another_ractor_replays_a_shared_builder_through_rfd
    debug = run_script(<<~RUBY)
      dialog = Ractor.make_shareable(Ferro::Rfd::FileDialog.new.add_filter("text", ["txt"]).set_title("shared"))
      Ractor.new(dialog) { |shared| shared.inspect }.value
    RUBY

    assert_includes debug, 'title: Some("shared")'
    assert_includes debug, 'Filter { name: "text", extensions: ["txt"] }'
  end

  def test_another_ractor_builds_its_own_dialogs_and_handles
    names = run_script(<<~RUBY)
      Ractor.new do
        [Ferro::Rfd::MessageDialog.new.set_level(Ferro::Rfd::MessageLevel::Warning).inspect,
          Ferro::Rfd::FileHandle.new("/tmp/report.csv").file_name]
      end.value
    RUBY

    assert_includes names.first, "level: Warning"
    assert_equal "report.csv", names.last
  end
end
