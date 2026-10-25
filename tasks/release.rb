# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "fileutils"
require "open3"

# Tags and publishes one gem.
#
# Bundler's release task tags each release <tt>v0.1.0</tt>. In a
# repository of many gems, each with its own version, those tags collide.
# This release names the tag for the gem, <tt>ferro-arboard/v0.1.0</tt>
# (ADR 001, section 5), and otherwise does what Bundler's does: build the
# gem, tag the commit, push the branch and the tag, and push the gem.
#
# Releasing is a human step. Agents never run it.
class Release
  # The branch releases come from.
  BRANCH = "trunk"

  # Raised when a release must not proceed; the message says why.
  class Failure < StandardError; end

  # [root] The repository root.
  # [name] The gem's name, such as <tt>ferro-arboard</tt>.
  # [dir] The gem's directory, relative to +root+.
  # [version] The version to release, from the gemspec.
  # [runner] Runs one command (an Array) in a directory; returns whether
  #   it succeeded. Tests pass a recorder.
  def initialize(root:, name:, dir:, version:, runner: -> (command, chdir:) { system(*command, chdir:) })
    @root = root
    @name = name
    @dir = dir
    @version = version
    @runner = runner
  end

  # The release's git tag.
  def tag
    "#{@name}/v#{@version}"
  end

  # The package the release builds and pushes.
  def package
    File.join(@root, "pkg", "#{@name}-#{@version}.gem")
  end

  # Raises Failure unless the repository is ready: on trunk, with a clean
  # tree, no tag for this version yet, and a CHANGELOG section for it.
  def preflight!
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip
    raise Failure, "release from #{BRANCH}, not #{branch}" unless branch == BRANCH
    raise Failure, "commit or stash your changes first" unless git("status", "--porcelain").empty?
    raise Failure, "#{tag} already exists" if tagged?

    changelog = File.join(@root, @dir, "CHANGELOG.md")
    section = /^## \[#{Regexp.escape(@version)}\]/
    raise Failure, "#{@dir}/CHANGELOG.md has no section for #{@version}" unless File.read(changelog).match?(section)
  end

  # The commands a release runs, each with the directory it runs in.
  def commands
    [
      [["gem", "build", "#{@name}.gemspec", "--output", package], File.join(@root, @dir)],
      [["git", "tag", "--annotate", tag, "--message", "#{@name} #{@version}"], @root],
      [["git", "push", "origin", BRANCH], @root],
      [["git", "push", "origin", tag], @root],
      [["gem", "push", package], @root],
    ]
  end

  # Checks, then runs each command, stopping at the first that fails.
  def run!
    preflight!
    FileUtils.mkdir_p(File.dirname(package))
    commands.each do |command, chdir|
      raise Failure, "#{command.join(' ')} failed" unless @runner.call(command, chdir:)
    end
  end

  private def tagged?
    _, status = Open3.capture2e("git", "rev-parse", "--quiet", "--verify", "refs/tags/#{tag}", chdir: @root)
    status.success?
  end

  private def git(*arguments)
    output, status = Open3.capture2e("git", *arguments, chdir: @root)
    raise Failure, "git #{arguments.join(' ')} failed: #{output}" unless status.success?

    output
  end
end
