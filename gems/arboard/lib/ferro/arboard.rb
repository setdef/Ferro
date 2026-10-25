# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "arboard/version"
require_relative "arboard/ferro_arboard"
require_relative "arboard/error"
require_relative "arboard/image_data"
require_relative "arboard/get"
require_relative "arboard/set"
require_relative "arboard/clear"
require_relative "arboard/clipboard"
require_relative "arboard/linux"
require_relative "arboard/apple"
require_relative "arboard/windows"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, such as the system clipboard. Each Ferro gem binds one crate,
# keeps its names, errors, and behavior, and adds nothing of its own.
module Ferro
  # The system clipboard, through arboard 3.7.0.
  #
  # Command-line tools, editors, and desktop apps all want to copy and
  # paste. Each operating system's clipboard speaks its own protocol, and
  # binding them yourself means native code three times over.
  #
  # This module binds arboard (https://github.com/1Password/arboard), the
  # clipboard crate 1Password maintains, one to one: Clipboard reads and
  # writes text, HTML, images, and file lists on macOS, Linux (X11 and
  # Wayland), and Windows. Get, Set, and Clear take the platform options
  # arboard offers, defined only where they exist. Failures raise Error
  # subclasses with arboard's messages.
  #
  # === Examples
  #
  #   require "ferro/arboard"
  #
  #   clipboard = Ferro::Arboard::Clipboard.new
  #   clipboard.set_text("Hello, world!")
  #   clipboard.get_text # => "Hello, world!"
  #
  #   pixel = [255, 0, 0, 255].pack("C*")
  #   clipboard.set_image(Ferro::Arboard::ImageData.new(width: 1, height: 1, bytes: pixel))
  #   clipboard.get_image.width # => 1
  module Arboard
    private_constant :PLATFORM
  end
end
