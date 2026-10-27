# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "mkmf"
require "rb_sys/mkmf"

# --locked: build against the Cargo.lock shipped with the gem, the versions
# the repository tested, and fail rather than resolve newer ones.
create_rust_makefile("ferro/time/ferro_time") do |r|
  r.extra_cargo_args += ["--locked"]
end
