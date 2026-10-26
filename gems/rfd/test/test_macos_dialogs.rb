# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# Real macOS dialogs that close themselves. While the dialog runs its modal
# loop on the main thread, another Ruby thread asks AppKit, through Fiddle,
# to run -[NSApplication abortModal] on the main thread, as rfd's dialog
# never would on its own. That thread runs only if the dialog released the
# GVL, so a dialog that held it would never close, and the watchdog would
# fail the test. Each runs in a child process, since an abort still queued
# when the dialog closes would close the next one.
class TestMacosDialogs < Minitest::Test
  include RfdSuite

  # Defines AppKit.abort_modal_until in the child: sends abortModal to the
  # main thread every quarter second until the block's flag is set, and
  # counts the sends.
  APPKIT = <<~RUBY
    require "fiddle"
    module AppKit
      OBJC = Fiddle.dlopen("/usr/lib/libobjc.A.dylib")
      KIT = Fiddle.dlopen("/System/Library/Frameworks/AppKit.framework/AppKit")
      SEL = Fiddle::Function.new(OBJC["sel_registerName"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
      SEND = Fiddle::Function.new(OBJC["objc_msgSend"],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_CHAR],
        Fiddle::TYPE_VOIDP)

      def self.abort_modal_until(done)
        Thread.new do
          sends = 0
          until done.call
            sleep 0.25
            app = Fiddle::Pointer.new(KIT["NSApp"]).ptr
            next if app.null?

            SEND.call(app, SEL.call("performSelectorOnMainThread:withObject:waitUntilDone:"),
              SEL.call("abortModal"), nil, 0)
            sends += 1
          end
          sends
        end
      end
    end
  RUBY

  def setup
    skip_unless_platform(:macos)
  end

  def test_a_sync_dialog_releases_the_gvl_and_returns_nil_when_aborted
    (result, sends), = in_child(<<~RUBY)
      #{APPKIT}
      done = false
      aborter = AppKit.abort_modal_until(-> { done })
      result = Ferro::Rfd::FileDialog.new.set_title("ferro-rfd test: this closes itself").pick_file
      done = true
      [result, aborter.value]
    RUBY

    assert_nil result
    assert_operator sends, :>=, 1
  end

  def test_pick_files_returns_nil_when_aborted
    (result,), = in_child(<<~RUBY)
      #{APPKIT}
      done = false
      aborter = AppKit.abort_modal_until(-> { done })
      result = Ferro::Rfd::FileDialog.new.pick_files
      done = true
      [result, aborter.value]
    RUBY

    assert_nil result
  end

  # Without a running application, rfd falls back to a modal there and
  # then, inside pick_folder (src/backend/macos/modal_future.rs:104-119),
  # printing a note; the Future is finished before value is called.
  def test_an_async_dialog_without_an_app_runs_when_started
    (sends_before_value, result), errors = in_child(<<~RUBY)
      #{APPKIT}
      done = false
      aborter = AppKit.abort_modal_until(-> { done })
      future = Ferro::Rfd::AsyncFileDialog.new.pick_folder
      done = true
      sends = aborter.value
      [sends, future.value]
    RUBY

    assert_operator sends_before_value, :>=, 1
    assert_nil result
    assert_includes errors, "I will fallback to sync dialog for you."
  end
end
