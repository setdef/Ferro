# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "urgency"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: Hint, its variants, their documentation, and its
    #   methods from notify-rust 4.18.2 src/hints.rs:28-145
    #++

    # Extra information for the notification server: a category, a sound,
    # a position, whether the notification stays.
    #
    # The notification specification
    # (https://specifications.freedesktop.org/notification-spec/latest/hints.html)
    # standardizes many hints. Which ones a server actually implements
    # depends strongly on the server; NotifyRust.get_capabilities gives
    # some clues, but the standard mentions much more than is usually
    # available.
    #
    # Each variant is a value class that includes this module: build one
    # and pass it to Notification#hint (Linux). Invalid, the one without
    # data, is a constant. Hints compare by value, as notify-rust's derive
    # +PartialEq+ and +Hash+ do, so a notification holds each one once.
    # ImageData exists only on Linux, where notify-rust's +images+ feature
    # builds it.
    #
    # Mirrors notify-rust's +Hint+ (<tt>src/hints.rs:28-95</tt>).
    #
    # === Examples
    #
    #   Ferro::NotifyRust::Notification.new
    #     .summary("Category:email")
    #     .hint(Ferro::NotifyRust::Hint::Category.new("email"))
    #     .hint(Ferro::NotifyRust::Hint::Resident.new(true))
    #     .show
    #
    #   Ferro::NotifyRust::Hint.from_key_val("x", "12") # => #<data Ferro::NotifyRust::Hint::X value=12>
    module Hint
      # If true, the server may interpret action identifiers as named icons
      # and display those.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::ActionIcons.new(true)
      class ActionIcons < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # +true+ or +false+.
      end

      # The notification's category, such as <tt>"email"</tt>; the
      # specification lists them.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Category.new("email")
      class Category < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The category, a String.
      end

      # The name of the desktop entry representing the calling application.
      # For <tt>"firefox.desktop"</tt>, use <tt>"firefox"</tt>. The server
      # may use it to find the right icon.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::DesktopEntry.new("firefox")
      class DesktopEntry < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The entry's name, a String.
      end

      # Display the image at this path.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::ImagePath.new("/usr/share/icons/hicolor/48x48/apps/firefox.png")
      class ImagePath < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The path or URI, a String.
      end

      # Keep the notification after an action is invoked. This does not
      # work on all servers; a Timeout of Never does the job.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Resident.new(true)
      class Resident < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # +true+ or +false+.
      end

      # Play the sound at this path.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::SoundFile.new("/usr/share/sounds/freedesktop/stereo/message.oga")
      class SoundFile < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The path, a String.
      end

      # A themeable named sound from the freedesktop.org sound naming
      # specification to play when the notification pops up. Similar to an
      # icon name, but for sounds. An example would be
      # <tt>"message-new-instant"</tt>.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::SoundName.new("message-new-instant")
      class SoundName < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The sound's name, a String.
      end

      # Suppress the notification sound.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::SuppressSound.new(true)
      class SuppressSound < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # +true+ or +false+.
      end

      # When set, the server treats the notification as transient and
      # bypasses its persistence capability, if it has one.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Transient.new(true)
      class Transient < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # +true+ or +false+.
      end

      # Lets the notification point to a certain x position on the screen.
      # Requires Y.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::X.new(100)
      class X < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The position, an Integer within a 32-bit signed range.
      end

      # Lets the notification point to a certain y position on the screen.
      # Requires X.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Y.new(100)
      class Y < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The position, an Integer within a 32-bit signed range.
      end

      # The notification's Urgency: Low, Normal, or Critical.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Urgency.new(Ferro::NotifyRust::Urgency::Critical)
      class Urgency < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The urgency, an Ferro::NotifyRust::Urgency.
      end

      # A hint of your own with a text value, when you need to pass
      # something entirely different. A notification keeps one per +key+:
      # the last one set.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Custom.new("x-canonical-private-synchronous", "volume")
      class Custom < Data.define(:key, :value)
        include Hint

        ##
        # :attr_reader: key
        # The hint's name, a String.

        ##
        # :attr_reader: value
        # The hint's value, a String.
      end

      # A hint of your own with an integer value. A notification keeps one
      # per +key+: the last one set.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::CustomInt.new("value", 42)
      class CustomInt < Data.define(:key, :value)
        include Hint

        ##
        # :attr_reader: key
        # The hint's name, a String.

        ##
        # :attr_reader: value
        # The hint's value, an Integer within a 32-bit signed range.
      end

      # The hint without data.
      class Unit # :nodoc:
        include Hint

        # [name] Symbol, the notify-rust variant's name.
        def initialize(name)
          @name = name
          freeze
        end

        # The constant that holds this hint.
        def inspect
          "Ferro::NotifyRust::Hint::#{@name}"
        end

        private def to_native
          [@name]
        end
      end
      private_constant :Unit

      # Only used by notify-rust's own notification server, which it does
      # not compile.
      Invalid = Unit.new(:Invalid)

      # The hint for a name and value as text, the way a command line
      # passes them: <tt>action-icons</tt>, <tt>resident</tt>,
      # <tt>suppress-sound</tt>, and <tt>transient</tt> take
      # <tt>"true"</tt> or <tt>"false"</tt>; +x+ and +y+ take a number;
      # +category+, <tt>desktop-entry</tt>, <tt>image-path</tt>,
      # <tt>sound-file</tt>, and <tt>sound-name</tt> take any text. Raises
      # +ArgumentError+ with notify-rust's reason otherwise, such as
      # <tt>unknown name</tt>. Mirrors <tt>Hint::from_key_val</tt>
      # (<tt>src/hints.rs:128-144</tt>).
      #
      # [name] String, the hint's specification name.
      # [value] String, its value.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint.from_key_val("resident", "true") # => #<data Ferro::NotifyRust::Hint::Resident value=true>
      def self.from_key_val(name, value)
        from_native(Native.hint_from_key_val(NotifyRust.__send__(:string, name), NotifyRust.__send__(:string, value)))
      end

      # The hint the native layer's +tag+ names.
      def self.from_native(tag) # :nodoc:
        name, *values = tag
        return Invalid if name == :Invalid
        if name == :Urgency
          urgency = NotifyRust.const_get(:Urgency, false)
          return Hint::Urgency.new(urgency.__send__(:from_native, values.first))
        end

        const_get(String(name), false).new(*values.map(&:freeze))
      end
      private_class_method :from_native

      # The hint's value if it is +true+ or +false+: for ActionIcons,
      # Resident, SuppressSound, and Transient; +nil+ for the rest. Mirrors
      # <tt>Hint::as_bool</tt> (<tt>src/hints.rs:97-107</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::Resident.new(true).as_bool # => true
      def as_bool
        Native.hint_as_bool(to_native)
      end

      # The hint's value if it is an integer: for X and Y; +nil+ for the
      # rest, CustomInt included. Mirrors <tt>Hint::as_i32</tt>
      # (<tt>src/hints.rs:109-115</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::X.new(3).as_i32 # => 3
      def as_i32
        Native.hint_as_i32(to_native)
      end

      # The hint's value if it is text: for DesktopEntry, ImagePath,
      # SoundFile, and SoundName; +nil+ for the rest, Category and Custom
      # included. Mirrors <tt>Hint::as_str</tt> (<tt>src/hints.rs:117-126</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::SoundName.new("bell").as_str # => "bell"
      def as_str
        Native.hint_as_str(to_native)
      end

      # The tag the native layer takes: the variant's name, then its
      # fields, with an Urgency as its name.
      private def to_native
        name = self.class.name.split("::").last.to_sym
        # An Urgency answers its own to_native; on macOS, naming the
        # deprecated constant here would warn.
        values = __send__(:to_h).values.map { |value| value.respond_to?(:to_native, true) ? value.__send__(:to_native) : value }
        [name, *values]
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
