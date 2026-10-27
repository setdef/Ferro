# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "tasks/ferro_gems"

# One target per gem, so each gem's signatures check its own code, with the
# standard libraries its signatures name (FerroGem#rbs_libraries), the same
# list rbs:validate loads.
FERRO_GEMS.each do |ferro_gem|
  target ferro_gem.short_name.to_sym do
    signature File.join(ferro_gem.dir, "sig")
    check File.join(ferro_gem.dir, "lib")
    library(*ferro_gem.rbs_libraries) unless ferro_gem.rbs_libraries.empty?
  end
end
