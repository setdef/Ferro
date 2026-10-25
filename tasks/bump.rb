# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "date"
require "open3"
require_relative "changelog"
require_relative "gem_version"

# Bumps one gem's version and commits the release.
#
# A gem's version lives in four files besides its CHANGELOG: version.rb,
# which the gemspec reads; the crate's Cargo.toml and the gem's Cargo.lock,
# which spell it Cargo's way; and the root Gemfile.lock, which records the
# path gem. Editing them by hand, one is always missed. This bump rewrites
# them all, releases the CHANGELOG's Unreleased entries, runs the gate, and
# commits <tt>chore(arboard): release 0.1.0.pre.2</tt>, a scoped
# Conventional Commit, so <tt>git log -- gems/arboard</tt> shows it.
# Tagging that commit is a separate step (Release#tag!).
#
# Following ratatui_ruby-devtools 0.4.1's bump workflow
# (<tt>lib/ratatui_ruby/devtools/tasks/bump/bump_workflow.rb</tt>), it bumps
# only on a clean trunk. That workflow also cuts a release branch for each
# minor version from 1.0 on; Ferro has no gem near 1.0 and no branch
# policy for a repository of many gems yet, so a bump to a stable 1.0 or
# later is refused until it does (plan 001).
class Bump
  # Raised when the bump must not proceed; the message says why.
  class Failure < StandardError; end

  # Where version.rb writes the version.
  VERSION = /(?<=VERSION = ")[^"]+(?=")/

  # [root] The repository root.
  # [gem] The FerroGem to bump.
  # [gate] Runs the gate; returns whether it passed.
  # [date] The release date for the CHANGELOG.
  def initialize(root:, gem:, gate: -> { system("bundle", "exec", "rake", chdir: root) }, date: Date.today)
    @root = root
    @gem = gem
    @gate = gate
    @date = date
  end

  # The version the gem has now.
  def current
    GemVersion.parse(File.read(path(@gem.version_file))[VERSION] || raise(Failure, "#{@gem.version_file} has no VERSION"))
  end

  # Bumps to the version the block returns, given the current one.
  def run!
    preflight!
    from = current
    target = yield(from)
    check_target!(from, target)

    edit(from, target)
    raise Failure, "the gate failed; #{target}'s changes are left uncommitted for you to inspect" unless @gate.call

    git("add", "--", *files)
    git("commit", "--quiet", "--message", "chore(#{@gem.short_name}): release #{target}")
    target
  rescue Changelog::Failure, ArgumentError => e
    raise Failure, e.message
  end

  # Rewrites every file, or none: the tree was clean, so a failure part way
  # restores what was written.
  private def edit(from, target)
    Changelog.new(path(@gem.changelog), tag_prefix: @gem.tag_prefix).release(target, date: @date)
    write_versions(from, target)
  rescue Failure, Changelog::Failure
    git("checkout", "--", *files)
    raise
  end

  private def preflight!
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip
    raise Failure, "bump on trunk, not #{branch}" unless branch == "trunk"
    raise Failure, "commit or stash your changes first" unless git("status", "--porcelain").empty?
  end

  private def check_target!(from, target)
    raise Failure, "#{target} does not come after #{from}" unless target > from
    return unless target.stable?

    raise Failure, "#{target} is 1.0 or later, which needs a release-branch policy Ferro does not have yet (plan 001)"
  end

  private def write_versions(from, target)
    rewrite(@gem.version_file, VERSION, target.to_s, "VERSION")
    manifest = File.join(@gem.crate, "Cargo.toml")
    rewrite(manifest, /^version = "#{Regexp.escape(from.cargo)}"$/, %(version = "#{target.cargo}"), "version #{from.cargo}")
    rewrite("Cargo.lock", /^(name = "#{Regexp.escape(@gem.extension_name)}"\nversion = )"#{Regexp.escape(from.cargo)}"$/,
      %(\\1"#{target.cargo}"), "#{@gem.extension_name} #{from.cargo}")
    gemfile_lock = File.join(@root, "Gemfile.lock")
    text = File.read(gemfile_lock)
    pattern = /^(\s+#{Regexp.escape(@gem.name)}) \(#{Regexp.escape(from.to_s)}\)$/
    raise Failure, "Gemfile.lock does not list #{@gem.name} #{from}" unless text.match?(pattern)

    File.write(gemfile_lock, text.gsub(pattern, "\\1 (#{target})"))
  end

  # Replaces +pattern+ in the gem's file at +relative+, failing when the
  # file does not hold +what+.
  private def rewrite(relative, pattern, replacement, what)
    file = path(relative)
    text = File.read(file)
    raise Failure, "#{File.join(@gem.dir, relative)} has no #{what}; keep it equal to the gem's version" unless text.match?(pattern)

    File.write(file, text.sub(pattern, replacement))
  end

  private def files
    [@gem.version_file, @gem.changelog, File.join(@gem.crate, "Cargo.toml"), "Cargo.lock"]
      .map { |relative| File.join(@gem.dir, relative) } + ["Gemfile.lock"]
  end

  private def path(relative)
    File.join(@root, @gem.dir, relative)
  end

  private def git(*arguments)
    output, status = Open3.capture2e("git", *arguments, chdir: @root)
    raise Failure, "git #{arguments.join(' ')} failed: #{output}" unless status.success?

    output
  end
end
