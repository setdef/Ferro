# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "mkmf"
require "rb_sys/mkmf"

# --locked: build against the Cargo.lock shipped with the gem, the versions
# the repository tested, and fail rather than resolve newer ones.
#
# --enable-test-hooks: the repository's own compiles pass it
# (tasks/compile.rake), to build the hooks its tests read (the test-hooks
# feature in Cargo.toml). The hooks are off unless the installer passes
# the option (gem install -- --enable-test-hooks, a Bundler build config,
# or CONFIGURE_ARGS reach mkmf), which only the repository's own build
# does (.agents/skills/bind-crate/SKILL.md, Test hooks).
#
# rb_sys's Makefile hands every RbConfig::CONFIG entry to rb-sys's build
# script as RBCONFIG_<key> (rb_sys 0.9.130, cargo_builder.rb,
# rb_config_env), which reads one before RbConfig itself. Windows' names
# for environment variables ignore case, so keys that differ only in case,
# as CPPFLAGS and cppflags do, arrive as one variable with either value.
# There bindgen got an empty CPPFLAGS and lost RubyInstaller's
# -DSIZEOF_RB_LEN_T=8, binding Ruby 4.1's 64-bit lengths as 32 bits
# (doc/contributors/plan/016.md). rb_sys writes no Makefile line for a nil
# value (mkmf.rb, env_line), and an entry the Makefile leaves out, rb-sys
# reads from RbConfig.
if Gem.win_platform?
  ambiguous = RbConfig::CONFIG.keys.group_by(&:downcase).values.select { |keys| keys.size > 1 }.flatten
end
create_rust_makefile("ferro/url/ferro_url") do |r|
  r.extra_cargo_args += ["--locked"]
  r.features += ["test-hooks"] if enable_config("test-hooks", false)
  ambiguous&.each { |key| r.env["RBCONFIG_#{key}"] = nil }
end
