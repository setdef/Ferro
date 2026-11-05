# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "fileutils"
require "json"
require "net/http"
require "open3"
require "rubygems/package"
require_relative "changelog"
require_relative "gem_version"

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
# #tag! once the gate and CI pass for that commit (AGENTS.md). #run! refuses
# a version that is already tagged, so a version tagged first goes to
# RubyGems.org with #push!, also the maintainer's step alone.
#
# The version is the SemVer string version.rb holds, <tt>1.0.0-beta.1</tt>,
# and the tag and the CHANGELOG heading spell it that way. The built
# package's file name spells it as RubyGems stores it,
# <tt>ferro-url-1.0.0.pre.beta.1.gem</tt> (GemVersion).
class Release
  # The branch releases come from.
  BRANCH = "trunk"

  # Raised when a release must not proceed; the message says why.
  class Failure < StandardError; end

  # Where the versions RubyGems.org has of a gem are listed, given its name.
  VERSIONS_URL = "https://rubygems.org/api/v1/versions/%<name>s.json"

  # Asks RubyGems.org which versions of the gem +name+ it has, as the
  # strings it stores, such as <tt>1.0.0.pre.beta.1</tt>. A gem it has never
  # seen has none.
  #
  # Tests pass +http+, anything with Net::HTTP's +get_response+.
  PUBLISHED_VERSIONS = lambda do |name, http = Net::HTTP|
    response = http.get_response(URI(format(VERSIONS_URL, name:)))
    case response
    when Net::HTTPNotFound then []
    when Net::HTTPSuccess then JSON.parse(response.body).map { |entry| entry.fetch("number") }
    else raise Failure, "RubyGems.org answered #{response.code} when asked for #{name}'s versions"
    end
  end

  # [root] The repository root.
  # [name] The gem's name, such as <tt>ferro-arboard</tt>.
  # [dir] The gem's directory, relative to +root+.
  # [version] The version to release, as version.rb writes it.
  # [scope] The gem's commit scope, such as <tt>arboard</tt>.
  # [runner] Runs one command (an Array) in a directory; returns whether
  #   it succeeded. Tests pass a recorder.
  # [published_versions] Given the gem's name, returns the versions
  #   RubyGems.org has. Tests pass a stand-in; nothing else touches the
  #   network.
  def initialize(root:, name:, dir:, version:, scope:, runner: -> (command, chdir:) { system(*command, chdir:) },
    published_versions: PUBLISHED_VERSIONS
  )
    @root = root
    @name = name
    @dir = dir
    @version = version
    @scope = scope
    @runner = runner
    @published_versions = published_versions
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
    File.join(@root, "pkg", "#{@name}-#{GemVersion.parse(@version).rubygems}.gem")
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

  # Pushes a version that is already tagged to RubyGems.org, built from a
  # clean checkout of origin's tag, never from the working tree.
  #
  # Raises Failure, before building anything, unless origin has the tag and
  # RubyGems.org does not have the version. Then it checks the tag out into
  # <tt>tmp/push/</tt> as a git worktree (the gemspec lists its files with
  # <tt>git ls-files</tt>), builds the gem there, pushes it, and removes the
  # checkout. It needs no particular branch and no clean tree.
  def push!
    raise Failure, "origin does not have #{tag}; tag it with rake release:#{@scope}:tag first" if remote_tag.empty?

    number = GemVersion.parse(@version).rubygems
    if @published_versions.call(@name).any? { |published| Gem::Version.new(published) == Gem::Version.new(number) }
      raise Failure, "RubyGems.org already has #{@name} #{number}"
    end

    git("fetch", "--quiet", "origin", "refs/tags/#{tag}")
    in_checkout_of("FETCH_HEAD") { |checkout| build_and_push(checkout) }
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

  private def remote_tag
    git("ls-remote", "--tags", "origin", "refs/tags/#{tag}")
  end

  # Yields a clean checkout of +revision+ under <tt>tmp/push/</tt>, and
  # removes it afterwards.
  private def in_checkout_of(revision)
    checkout = File.join(@root, "tmp", "push", "#{@name}-#{@version}")
    FileUtils.mkdir_p(File.dirname(checkout))
    clear_leftover(checkout)
    git("worktree", "add", "--quiet", "--detach", checkout, revision)
    begin
      yield checkout
    ensure
      begin
        git("worktree", "remove", "--force", checkout)
      rescue Failure => e
        warn "could not remove #{checkout}: #{e.message}"
      end
    end
  end

  # Removes what a killed run left at +checkout+, so the next run can add
  # its worktree there.
  private def clear_leftover(checkout)
    return unless File.exist?(checkout)

    Open3.capture2e("git", "worktree", "remove", "--force", checkout, chdir: @root)
    FileUtils.rm_rf(checkout)
    git("worktree", "prune")
  end

  # Builds the package and pushes it, once the package holds this version.
  # The package is deleted first, because +gem build --output+ leaves an
  # old one in place if it fails to write a new one, and the build is
  # checked by reading the package back, since a tag whose version.rb says
  # something else builds a different version than the tag names.
  private def build_and_push(checkout)
    FileUtils.mkdir_p(File.dirname(package))
    FileUtils.rm_f(package)
    build = ["gem", "build", "#{@name}.gemspec", "--output", package]
    raise Failure, "#{build.join(' ')} failed" unless @runner.call(build, chdir: File.join(checkout, @dir))

    check_package!

    push = ["gem", "push", package]
    raise Failure, "#{push.join(' ')} failed" unless @runner.call(push, chdir: @root)
  end

  private def check_package!
    raise Failure, "gem build made no #{package}" unless File.exist?(package)

    built = Gem::Package.new(package).spec.version
    wanted = Gem::Version.new(GemVersion.parse(@version).rubygems)
    return if built == wanted

    raise Failure, "#{package} holds version #{built}, not #{wanted}; does the tag's version.rb say #{@version}?"
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
