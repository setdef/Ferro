# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

# Checks that every gem links the same magnus and rb-sys.
#
# Each gem is its own Cargo workspace with its own Cargo.lock, so nothing
# stops two gems from drifting to different versions of the binding
# crates. Then a fix in one magnus reaches only some gems, and the shared
# target directory compiles both. ADR 001, section 3 makes agreement a
# gate: every gem's lockfile names the same version and source of each
# crate below, and every gemspec asks for the same rb_sys gem.
class PinCheck
  # The crates every gem links to talk to Ruby.
  CRATES = %w[magnus rb-sys].freeze

  # Raised when the gems disagree; the message names each pin.
  class Failure < StandardError; end

  # [lockfiles] Each gem's name and the text of its Cargo.lock.
  # [requirements] Each gem's name and its rb_sys gem requirement, or
  #   +nil+ for a gem with no native extension.
  def initialize(lockfiles:, requirements:)
    @lockfiles = lockfiles
    @requirements = requirements
  end

  # Raises Failure unless the gems agree. Returns the agreed pins.
  def check!
    problems = CRATES.filter_map { |crate| disagreement(crate, @lockfiles.transform_values { |lock| pin(lock, crate) }) }
    requirements = @requirements.compact
    problems << describe("the rb_sys gem", requirements) if requirements.values.uniq.size > 1
    raise Failure, problems.join("\n") if problems.any?

    CRATES.to_h { |crate| [crate, @lockfiles.values.map { |lock| pin(lock, crate) }.compact.first] }
  end

  # The <tt>version (source)</tt> a Cargo.lock locks +crate+ at, or +nil+.
  # A lockfile holding two versions of the crate yields both.
  def self.pin(lock, crate)
    lock.split(/^\[\[package\]\]$/).filter_map do |block|
      next unless block[/^name = "([^"]+)"$/, 1] == crate

      "#{block[/^version = "([^"]+)"$/, 1]} (#{block[/^source = "([^"]+)"$/, 1] || 'local'})"
    end.sort.join(", ").then { |pins| pins.empty? ? nil : pins }
  end

  private def pin(lock, crate)
    self.class.pin(lock, crate)
  end

  private def disagreement(crate, pins)
    found = pins.compact
    describe(crate, found) if found.values.uniq.size > 1
  end

  private def describe(what, pins)
    "Gems disagree on #{what}:\n#{pins.sort.map { |gem, pin| "  #{gem}: #{pin}" }.join("\n")}"
  end
end
