# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: ImageData's layout from arboard 3.7.0 src/common.rs:98-131
    #++

    # The pixels of an image, as the clipboard trades them.
    #
    # Every platform stores clipboard images differently: an NSImage on
    # macOS, a PNG on Linux, a device-independent bitmap on Windows.
    # Converting between them and your own pixels is fiddly, lossy work.
    #
    # This value holds the one layout arboard converts to and from: four
    # bytes per pixel (red, green, blue, alpha), in row-major order from
    # the top-left corner. The fifth byte starts the pixel just right of
    # the first one (x=1, y=0). A 3 by 3 image is <tt>3 * 3 * 4 = 36</tt>
    # bytes.
    #
    # Use it to copy a rendered chart, a screenshot, or a generated
    # thumbnail, or to read what the user copied from an image editor.
    #
    # Mirrors arboard's +ImageData+ (<tt>src/common.rs:98-131</tt>). Its
    # helpers +into_owned_bytes+ and +to_owned_img+ turn borrowed bytes
    # into owned ones; a Ruby String is always owned, so #bytes and the
    # image itself already are what they return.
    #
    # === Examples
    #
    #   # A 2 by 1 image: a red pixel, then a green one.
    #   bytes = [255, 0, 0, 255, 0, 255, 0, 255].pack("C*")
    #   image = Ferro::Arboard::ImageData.new(width: 2, height: 1, bytes:)
    #   Ferro::Arboard::Clipboard.new.set_image(image)
    #
    #   image = Ferro::Arboard::Clipboard.new.get_image
    #   red, green, blue, alpha = image.bytes.unpack("C4")
    class ImageData < Data.define(:width, :height, :bytes)
      ##
      # :attr_reader: width
      # The image's width in pixels.

      ##
      # :attr_reader: height
      # The image's height in pixels.

      ##
      # :attr_reader: bytes
      # The pixels as a binary String: four bytes (red, green, blue, alpha)
      # per pixel, row by row from the top-left corner.
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
