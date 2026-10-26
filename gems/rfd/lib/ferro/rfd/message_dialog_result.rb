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
    # SPDX-SnippetComment: MessageDialogResult and its Display from rfd 0.17.2
    #   src/message_dialog.rs:179-203
    #++

    # The button the user pressed to close a message dialog.
    #
    # A question is only useful if you learn the answer. Each system
    # reports it differently, and a dialog closed with the Escape key or
    # its close box reports no button at all.
    #
    # MessageDialog#show returns one of these, and an AsyncMessageDialog's
    # Future#value does too. The four constants are the standard buttons.
    # A dialog with labels of your own (MessageButtons::OkCustom and the
    # like) returns Custom with the label of the button pressed. A dialog
    # closed without a button, or one that could not open, returns Cancel,
    # the default.
    #
    # Results compare with <tt>==</tt>, as rfd's derive +PartialEq+ does:
    # the constants by identity, Custom by its label.
    #
    # Mirrors rfd's +MessageDialogResult+ (<tt>src/message_dialog.rs:179-203</tt>).
    #
    # === Examples
    #
    #   case Ferro::Rfd::MessageDialog.new.set_buttons(Ferro::Rfd::MessageButtons::YesNo).show
    #   when Ferro::Rfd::MessageDialogResult::Yes then delete_file
    #   else keep_file
    #   end
    #
    #   result = Ferro::Rfd::MessageDialog.new
    #     .set_buttons(Ferro::Rfd::MessageButtons::OkCancelCustom.new("Save", "Discard"))
    #     .show
    #   save if result == Ferro::Rfd::MessageDialogResult::Custom.new("Save")
    #   result.to_s # => "Custom(Save)"
    class MessageDialogResult
      private_class_method :new

      # Creates the result named +name+. The four constants are the only
      # instances.
      #
      # [name] Symbol, the rfd variant's name.
      def initialize(name)
        @name = name
        freeze
      end

      # The constant that holds this result.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialogResult::Yes.inspect # => "Ferro::Rfd::MessageDialogResult::Yes"
      def inspect
        "#{self.class}::#{@name}"
      end

      # The result's name, as rfd displays it: <tt>"Yes"</tt>,
      # <tt>"No"</tt>, <tt>"Ok"</tt>, or <tt>"Cancel"</tt>. Mirrors rfd's
      # +Display+ (<tt>src/message_dialog.rs:189-203</tt>).
      #
      # === Example
      #
      #   puts "res: #{Ferro::Rfd::MessageDialogResult::Ok}" # prints "res: Ok"
      def to_s
        @name.to_s
      end

      # The user pressed Yes.
      Yes = new(:Yes)

      # The user pressed No.
      No = new(:No)

      # The user pressed OK.
      Ok = new(:Ok)

      # The user pressed Cancel, or closed the dialog without a button, or
      # it could not open. The default.
      Cancel = new(:Cancel)

      # The user pressed the button labelled +custom+, one of the labels
      # you gave MessageButtons::OkCustom, OkCancelCustom, or
      # YesNoCancelCustom.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialogResult::Custom.new("Save").to_s # => "Custom(Save)"
      class Custom < Data.define(:custom)
        ##
        # :attr_reader: custom
        # The label of the button pressed, a String.

        # The result as rfd displays it: <tt>Custom(label)</tt>.
        #
        # === Example
        #
        #   Ferro::Rfd::MessageDialogResult::Custom.new("Save").to_s # => "Custom(Save)"
        def to_s
          "Custom(#{custom})"
        end
      end

      # The result rfd uses when a dialog reports none: Cancel. Mirrors
      # rfd's derived +Default+.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialogResult.default # => Ferro::Rfd::MessageDialogResult::Cancel
      def self.default
        Cancel
      end

      # The result the native layer's <tt>[:Yes]</tt> or
      # <tt>[:Custom, label]</tt> names.
      def self.from_native(tuple) # :nodoc:
        name, custom = tuple
        custom ? Custom.new(String(custom)) : const_get(name.to_s, false)
      end
      private_class_method :from_native
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
