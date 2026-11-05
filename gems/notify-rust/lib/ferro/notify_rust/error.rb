# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: Error, ErrorKind, and their Display text from
    #   notify-rust 4.18.2 src/error.rs:15-78
    #++

    # Showing a notification, or talking to the notification server,
    # failed.
    #
    # A notification passes through a lot on its way to the screen: a
    # D-Bus session bus and a notification server on Linux, the
    # notification center on macOS, the toast system on Windows. Any of
    # them can be missing or refuse, and a single "it failed" would leave
    # you guessing which.
    #
    # Each kind of notify-rust's error is a subclass, named for its
    # +ErrorKind+ variant, with notify-rust's message. Rescue the one you
    # can handle, or this class for all of them. Some exist only on one
    # platform: Error::Zbus and Error::Image on Linux,
    # Error::MacNotificationSys on macOS.
    #
    # A kind a later notify-rust adds raises this class itself, with
    # notify-rust's message, until ferro-notify-rust names it. So does a
    # panic inside notify-rust, with the message
    # <tt>notify-rust panicked: ...</tt>, which would otherwise end the
    # Ruby process.
    #
    # #debug answers the +Debug+ text of the error notify-rust returned,
    # which Rust formatted when it raised; +inspect+ stays Ruby's.
    #
    # Mirrors notify-rust's <tt>error::Error</tt> and +ErrorKind+
    # (<tt>src/error.rs:15-78</tt>).
    #
    # === Examples
    #
    #   begin
    #     Ferro::NotifyRust::Notification.new.summary("Hi").show
    #   rescue Ferro::NotifyRust::Error => e
    #     warn "No notification: #{e.message}"
    #   end
    #
    #   begin
    #     Ferro::NotifyRust::Urgency.try_from("urgent")
    #   rescue Ferro::NotifyRust::Error::Conversion => e
    #     e.message # => "Conversion Error: invalid input \"urgent\""
    #   end
    class Error < StandardError
      # The +Debug+ text of the Rust error this exception was raised for,
      # formatted by Rust: notify-rust's <tt>Error { kind: ... }</tt>, or,
      # from NotifyRust.set_application, mac-notification-sys's own error.
      # +nil+ when there is no such value: for a panic, and for most
      # exceptions Ruby code makes, though a subclass whose variant holds
      # only text builds the value notify-rust would. Mirrors
      # notify-rust's <tt>#[derive(Debug)]</tt> on +Error+ and +ErrorKind+
      # (<tt>src/error.rs:15-16</tt>, <tt>:21-22</tt>).
      #
      # === Example
      #
      #   begin
      #     Ferro::NotifyRust::Urgency.try_from("urgent")
      #   rescue Ferro::NotifyRust::Error => e
      #     e.debug # => "Error { kind: Conversion(\"invalid input \\\"urgent\\\"\") }"
      #   end
      def debug
        @debug
      end

      # A message notify-rust passes along as text, such as
      # <tt>invalid subpath</tt> for a bad sub-bus, or, on Windows, why a
      # toast could not show. notify-rust keeps it "only for backwards
      # compatibility".
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.show_async_at_bus("1").value
      #   # raises Ferro::NotifyRust::Error::Msg, "invalid subpath"
      class Msg < Error
        # notify-rust's +Debug+ text for the error, which Rust formats from
        # the message where Ruby code made the exception.
        #
        # === Example
        #
        #   Ferro::NotifyRust::Error::Msg.new("invalid subpath").debug
        #   # => "Error { kind: Msg(\"invalid subpath\") }"
        def debug
          @debug || Native.error_debug(:Msg, message)
        end
      end

      # A number did not parse. The message is
      # <tt>Parsing Error: </tt> and Rust's reason.
      #
      # === Example
      #
      #   rescue Ferro::NotifyRust::Error::Parse => e
      #     warn e.message # => "Parsing Error: invalid digit found in string"
      class Parse < Error
      end

      # The notification server reported a specification version
      # notify-rust could not read.
      #
      # === Example
      #
      #   rescue Ferro::NotifyRust::Error::SpecVersion => e
      #     warn "odd server version: #{e.message}"
      class SpecVersion < Error
        # notify-rust's +Debug+ text for the error, which Rust formats from
        # the message where Ruby code made the exception.
        #
        # === Example
        #
        #   Ferro::NotifyRust::Error::SpecVersion.new("0.9").debug # => "Error { kind: SpecVersion(\"0.9\") }"
        def debug
          @debug || Native.error_debug(:SpecVersion, message)
        end
      end

      # A value could not be converted, such as an urgency name
      # Urgency.try_from does not know. The message is
      # <tt>Conversion Error: </tt> and the reason.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Urgency.try_from("urgent")
      #   # raises Ferro::NotifyRust::Error::Conversion, "Conversion Error: invalid input \"urgent\""
      class Conversion < Error
        # Creates the error, with notify-rust's message around +conversion+,
        # as <tt>ErrorKind::Conversion</tt> holds the reason and its
        # +Display+ adds the prefix.
        #
        # [conversion] String, why the value could not be converted.
        #
        # === Example
        #
        #   Ferro::NotifyRust::Error::Conversion.new("invalid input \"x\"").message
        #   # => "Conversion Error: invalid input \"x\""
        def initialize(conversion = "")
          @conversion = conversion.to_s
          super("Conversion Error: #{@conversion}")
        end

        # notify-rust's +Debug+ text for the error, which Rust formats from
        # the reason where Ruby code made the exception.
        #
        # === Example
        #
        #   Ferro::NotifyRust::Error::Conversion.new("x").debug # => "Error { kind: Conversion(\"x\") }"
        def debug
          @debug || Native.error_debug(:Conversion, @conversion)
        end
      end

      # No D-Bus implementation was compiled in. ferro-notify-rust always
      # builds zbus, so this does not happen; the class exists because
      # notify-rust's +ErrorKind+ has the variant.
      #
      # === Example
      #
      #   raise Ferro::NotifyRust::Error::ImplementationMissing
      class ImplementationMissing < Error
        # Creates the error. Without a +message+, or with +nil+, the
        # message is notify-rust's.
        #
        # [message] String, the error message.
        #
        # === Example
        #
        #   Ferro::NotifyRust::Error::ImplementationMissing.new.message
        #   # => "No Dbus implementation available, please compile with either feature =\"z\" or feature=\"d\""
        def initialize(message = nil)
          super(message || 'No Dbus implementation available, please compile with either feature ="z" or feature="d"')
        end

        # notify-rust's +Debug+ text for the error.
        #
        # === Example
        #
        #   Ferro::NotifyRust::Error::ImplementationMissing.new.debug # => "Error { kind: ImplementationMissing }"
        def debug
          @debug || Native.error_debug(:ImplementationMissing, nil)
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
