# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "tmpdir"
require_relative "../../tasks/package_check"
require_relative "../../tasks/platform_gem"

# Tests the precompiled gem (plan 015) against a throwaway gem in its own
# git repository, built with the real gem command and compiled with its own
# extconf.rb and the real make, whose Makefile copies a file where Cargo
# would build the extension.
class TestPlatformGem < Minitest::Test
  def setup
    @root = Dir.mktmpdir("platform_gem")
    write("fixture/fixture.gemspec", <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = "fixture"
        spec.version = "0.0.1"
        spec.summary = "Fixture"
        spec.authors = ["Fixture"]
        spec.license = "MIT"
        spec.homepage = "https://example.com"
        spec.required_ruby_version = ">= 3.0"
        spec.files = IO.popen(%w[git ls-files -z -- lib ext], chdir: __dir__, &:read).split("\\x0")
        spec.extensions = ["ext/fixture/extconf.rb"]
        spec.add_dependency "rb_sys", "~> 0.9"
      end
    RUBY
    write("fixture/lib/fixture.rb", "module Fixture; PART = 42; end\n")
    # What the extension holds says how extconf.rb was run: its options, and
    # whether it saw the repository's shared target directory.
    write("fixture/ext/fixture/extconf.rb", <<~RUBY)
      require "rbconfig"
      File.write("payload", "compiled \#{ARGV.inspect} target=\#{ENV.fetch('RB_SYS_CARGO_TARGET_DIR', 'unset')}")
      File.write("Makefile", "all:\\n\\tcp payload fixture.\#{RbConfig::CONFIG['DLEXT']}\\n")
    RUBY
    write(".gitignore", "*.so\n*.bundle\n*.dll\n*.gem\n/tmp/\n")
    git("init", "--quiet")
    git("add", ".")
    git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.com", "commit", "--quiet", "-m", "fixture")
    @out = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  private def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), content)
  end

  private def git(*)
    system("git", *, chdir: @root, exception: true)
  end

  private def source(ref: nil)
    PlatformGem.source_gem(root: @root, dir: "fixture", gemspec: "fixture.gemspec", work: @root, ref:)
  end

  private def platform_gem(source: nil, platform: "x86_64-linux", host_os: "linux-gnu", ruby_version: "4.1.0.preview1")
    PlatformGem.new(source: source || self.source, extension: "lib/fixture/fixture", platform: Gem::Platform.new(platform),
      host_os:, ruby_version: Gem::Version.new(ruby_version), out: @out)
  end

  def test_a_mac_gem_names_no_darwin_version
    assert_equal "arm64-darwin", platform_gem(platform: "arm64-darwin-24", host_os: "darwin24").platform.to_s
  end

  def test_a_linux_gem_names_glibc
    assert_equal "x86_64-linux-gnu", platform_gem(platform: "x86_64-linux", host_os: "linux-gnu").platform.to_s
    assert_equal "aarch64-linux-gnu", platform_gem(platform: "aarch64-linux", host_os: "linux").platform.to_s
  end

  def test_a_linux_gem_built_on_musl_names_musl
    assert_equal "x86_64-linux-musl", platform_gem(platform: "x86_64-linux-musl", host_os: "linux-musl").platform.to_s
  end

  def test_a_windows_gem_keeps_ruby_s_platform
    assert_equal "x64-mingw-ucrt", platform_gem(platform: "x64-mingw-ucrt", host_os: "mingw32").platform.to_s
  end

  # Bundler writes a platform's gem into a lockfile only when the Ruby
  # that locks satisfies it, so the gems of one release, built on a
  # preview on one system and on master on another, admit each other's
  # Ruby.
  def test_a_gem_built_on_a_preview_serves_every_prerelease_of_that_release
    requirement = platform_gem(ruby_version: "4.1.0.preview1").required_ruby_version

    %w[4.1.0.preview1 4.1.0.preview2 4.1.0.dev 4.1.0.rc1].each do |prerelease|
      assert requirement.satisfied_by?(Gem::Version.new(prerelease)), "#{requirement} refuses #{prerelease}"
    end
    %w[4.1.0 4.1.1 4.0.9 4.2.0.dev 4.2.0.preview1].each do |other|
      refute requirement.satisfied_by?(Gem::Version.new(other)), "#{requirement} admits #{other}"
    end
  end

  def test_a_gem_built_on_ruby_s_master_serves_the_same_prereleases
    requirement = platform_gem(ruby_version: "4.1.0.dev").required_ruby_version

    assert_equal platform_gem(ruby_version: "4.1.0.preview1").required_ruby_version, requirement
    assert requirement.satisfied_by?(Gem::Version.new("4.1.0.dev"))
    refute requirement.satisfied_by?(Gem::Version.new("4.1.0"))
  end

  def test_a_gem_built_on_a_release_serves_its_minor_version
    requirement = platform_gem(ruby_version: "4.1.2").required_ruby_version

    %w[4.1.0 4.1.2 4.1.9].each { |version| assert requirement.satisfied_by?(Gem::Version.new(version)), version }
    %w[4.1.0.preview1 4.2.0.preview1 4.2.0 4.0.9].each do |other|
      refute requirement.satisfied_by?(Gem::Version.new(other)), "#{requirement} admits #{other}"
    end
  end

  def test_the_requirement_keeps_the_source_gem_s_floor
    requirement = platform_gem(ruby_version: "4.1.0").required_ruby_version(Gem::Requirement.new(">= 4.1.1"))

    refute requirement.satisfied_by?(Gem::Version.new("4.1.0"))
    assert requirement.satisfied_by?(Gem::Version.new("4.1.1"))
  end

  def test_the_gem_compiles_the_source_gem_s_extension_as_rubygems_would_and_has_nothing_to_compile
    target = ENV.fetch("RB_SYS_CARGO_TARGET_DIR", nil)
    ENV["RB_SYS_CARGO_TARGET_DIR"] = File.join(@root, "target")
    package = Gem::Package.new(platform_gem.build(File.join(@root, "pkg")))
    spec = package.spec
    extension = "lib/fixture/fixture.#{RbConfig::CONFIG['DLEXT']}"

    assert_equal "x86_64-linux-gnu", spec.platform.to_s
    assert_empty spec.extensions
    assert_equal ["ext/fixture/extconf.rb", "lib/fixture.rb", extension], spec.files.sort
    assert_empty spec.runtime_dependencies
    assert_equal Gem::Requirement.new(">= 3.0", ">= 4.1.0.a", "< 4.1.0"), spec.required_ruby_version
    assert_equal "compiled [] target=unset", read_file(package, extension)
  ensure
    ENV["RB_SYS_CARGO_TARGET_DIR"] = target
  end

  private def read_file(package, path)
    Dir.mktmpdir("unpacked") do |dir|
      package.extract_files(dir)
      File.read(File.join(dir, path))
    end
  end

  def test_a_failing_extconf_stops_the_build
    write("fixture/ext/fixture/extconf.rb", "abort 'no compiler'\n")
    git("add", ".")

    error = assert_raises(PlatformGem::Failure) { platform_gem.build(File.join(@root, "pkg")) }

    assert_match "extconf.rb failed", error.message
    assert_includes @out.string, "no compiler"
  end

  def test_a_make_that_builds_no_extension_stops_the_build
    write("fixture/ext/fixture/extconf.rb", %(File.write("Makefile", "all:\\n\\ttrue\\n")\n))
    git("add", ".")

    error = assert_raises(PlatformGem::Failure) { platform_gem.build(File.join(@root, "pkg")) }

    assert_match "make built no fixture.#{RbConfig::CONFIG['DLEXT']}", error.message
  end

  def test_a_gem_that_builds_with_warnings_does_not_build
    gemspec = File.join(@root, "fixture/fixture.gemspec")
    File.write(gemspec, File.read(gemspec).sub(/^.*homepage.*\n/, ""))

    error = assert_raises(PlatformGem::Failure) { platform_gem.build(File.join(@root, "pkg")) }

    assert_match "no homepage specified", error.message
  end

  def test_a_ref_builds_that_commit_s_sources_and_leaves_no_checkout
    git("tag", "fixture/v0.0.1")
    write("fixture/lib/fixture.rb", "module Fixture; PART = 43; end\n")

    tagged = read_file(Gem::Package.new(source(ref: "fixture/v0.0.1")), "lib/fixture.rb")
    working = read_file(Gem::Package.new(source), "lib/fixture.rb")

    assert_includes tagged, "PART = 42"
    assert_includes working, "PART = 43"
    refute_path_exists File.join(@root, "tmp", "native", "fixture-v0.0.1")
    refute_includes IO.popen(%w[git worktree list], chdir: @root, &:read), "native"
  end

  def test_a_ref_that_names_no_commit_is_refused
    error = assert_raises(PlatformGem::Failure) { source(ref: "fixture/v9.9.9") }

    assert_match "git worktree add", error.message
  end

  private def target
    PackageCheck::Target.new(name: "fixture", dir: "fixture", packaged: %w[lib ext], generated: [], crate: nil,
      extension: "lib/fixture/fixture", smoke: %(require "fixture"\nputs "part \#{Fixture::PART}"\n), reuse: false)
  end

  # A gem for this platform and Ruby, so RubyGems installs it here.
  private def local_gem
    PlatformGem.new(source:, extension: "lib/fixture/fixture", out: @out).build(File.join(@root, "pkg"))
  end

  def test_a_precompiled_gem_installs_and_runs_its_smoke_script
    PackageCheck.new(root: @root, gems: [target], out: @out).precompiled(target, local_gem)

    assert_includes @out.string, "✅ fixture-0.0.1-"
    assert_includes @out.string, "✅ fixture: part 42"
  end

  def test_a_gem_with_an_extension_to_compile_is_refused
    error = assert_raises(PackageCheck::Failure) do
      PackageCheck.new(root: @root, gems: [target], out: @out).precompiled(target, source)
    end

    assert_match "is for every platform", error.message
    assert_match "has extensions to compile: ext/fixture/extconf.rb", error.message
    assert_match "lacks its compiled extension, lib/fixture/fixture", error.message
  end

  def test_the_install_path_holds_no_rust_toolchain
    with_rust = File.join(@root, "rust")
    without = File.join(@root, "plain")
    write("rust/cargo", "")
    write("plain/ruby", "")

    assert_equal without, PackageCheck.path_without_rust([with_rust, without].join(File::PATH_SEPARATOR))
  end
end
