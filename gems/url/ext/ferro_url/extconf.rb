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
# does (ADR 001, amendment of 2026-11-05: test hooks).
create_rust_makefile("ferro/url/ferro_url") do |r|
  r.extra_cargo_args += ["--locked"]
  r.features += ["test-hooks"] if enable_config("test-hooks", false)
end
