# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "tasks/ferro_gems"

# Every gem compiles into one target directory during development, so a
# shared dependency such as magnus compiles once
# (doc/contributors/design/repository.md). rb_sys's generated Makefile
# honors RB_SYS_CARGO_TARGET_DIR; the cargo tasks read CARGO_TARGET_DIR.
# An installed gem builds on its own.
ENV["RB_SYS_CARGO_TARGET_DIR"] ||= File.expand_path("target", __dir__)
ENV["CARGO_TARGET_DIR"] ||= ENV.fetch("RB_SYS_CARGO_TARGET_DIR")

Dir.glob("tasks/*.rake").each { |file| import file }

# The gate runs the desktop tests too, in the session that runs it
# (plan 014), so its first step sets FERRO_DESKTOP=1.
desc "The gate: every check, across every gem, the desktop tests included"
task default: %w[test:allow_desktop compile:strict test rubocop steep lint:rbs rdoc:check reuse:lint lint:rust pins:check package:check]
