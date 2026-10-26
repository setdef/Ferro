# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "rfd/version"
require_relative "rfd/ferro_rfd"
require_relative "rfd/error"
require_relative "rfd/handles"
require_relative "rfd/message_level"
require_relative "rfd/message_buttons"
require_relative "rfd/message_dialog_result"
require_relative "rfd/file_handle"
require_relative "rfd/future"
require_relative "rfd/file_dialog"
require_relative "rfd/async_file_dialog"
require_relative "rfd/message_dialog"
require_relative "rfd/async_message_dialog"
require_relative "rfd/apple"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, such as native file dialogs. Each Ferro gem binds one crate,
# keeps its names and behavior, and adds nothing of its own.
module Ferro
  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: MIT
  # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
  # SPDX-SnippetComment: the crate overview from rfd 0.17.2 src/lib.rs:1-86
  #++

  # Native file and message dialogs, through rfd 0.17.2.
  #
  # A program that asks the user for a file, or tells them something,
  # looks foreign unless it uses the system's own dialogs. Each system
  # has a different API for them: AppKit on macOS, the Common Item Dialog
  # on Windows, the XDG desktop portal on Linux.
  #
  # This module binds rfd (https://github.com/PolyMeilex/rfd), Rusty File
  # Dialogs, one to one. FileDialog opens and saves files and picks
  # folders; MessageDialog shows a message with a few buttons. Each has an
  # async twin, AsyncFileDialog and AsyncMessageDialog, that returns a
  # Future, for apps that must keep their event loop running while the
  # dialog is open.
  #
  # On Linux, ferro-rfd builds rfd's XDG desktop portal backend, rfd's
  # default, which needs no GTK to build and asks the desktop for its own
  # dialog at run time, falling back to +zenity+. rfd's GTK backend and
  # its Windows <tt>common-controls-v6</tt> feature are not built; the
  # README says why.
  #
  # === Examples
  #
  #   require "ferro/rfd"
  #
  #   path = Ferro::Rfd::FileDialog.new
  #     .add_filter("text", ["txt", "rs"])
  #     .set_directory("/")
  #     .pick_file
  #
  #   Ferro::Rfd::MessageDialog.new
  #     .set_title("Msg!")
  #     .set_description("Description!")
  #     .set_buttons(Ferro::Rfd::MessageButtons::OkCancel)
  #     .show # => Ferro::Rfd::MessageDialogResult::Ok
  module Rfd
    private_constant :PLATFORM, :Native

    # +value+ if it is a String (or converts to one implicitly), frozen;
    # otherwise raises +TypeError+ in Ruby's words. rfd's
    # <tt>impl Into<String></tt> arguments take Strings.
    def self.string(value) # :nodoc:
      string = String.try_convert(value)
      raise TypeError, "no implicit conversion of #{value.nil? ? 'nil' : value.class} into String" unless string

      -string
    end
    private_class_method :string

    # A binary copy of +value+, a String (or one that converts
    # implicitly), for a <tt>&[u8]</tt> argument; otherwise raises
    # +TypeError+ as #string does. The copy is never interned, so a large
    # payload is not kept for the life of the process.
    def self.bytes(value) # :nodoc:
      string = String.try_convert(value)
      raise TypeError, "no implicit conversion of #{value.nil? ? 'nil' : value.class} into String" unless string

      string.b.freeze
    end
    private_class_method :bytes

    # A filter as the native layer takes it: its name and extensions, as
    # frozen Strings. Each extension becomes a String with +to_s+, as
    # Rust's +ToString+ formats any value. A NUL byte raises
    # +ArgumentError+ in Ruby's words, since rfd's portal backend panics
    # on one (rfd <tt>src/backend/xdg_desktop_portal.rs:47-65</tt>).
    def self.filter(name, extensions) # :nodoc:
      list = Array.try_convert(extensions)
      raise TypeError, "no implicit conversion of #{extensions.class} into Array" unless list

      name = string(name)
      extensions = list.map { |extension| -extension.to_s }.freeze
      raise ArgumentError, "string contains null byte" if [name, *extensions].any? { |text| text.include?("\0") }

      [name, extensions]
    end
    private_class_method :filter
  end

  #--
  # SPDX-SnippetEnd
  #++
end
