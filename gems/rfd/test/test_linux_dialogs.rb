# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# Real Linux dialogs, answered by a stand-in for zenity.
#
# rfd's portal backend asks the XDG desktop portal over D-Bus and, when
# that fails, runs zenity (src/backend/xdg_desktop_portal.rs:98-113); its
# message dialogs always run zenity (:297-341). With D-Bus pointed at a
# socket that does not exist and a fake zenity first on PATH, every
# terminal method runs rfd's own code end to end: rfd builds zenity's
# arguments, the fake records them and answers as zenity would, and rfd
# turns the answer into its result (src/backend/linux/zenity.rs). Each
# runs in a child process with that environment.
class TestLinuxDialogs < Minitest::Test
  include RfdSuite

  FAKE_ZENITY = <<~SH
    #!/bin/sh
    printf '%s\\n' "$@" > "$FAKE_ZENITY_LOG"
    sleep "${FAKE_ZENITY_SLEEP:-0}"
    printf '%s' "$FAKE_ZENITY_OUTPUT"
    exit "${FAKE_ZENITY_STATUS:-0}"
  SH

  def setup
    skip_unless_platform(:linux)
    @dir = Dir.mktmpdir("ferro-rfd")
    @bin = File.join(@dir, "bin")
    Dir.mkdir(@bin)
    File.write(File.join(@bin, "zenity"), FAKE_ZENITY)
    File.chmod(0o755, File.join(@bin, "zenity"))
    @log = File.join(@dir, "zenity.log")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end

  # Runs +script+ in a child whose zenity is the fake, first on +path+,
  # which prints +output+ and exits with +status+ after +sleep+ seconds. Returns the script's value and the
  # arguments rfd passed zenity (nil if it never ran).
  private def answer(script, output: "", status: 0, sleep: 0, path: "#{@bin}:/usr/bin:/bin")
    env = {
      "PATH" => path,
      "DBUS_SESSION_BUS_ADDRESS" => "unix:path=#{File.join(@dir, 'no-bus')}",
      "FAKE_ZENITY_LOG" => @log,
      "FAKE_ZENITY_OUTPUT" => output,
      "FAKE_ZENITY_STATUS" => status.to_s,
      "FAKE_ZENITY_SLEEP" => sleep.to_s,
    }
    value, = in_child(script, env)
    [value, File.exist?(@log) ? File.read(@log).lines(chomp: true) : nil]
  end

  def test_pick_file_passes_the_options_and_returns_the_path
    path, args = answer(<<~RUBY, output: "/home/me/notes one.txt\n")
      Ferro::Rfd::FileDialog.new.add_filter("text", ["txt", "rs"]).set_file_name("notes.txt").pick_file
    RUBY

    assert_equal "/home/me/notes one.txt", path
    assert_equal [
      "--no-markup",
      "--file-selection",
      "--file-filter",
      "text | *.txt *.rs",
      "--filename",
      "notes.txt",
], args
  end

  def test_each_file_dialog_call_asks_zenity_for_its_kind
    {
      "pick_files" => [%w[--file-selection --multiple], "/a|/b", %w[/a /b]],
      "pick_folder" => [%w[--file-selection --directory], "/a\n", "/a"],
      "pick_folders" => [%w[--file-selection --directory --multiple], "/a|/b\n", %w[/a /b]],
      "save_file" => [%w[--file-selection --save --confirm-overwrite], "/a.txt\n", "/a.txt"],
    }.each do |call, (flags, output, expected)|
      result, args = answer("Ferro::Rfd::FileDialog.new.#{call}", output:)

      assert_equal expected, result, call
      assert_equal ["--no-markup", *flags], args, call
    end
  end

  # zenity exits 1 when the user cancels. rfd returns None for one path,
  # and an empty list for several (zenity.rs:95-109).
  def test_a_cancelled_dialog_returns_nil_or_an_empty_list
    assert_nil answer("Ferro::Rfd::FileDialog.new.pick_file", status: 1).first
    assert_equal [], answer("Ferro::Rfd::FileDialog.new.pick_files", status: 1).first
  end

  # Without the portal or zenity, rfd logs and returns None
  # (xdg_desktop_portal.rs:105-112) or Cancel (:313-316).
  def test_without_zenity_a_dialog_answers_nothing_at_once
    empty = File.join(@dir, "empty")
    Dir.mkdir(empty)

    assert_nil answer("Ferro::Rfd::FileDialog.new.pick_file", path: empty).first
    assert_equal "Cancel", answer("Ferro::Rfd::MessageDialog.new.show.to_s", path: empty).first
  end

  def test_a_message_passes_its_level_title_and_text
    result, args = answer(<<~RUBY)
      Ferro::Rfd::MessageDialog.new.set_level(Ferro::Rfd::MessageLevel::Warning)
        .set_title("Careful").set_description("Disk almost full").show.to_s
    RUBY

    assert_equal "Ok", result
    assert_equal ["--no-markup", "--warning", "--title", "Careful", "--text", "Disk almost full"], args
  end

  # rfd's mapping of zenity's answers (zenity.rs:157-242).
  def test_each_set_of_buttons_maps_zenitys_answer_to_rfds_result
    cases = [
      ["OkCustom.new('Got it')", 0, "", "Ok", %w[--info --title t --text d --ok-label Got\ it]],
      ["OkCancel", 1, "", "Cancel", %w[--question --title t --text d --ok-label Ok --cancel-label Cancel]],
      ["YesNo", 0, "", "Yes", %w[--question --title t --text d]],
      ["YesNo", 1, "", "No", %w[--question --title t --text d]],
      ["YesNoCancel", 0, "", "Yes", %w[--question --title t --text d --extra-button No --cancel-label Cancel]],
      ["YesNoCancel", 1, "No\n", "No", nil],
      ["YesNoCancel", 1, "", "Cancel", nil],
      [
        "OkCancelCustom.new('Save', 'Discard')",
        1,
        "",
        "Custom(Discard)",
        %w[--question --title t --text d --ok-label Save --cancel-label Discard],
],
      [
        "YesNoCancelCustom.new('Y', 'N', 'C')",
        1,
        "N\n",
        "Custom(N)",
        %w[--question --title t --text d --ok-label Y --cancel-label C --extra-button N],
],
    ]
    cases.each do |buttons, status, output, expected, expected_args|
      script = "Ferro::Rfd::MessageDialog.new.set_title('t').set_description('d')" \
        ".set_buttons(Ferro::Rfd::MessageButtons::#{buttons}).show.to_s"
      result, args = answer(script, status:, output:)

      assert_equal expected, result, buttons
      assert_equal ["--no-markup", *expected_args], args, buttons if expected_args
    end
  end

  # rfd's async dialogs here start nothing until polled
  # (xdg_desktop_portal.rs:19-34): zenity runs only once value is called.
  def test_an_async_dialog_runs_when_its_value_is_asked_for
    (before, handle), = answer(<<~RUBY, output: "/home/me/a.txt\n")
      future = Ferro::Rfd::AsyncFileDialog.new.pick_file
      sleep 0.2
      before = File.exist?(ENV.fetch("FAKE_ZENITY_LOG"))
      [before, future.value.path]
    RUBY

    refute before
    assert_equal "/home/me/a.txt", handle
    assert_equal "Yes", answer("Ferro::Rfd::AsyncMessageDialog.new.set_buttons(Ferro::Rfd::MessageButtons::YesNo)" \
      ".show.value.to_s").first
  end

  # While zenity runs, other Ruby threads run: the dialog released the GVL.
  def test_a_dialog_lets_other_threads_run_while_it_is_open
    ticks, = answer(<<~RUBY, output: "/a\n", sleep: 1)
      ticks = 0
      Thread.new { loop { ticks += 1; sleep 0.01 } }
      sleep 0.05
      before = ticks
      Ferro::Rfd::FileDialog.new.pick_file
      ticks - before
    RUBY

    assert_operator ticks, :>=, 20
  end
end
