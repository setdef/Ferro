# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "fileutils"
require "open3"
require_relative "changelog"

# Tags and publishes one gem.
#
# Bundler's release task tags each release <tt>v0.1.0</tt>. In a
# repository of many gems, each with its own version, those tags collide.
# This release names the tag for the gem, <tt>ferro-arboard/v0.1.0</tt>
# (ADR 001, section 5), and otherwise does what Bundler's does: build the
# gem, tag the commit, push the branch and the tag, and push the gem.
#
# A release can also stop at the tag (#tag!). Ferro publishes nothing to
# RubyGems.org yet, but a pushed tag is enough for Bundler's git sources,
# which is how Tokra uses a Ferro gem. The tag goes on the commit the bump
# made (Bump), so it names exactly the release the CHANGELOG describes.
#
# Publishing with #run! is the maintainer's step alone; agents may run
# #tag! once the gate and CI pass for that commit (AGENTS.md).
class Release
  # The branch releases come from.
  BRANCH = "trunk"

  # Raised when a release must not proceed; the message says why.
  class Failure < StandardError; end

  # [root] The repository root.
  # [name] The gem's name, such as <tt>ferro-arboard</tt>.
  # [dir] The gem's directory, relative to +root+.
  # [version] The version to release, from the gemspec.
  # [scope] The gem's commit scope, such as <tt>arboard</tt>.
  # [runner] Runs one command (an Array) in a directory; returns whether
  #   it succeeded. Tests pass a recorder.
  def initialize(root:, name:, dir:, version:, scope:, runner: -> (command, chdir:) { system(*command, chdir:) })
    @root = root
    @name = name
    @dir = dir
    @version = version
    @scope = scope
    @runner = runner
  end

  # The subject of the commit that released this version.
  def release_subject
    "chore(#{@scope}): release #{@version}"
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

    changelog = Changelog.new(File.join(@root, @dir, "CHANGELOG.md"), tag_prefix: "#{@name}/v")
    raise Failure, "#{@dir}/CHANGELOG.md has no section for #{@version}" unless changelog.released?(@version)
  end

  # Tags the commit that released this version and pushes only the tag.
  # Raises Failure, before running anything, unless #preflight! passes,
  # trunk matches origin's, origin has no such tag either, and trunk holds
  # the commit #release_subject names.
  def tag!
    preflight!
    git("fetch", "--quiet", "origin", "refs/heads/#{BRANCH}")
    unless git("rev-parse", "HEAD") == git("rev-parse", "FETCH_HEAD")
      raise Failure, "#{BRANCH} differs from origin's; pull or push it first"
    end
    raise Failure, "origin already has #{tag}" unless git("ls-remote", "--tags", "origin", "refs/tags/#{tag}").empty?

    commit = release_commit or raise Failure, "#{BRANCH} has no commit \"#{release_subject}\"; run rake bump:#{@scope}:... first"
    [
      ["git", "tag", "--annotate", tag, commit, "--message", "#{@name} #{@version}"],
      ["git", "push", "origin", "refs/tags/#{tag}"],
    ].each { |command| raise Failure, "#{command.join(' ')} failed" unless @runner.call(command, chdir: @root) }
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

  # The newest commit on trunk's first-parent history with the release
  # subject, or nil.
  private def release_commit
    git("log", "--first-parent", "--format=%H %s", BRANCH).lines.map { |line| line.chomp.split(" ", 2) }
      .find { |_, subject| subject == release_subject }&.first
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
