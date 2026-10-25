# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"
require_relative "error"
require_relative "image_data"

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: Set's methods and their docs from arboard 3.7.0
    #   src/lib.rs:215-264
    #++

    # A write to the clipboard, waiting for you to say what to write.
    #
    # A plain write needs only the data, and Clipboard#set_text covers it.
    # Platforms add options: keeping a password out of clipboard history,
    # picking a Linux selection, or serving the contents until another
    # program takes them. A method per combination would multiply fast.
    #
    # So Clipboard#set returns this builder. Each option returns the
    # builder for chaining, and one of the format methods below finishes
    # the write. The options are defined only on the platforms that have
    # them: SetExtLinux, SetExtApple, and SetExtWindows.
    #
    # Mirrors arboard's +Set+ (<tt>src/lib.rs:215-264</tt>). arboard's
    # builder works once; this one keeps its options and may be finished
    # again.
    #
    # === Examples
    #
    #   clipboard = Ferro::Arboard::Clipboard.new
    #   clipboard.set.text("plain")
    #   clipboard.set.html("<i>rich</i>", "rich")
    #
    #   # Keep a one-time code out of clipboard managers.
    #   clipboard.set.exclude_from_history.text("492 117")
    class Set
      private_class_method :new

      # Creates a write to +clipboard+. Use Clipboard#set.
      #
      # [clipboard] Clipboard, the clipboard to write.
      def initialize(clipboard)
        @clipboard = clipboard
        @selection = nil
        @wait = nil
        @exclude_from_history = false
        @exclude_from_monitoring = false
        @exclude_from_cloud = false
      end

      # Puts +text+ on the clipboard. Any valid UTF-8 string works; a
      # String in another encoding is converted, and one that cannot be
      # raises +EncodingError+.
      #
      # Mirrors arboard's <tt>Set::text</tt> (<tt>src/lib.rs:227-232</tt>).
      #
      # === Example
      #
      #   clipboard.set.text("Copied!")
      def text(text)
        @clipboard.__send__(:native_set_text, text, options)
      end

      # Puts +html+ on the clipboard, with +alt_text+ as the plain-text
      # version for programs that cannot paste HTML, or +nil+ for none.
      # Any valid UTF-8 string works.
      #
      # On macOS, arboard wraps +html+ in <tt><html></tt>, <tt><head></tt>,
      # and <tt><body></tt> tags with a UTF-8 <tt>meta</tt> tag, because
      # some programs would read it as Windows Latin 1 otherwise. On
      # Wayland, a text read with no +alt_text+ returns +html+ itself, since
      # it takes any text type the clipboard offers.
      #
      # Mirrors arboard's <tt>Set::html</tt> (<tt>src/lib.rs:234-246</tt>).
      #
      # === Example
      #
      #   clipboard.set.html("<h1>Title</h1>", "Title")
      def html(html, alt_text)
        @clipboard.__send__(:native_set_html, html, alt_text, options)
      end

      # Puts +image+, an ImageData, on the clipboard.
      #
      # arboard stores it as an NSImage on macOS, as a PNG under the
      # <tt>image/png</tt> type on Linux, and as <tt>CF_DIB</tt> (then
      # <tt>CF_BITMAP</tt>) on Windows. An image with a zero width or
      # height, or a byte count other than <tt>width * height * 4</tt>,
      # raises Error::ConversionFailure without reaching arboard, which
      # would panic on some platforms.
      #
      # Mirrors arboard's <tt>Set::image</tt> (<tt>src/lib.rs:248-258</tt>).
      #
      # === Example
      #
      #   white = ([255] * 16).pack("C*")
      #   clipboard.set.image(Ferro::Arboard::ImageData.new(width: 2, height: 2, bytes: white))
      def image(image)
        raise TypeError, "wrong argument type #{image.class} (expected #{ImageData})" unless image.is_a?(ImageData)

        @clipboard.__send__(:native_set_image, image.width, image.height, image.bytes, options)
      end

      # Puts a list of files on the clipboard, as a file manager's copy
      # does. +paths+ is an Array of Strings, or of objects such as Pathname
      # that respond to +to_path+.
      #
      # arboard stores each file's real, absolute path and skips any that
      # do not exist. If none exist, this raises Error::ConversionFailure.
      #
      # Mirrors arboard's <tt>Set::file_list</tt>
      # (<tt>src/lib.rs:260-263</tt>).
      #
      # === Example
      #
      #   clipboard.set.file_list(["report.pdf", Pathname("chart.png")])
      def file_list(paths)
        list = Array.try_convert(paths) or raise TypeError, "no implicit conversion of #{paths.class} into Array"
        @clipboard.__send__(:native_set_file_list, list.map { |path| File.path(path) }, options)
      end

      # The options the native layer takes, in its order: the Linux
      # selection, the Linux wait (the seconds left, for a deadline), and
      # the three history exclusions.
      private def options
        wait = @wait
        wait -= Process.clock_gettime(Process::CLOCK_MONOTONIC) if wait.is_a?(Float)
        [@selection, wait, @exclude_from_history, @exclude_from_monitoring, @exclude_from_cloud]
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
