# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "date"

# A gem's CHANGELOG.md, as a release rewrites it.
#
# Each gem keeps a Keep a Changelog file whose Unreleased section collects
# changes since its last tag. Releasing turns that section into a dated
# one, leaves an empty Unreleased section above it, and moves the compare
# links at the bottom: Unreleased now starts from the new tag, and the new
# version gets a link of its own. By hand, the links are the part that goes
# wrong.
#
# Adapted from ratatui_ruby-devtools 0.4.1
# (<tt>lib/ratatui_ruby/devtools/tasks/bump/changelog.rb</tt>,
# <tt>unreleased_section.rb</tt>, and <tt>links.rb</tt>, by the same author
# under the same license), with Ferro's per-gem tags such as
# <tt>ferro-arboard/v0.1.0</tt>.
class Changelog
  # Raised when the file cannot be released; the message says what to fix.
  class Failure < StandardError; end

  # The Unreleased heading.
  UNRELEASED = /^## \[Unreleased\][^\n]*\n/

  # Where a section ends: the next version heading or the link definitions.
  SECTION_END = /^## \[|^\[[^\]]+\]: /

  # The Unreleased link, which names the GitHub repository.
  UNRELEASED_LINK = %r{^\[Unreleased\]: (https://github\.com/[^/\s]+/[^/\s]+)/\S*$}

  # [path] The CHANGELOG.md to rewrite.
  # [tag_prefix] What comes before the version in a tag, such as
  #   <tt>ferro-arboard/v</tt>.
  def initialize(path, tag_prefix:)
    @path = path
    @tag_prefix = tag_prefix
  end

  # Whether the file has a section for +version+.
  def released?(version)
    File.read(@path).match?(/^## \[#{Regexp.escape(version.to_s)}\]/)
  end

  # Releases the Unreleased entries as +version+, dated +date+. Raises
  # Failure when there are none, or when the file has no Unreleased link to
  # move.
  def release(version, date: Date.today)
    content = File.read(@path)
    heading = content.match(UNRELEASED) or raise Failure, "#{@path} has no ## [Unreleased] section"
    rest = content[(heading.end(0))..]
    body_end = rest.index(SECTION_END) || rest.length
    body = rest[0...body_end].strip
    raise Failure, "#{@path} has nothing under Unreleased to release" unless body.match?(/^- /)

    previous = rest[/^## \[([^\]]+)\]/, 1]
    released = "#{content[0...(heading.begin(0))]}## [Unreleased]\n\n## [#{version}] - #{date.iso8601}\n\n#{body}\n\n" \
      "#{rest[body_end..].sub(/\A\n+/, '')}"
    File.write(@path, links(released, version, previous))
  end

  private def links(content, version, previous)
    repository = content[UNRELEASED_LINK, 1] or
      raise Failure, "#{@path} has no [Unreleased]: link to a GitHub repository to move; add one at the bottom"

    tag = "#{@tag_prefix}#{version}"
    link = previous ? "#{repository}/compare/#{@tag_prefix}#{previous}...#{tag}" : "#{repository}/releases/tag/#{tag}"
    content.sub(UNRELEASED_LINK, "[Unreleased]: #{repository}/compare/#{tag}...HEAD\n[#{version}]: #{link}")
  end
end
