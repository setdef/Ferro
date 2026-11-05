# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: Error variants, their docs, and their Display text
    #   from arboard 3.7.0 src/common.rs:14-65
    #++

    # A clipboard operation failed.
    #
    # The system clipboard is shared with every other program on the
    # machine. It can be empty, hold the wrong kind of data, be locked by
    # someone else, or be missing altogether. A single "it failed" would
    # leave you guessing which.
    #
    # Each of arboard's error variants is a subclass, so you can rescue
    # the case you know how to handle and let the rest propagate. Each
    # message is arboard's own text. Rescue this class to catch them all.
    #
    # A variant that a later arboard adds raises this class itself, with
    # arboard's message, until ferro-arboard names it. So does a panic
    # inside arboard, with the message <tt>arboard panicked: ...</tt>,
    # which would otherwise end the Ruby process.
    #
    # Each subclass answers #debug with arboard's +Debug+ text for its
    # variant, which Rust formats; +inspect+ stays Ruby's. This class
    # itself is no variant of arboard's, so it has no +debug+.
    #
    # Mirrors arboard's +Error+ (<tt>src/common.rs:14-53</tt>), and its
    # +Debug+ (<tt>src/common.rs:69-90</tt>).
    #
    # === Examples
    #
    #   clipboard = Ferro::Arboard::Clipboard.new
    #   begin
    #     puts clipboard.get_text
    #   rescue Ferro::Arboard::Error::ContentNotAvailable
    #     puts "(the clipboard holds no text)"
    #   end
    #
    #   begin
    #     clipboard.set_text("hello")
    #   rescue Ferro::Arboard::Error => e
    #     warn "Could not copy: #{e.message}"
    #   end
    class Error < StandardError
      # The clipboard contents were not available in the requested format.
      #
      # Either the clipboard is empty, or it holds something else, as when
      # you call Clipboard#get_image while it holds text.
      #
      # === Example
      #
      #   clipboard.clear
      #   clipboard.get_text # raises Ferro::Arboard::Error::ContentNotAvailable
      class ContentNotAvailable < Error
        # Creates the error. Without a +message+, or with +nil+, the message
        # is arboard's.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   raise Ferro::Arboard::Error::ContentNotAvailable
        def initialize(message = nil)
          super(message || "The clipboard contents were not available in the requested format or the clipboard " \
            "is empty.")
        end

        # arboard's +Debug+ text for this variant, formatted by Rust:
        # the variant's name, then arboard's message in quotes, whatever
        # message this error carries.
        #
        # === Example
        #
        #   Ferro::Arboard::Error::ContentNotAvailable.new.debug
        #   # => 'ContentNotAvailable - "The clipboard contents were not available ..."'
        def debug
          Native.error_debug(:ContentNotAvailable, nil)
        end
      end

      # The selected clipboard is not supported by the current system or
      # environment.
      #
      # This happens when you use the Primary clipboard with an older
      # Wayland compositor (one that lacks version 2 of the protocol), or
      # the Secondary clipboard on Wayland. On macOS, it happens when the
      # process has no pasteboard at all, as under some launchd daemons.
      #
      # === Example
      #
      #   begin
      #     clipboard = Ferro::Arboard::Clipboard.new
      #   rescue Ferro::Arboard::Error::ClipboardNotSupported
      #     clipboard = nil # run without a clipboard
      #   end
      class ClipboardNotSupported < Error
        # Creates the error. Without a +message+, or with +nil+, the message
        # is arboard's.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   raise Ferro::Arboard::Error::ClipboardNotSupported
        def initialize(message = nil)
          super(message || "The selected clipboard is not supported with the current system configuration.")
        end

        # arboard's +Debug+ text for this variant, formatted by Rust:
        # the variant's name, then arboard's message in quotes, whatever
        # message this error carries.
        #
        # === Example
        #
        #   Ferro::Arboard::Error::ClipboardNotSupported.new.debug
        #   # => 'ClipboardNotSupported - "The selected clipboard is not supported ..."'
        def debug
          Native.error_debug(:ClipboardNotSupported, nil)
        end
      end

      # The native clipboard is held by another party.
      #
      # The other party may be another process, or another thread of this
      # one: operations on several threads at once can fail this way. Many
      # Clipboard objects may exist at once; arboard opens the native
      # clipboard only while it moves data, then closes it again.
      #
      # === Example
      #
      #   begin
      #     clipboard.set_text("hello")
      #   rescue Ferro::Arboard::Error::ClipboardOccupied
      #     sleep 0.05
      #     retry
      #   end
      class ClipboardOccupied < Error
        # Creates the error. Without a +message+, or with +nil+, the message
        # is arboard's.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   raise Ferro::Arboard::Error::ClipboardOccupied
        def initialize(message = nil)
          super(message || "The native clipboard is not accessible due to being held by another party.")
        end

        # arboard's +Debug+ text for this variant, formatted by Rust:
        # the variant's name, then arboard's message in quotes, whatever
        # message this error carries.
        #
        # === Example
        #
        #   Ferro::Arboard::Error::ClipboardOccupied.new.debug
        #   # => 'ClipboardOccupied - "The native clipboard is not accessible ..."'
        def debug
          Native.error_debug(:ClipboardOccupied, nil)
        end
      end

      # The image or text could not be converted to or from the format the
      # clipboard needs.
      #
      # ferro-arboard also raises it, before arboard sees the image, for an
      # ImageData arboard could panic on: on Linux and Windows, one with a
      # zero width or height or a byte count other than
      # <tt>width * height * 4</tt>, since the PNG encoder there asserts
      # the count; on macOS, one with no bytes, or a size too large to
      # count. On macOS arboard itself raises it for a zero width or height
      # or too few bytes.
      #
      # The message keeps arboard's wording, typo included.
      #
      # === Example
      #
      #   image = Ferro::Arboard::ImageData.new(width: 0, height: 0, bytes: "")
      #   clipboard.set_image(image) # raises Ferro::Arboard::Error::ConversionFailure
      class ConversionFailure < Error
        # Creates the error. Without a +message+, or with +nil+, the message
        # is arboard's.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   raise Ferro::Arboard::Error::ConversionFailure
        def initialize(message = nil)
          super(message || "The image or the text that was about the be transferred to/from the clipboard could " \
            "not be converted to the appropriate format.")
        end

        # arboard's +Debug+ text for this variant, formatted by Rust:
        # the variant's name, then arboard's message in quotes, whatever
        # message this error carries.
        #
        # === Example
        #
        #   Ferro::Arboard::Error::ConversionFailure.new.debug
        #   # => 'ConversionFailure - "The image or the text that was about the be ..."'
        def debug
          Native.error_debug(:ConversionFailure, nil)
        end
      end

      # Any failure that fits none of the other classes.
      #
      # The description helps you debug. Do not match on it to tell
      # failures apart: arboard does not promise its wording.
      #
      # === Example
      #
      #   rescue Ferro::Arboard::Error::Unknown => e
      #     warn e.description
      class Unknown < Error
        # What went wrong, in the platform's words.
        attr_reader :description

        # Creates the error, with arboard's message around +description+.
        #
        # [description] String, what went wrong.
        #
        # === Example
        #
        #   error = Ferro::Arboard::Error::Unknown.new("pasteboard unavailable")
        #   error.message
        #   # => "Unknown error while interacting with the clipboard: pasteboard unavailable"
        def initialize(description = "")
          @description = description
          super("Unknown error while interacting with the clipboard: #{description}")
        end

        # arboard's +Debug+ text for an +Unknown+, formatted by Rust:
        # <tt>Unknown { .. }</tt>, the pattern arboard names it by, then
        # arboard's message for #description in quotes.
        #
        # === Example
        #
        #   Ferro::Arboard::Error::Unknown.new("pasteboard unavailable").debug
        #   # => 'Unknown { .. } - "Unknown error while interacting with the clipboard: pasteboard unavailable"'
        def debug
          Native.error_debug(:Unknown, description)
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
