# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

require_relative "ferro_rfd"

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
    # MessageDialog#show returns a MessageDialogResult, and an
    # AsyncMessageDialog's Future#value does too. The four constants are
    # the standard buttons.
    # A dialog with labels of your own (MessageButtons::OkCustom and the
    # like) returns Custom with the label of the button pressed. A dialog
    # closed without a button, or one that could not open, returns Cancel,
    # the default.
    #
    # Every result, Custom included, is a MessageDialogResult, as every
    # variant of a Rust enum has the enum's type. Results compare with
    # <tt>==</tt>, as rfd's derived +PartialEq+ does: by variant, and
    # Custom by its label too, so a copy made with +dup+, +clone+, or
    # +Marshal+ equals its original, as rfd's +Clone+ does.
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
    module MessageDialogResult
      # A standard result: the class of the four constants. Private to the
      # gem; the four constants are its only instances, and their copies.
      class Value # :nodoc:
        include MessageDialogResult

        private_class_method :new

        # Creates the result named +name+.
        #
        # [name] Symbol, the rfd variant's name.
        def initialize(name)
          @name = name
          freeze
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

        # Whether +other+ is the same result, as rfd's derived +PartialEq+
        # compares: by variant, so a copy equals its original.
        #
        # [other] Object.
        #
        # === Example
        #
        #   Ferro::Rfd::MessageDialogResult::Ok == Ferro::Rfd::MessageDialogResult::Ok.dup # => true
        def ==(other)
          other.instance_of?(Value) && to_s == other.to_s
        end
        alias eql? ==

        # A hash code that agrees with #eql?, so equal results are one
        # Hash key. rfd derives no +Hash+; Ruby needs one consistent with
        # #eql?.
        #
        # === Example
        #
        #   {Ferro::Rfd::MessageDialogResult::Ok => 1}[Ferro::Rfd::MessageDialogResult::Ok.dup] # => 1
        def hash
          [Value, @name].hash
        end
      end
      private_constant :Value

      # The user pressed Yes.
      Yes = Value.__send__(:new, :Yes)

      # The user pressed No.
      No = Value.__send__(:new, :No)

      # The user pressed OK.
      Ok = Value.__send__(:new, :Ok)

      # The user pressed Cancel, or closed the dialog without a button, or
      # it could not open. The default.
      Cancel = Value.__send__(:new, :Cancel)

      # The user pressed the button labelled +custom+, one of the labels
      # you gave MessageButtons::OkCustom, OkCancelCustom, or
      # YesNoCancelCustom.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialogResult::Custom.new("Save").to_s # => "Custom(Save)"
      class Custom < Data.define(:custom)
        include MessageDialogResult

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

      # rfd's derived +Debug+ text for this result, formatted by Rust: the
      # variant's name, or <tt>Custom("Save")</tt> with the label as Rust
      # quotes it. +inspect+ stays Ruby's.
      #
      # Mirrors rfd's derived +Debug+ (<tt>src/message_dialog.rs:179</tt>).
      #
      # === Example
      #
      #   Ferro::Rfd::MessageDialogResult::Yes.debug # => "Yes"
      #   Ferro::Rfd::MessageDialogResult::Custom.new("Save").debug # => "Custom(\"Save\")"
      def debug
        Native.message_dialog_result_debug(MessageDialogResult.__send__(:to_native, self))
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

      # The tagged Array the native layer takes for +result+:
      # <tt>[:Yes]</tt>, or <tt>[:Custom, label]</tt>.
      def self.to_native(result) # :nodoc:
        case result
        when Custom then [:Custom, Rfd.__send__(:string, result.custom)]
        else [result.to_s.to_sym]
        end
      end
      private_class_method :to_native

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
