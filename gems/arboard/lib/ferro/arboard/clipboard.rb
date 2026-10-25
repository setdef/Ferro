# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"
require_relative "error"
require_relative "image_data"
require_relative "get"
require_relative "set"
require_relative "clear"

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: Clipboard's behavior and its docs from arboard 3.7.0
    #   src/lib.rs:36-174
    #++

    # The system clipboard.
    #
    # Programs copy and paste through a clipboard the operating system
    # owns, and each system speaks its own protocol: NSPasteboard on macOS,
    # X11 selections or Wayland's data-control protocol on Linux, the
    # Win32 clipboard on Windows. Writing to all three by hand means three
    # sets of native calls, encodings, and failure modes.
    #
    # This class speaks to whichever one you run on. It reads and writes
    # text, HTML, images, and lists of files, and raises an Error subclass
    # when the clipboard cannot do what you asked.
    #
    # Use it to copy a result for the user to paste elsewhere, to read what
    # they copied, or to clear something sensitive once it is used.
    #
    # Any number of clipboards may exist at once, on any threads. Running
    # operations in parallel can still fail with
    # Error::ClipboardOccupied. A call that can block (on Linux, a read, or
    # a write that waits) releases Ruby's global VM lock while arboard works,
    # so other Ruby threads run meanwhile; a short call keeps it, since
    # giving it up and taking it back costs up to a time slice per waiting
    # thread. arboard cannot cancel a call in progress, so Ctrl-C and
    # <tt>Thread#kill</tt> take effect when it returns, and the process does
    # not exit until a thread stuck in one finishes. A short call that finds
    # the clipboard busy with another thread's waiting write waits for it
    # with the lock released.
    #
    # arboard asks that every clipboard be dropped before the program
    # exits. Ruby frees each one when the garbage collector collects it,
    # and frees any left at a normal exit. <tt>exit!</tt> skips that.
    #
    # Any Ractor may open a clipboard, and a frozen one can be shared with
    # other Ractors (<tt>Ractor.make_shareable</tt>), since arboard's
    # clipboard is safe to use from any thread.
    #
    # === Platform behavior
    #
    # arboard abstracts over each platform, but some differences leak
    # through, and they may shape whether you open a clipboard per
    # operation or keep one around.
    #
    # On Linux, under both X11 and Wayland, the clipboard's contents live
    # inside the program that last set them. When that program's last
    # clipboard is dropped, the contents may vanish for other programs.
    # See SetExtLinux#wait.
    #
    # On Windows, the clipboard is a global object that only one thread
    # may open at a time, so arboard opens it only for the length of each
    # operation. Operations in parallel are likely to fail or deadlock, so
    # avoid using clipboards from more than one thread.
    #
    # Mirrors arboard's +Clipboard+ (<tt>src/lib.rs:36-174</tt>).
    #
    # === Examples
    #
    #   clipboard = Ferro::Arboard::Clipboard.new
    #   clipboard.set_text("Hello, world!")
    #   clipboard.get_text # => "Hello, world!"
    #
    #   clipboard.set_html("<b>Hello</b>, world!", "Hello, world!")
    #   clipboard.get.html
    #
    #   clipboard.set.file_list(["/etc/hosts"])
    #   clipboard.get.file_list # => ["/etc/hosts"] (or its real path)
    #
    #   clipboard.clear
    class Clipboard
      ##
      # :singleton-method: new
      # Opens the clipboard.
      #
      # Some platforms or desktop environments have no clipboard, and some
      # processes (a launchd daemon on macOS, say) cannot reach it. Then
      # this raises an Error subclass, usually Error::ClipboardNotSupported.
      # You may retry.
      #
      # Mirrors arboard's <tt>Clipboard::new</tt> (<tt>src/lib.rs:75-83</tt>).
      #
      # === Example
      #
      #   clipboard = Ferro::Arboard::Clipboard.new

      # Reads UTF-8 text from the clipboard.
      #
      # Raises Error::ContentNotAvailable when the clipboard is empty or
      # holds no text. The same as <tt>get.text</tt>.
      #
      # Mirrors arboard's <tt>Clipboard::get_text</tt>
      # (<tt>src/lib.rs:85-92</tt>).
      #
      # === Example
      #
      #   clipboard.get_text # => "what the user copied"
      def get_text
        get.text
      end

      # Puts +text+ on the clipboard, replacing what was there. Any valid
      # UTF-8 string works; a String in another encoding is converted, and
      # one that cannot be raises +EncodingError+. The same as
      # <tt>set.text(text)</tt>.
      #
      # Mirrors arboard's <tt>Clipboard::set_text</tt>
      # (<tt>src/lib.rs:94-101</tt>).
      #
      # === Example
      #
      #   clipboard.set_text("Copied!")
      def set_text(text)
        set.text(text)
      end

      # Puts +html+ on the clipboard, with +alt_text+ as the plain-text
      # version for programs that cannot paste HTML. Pass +nil+ for no
      # plain text. Raises only if both failed to be stored. The same as
      # <tt>set.html(html, alt_text)</tt>.
      #
      # Mirrors arboard's <tt>Clipboard::set_html</tt>
      # (<tt>src/lib.rs:103-116</tt>).
      #
      # === Example
      #
      #   clipboard.set_html("<b>Bold</b> move", "Bold move")
      def set_html(html, alt_text)
        set.html(html, alt_text)
      end

      # Reads an image from the clipboard and returns its pixels as
      # ImageData.
      #
      # Any image put there with #set_image reads back. An image another
      # program copied may be in a format arboard cannot decode; then this
      # raises Error::ConversionFailure. An empty clipboard, or one holding
      # no image, raises Error::ContentNotAvailable. The same as
      # <tt>get.image</tt>.
      #
      # Mirrors arboard's <tt>Clipboard::get_image</tt>
      # (<tt>src/lib.rs:118-131</tt>).
      #
      # === Example
      #
      #   image = clipboard.get_image
      #   puts "#{image.width}x#{image.height}"
      def get_image
        get.image
      end

      # Puts +image+, an ImageData, on the clipboard.
      #
      # arboard stores it as an NSImage on macOS, as a PNG under the
      # <tt>image/png</tt> type on Linux, and as <tt>CF_DIB</tt> (then
      # <tt>CF_BITMAP</tt>) on Windows. Raises Error::ConversionFailure if
      # the image cannot be converted, including any image with a zero
      # width or height or a byte count other than
      # <tt>width * height * 4</tt>. The same as <tt>set.image(image)</tt>.
      #
      # Mirrors arboard's <tt>Clipboard::set_image</tt>
      # (<tt>src/lib.rs:133-148</tt>).
      #
      # === Example
      #
      #   pixel = [0, 128, 255, 255].pack("C*")
      #   clipboard.set_image(Ferro::Arboard::ImageData.new(width: 1, height: 1, bytes: pixel))
      def set_image(image)
        set.image(image)
      end

      # Removes whatever the clipboard holds, in any format. The same as
      # <tt>clear_with.default</tt>.
      #
      # On Windows and Linux this raises an Error subclass if the clipboard
      # cannot be cleared. Clearing an empty clipboard succeeds.
      #
      # Mirrors arboard's <tt>Clipboard::clear</tt>
      # (<tt>src/lib.rs:150-158</tt>).
      #
      # === Example
      #
      #   clipboard.set_text(password)
      #   # ... the user pastes it ...
      #   clipboard.clear
      def clear
        clear_with.default
      end

      # Begins a clear operation. Finish it with Clear#default, or on
      # Linux with ClearExtLinux#clipboard to pick the selection.
      #
      # Mirrors arboard's <tt>Clipboard::clear_with</tt>
      # (<tt>src/lib.rs:160-163</tt>).
      #
      # === Example
      #
      #   clipboard.clear_with.default
      def clear_with
        Clear.__send__(:new, self)
      end

      # Begins a get operation. Finish it with Get#text, Get#html,
      # Get#image, or Get#file_list.
      #
      # Mirrors arboard's <tt>Clipboard::get</tt>
      # (<tt>src/lib.rs:165-168</tt>).
      #
      # === Example
      #
      #   clipboard.get.html
      def get
        Get.__send__(:new, self)
      end

      # Begins a set operation. Choose its options (on Linux, for example,
      # SetExtLinux#wait), then finish it with Set#text, Set#html,
      # Set#image, or Set#file_list.
      #
      # Mirrors arboard's <tt>Clipboard::set</tt>
      # (<tt>src/lib.rs:170-173</tt>).
      #
      # === Example
      #
      #   clipboard.set.exclude_from_history.text(one_time_code)
      def set
        Set.__send__(:new, self)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
