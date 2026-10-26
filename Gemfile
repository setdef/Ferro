# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

source "https://rubygems.org"

# Every gem in gems/, so the root bundle loads and tests each of them.
gemspec path: "gems/arboard"
gemspec path: "gems/rfd"

gem "irb"
gem "rake", "~> 13.0"
gem "rake-compiler", "~> 1.3"

gem "minitest", "~> 6.0"
# The macOS dialog tests close real panels through AppKit with Fiddle,
# which Ruby 4.0 ships as a bundled gem rather than a default one.
gem "fiddle"

gem "prism"
gem "rbs", "~> 3.10"
gem "rdoc", "~> 7.0"
gem "rubocop", "~> 1.84.0"
gem "steep", "~> 1.10.0"
