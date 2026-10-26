# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

module Ferro
  module Rfd
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT
    # SPDX-SnippetCopyrightText: 2022 Bartłomiej Maryńczak
    # SPDX-SnippetComment: MessageLevel and set_level's docs from rfd 0.17.2
    #   src/message_dialog.rs:33-40, 153-159
    #++

    # How serious a message is.
    #
    # A message box that says "Saved" and one that says "Your disk is
    # full" should not look alike. Each system marks the difference with
    # an icon, and some with a sound.
    #
    # These three values name the levels rfd offers. Pass one to
    # MessageDialog#set_level; depending on the system, the dialog shows an
    # icon for information, a warning, or an error. Without one, a dialog
    # is Info.
    #
    # Mirrors rfd's +MessageLevel+ (<tt>src/message_dialog.rs:153-159</tt>).
    #
    # === Examples
    #
    #   Ferro::Rfd::MessageDialog.new
    #     .set_level(Ferro::Rfd::MessageLevel::Warning)
    #     .set_description("The file changed on disk.")
    #     .show
    #
    #   Ferro::Rfd::MessageLevel.default # => Ferro::Rfd::MessageLevel::Info
    class MessageLevel
      private_class_method :new

      # Creates the level named +name+. The three constants are the only
      # instances.
      #
      # [name] Symbol, the rfd variant's name.
      def initialize(name)
        @name = name
        freeze
      end

      # The constant that holds this level.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageLevel::Error.inspect # => "Ferro::Rfd::MessageLevel::Error"
      def inspect
        "#{self.class}::#{@name}"
      end

      # Information: the default.
      Info = new(:Info)

      # A warning.
      Warning = new(:Warning)

      # An error.
      Error = new(:Error)

      # The level a dialog has until you set one: Info. Mirrors rfd's
      # derived +Default+.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageLevel.default # => Ferro::Rfd::MessageLevel::Info
      def self.default
        Info
      end

      # The variant name the native layer takes for +level+, if it is a
      # MessageLevel; otherwise raises +TypeError+ as Ruby does for a wrong
      # argument type. rfd's enum has no such method, so it stays private.
      def self.variant(level) # :nodoc:
        case level
        when MessageLevel then level.instance_variable_get(:@name)
        else raise TypeError, "wrong argument type #{level.class} (expected #{self})"
        end
      end
      private_class_method :variant
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
