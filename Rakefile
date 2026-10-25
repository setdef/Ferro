# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "tasks/ferro_gems"

# Every gem compiles into one target directory during development, so a
# shared dependency such as magnus compiles once (ADR 001, section 3).
# rb_sys's generated Makefile honors RB_SYS_CARGO_TARGET_DIR; the cargo
# tasks read CARGO_TARGET_DIR. An installed gem builds on its own.
ENV["RB_SYS_CARGO_TARGET_DIR"] ||= File.expand_path("target", __dir__)
ENV["CARGO_TARGET_DIR"] ||= ENV.fetch("RB_SYS_CARGO_TARGET_DIR")

Dir.glob("tasks/*.rake").each { |file| import file }

desc "The gate: every check, across every gem"
task default: %w[compile:strict test rubocop steep lint:rbs rdoc:check reuse:lint lint:rust pins:check package:check]
