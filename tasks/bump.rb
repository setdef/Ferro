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

  # The footer AGENTS.md asks every commit to end with.
  FOOTER = <<~FOOTER.chomp
    Generated with Claude Code (https://claude.com/claude-code)

    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  FOOTER

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
    commit!(from, target)
  rescue Changelog::Failure, ArgumentError => e
    raise Failure, e.message
  end

  # Releases the version the gem has now, without moving it.
  #
  # A new gem starts at <tt>0.1.0.pre.1</tt> with its changes under
  # Unreleased. #run! only moves forward, so without this the first release
  # would skip to <tt>0.1.0.pre.2</tt>, as ferro-arboard's and ferro-rfd's
  # did. Releasing the current version is safe only while nobody has it,
  # so this refuses when the gem's tag exists here or on origin (asking
  # origin, so a missing remote is a failure, not a pass), when the
  # CHANGELOG already has the version's section, or when a later version is
  # already tagged here or in the CHANGELOG.
  def release_current!
    preflight!
    version = current
    check_unreleased!(version)
    check_target!(nil, version)
    commit!(version, version)
  rescue Changelog::Failure, ArgumentError => e
    raise Failure, e.message
  end

  # The release commit's message: a scoped Conventional Commit subject, a
  # short prose body, and the footer AGENTS.md asks for.
  def commit_message(target)
    <<~MESSAGE
      chore(#{@gem.short_name}): release #{target}

      #{wrap("Release #{@gem.name} #{target}. The entries that were under Unreleased in its CHANGELOG are now the " \
        "#{target} section, dated #{@date.iso8601}, and version.rb, the crate's Cargo.toml, its Cargo.lock, and the " \
        "root Gemfile.lock name #{target}. Tag it with rake release:#{@gem.short_name}:tag.")}

      #{FOOTER}
    MESSAGE
  end

  # Writes +target+ over +from+, runs the gate, and commits the release.
  private def commit!(from, target)
    edit(from, target)
    raise Failure, "the gate failed; #{target}'s changes are left uncommitted for you to inspect" unless @gate.call

    git("add", "--", *files)
    git("commit", "--quiet", "--message", commit_message(target))
    target
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

  # +text+ wrapped at 72 columns, as commit bodies are.
  private def wrap(text)
    text.gsub(/(.{1,72})(?:\s+|\z)/, "\\1\n").chomp
  end

  private def preflight!
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip
    raise Failure, "bump on trunk, not #{branch}" unless branch == "trunk"
    raise Failure, "commit or stash your changes first" unless git("status", "--porcelain").empty?
  end

  # Refuses a +version+ anyone could already have.
  private def check_unreleased!(version)
    tag = "#{@gem.tag_prefix}#{version}"
    _, status = Open3.capture2e("git", "rev-parse", "--quiet", "--verify", "refs/tags/#{tag}", chdir: @root)
    raise Failure, "#{tag} already exists, so #{version} is released; bump past it" if status.success?
    unless git("ls-remote", "--tags", "origin", "refs/tags/#{tag}").empty?
      raise Failure, "origin already has #{tag}, so #{version} is released; bump past it"
    end
    if Changelog.new(path(@gem.changelog), tag_prefix: @gem.tag_prefix).released?(version)
      raise Failure, "#{File.join(@gem.dir, @gem.changelog)} already has a #{version} section; bump past it"
    end

    newest = released_versions.max
    raise Failure, "#{version} is below #{newest}, which is released; bump past it" if newest && newest > version
  end

  # The versions the gem's local tags and CHANGELOG sections name.
  private def released_versions
    tags = git("tag", "--list", "#{@gem.tag_prefix}*").lines.map { |line| line.strip.delete_prefix(@gem.tag_prefix) }
    sections = File.read(path(@gem.changelog)).scan(/^## \[([^\]]+)\]/).flatten - ["Unreleased"]
    (tags + sections).filter_map do |text|
      GemVersion.parse(text)
    rescue ArgumentError
      nil
    end
  end

  # Refuses a +target+ that does not follow +from+ (+nil+ when the version
  # stays), or a stable one.
  private def check_target!(from, target)
    raise Failure, "#{target} does not come after #{from}" if from && !(target > from)
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
