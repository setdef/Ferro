# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../tasks/release"

# Tests the release task's checks and commands in a throwaway repository.
# A recorder stands in for the commands, so nothing is built, tagged, or
# pushed.
class TestRelease < Minitest::Test
  def setup
    @root = Dir.mktmpdir("release")
    write("gems/demo/CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n## [0.1.0] - 2026-10-24\n\n- First.\n")
    git("init", "--quiet", "--initial-branch", "trunk")
    git("add", ".")
    git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "--message", "init")
    @ran = []
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  private def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), content)
  end

  private def git(*)
    system("git", *, chdir: @root, exception: true, out: File::NULL, err: File::NULL)
  end

  private def release(version: "0.1.0", succeed: true)
    runner = lambda do |command, chdir:|
      @ran << [command, chdir]
      succeed
    end
    Release.new(root: @root, name: "ferro-demo", dir: "gems/demo", version:, runner:)
  end

  def test_the_tag_names_the_gem
    assert_equal "ferro-demo/v0.1.0", release.tag
  end

  def test_a_ready_repository_runs_build_tag_push_and_publish_in_order
    release.run!

    assert_equal [
      ["gem", "build", "ferro-demo.gemspec", "--output", File.join(@root, "pkg/ferro-demo-0.1.0.gem")],
      ["git", "tag", "--annotate", "ferro-demo/v0.1.0", "--message", "ferro-demo 0.1.0"],
      %w[git push origin trunk],
      ["git", "push", "origin", "ferro-demo/v0.1.0"],
      ["gem", "push", File.join(@root, "pkg/ferro-demo-0.1.0.gem")],
    ], @ran.map(&:first)
    assert_equal File.join(@root, "gems/demo"), @ran.first.last
  end

  def test_a_failing_command_stops_the_release
    error = assert_raises(Release::Failure) { release(succeed: false).run! }

    assert_includes error.message, "gem build"
    assert_equal 1, @ran.size
  end

  def test_another_branch_is_refused
    git("switch", "--quiet", "--create", "topic")

    error = assert_raises(Release::Failure) { release.run! }

    assert_equal "release from trunk, not topic", error.message
    assert_empty @ran
  end

  def test_a_dirty_tree_is_refused
    write("gems/demo/stray.rb", "")

    error = assert_raises(Release::Failure) { release.run! }

    assert_equal "commit or stash your changes first", error.message
  end

  def test_an_existing_tag_is_refused
    git("tag", "ferro-demo/v0.1.0")

    error = assert_raises(Release::Failure) { release.run! }

    assert_equal "ferro-demo/v0.1.0 already exists", error.message
  end

  def test_a_version_without_a_changelog_section_is_refused
    error = assert_raises(Release::Failure) { release(version: "0.2.0").run! }

    assert_equal "gems/demo/CHANGELOG.md has no section for 0.2.0", error.message
  end
end
