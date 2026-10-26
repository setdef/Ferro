# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# On macOS, rfd panics when a dialog starts off the main thread while no
# application runs its event loop, after creating the NSApplication from
# that thread (src/backend/macos/utils.rs:20-31, modal_future.rs:104-119).
# ferro-rfd refuses first, with rfd's message (plan 002, decision 5). The
# test process runs no application, so a Ruby thread is such a thread.
class TestThreads < Minitest::Test
  include RfdSuite

  # SPDX-SnippetBegin
  # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
  # SPDX-License-Identifier: MIT
  # SPDX-SnippetComment: rfd 0.17.2's panic messages, verbatim, from
  #   src/backend/macos/utils.rs:29 and modal_future.rs:117
  NON_WINDOWED = "You are running RFD in NonWindowed environment, it is impossible to spawn dialog from thread " \
    "different than main in this env."
  FALLBACK = "Fallback Sync Dialog Must Be Spawned On Main Thread (Why? If async dialog is unsupported in this " \
    "env, it also means that spawning dialogs outside of main thread is also inpossible"
  # SPDX-SnippetEnd

  private def off_the_main_thread(&)
    Thread.new(&).join.value
  end

  def test_sync_dialogs_off_the_main_thread_raise_rfds_message
    skip_unless_platform(:macos)
    calls = {
      pick_file: -> { Ferro::Rfd::FileDialog.new.pick_file },
      pick_folders: -> { Ferro::Rfd::FileDialog.new.pick_folders },
      save_file: -> { Ferro::Rfd::FileDialog.new.save_file },
      pick_files_or_folders: -> { Ferro::Rfd::FileDialog.new.pick_files_or_folders },
      show: -> { Ferro::Rfd::MessageDialog.new.show },
    }

    calls.each do |name, call|
      error = off_the_main_thread { assert_raises(Ferro::Rfd::Error, name.to_s, &call) }
      assert_equal NON_WINDOWED, error.message
    end
  end

  def test_async_file_dialogs_off_the_main_thread_raise_rfds_message
    skip_unless_platform(:macos)

    error = off_the_main_thread { assert_raises(Ferro::Rfd::Error) { Ferro::Rfd::AsyncFileDialog.new.pick_file } }
    assert_equal FALLBACK, error.message
  end
end
