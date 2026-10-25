# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

# The gate for one gem, while you work on it. The full gate (rake with no
# arguments) still runs before a commit: it also covers the tooling, the
# other gems, licensing, RDoc, and the pins every gem must share.
namespace :gate do
  FERRO_GEMS.each do |gem|
    desc "Run every check for #{gem.name} alone"
    task gem.short_name => [
      "compile:#{gem.short_name}",
      "test:#{gem.short_name}",
      "rust:#{gem.short_name}",
      "steep:#{gem.short_name}",
      "rbs:parity:#{gem.short_name}",
      "package:check:#{gem.short_name}",
    ] do
      sh "bundle", "exec", "rubocop", gem.dir
    end
  end
end
