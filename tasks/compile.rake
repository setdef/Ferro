# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rb_sys/extensiontask"

# rb_sys's extension task for a gem under gems/.
#
# rb_sys finds the crate by running cargo metadata in the working
# directory. Rake runs at the repository root, and each gem is its own
# Cargo workspace (ADR 001, section 3), so this task asks Cargo from inside
# the gem. Every other path stays relative to the root. It takes no gemspec:
# rake-compiler would stage the gemspec's files, which are relative to the
# gem, for native gems Ferro does not build.
class FerroExtensionTask < RbSys::ExtensionTask
  # [gem] The FerroGem to compile.
  def initialize(gem, &)
    @ferro_gem = gem
    super(gem.extension_name, &)
  end

  # The crate's metadata, read from the gem's own workspace.
  def cargo_metadata
    @cargo_metadata ||= Dir.chdir(@ferro_gem.dir) { RbSys::Cargo::Metadata.new(@name).load! }
  end

  # rb_sys's rb_sys:env:default task sets RB_SYS_CARGO_MANIFEST_DIR in the
  # environment, once per rake run, with ||= (rb_sys 0.9.130
  # extensiontask.rb:106-110). Every extension task shares that task, so
  # with two gems the first gem's crate wins, and since each Makefile
  # assigns the variable with ?=, the environment overrides the second
  # gem's own and make builds the first gem's crate twice. Each Makefile
  # already names its own crate (rb_sys mkmf.rb:77), so this task leaves
  # the variable unset.
  def define_env_tasks
    super
    Rake::Task["rb_sys:env:default"].clear_actions
    task "rb_sys:env:default" do
      ENV["RB_SYS_CARGO_TARGET_DIR"] ||= target_directory
      ENV["RB_SYS_CARGO_PROFILE"] ||= "release"
    end
  end
end

# One extension task per gem. rake-compiler names them after the
# extension (compile:ferro_arboard); compile:<gem> is the short name.
FERRO_GEMS.each do |gem|
  FerroExtensionTask.new(gem) do |ext|
    ext.lib_dir = gem.extension_dir
  end

  desc "Compile #{gem.name}'s native extension"
  task "compile:#{gem.short_name}" => "compile:#{gem.extension_name}"
end

require_relative "cargo_output"

# rake-compiler runs make, and rb_sys's Makefile runs cargo, without
# looking at what either prints, so this compiles in a child rake and fails
# on any warning in its output (CargoOutput). The gate starts here; later
# compiles are no-ops.
desc "Compile every gem's extension, failing on any rustc or Cargo warning"
task "compile:strict" do
  CargoOutput.run!(Gem.ruby, "-S", "rake", "compile")
rescue CargoOutput::Failure => e
  abort "❌ #{e.message}"
end
