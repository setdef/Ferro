# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "fileutils"
require "open3"
require "rbconfig"
require "rubygems/package"
require "stringio"
require "tmpdir"
require_relative "package_check"

# Builds a gem's precompiled gem, for the platform and Ruby it runs on, from
# its source gem (plan 015).
#
# A source gem compiles its extension when it installs, which needs Rust and
# libclang. A precompiled gem carries the compiled extension instead, as
# rake-compiler's native gems do: its platform is the build's, it has no
# extension to compile, and the extension sits where the gem's
# <tt>require</tt> finds it. Installing it copies files and runs nothing.
#
# It starts from the source gem, not the repository: it unpacks the
# package, compiles the extension there as RubyGems would, running
# extconf.rb with no options and then make, and packs the same files with
# the extension added. So it carries exactly the source gem's files, the
# crate and its lockfile among them, and never the test hooks that the
# repository's own compiles turn on (FerroGem#test_hooks). It drops the
# source gem's rb_sys dependency, which only extconf.rb loads.
#
# Each platform builds its own gem, natively, on the Ruby it is for.
class PlatformGem
  # Raised when the gem cannot be built; the message says why.
  class Failure < StandardError; end

  # What the compile leaves out of the environment, so the extension builds
  # in a directory of its own, in Cargo's release profile, as it does when
  # RubyGems installs the source gem, rather than into the repository's
  # shared target directory (Rakefile).
  COMPILE_ENV = %w[RB_SYS_CARGO_TARGET_DIR CARGO_TARGET_DIR RB_SYS_CARGO_PROFILE].to_h { |name| [name, nil] }.freeze

  # Builds the source gem of the gem in +dir+ (relative to +root+) into
  # +work+ and returns its path. With a +ref+, it builds that commit's
  # sources, from a clean checkout of it under <tt>tmp/native/</tt> (the
  # gemspec lists its files with git), so a released version's precompiled
  # gems hold exactly its tag's files; without one, the working tree's.
  def self.source_gem(root:, dir:, gemspec:, work:, ref: nil)
    output = File.join(File.expand_path(work), "#{File.basename(gemspec, '.gemspec')}.gem")
    build = lambda do |checkout|
      _, errors, status = Open3.capture3(PackageCheck::UNBUNDLED, Gem.ruby, "-S", "gem", "build", gemspec, "--output",
        output, chdir: File.join(checkout, dir))
      raise Failure, "gem build #{gemspec} failed in #{File.join(checkout, dir)}:\n#{errors}" unless status.success?
    end
    ref ? in_checkout_of(root, ref, &build) : build.call(root)
    output
  end

  # Yields a clean checkout of +ref+ under <tt>tmp/native/</tt>, and removes
  # it afterwards.
  def self.in_checkout_of(root, ref)
    checkout = File.join(root, "tmp", "native", ref.tr("/", "-"))
    git = lambda do |*arguments|
      output, status = Open3.capture2e("git", *arguments, chdir: root)
      raise Failure, "git #{arguments.join(' ')} failed:\n#{output}" unless status.success?
    end
    if File.exist?(checkout)
      Open3.capture2e("git", "worktree", "remove", "--force", checkout, chdir: root)
      FileUtils.rm_rf(checkout)
      git.call("worktree", "prune")
    end
    FileUtils.mkdir_p(File.dirname(checkout))
    git.call("worktree", "add", "--quiet", "--detach", checkout, "#{ref}^{commit}")
    begin
      yield checkout
    ensure
      git.call("worktree", "remove", "--force", checkout)
    end
  end

  # [source] The source gem's package.
  # [extension] The compiled extension's path inside the gem, without its
  #   file extension (FerroGem#extension).
  # [platform] The Gem::Platform the extension is built for.
  # [host_os] RbConfig's +host_os+, which says which C library a Linux Ruby
  #   runs on.
  # [ruby_version] The Ruby the extension is built for, as RubyGems sees it
  #   (Gem.ruby_version).
  # [dlext] The extension's file extension.
  # [out] Where the compile's output goes.
  def initialize(source:, extension:, platform: Gem::Platform.local, host_os: RbConfig::CONFIG["host_os"],
    ruby_version: Gem.ruby_version, dlext: RbConfig::CONFIG["DLEXT"], out: $stdout
  )
    @source = source
    @extension = extension
    @platform = platform
    @host_os = host_os
    @ruby_version = ruby_version
    @dlext = dlext
    @out = out
  end

  # The gem's platform. A Mac's has no darwin version: RubyGems installs an
  # <tt>arm64-darwin-24</tt> gem only on a Ruby that reports exactly darwin
  # 24, which names the build machine's macOS, not one the extension needs.
  # A Linux one names its C library: RubyGems matches a plain
  # <tt>x86_64-linux</tt> gem on musl too, where an extension built against
  # glibc does not load.
  def platform
    case @platform.os
    when "darwin" then Gem::Platform.new([@platform.cpu, "darwin", nil])
    when "linux" then Gem::Platform.new([@platform.cpu, "linux", @host_os.to_s.include?("musl") ? "musl" : "gnu"])
    else @platform
    end
  end

  # The gem's Ruby requirement: the source gem's, narrowed to the Rubies
  # the extension can be offered to.
  #
  # A release's teeny versions keep its ABI, so a gem built on 4.1.2 serves
  # every 4.1, below the next minor's previews, as rake-compiler bounds its
  # native gems. A preview or a build of Ruby's master has an ABI version of
  # its own (include/ruby/internal/abi.h), and off Windows Ruby refuses an
  # extension built for another (dln.c, dln_load_and_init). Such a gem
  # still admits every prerelease of its release, 4.1.0.dev and
  # 4.1.0.preview1 alike, and not the release: Bundler writes a platform's
  # gem into a lockfile only when the Ruby that locks satisfies the gem's
  # requirement, so gems that each required their own prerelease could
  # never share one lockfile, and an app locked on a Mac would compile on
  # Windows. The price is a gem offered to a prerelease it was not built
  # for, which Ruby refuses to load off Windows and does not check there.
  def required_ruby_version(source = source_spec.required_ruby_version)
    narrowed = if @ruby_version.prerelease?
      [">= #{@ruby_version.release}.a", "< #{@ruby_version.release}"]
    else
      major, minor = @ruby_version.segments
      [">= #{major}.#{minor}", "< #{major}.#{minor + 1}.dev"]
    end
    Gem::Requirement.new(*source.requirements.map { |op, version| "#{op} #{version}" }, *narrowed)
  end

  # The gem's specification: the source gem's, for this platform and Ruby,
  # with the compiled extension and nothing to compile.
  def spec
    source_spec.dup.tap do |spec|
      spec.platform = platform
      spec.required_ruby_version = required_ruby_version(spec.required_ruby_version)
      spec.extensions = []
      spec.files = (spec.files + [compiled]).uniq
      spec.dependencies.reject! { |dependency| dependency.name == "rb_sys" }
    end
  end

  # Compiles the extension from the source gem and builds the precompiled
  # gem into +dir+, returning its path. A warning RubyGems prints, such as
  # for a file the gem lacks, fails the build.
  def build(dir)
    Dir.mktmpdir("ferro-native") do |work|
      unpacked = File.join(work, "gem")
      Gem::Package.new(@source).extract_files(unpacked)
      compile(unpacked, File.join(work, "build"))
      package(unpacked, dir)
    end
  end

  # The compiled extension's path inside the gem.
  private def compiled
    "#{@extension}.#{@dlext}"
  end

  # Runs the source gem's extconf.rb with no options, then make, in +build+,
  # and puts the extension where the gem loads it.
  private def compile(unpacked, build)
    extconf = source_spec.extensions.first or raise Failure, "#{source_spec.full_name} has no extension to compile"
    FileUtils.mkdir_p(build)
    run!(Gem.ruby, File.join(unpacked, extconf), chdir: build)
    run!(ENV.fetch("MAKE", "make"), chdir: build)
    built = File.join(build, File.basename(compiled))
    raise Failure, "make built no #{File.basename(compiled)} in #{build}" unless File.file?(built)

    FileUtils.mkdir_p(File.dirname(File.join(unpacked, compiled)))
    FileUtils.cp(built, File.join(unpacked, compiled))
  end

  private def package(unpacked, dir)
    spec = self.spec
    FileUtils.mkdir_p(dir)
    output = File.join(File.expand_path(dir), spec.file_name)
    messages = StringIO.new
    Gem::DefaultUserInteraction.use_ui(Gem::StreamUI.new(StringIO.new, messages, messages, false)) do
      Dir.chdir(unpacked) { Gem::Package.build(spec, false, false, output) }
    end
    warnings = messages.string.lines.grep(/WARNING/)
    raise Failure, "#{spec.file_name} built with warnings:\n#{warnings.join}" if warnings.any?

    output
  rescue Gem::InvalidSpecificationException, Gem::Package::Error => e
    raise Failure, "#{spec&.file_name} did not build: #{e.message}\n#{messages&.string}"
  end

  private def run!(*command, chdir:)
    Open3.popen2e(COMPILE_ENV, *command, chdir:) do |_stdin, output, thread|
      output.each_line { |line| @out.print line }
      raise Failure, "#{command.join(' ')} failed in #{chdir}" unless thread.value.success?
    end
  end

  private def source_spec
    Gem::Package.new(@source).spec
  end
end
