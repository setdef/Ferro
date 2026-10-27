# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    # SPDX-SnippetComment: PathSegmentsMut, its methods, and their docs from
    #   url 2.5.8 src/path_segments.rs:14-267
    #++

    # Exposes methods to manipulate the path of an URL that is not
    # cannot-be-a-base.
    #
    # Editing a path as a string means splitting on slashes, encoding each
    # new segment, and keeping the query and fragment out of the way. One
    # unencoded <tt>/</tt> or <tt>%</tt> in a segment changes what the URL
    # names.
    #
    # The path always starts with a <tt>/</tt> slash, and is made of
    # slash-separated segments. There is always at least one segment
    # (which may be the empty string). Url#path_segments_mut returns one of
    # these, and each method changes the URL at once and returns +self+,
    # so calls chain. In Rust the value borrows the URL until it is
    # dropped; here the URL stays valid between calls.
    #
    # Mirrors url's +PathSegmentsMut+ (<tt>src/path_segments.rs:14-267</tt>).
    #
    # === Example
    #
    #   url = Ferro::Url::Url.parse("http://example.net/foo/index.html")
    #   url.path_segments_mut.pop.push("img").push("2/100%.png")
    #   url.as_str # => "http://example.net/foo/img/2%2F100%25.png"
    class PathSegmentsMut
      private_class_method :new

      # Holds +url+, the Url whose path it changes.
      #
      # [url] Url.
      def initialize(url)
        @url = url
        freeze
      end

      # Removes all segments in the path, leaving the minimal
      # <tt>url.path == "/"</tt>. Mirrors url's
      # <tt>PathSegmentsMut::clear</tt> (<tt>src/path_segments.rs:78-104</tt>).
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://github.com/servo/rust-url/")
      #   url.path_segments_mut.clear.push("logout")
      #   url.as_str # => "https://github.com/logout"
      def clear
        run([:clear])
      end

      # Removes the last segment of this URL's path if it is empty, except
      # if there was only one segment to begin with. In other words, removes
      # one path trailing slash, if any, unless it is also the initial slash
      # (so this does nothing if <tt>url.path == "/"</tt>). Mirrors url's
      # <tt>PathSegmentsMut::pop_if_empty</tt>
      # (<tt>src/path_segments.rs:106-146</tt>).
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://github.com/servo/rust-url/")
      #   url.path_segments_mut.pop_if_empty.push("pulls")
      #   url.as_str # => "https://github.com/servo/rust-url/pulls"
      def pop_if_empty
        run([:pop_if_empty])
      end

      # Removes the last segment of this URL's path. If the path only has
      # one segment, makes it empty such that <tt>url.path == "/"</tt>.
      # Mirrors url's <tt>PathSegmentsMut::pop</tt>
      # (<tt>src/path_segments.rs:148-164</tt>).
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.net/a/b")
      #   url.path_segments_mut.pop
      #   url.path # => "/a"
      def pop
        run([:pop])
      end

      # Appends the given segment at the end of this URL's path. See the
      # documentation for #extend. Mirrors url's
      # <tt>PathSegmentsMut::push</tt> (<tt>src/path_segments.rs:166-173</tt>).
      #
      # [segment] String.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://github.com/servo/rust-url/")
      #   url.path_segments_mut.push("pulls")
      #   url.as_str # => "https://github.com/servo/rust-url//pulls"
      def push(segment)
        run([:push, segment])
      end

      # Appends each segment from the given Enumerable at the end of this
      # URL's path.
      #
      # Each segment is percent-encoded like in Url.parse or Url#join,
      # except that <tt>%</tt> and <tt>/</tt> characters are also encoded
      # (to <tt>%25</tt> and <tt>%2F</tt>). This is unlike Url.parse, where
      # <tt>%</tt> is left as-is in case some of the input is already
      # percent-encoded, and <tt>/</tt> denotes a path segment separator.
      #
      # Note that, in addition to slashes between new segments, this always
      # adds a slash between the existing path and the new segments except
      # if the existing path is <tt>"/"</tt>. If the previous last segment
      # was empty (if the path had a trailing slash) the path after #extend
      # will contain two consecutive slashes. If that is undesired, call
      # #pop_if_empty first. To obtain a behavior similar to Url#join, call
      # #pop unconditionally first.
      #
      # In order to make sure that parsing the serialization of an URL gives
      # the same URL, a segment is ignored if it is <tt>"."</tt> or
      # <tt>".."</tt>. Mirrors url's <tt>PathSegmentsMut::extend</tt>
      # (<tt>src/path_segments.rs:175-266</tt>).
      #
      # [segments] Enumerable of Strings.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://github.com/")
      #   url.path_segments_mut.extend(["servo", "rust-url", "issues", "188"])
      #   url.as_str # => "https://github.com/servo/rust-url/issues/188"
      #
      #   url = Ferro::Url::Url.parse("https://github.com/servo")
      #   url.path_segments_mut.extend(["..", "rust-url", ".", "pulls"])
      #   url.as_str # => "https://github.com/servo/rust-url/pulls"
      def extend(segments)
        run([:extend, segments.to_a])
      end

      # Runs one operation on the URL's path and returns +self+.
      private def run(operation)
        @url.__send__(:writable!)
        Native.url_path_segments_mut(Arguments.native(@url), operation)
        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
