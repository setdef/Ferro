# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "timeout"

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: the setters, fields, and their documentation of
    #   notify-rust 4.18.2's Notification, src/notification.rs:35-487
    #++

    # The setters and fields of notify-rust's +Notification+, which every
    # object holding one shares.
    #
    # A Notification has them. So does a NotificationHandle on Linux and
    # Windows, which reaches the notification it showed the way Rust's
    # +Deref+ and +DerefMut+ do: change it there, then call
    # NotificationHandle#update (Linux) to show the change.
    #
    # Each setter runs notify-rust's own and returns the receiver, so calls
    # chain. Called without an argument, a method that has a field of the
    # same name returns the field, which notify-rust stores as the setter
    # left it. A frozen notification raises +FrozenError+ from every setter.
    #
    # === Example
    #
    #   notification = Ferro::NotifyRust::Notification.new.summary("Hi").body("there")
    #   notification.summary # => "Hi"
    #   notification.body = "everyone"
    module Builder
      # Stands for "no argument", so +nil+ can still reach a setter that
      # refuses it.
      NONE = Object.new.freeze
      private_constant :NONE

      # Without +appname+, the field: the name of the current executable
      # until you set another. With it, sets the field. Some desktops use it
      # to group notifications.
      #
      # On macOS this does nothing; use NotifyRust.set_application there.
      # Mirrors <tt>Notification::appname</tt>
      # (<tt>src/notification.rs:141-148</tt>).
      #
      # [appname] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.appname("thunderbird").appname # => "thunderbird"
      def appname(appname = NONE)
        return __send__(:native_field, :appname) if NONE.equal?(appname)

        __send__(:native_appname, appname)
        self
      end

      # Assigns the +appname+ field, as Rust code may.
      #
      # === Example
      #
      #   notification.appname = "thunderbird"
      def appname=(appname)
        __send__(:native_set_field, :appname, appname)
      end

      # Without +summary+, the field. With it, sets the summary: a single
      # line that often acts as the notification's title. Put more in the
      # body. Mirrors <tt>Notification::summary</tt>
      # (<tt>src/notification.rs:150-156</tt>).
      #
      # [summary] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Firefox News")
      def summary(summary = NONE)
        return __send__(:native_field, :summary) if NONE.equal?(summary)

        __send__(:native_summary, summary)
        self
      end

      # Assigns the +summary+ field.
      #
      # === Example
      #
      #   notification.summary = "Firefox News"
      def summary=(summary)
        __send__(:native_set_field, :summary, summary)
      end

      # Without +subtitle+, the field: +nil+ until set. With it, sets the
      # subtitle, which only macOS and Windows show; it is not part of the
      # XDG specification. Mirrors <tt>Notification::subtitle</tt>
      # (<tt>src/notification.rs:158-164</tt>).
      #
      # [subtitle] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Build").subtitle("main")
      def subtitle(subtitle = NONE)
        return __send__(:native_field, :subtitle) if NONE.equal?(subtitle)

        __send__(:native_subtitle, subtitle)
        self
      end

      # Assigns the +subtitle+ field: a String, or +nil+ for none.
      #
      # === Example
      #
      #   notification.subtitle = nil
      def subtitle=(subtitle)
        __send__(:native_set_field, :subtitle, subtitle)
      end

      # Without +body+, the field. With it, sets the body: the
      # notification's text, where each line is a paragraph. Simple HTML
      # markup should work, depending on the server; check
      # NotifyRust.get_capabilities for <tt>body-markup</tt> and
      # <tt>body-hyperlinks</tt>. Mirrors <tt>Notification::body</tt>
      # (<tt>src/notification.rs:241-249</tt>).
      #
      # [body] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.body("your <b>body</b> is a <u>wonderland</u>")
      def body(body = NONE)
        return __send__(:native_field, :body) if NONE.equal?(body)

        __send__(:native_body, body)
        self
      end

      # Assigns the +body+ field.
      #
      # === Example
      #
      #   notification.body = "Done."
      def body=(body)
        __send__(:native_set_field, :body, body)
      end

      # Without +icon+, the field. With it, sets the icon: a name from the
      # icon theme, usually those in <tt>/usr/share/icons</tt>, or an
      # absolute path to a file. A <tt>file://</tt> URI works too.
      #
      # macOS does not let you set the icon; you can pretend to be another
      # app with NotifyRust.set_application. Mirrors
      # <tt>Notification::icon</tt> (<tt>src/notification.rs:251-262</tt>).
      #
      # [icon] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.icon("dialog-information")
      def icon(icon = NONE)
        return __send__(:native_field, :icon) if NONE.equal?(icon)

        __send__(:native_icon, icon)
        self
      end

      # Assigns the +icon+ field.
      #
      # === Example
      #
      #   notification.icon = "firefox"
      def icon=(icon)
        __send__(:native_set_field, :icon, icon)
      end

      # Sets the icon to the executable's name, which for a Ruby program
      # is the Ruby interpreter's: <tt>ruby</tt>. macOS ignores the icon.
      # Mirrors <tt>Notification::auto_icon</tt>
      # (<tt>src/notification.rs:264-273</tt>).
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.auto_icon.icon # => "ruby"
      def auto_icon
        __send__(:native_auto_icon)
        self
      end

      # Sets the image's path, which goes straight to the platform: the
      # <tt>image-path</tt> hint on Linux, the content image on the right
      # of a macOS banner, the toast's image on Windows. Mirrors
      # <tt>Notification::image_path</tt>
      # (<tt>src/notification.rs:173-193</tt>).
      #
      # [path] String, a path or, on Linux, a <tt>file://</tt> URI.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.image_path("/tmp/chart.png")
      def image_path(path)
        __send__(:native_image_path, path)
        self
      end

      # Sets the sound to play: on Linux the <tt>sound-name</tt> hint, a
      # name from the freedesktop.org sound theme; on macOS an
      # +NSUserNotification+ sound name (<tt>"Ping"</tt>, or
      # <tt>"NSUserNotificationDefaultSoundName"</tt>); on Windows a toast
      # sound name such as <tt>"Mail"</tt>. Mirrors
      # <tt>Notification::sound_name</tt>
      # (<tt>src/notification.rs:213-225</tt>).
      #
      # [name] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.sound_name("message-new-instant")
      def sound_name(name)
        __send__(:native_sound_name, name)
        self
      end

      # Without +timeout+, the field, a Timeout. With it, sets how long the
      # notification lasts, often not respected by the server: a Timeout,
      # or an Integer of milliseconds read as Timeout.from reads it, where
      # -1 leaves it to the server and 0 means never expire. macOS ignores
      # it. Mirrors <tt>Notification::timeout</tt>
      # (<tt>src/notification.rs:325-364</tt>).
      #
      # [timeout] Timeout, or Integer milliseconds.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.timeout(6000).timeout
      #   # => #<data Ferro::NotifyRust::Timeout::Milliseconds value=6000>
      def timeout(timeout = NONE)
        return Timeout.__send__(:from_native, __send__(:native_field, :timeout)) if NONE.equal?(timeout)

        timeout = Timeout.from(timeout) if timeout.is_a?(Integer)
        __send__(:native_timeout, timeout_tag(timeout))
        self
      end

      # Assigns the +timeout+ field, a Timeout.
      #
      # === Example
      #
      #   notification.timeout = Ferro::NotifyRust::Timeout::Never
      def timeout=(timeout)
        __send__(:native_set_field, :timeout, timeout_tag(timeout))
      end

      # Without +actions+, the field: the actions as a flat Array of
      # identifier, label, identifier, label. With it, replaces them all.
      #
      # Deprecated in notify-rust: "please use .action() only". Setting
      # them warns when <tt>Warning[:deprecated]</tt> is on. Mirrors
      # <tt>Notification::actions</tt> (<tt>src/notification.rs:432-446</tt>).
      #
      # [actions] Array of String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.action("ok", "OK").actions # => ["ok", "OK"]
      def actions(actions = NONE)
        return __send__(:native_field, :actions) if NONE.equal?(actions)

        warn("Ferro::NotifyRust::Notification#actions is deprecated: please use .action() only",
          category: :deprecated, uplevel: 1)
        __send__(:native_actions, actions)
        self
      end

      # Assigns the +actions+ field, a flat Array of identifier, label,
      # identifier, label.
      #
      # === Example
      #
      #   notification.actions = ["ok", "OK"]
      def actions=(actions)
        __send__(:native_set_field, :actions, actions)
      end

      # Adds an action: an +identifier+ your program reads back, and the
      # +label+ the user sees. The identifier <tt>"default"</tt> is the
      # action of clicking the notification itself. Mirrors
      # <tt>Notification::action</tt> (<tt>src/notification.rs:448-455</tt>).
      #
      # [identifier] String.
      # [label] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.action("clicked_a", "button a")
      def action(identifier, label)
        __send__(:native_action, identifier, label)
        self
      end

      # Sets an id ahead of time, so the notification replaces the one the
      # server knows by that id. NotificationHandle#update is the easier way
      # to change a notification you showed. On macOS notify-rust ignores
      # it. Mirrors <tt>Notification::id</tt>
      # (<tt>src/notification.rs:457-468</tt>).
      #
      # [id] Integer from 0 to <tt>2**32 - 1</tt>.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Volume 40%").id(42).show
      def id(id)
        __send__(:native_id, id)
        self
      end

      # A copy of the notification, a new Notification. Mirrors
      # <tt>Notification::finalize</tt>
      # (<tt>src/notification.rs:482-487</tt>).
      #
      # === Example
      #
      #   template = Ferro::NotifyRust::Notification.new.appname("backup")
      #   done = template.finalize.summary("Backup finished")
      def finalize
        __send__(:native_finalize)
      end

      # Shows a copy of the notification and returns its NotificationHandle,
      # or, given a block, yields the handle and returns the block's value.
      #
      # On Linux it sends the notification to the server over D-Bus, and on
      # Windows shows a toast, before it returns. On macOS notify-rust sends
      # when the handle drops, or when one of its waits sends and waits
      # first; Ruby has no point where a handle drops, so without a block
      # +show+ sends at once, and with one it sends when the block ends,
      # unless a wait inside it already did.
      #
      # Showing releases Ruby's global VM lock. On Linux an interrupt
      # (Ctrl-C, <tt>Thread#raise</tt>, +Timeout+) ends the wait for the
      # server; elsewhere it takes effect once the call returns. Raises
      # Error (on Linux, Error::Zbus without a session bus or server).
      # Mirrors <tt>Notification::show</tt>
      # (<tt>src/notification.rs:507-554</tt>).
      #
      # === Examples
      #
      #   handle = Ferro::NotifyRust::Notification.new.summary("Done").show
      #
      #   Ferro::NotifyRust::Notification.new.summary("click me").action("default", "default").show do |handle|
      #     handle.wait_for_action { |action| puts action }
      #   end
      def show
        handle = __send__(:native_show)
        return handle.__send__(:release) unless block_given?

        begin
          yield handle
        ensure
          handle.__send__(:release)
        end
      end

      # The tag the native layer takes for +timeout+, a Timeout.
      private def timeout_tag(timeout)
        raise TypeError, "no implicit conversion of #{timeout.class} into Ferro::NotifyRust::Timeout" unless timeout.is_a?(Timeout)

        (_ = timeout).__send__(:to_native)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
