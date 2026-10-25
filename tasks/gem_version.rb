# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rubygems"

# A gem's version, and the version a bump moves it to.
#
# Ferro writes versions as RubyGems does: <tt>0.1.0</tt>, or a prerelease
# such as <tt>0.1.0.pre.2</tt>. Working out the next one by hand invites
# mistakes: which segments reset, whether a bump finishes a prerelease or
# starts another, how the crate's Cargo.toml spells it.
#
# The bump rules are ported from ratatui_ruby-devtools 0.4.1
# (<tt>lib/ratatui_ruby/devtools/tasks/bump/sem_ver.rb</tt>, by the same
# author under the same license), which writes SemVer's
# <tt>1.0.0-rc.1</tt>. This class reads and writes RubyGems' form instead
# and lets Gem::Version order them.
#
# === Example
#
#   GemVersion.parse("0.1.0.pre.1").next(:patch, "pre").to_s  # => "0.1.0.pre.2"
#   GemVersion.parse("0.1.0.pre.2").next(:patch).to_s         # => "0.1.0"
#   GemVersion.parse("0.1.0.pre.2").cargo                     # => "0.1.0-pre.2"
class GemVersion
  include Comparable

  # The segments a bump can raise.
  SEGMENTS = %i[major minor patch].freeze

  # A prerelease label: a letter, then letters or digits.
  LABEL = /\A[a-zA-Z][a-zA-Z0-9]*\z/

  # Parses +string+, such as <tt>"0.1.0"</tt> or <tt>"0.1.0.pre.2"</tt>.
  # Raises ArgumentError for anything else, including SemVer's hyphenated
  # prerelease, which RubyGems would read as a different version.
  def self.parse(string)
    raise ArgumentError, "#{string} has a hyphen. Write prereleases as RubyGems does, like 0.1.0.pre.2." if string.include?("-")
    raise ArgumentError, "#{string.inspect} is not a version" unless Gem::Version.correct?(string)

    segments = Gem::Version.new(string).segments
    release = segments.take_while { |segment| segment.is_a?(Integer) }
    prerelease = segments.drop(release.size)
    raise ArgumentError, "#{string} has more than three release segments" if release.size > 3

    new((release + [0, 0, 0]).first(3), prerelease)
  end

  # [release] Three Integers: major, minor, patch.
  # [prerelease] The prerelease identifiers, such as <tt>["pre", 2]</tt>, or
  #   none.
  def initialize(release, prerelease = [])
    @release = release
    @prerelease = prerelease
  end

  # The major segment.
  def major
    @release[0]
  end

  # Whether this is a prerelease, such as <tt>0.1.0.pre.2</tt>.
  def prerelease?
    !@prerelease.empty?
  end

  # Whether this version promises a stable API: 1.0 or later, and not a
  # prerelease.
  def stable?
    major >= 1 && !prerelease?
  end

  # The version after bumping +segment+, which resets the segments after
  # it. A prerelease comes before its release, so bumping it to a segment
  # it already leads up to releases it: <tt>0.1.0.pre.2</tt> becomes
  # <tt>0.1.0</tt> on <tt>:patch</tt> or <tt>:minor</tt>.
  #
  # With a +label+, the result is a prerelease of that version instead.
  # Its number counts up from the prerelease you are on when that leads to
  # the same version under the same label, and starts at 1 otherwise:
  # <tt>0.1.0.pre.1</tt> becomes <tt>0.1.0.pre.2</tt> on <tt>:patch</tt>
  # with <tt>"pre"</tt>, and <tt>0.1.0.beta.3</tt> becomes
  # <tt>0.1.0.rc.1</tt> with <tt>"rc"</tt>.
  #
  # Raises ArgumentError for an unknown segment, an invalid label, or a
  # labelled version that would come before this one (RubyGems orders labels
  # as text, so <tt>beta</tt> cannot follow <tt>rc</tt>).
  def next(segment, label = nil)
    release = release_after(segment)
    return release unless label
    raise ArgumentError, "#{label.inspect} is not a prerelease label; use letters and digits, like pre" unless label.match?(LABEL)

    candidate = GemVersion.new(release.release, [label, count_toward(release, label) + 1])
    return candidate if candidate > self

    raise ArgumentError, "#{candidate} would come before #{self}; pick a label that sorts after #{@prerelease.first}"
  end

  # Orders versions as RubyGems does.
  def <=>(other)
    to_gem_version <=> other.to_gem_version if other.is_a?(GemVersion)
  end

  # The version as RubyGems reads it.
  def to_gem_version
    Gem::Version.new(to_s)
  end

  # The version as RubyGems writes it: <tt>0.1.0.pre.2</tt>.
  def to_s
    [*@release, *@prerelease].join(".")
  end

  # The version as Cargo writes it: <tt>0.1.0-pre.2</tt>.
  def cargo
    prerelease? ? "#{@release.join('.')}-#{@prerelease.join('.')}" : @release.join(".")
  end

  protected attr_reader :release

  private def release_after(segment)
    index = SEGMENTS.index(segment) or raise ArgumentError, "#{segment.inspect} is not one of #{SEGMENTS.join(', ')}"
    return GemVersion.new(@release) if prerelease? && @release[(index + 1)..].all?(&:zero?)

    raised = @release.dup
    raised[index] += 1
    raised.fill(0, (index + 1)..2)
    GemVersion.new(raised)
  end

  # How many prereleases labelled +label+ this one has counted toward
  # +release+: 1 for pre.1, none for beta.3 or another version's pre.
  private def count_toward(release, label)
    return 0 unless @release == release.release && @prerelease.first == label

    (@prerelease[1].is_a?(Integer) && @prerelease.size == 2) ? @prerelease[1] : 0
  end
end
