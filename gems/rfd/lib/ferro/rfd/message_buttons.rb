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
    # SPDX-SnippetComment: MessageButtons and set_buttons' docs from rfd 0.17.2
    #   src/message_dialog.rs:56-65, 161-177
    #++

    # The buttons a message dialog offers.
    #
    # A message either informs ("OK") or asks ("Yes", "No", "Cancel"), and
    # the buttons tell the user which. Labels in the user's language come
    # from the system, and an app sometimes wants its own words instead:
    # "Save", "Don't Save".
    #
    # The four constants are the standard sets. The three classes below
    # carry labels of your own. Every one of them is a MessageButtons, as
    # every variant of a Rust enum has the enum's type. Pass any to
    # MessageDialog#set_buttons:
    #
    # - Ok: a single OK button. The default.
    # - OkCancel: OK and Cancel.
    # - YesNo: Yes and No.
    # - YesNoCancel: Yes, No, and Cancel.
    # - OkCustom: one button labelled as you say.
    # - OkCancelCustom: two buttons labelled as you say.
    # - YesNoCancelCustom: three buttons labelled as you say.
    #
    # On Windows, custom labels need rfd's <tt>common-controls-v6</tt>
    # feature, which ferro-rfd does not build: ruby.exe has no application
    # manifest that loads the controls it needs. There, the custom sets
    # show OK, OK and Cancel, or Yes, No, and Cancel, and MessageDialog#show
    # returns MessageDialogResult::Ok, Cancel, Yes, or No for them.
    #
    # Mirrors rfd's +MessageButtons+ (<tt>src/message_dialog.rs:161-177</tt>).
    #
    # === Examples
    #
    #   Ferro::Rfd::MessageDialog.new
    #     .set_description("Delete the file?")
    #     .set_buttons(Ferro::Rfd::MessageButtons::YesNo)
    #     .show
    #
    #   labels = Ferro::Rfd::MessageButtons::OkCancelCustom.new("Save", "Don't Save")
    #   Ferro::Rfd::MessageDialog.new.set_buttons(labels).show
    #   # => Ferro::Rfd::MessageDialogResult::Custom.new("Save") when the user saves
    module MessageButtons
      # A standard set: the class of the four constants. Private to the
      # gem; the four constants are its only instances.
      class Value # :nodoc:
        include MessageButtons

        private_class_method :new

        # Creates the set named +name+.
        #
        # [name] Symbol, the rfd variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        # The constant that holds this set.
        #
        # === Example
        #
        #   Ferro::Rfd::MessageButtons::YesNo.inspect # => "Ferro::Rfd::MessageButtons::YesNo"
        def inspect
          "Ferro::Rfd::MessageButtons::#{@name}"
        end

        # The variant's name, which the native layer takes.
        private attr_reader :name
      end
      private_constant :Value

      # A single OK button: the default.
      Ok = Value.__send__(:new, :Ok)

      # OK and Cancel.
      OkCancel = Value.__send__(:new, :OkCancel)

      # Yes and No.
      YesNo = Value.__send__(:new, :YesNo)

      # Yes, No, and Cancel.
      YesNoCancel = Value.__send__(:new, :YesNoCancel)

      # One button labelled +ok_text+.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageButtons::OkCustom.new("Got it")
      class OkCustom < Data.define(:ok_text)
        include MessageButtons

        ##
        # :attr_reader: ok_text
        # The button's label, a String.
      end

      # Two buttons, labelled +ok_text+ and +cancel_text+.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageButtons::OkCancelCustom.new("Save", "Don't Save")
      class OkCancelCustom < Data.define(:ok_text, :cancel_text)
        include MessageButtons

        ##
        # :attr_reader: ok_text
        # The first button's label, a String.

        ##
        # :attr_reader: cancel_text
        # The second button's label, a String.
      end

      # Three buttons, labelled +yes_text+, +no_text+, and +cancel_text+.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageButtons::YesNoCancelCustom.new("Save", "Discard", "Keep Editing")
      class YesNoCancelCustom < Data.define(:yes_text, :no_text, :cancel_text)
        include MessageButtons

        ##
        # :attr_reader: yes_text
        # The first button's label, a String.

        ##
        # :attr_reader: no_text
        # The second button's label, a String.

        ##
        # :attr_reader: cancel_text
        # The third button's label, a String.
      end

      # The set a dialog has until you choose one: Ok. Mirrors rfd's derived
      # +Default+.
      #
      # === Example
      #
      #   Ferro::Rfd::MessageButtons.default # => Ferro::Rfd::MessageButtons::Ok
      def self.default
        Ok
      end

      # The tagged Array the native layer takes for +buttons+:
      # <tt>[:Ok]</tt>, or the variant and its labels. The variant is the
      # class matched, so a subclass is the variant it inherits. Anything
      # else, a stranger that includes this module among them, raises
      # +TypeError+, as Rust's type checker would refuse it.
      def self.variant(buttons) # :nodoc:
        case buttons
        when Value then [buttons.__send__(:name)]
        when OkCustom then [:OkCustom, *labels(buttons)]
        when OkCancelCustom then [:OkCancelCustom, *labels(buttons)]
        when YesNoCancelCustom then [:YesNoCancelCustom, *labels(buttons)]
        else raise TypeError, "wrong argument type #{buttons.class} (expected #{self})"
        end
      end
      private_class_method :variant

      # A custom set's labels, each refused unless it is a String.
      def self.labels(buttons) # :nodoc:
        buttons.deconstruct.map { |text| Rfd.__send__(:string, text) }
      end
      private_class_method :labels
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
