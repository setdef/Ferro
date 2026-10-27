# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "error"
require_relative "notification"
require_relative "notification_handle"
require_relative "urgency"

# notify-rust compiles these only for macOS (src/macos/mod.rs,
# src/notification.rs:489-505, src/error.rs:9-10).
return unless Ferro::NotifyRust.const_get(:PLATFORM) == :macos

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: the macOS API and its documentation from
    #   notify-rust 4.18.2 src/macos/nsusernotifications.rs,
    #   src/notification.rs:489-505, src/lib.rs:218-222
    #++

    # notify-rust deprecates Urgency on macOS: "Urgency is not supported
    # on macOS (NSUserNotificationCenter path)".
    deprecate_constant :Urgency

    #--
    # SPDX-SnippetEnd
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: Felix Döring <development@felixdoering.com>, Hendrik Sollich <hendrik@hoodie.de>
    # SPDX-SnippetComment: mac-notification-sys 0.6.15's errors, their
    #   documentation and Display text, src/error.rs:9-101, and its
    #   application functions, src/lib.rs:119-158
    #++

    class Error
      # The macOS notification center refused: mac-notification-sys's
      # error, inside notify-rust's. Each of its kinds is a subclass under
      # the kind of error it is, Application or Notification. Defined only
      # on macOS.
      #
      # === Example
      #
      #   begin
      #     Ferro::NotifyRust.set_application("com.apple.Safari")
      #   rescue Ferro::NotifyRust::Error::MacNotificationSys => e
      #     warn e.message
      #   end
      class MacNotificationSys < Error
        # Setting the application that sends notifications failed.
        #
        # === Example
        #
        #   rescue Ferro::NotifyRust::Error::MacNotificationSys::Application => e
        #     warn e.name
        class Application < MacNotificationSys
          # The bundle identifier that could not be set, a String.
          attr_reader :name

          # The application was already set: it can be set only once per
          # process, and sending a notification first sets the default.
          #
          # === Example
          #
          #   Ferro::NotifyRust.set_application("com.apple.Safari")
          #   Ferro::NotifyRust.set_application("com.apple.Safari")
          #   # raises Ferro::NotifyRust::Error::MacNotificationSys::Application::AlreadySet
          class AlreadySet < Application
            # Creates the error, with mac-notification-sys's message around
            # +name+.
            #
            # [name] String, the bundle identifier.
            #
            # === Example
            #
            #   Ferro::NotifyRust::Error::MacNotificationSys::Application::AlreadySet.new("a.b").message
            #   # => "Application 'a.b' can only be set once."
            def initialize(name = "")
              @name = name
              super("Application '#{name}' can only be set once.")
            end
          end

          # No application has that bundle identifier. notify-rust then
          # sends as Terminal.
          #
          # === Example
          #
          #   Ferro::NotifyRust.set_application("no.such.bundle")
          #   # raises Ferro::NotifyRust::Error::MacNotificationSys::Application::CouldNotSet
          class CouldNotSet < Application
            # Creates the error, with mac-notification-sys's message around
            # +name+.
            #
            # [name] String, the bundle identifier.
            #
            # === Example
            #
            #   Ferro::NotifyRust::Error::MacNotificationSys::Application::CouldNotSet.new("a.b").message
            #   # => "Could not set application 'a.b', using default \"com.apple.Terminal\""
            def initialize(name = "")
              @name = name
              super("Could not set application '#{name}', using default \"com.apple.Terminal\"")
            end
          end
        end

        # Delivering or scheduling a notification failed.
        #
        # === Example
        #
        #   rescue Ferro::NotifyRust::Error::MacNotificationSys::Notification => e
        #     warn e.message
        class Notification < MacNotificationSys
          # A notification cannot be scheduled in the past.
          #
          # === Example
          #
          #   Ferro::NotifyRust::Notification.new.schedule(::Time.now - 60)
          #   # raises Ferro::NotifyRust::Error::MacNotificationSys::Notification::ScheduleInThePast
          class ScheduleInThePast < Notification
            # Creates the error. Without a +message+, or with +nil+, the
            # message is mac-notification-sys's.
            #
            # [message] String, the error message.
            #
            # === Example
            #
            #   raise Ferro::NotifyRust::Error::MacNotificationSys::Notification::ScheduleInThePast
            def initialize(message = nil)
              super(message || "Can not schedule notification in the past")
            end
          end

          # Scheduling the notification failed.
          #
          # === Example
          #
          #   raise Ferro::NotifyRust::Error::MacNotificationSys::Notification::UnableToSchedule
          class UnableToSchedule < Notification
            # Creates the error. Without a +message+, or with +nil+, the
            # message is mac-notification-sys's.
            #
            # [message] String, the error message.
            #
            # === Example
            #
            #   raise Ferro::NotifyRust::Error::MacNotificationSys::Notification::UnableToSchedule
            def initialize(message = nil)
              super(message || "Could not schedule notification")
            end
          end

          # Delivering the notification failed.
          #
          # === Example
          #
          #   raise Ferro::NotifyRust::Error::MacNotificationSys::Notification::UnableToDeliver
          class UnableToDeliver < Notification
            # Creates the error. Without a +message+, or with +nil+, the
            # message is mac-notification-sys's.
            #
            # [message] String, the error message.
            #
            # === Example
            #
            #   raise Ferro::NotifyRust::Error::MacNotificationSys::Notification::UnableToDeliver
            def initialize(message = nil)
              super(message || "Could not deliver notification")
            end
          end
        end
      end
    end

    # Makes notifications come from the application with bundle identifier
    # +bundle_ident+, such as <tt>"com.apple.Safari"</tt>: its name and icon
    # show on them. macOS does not let a program set a notification's icon,
    # but it can pretend to be another app.
    #
    # It works by replacing what <tt>NSBundle.mainBundle</tt> reports as its
    # bundle identifier, once per process. The first call wins: a second
    # raises Error::MacNotificationSys::Application::AlreadySet, and so does
    # a call after the first notification, which sets the default
    # (<tt>com.apple.Finder</tt>). An identifier no installed application
    # has raises Error::MacNotificationSys::Application::CouldNotSet, and
    # notifications then come from Terminal. No other library in the
    # process may link notify-rust or mac-notification-sys, since a second
    # copy would undo this. Defined only on macOS. Mirrors
    # mac-notification-sys's +set_application+ (<tt>src/lib.rs:146-158</tt>).
    #
    # [bundle_ident] String.
    #
    # === Example
    #
    #   Ferro::NotifyRust.set_application(Ferro::NotifyRust.get_bundle_identifier_or_default("Safari"))
    def self.set_application(bundle_ident)
      Native.set_application(NotifyRust.__send__(:string, bundle_ident))
    end

    # The bundle identifier of the application named +app_name+, found by
    # AppleScript, or <tt>"com.apple.Finder"</tt> when there is none. It
    # releases Ruby's global VM lock while the script runs. Defined only on
    # macOS. Mirrors mac-notification-sys's
    # +get_bundle_identifier_or_default+ (<tt>src/lib.rs:119-123</tt>).
    #
    # [app_name] String, such as <tt>"Safari"</tt>.
    #
    # === Example
    #
    #   Ferro::NotifyRust.get_bundle_identifier_or_default("Finder") # => "com.apple.finder"
    def self.get_bundle_identifier_or_default(app_name)
      Native.get_bundle_identifier_or_default(NotifyRust.__send__(:string, app_name))
    end

    #--
    # SPDX-SnippetEnd
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: scheduling from notify-rust 4.18.2
    #   src/notification.rs:489-505 and src/macos/nsusernotifications.rs:259-275
    #++

    class Notification
      # Schedules a copy of the notification for +time+, a Ruby ::Time, read to
      # the second, and returns a NotificationHandle whose waits return at
      # once, as notify-rust's does. Raises
      # Error::MacNotificationSys::Notification::ScheduleInThePast for a
      # time in the past. Defined only on macOS. Mirrors
      # <tt>Notification::schedule</tt> (<tt>src/notification.rs:489-496</tt>),
      # which takes a chrono <tt>DateTime</tt>.
      #
      # [time] ::Time.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Stand up").schedule(::Time.now + 3600)
      def schedule(time)
        raise TypeError, "no implicit conversion of #{time.class} into Time" unless time.is_a?(::Time)

        native_schedule(time.to_i)
      end

      # Schedules a copy of the notification for +timestamp+, seconds since
      # the Unix epoch, as #schedule does. Defined only on macOS. Mirrors
      # <tt>Notification::schedule_raw</tt>
      # (<tt>src/notification.rs:498-505</tt>).
      #
      # [timestamp] Float, or another Numeric.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Stand up").schedule_raw(::Time.now.to_f + 3600)
      def schedule_raw(timestamp)
        native_schedule_raw(timestamp)
      end
    end

    class NotificationHandle
      # Replaced below: on macOS the handle's drop sends the notification.
      remove_method :release

      # Drops notify-rust's handle, which sends the notification unless a
      # wait already did (<tt>src/macos/nsusernotifications.rs:142-162</tt>).
      # The send waits up to about two seconds for the notification
      # center to confirm delivery, with Ruby's global VM lock released.
      private def release
        native_drop
        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
