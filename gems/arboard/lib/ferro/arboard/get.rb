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
    # SPDX-SnippetComment: Get's methods and their docs from arboard 3.7.0
    #   src/lib.rs:176-213
    #++

    # A read from the clipboard, waiting for you to say what to read.
    #
    # Most reads need nothing but a format, and Clipboard#get_text and
    # Clipboard#get_image cover the common ones. Some platforms offer more
    # choices, such as which Linux selection to read, and a method per
    # combination would multiply fast.
    #
    # So Clipboard#get returns this builder. Platform options, where they
    # exist, return the builder for chaining (GetExtLinux#clipboard on
    # Linux), and one of the format methods below finishes the read.
    #
    # Each format method raises Error::ContentNotAvailable when the
    # clipboard is empty or holds another format.
    #
    # Mirrors arboard's +Get+ (<tt>src/lib.rs:176-213</tt>). arboard's
    # builder works once; this one may be finished again, reading the
    # clipboard afresh each time.
    #
    # === Examples
    #
    #   clipboard = Ferro::Arboard::Clipboard.new
    #   text = clipboard.get.text
    #   html = clipboard.get.html
    #
    #   # On Linux, read the selection the middle mouse button pastes.
    #   clipboard.get.clipboard(Ferro::Arboard::LinuxClipboardKind::Primary).text
    class Get
      private_class_method :new

      # Creates a read from +clipboard+. Use Clipboard#get.
      #
      # [clipboard] Clipboard, the clipboard to read.
      def initialize(clipboard)
        @clipboard = clipboard
        @selection = nil
      end

      # Reads UTF-8 text.
      #
      # Mirrors arboard's <tt>Get::text</tt> (<tt>src/lib.rs:188-191</tt>).
      #
      # === Example
      #
      #   clipboard.get.text # => "copied text"
      def text
        @clipboard.__send__(:native_get_text, @selection)
      end

      # Reads an image and returns its decoded pixels as ImageData.
      #
      # Any image Set#image put there reads back. An image another program
      # copied may be in a format arboard cannot decode, which raises
      # Error::ConversionFailure.
      #
      # Mirrors arboard's <tt>Get::image</tt> (<tt>src/lib.rs:193-202</tt>).
      #
      # === Example
      #
      #   image = clipboard.get.image
      #   image.width # => 640
      def image
        width, height, bytes = @clipboard.__send__(:native_get_image, @selection)
        ImageData.new(width:, height:, bytes:)
      end

      # Reads HTML.
      #
      # On macOS the result is wrapped in the <tt><html></tt>,
      # <tt><head></tt>, and <tt><body></tt> tags that Set#html adds there
      # to mark the text as UTF-8.
      #
      # Mirrors arboard's <tt>Get::html</tt> (<tt>src/lib.rs:204-207</tt>).
      #
      # === Example
      #
      #   clipboard.get.html # => "<b>bold</b>"
      def html
        @clipboard.__send__(:native_get_html, @selection)
      end

      # Reads a list of file paths, as Strings.
      #
      # Mirrors arboard's <tt>Get::file_list</tt>
      # (<tt>src/lib.rs:209-212</tt>).
      #
      # === Example
      #
      #   clipboard.get.file_list # => ["/path/to/report.pdf"]
      def file_list
        @clipboard.__send__(:native_get_file_list, @selection)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
