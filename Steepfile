# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

# One target per gem, so each gem's signatures check its own code.
target :arboard do
  signature "gems/arboard/sig"
  check "gems/arboard/lib"
end

target :rfd do
  signature "gems/rfd/sig"
  check "gems/rfd/lib"
end

target :"notify-rust" do
  signature "gems/notify-rust/sig"
  check "gems/notify-rust/lib"
end
