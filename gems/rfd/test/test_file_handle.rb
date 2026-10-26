# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require "test_helper"

# FileHandle wraps a path and runs rfd's FileHandle code on it (plan 002,
# decision 10).
class TestFileHandle < Minitest::Test
  include RfdSuite

  def setup
    @dir = Dir.mktmpdir("ferro-rfd")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  private def path(name = "notes.txt")
    File.join(@dir, name)
  end

  def test_a_handle_is_its_path
    handle = Ferro::Rfd::FileHandle.new(path)

    assert_equal path, handle.path
    assert_equal path, handle.inner
    assert_equal path, handle.to_path
    assert_equal "notes.txt", handle.file_name
    assert_predicate handle, :frozen?
  end

  def test_a_handle_takes_any_object_with_to_path
    assert_equal path, Ferro::Rfd::FileHandle.new(Pathname.new(path)).path
  end

  # rfd's Debug is the path's (src/file_handle/native.rs:173-177).
  def test_inspect_is_rfds_debug
    assert_equal "\"/tmp/report.csv\"", Ferro::Rfd::FileHandle.new("/tmp/report.csv").inspect
  end

  # rfd's file_name is empty without a final component or for a name that
  # is not UTF-8 (src/file_handle/native.rs:124-131).
  def test_file_name_is_empty_where_rfd_has_none
    assert_equal "", Ferro::Rfd::FileHandle.new("/").file_name
    skip "Windows paths are UTF-8 here" if PLATFORM == :windows
    assert_equal "", Ferro::Rfd::FileHandle.new("/tmp/\xFF.txt".b).file_name
  end

  def test_ruby_file_methods_take_a_handle
    File.write(path, "hello")

    assert_equal "hello", File.read(Ferro::Rfd::FileHandle.new(path))
  end

  def test_write_then_read_round_trips_bytes
    handle = Ferro::Rfd::FileHandle.new(path)
    bytes = [0, 255, 10, 13].pack("C*")

    assert_nil handle.write(bytes).value
    read = handle.read.value

    assert_equal bytes, read
    assert_equal Encoding::BINARY, read.encoding
  end

  # rfd unwraps the read (src/file_handle/native.rs:51), so a missing file
  # panics inside rfd; the panic arrives as Ferro::Rfd::Error, the same one
  # each time.
  def test_reading_a_missing_file_raises_rfds_panic
    future = Ferro::Rfd::FileHandle.new(path("missing")).read

    error = assert_raises(Ferro::Rfd::Error) { future.value }
    assert_match(/\Arfd panicked: called `Result::unwrap\(\)` on an `Err` value: /, error.message)
    assert_same error, assert_raises(Ferro::Rfd::Error) { future.value }
  end

  def test_a_failed_write_raises_rubys_error_for_it
    future = Ferro::Rfd::FileHandle.new(path("missing/notes.txt")).write("x")

    if PLATFORM == :windows
      assert_raises(IOError) { future.value }
    else
      error = assert_raises(Errno::ENOENT) { future.value }
      assert_equal "No such file or directory - #{path('missing/notes.txt')}", error.message
    end
  end

  def test_write_takes_a_string
    assert_raises(TypeError) { Ferro::Rfd::FileHandle.new(path).write(42) }
  end
end
