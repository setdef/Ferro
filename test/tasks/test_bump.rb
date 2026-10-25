# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "date"
require "fileutils"
require "tmpdir"
require_relative "../../tasks/bump"
require_relative "../../tasks/ferro_gems"

# Tests bump:<gem>:* in a throwaway repository holding a gem laid out as
# Ferro's are, with real git. A stand-in replaces the gate.
class TestBump < Minitest::Test
  GEM = FerroGem.new(short_name: "demo", name: "ferro-demo", crate: "ext/ferro_demo", extension: "lib/ferro/demo/ferro_demo",
    packaged: [], native_namespace: "Ferro::Demo", platform_sigs: {}, platform_probe: "", smoke: "")

  def setup
    @root = Dir.mktmpdir("bump")
    write("gems/demo/lib/ferro/demo/version.rb", %(module Ferro\n  module Demo\n    VERSION = "0.1.0.pre.1"\n  end\nend\n))
    write("gems/demo/CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n### Added\n\n- A thing.\n\n" \
      "[Unreleased]: https://github.com/setdef/Ferro/commits/trunk/gems/demo\n")
    write("gems/demo/ext/ferro_demo/Cargo.toml", %([package]\nname = "ferro_demo"\nversion = "0.1.0-pre.1"\n\n) +
      %([dependencies]\nmagnus = { version = "0.9.3" }\n))
    write("gems/demo/Cargo.lock", %([[package]]\nname = "ferro_demo"\nversion = "0.1.0-pre.1"\n\n[[package]]\nname = "magnus"\nversion = "0.9.3"\n))
    write("Gemfile.lock", "PATH\n  remote: gems/demo\n  specs:\n    ferro-demo (0.1.0.pre.1)\n\nCHECKSUMS\n  ferro-demo (0.1.0.pre.1)\n")
    git("init", "--quiet", "--initial-branch", "trunk")
    git("add", ".")
    commit("init")
    @gate_runs = 0
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  private def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), content)
  end

  private def read(path)
    File.read(File.join(@root, path))
  end

  private def git(*)
    system("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", *, chdir: @root, exception: true,
      out: File::NULL, err: File::NULL)
  end

  private def commit(message)
    git("commit", "--quiet", "--message", message)
  end

  private def log
    IO.popen(["git", "log", "--format=%s", chdir: @root], &:read).lines.map(&:chomp)
  end

  private def bump(gate: true, &)
    ENV["GIT_AUTHOR_NAME"] = ENV["GIT_COMMITTER_NAME"] = "Test"
    ENV["GIT_AUTHOR_EMAIL"] = ENV["GIT_COMMITTER_EMAIL"] = "test@example.com"
    Bump.new(root: @root, gem: GEM, gate: -> { @gate_runs += 1; gate }, date: Date.new(2026, 10, 25)).run!(&)
  ensure
    %w[GIT_AUTHOR_NAME GIT_COMMITTER_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL].each { |name| ENV.delete(name) }
  end

  def test_a_prerelease_bump_rewrites_every_version_runs_the_gate_and_commits
    version = bump { |current| current.next(:patch, "pre") }

    assert_equal "0.1.0.pre.2", version.to_s
    assert_includes read("gems/demo/lib/ferro/demo/version.rb"), %(VERSION = "0.1.0.pre.2")
    assert_includes read("gems/demo/ext/ferro_demo/Cargo.toml"), %(version = "0.1.0-pre.2")
    assert_includes read("gems/demo/ext/ferro_demo/Cargo.toml"), %(magnus = { version = "0.9.3" })
    assert_includes read("gems/demo/Cargo.lock"), %(name = "ferro_demo"\nversion = "0.1.0-pre.2")
    assert_includes read("gems/demo/Cargo.lock"), %(name = "magnus"\nversion = "0.9.3")
    assert_equal 2, read("Gemfile.lock").scan("ferro-demo (0.1.0.pre.2)").size
    assert_includes read("gems/demo/CHANGELOG.md"), "## [Unreleased]\n\n## [0.1.0.pre.2] - 2026-10-25\n\n### Added\n\n- A thing.\n"
    assert_equal 1, @gate_runs
    assert_equal ["chore(demo): release 0.1.0.pre.2", "init"], log
    assert_empty IO.popen(["git", "status", "--porcelain", chdir: @root], &:read)
  end

  def test_a_failing_gate_leaves_the_bump_uncommitted
    error = assert_raises(Bump::Failure) { bump(gate: false) { |current| current.next(:patch) } }

    assert_includes error.message, "the gate failed"
    assert_equal ["init"], log
    assert_includes read("gems/demo/lib/ferro/demo/version.rb"), %(VERSION = "0.1.0")
  end

  def test_a_version_file_out_of_step_restores_everything
    write("gems/demo/ext/ferro_demo/Cargo.toml", %([package]\nname = "ferro_demo"\nversion = "0.0.9"\n))
    commit_all("drift")

    error = assert_raises(Bump::Failure) { bump { |current| current.next(:patch) } }

    assert_includes error.message, "has no version 0.1.0-pre.1"
    assert_equal 0, @gate_runs
    assert_empty IO.popen(["git", "status", "--porcelain", chdir: @root], &:read)
  end

  private def commit_all(message)
    git("add", ".")
    commit(message)
  end

  def test_an_older_or_equal_version_is_refused
    error = assert_raises(Bump::Failure) { bump { GemVersion.parse("0.1.0.pre.1") } }

    assert_equal "0.1.0.pre.1 does not come after 0.1.0.pre.1", error.message
  end

  def test_a_stable_one_point_oh_waits_for_a_branch_policy
    error = assert_raises(Bump::Failure) { bump { |current| current.next(:major) } }

    assert_includes error.message, "release-branch policy"
  end

  def test_a_bad_label_is_reported
    error = assert_raises(Bump::Failure) { bump { |current| current.next(:patch, "pre-2") } }

    assert_includes error.message, "not a prerelease label"
  end

  def test_another_branch_or_a_dirty_tree_is_refused
    write("stray.txt", "")
    assert_equal "commit or stash your changes first", assert_raises(Bump::Failure) { bump { |c| c.next(:patch) } }.message

    FileUtils.rm(File.join(@root, "stray.txt"))
    git("switch", "--quiet", "--create", "topic")
    assert_equal "bump on trunk, not topic", assert_raises(Bump::Failure) { bump { |c| c.next(:patch) } }.message
  end
end
