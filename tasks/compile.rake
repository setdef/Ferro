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
