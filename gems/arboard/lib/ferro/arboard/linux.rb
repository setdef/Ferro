# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_arboard"
require_relative "get"
require_relative "set"
require_relative "clear"

# arboard compiles these only for X11 and Wayland systems (src/lib.rs:24-28),
# and the native extension reports which platform it was built for.
return unless Ferro::Arboard.const_get(:PLATFORM) == :linux

module Ferro
  module Arboard
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: Apache-2.0 OR MIT
    # SPDX-SnippetCopyrightText: 2022 The Arboard contributors
    # SPDX-SnippetComment: LinuxClipboardKind, GetExtLinux, SetExtLinux, and
    #   ClearExtLinux and their docs from arboard 3.7.0
    #   src/platform/linux/mod.rs:95-122, 197-211, 307-408, 432-459
    #++

    # One of Linux's clipboard selections.
    #
    # Linux has several clipboards, called selections, and programs use
    # them in different places. Ctrl+C and Ctrl+V go through one; selecting
    # text with the mouse and pasting with the middle button go through
    # another. Reading or writing the wrong one surprises the user.
    #
    # These three values name them. Pass one to GetExtLinux#clipboard,
    # SetExtLinux#clipboard, or ClearExtLinux#clipboard. Without one,
    # operations use Clipboard.
    #
    # See https://specifications.freedesktop.org/clipboards-spec/clipboards-0.1.txt
    # for how the selections differ.
    #
    # Defined only on Linux and the other systems arboard serves through
    # X11 or Wayland. Mirrors arboard's +LinuxClipboardKind+
    # (<tt>src/platform/linux/mod.rs:95-122</tt>).
    #
    # === Examples
    #
    #   kind = Ferro::Arboard::LinuxClipboardKind::Primary
    #   Ferro::Arboard::Clipboard.new.set.clipboard(kind).text("middle-click me")
    #
    #   Ferro::Arboard::Clipboard.new.get.clipboard(Ferro::Arboard::LinuxClipboardKind::Clipboard).text
    class LinuxClipboardKind
      private_class_method :new

      # Creates the selection named +name+. The three constants are the
      # only instances.
      #
      # [name] Symbol, the arboard variant's name.
      def initialize(name)
        @name = name
        freeze
      end

      # The constant that holds this selection.
      #
      # === Example
      #
      #   Ferro::Arboard::LinuxClipboardKind::Primary.inspect
      #   # => "Ferro::Arboard::LinuxClipboardKind::Primary"
      def inspect
        "#{self.class}::#{@name}"
      end

      # The selection explicit cut, copy, and paste use, as on Windows and
      # macOS.
      Clipboard = new(:Clipboard)

      # The selection that holds the current mouse selection, pasted with
      # the middle mouse button.
      #
      # Wayland compositors offer it only from version 2 of the protocol;
      # on older ones, operations on it raise Error::ClipboardNotSupported.
      Primary = new(:Primary)

      # A selection rarely used, but available on X11.
      #
      # Wayland lacks it, so operations on it there raise
      # Error::ClipboardNotSupported.
      Secondary = new(:Secondary)

      # The variant name the native layer takes for +selection+, if it is a
      # LinuxClipboardKind; otherwise raises +TypeError+ as Ruby does for a
      # wrong argument type. arboard's enum has no such method, so it stays
      # private.
      def self.variant(selection) # :nodoc:
        case selection
        when LinuxClipboardKind then selection.instance_variable_get(:@name)
        else raise TypeError, "wrong argument type #{selection.class} (expected #{self})"
        end
      end
      private_class_method :variant
    end

    # Linux options for a Get.
    #
    # Get is the same on every platform, but only Linux has more than one
    # selection to read from. This module adds the choice to Get on Linux
    # alone, so <tt>respond_to?(:clipboard)</tt> tells you whether you
    # have it.
    #
    # Mirrors arboard's +GetExtLinux+
    # (<tt>src/platform/linux/mod.rs:197-211</tt>).
    #
    # === Example
    #
    #   clipboard.get.clipboard(Ferro::Arboard::LinuxClipboardKind::Primary).text
    module GetExtLinux
      # Reads from +selection+, a LinuxClipboardKind, instead of the
      # default. Returns the Get.
      #
      # With Wayland support available, reading the Secondary selection
      # raises Error::ClipboardNotSupported.
      #
      # === Example
      #
      #   clipboard.get.clipboard(Ferro::Arboard::LinuxClipboardKind::Secondary).text
      def clipboard(selection)
        @selection = LinuxClipboardKind.__send__(:variant, selection)
        self
      end
    end

    # Linux options for a Set.
    #
    # On Linux, under X11 and Wayland alike, the program that last set the
    # clipboard owns its contents and answers every other program that
    # asks for them. A short-lived program that copies and exits takes the
    # contents with it, and you may need to pick a selection or keep the
    # data out of clipboard managers too.
    #
    # This module adds those options to Set on Linux alone. Each returns
    # the Set for chaining.
    #
    # Mirrors arboard's +SetExtLinux+
    # (<tt>src/platform/linux/mod.rs:307-408</tt>).
    #
    # === Examples
    #
    #   clipboard.set.wait.text("stays until someone copies over it")
    #   clipboard.set.clipboard(Ferro::Arboard::LinuxClipboardKind::Primary).text("middle-click me")
    module SetExtLinux
      # Waits, after setting the contents, until another program replaces
      # them. Returns the Set.
      #
      # When a program that owns the clipboard exits, its contents vanish,
      # since no one is left to serve them. A program that copies and then
      # exits would rather not wait for the user to copy something else.
      # Instead, hand the copy to a background process, which can outlive
      # yours and serves every request until the user copies something
      # else, then exits quietly.
      #
      # This option serves the contents, and returns only once they are
      # overwritten. Keep your process alive until the terminal method
      # returns, and the contents never vanish from under the user. See
      # arboard's daemonize example
      # (https://github.com/1Password/arboard/blob/master/examples/daemonize.rs).
      #
      # It releases Ruby's global VM lock while it waits, so your other
      # threads keep running, but Ctrl-C cannot stop it before another
      # program takes the clipboard. To serve the clipboard after your
      # program exits, run the wait in a fresh process, as arboard's example
      # does. Do not +fork+: arboard keeps one X11 connection and the thread
      # that serves it for the whole process, and a forked child shares the
      # parent's connection without that thread.
      #
      # === Example
      #
      #   script = 'Ferro::Arboard::Clipboard.new.set.wait.text("Hello, world!")'
      #   pid = Process.spawn(RbConfig.ruby, "-rferro/arboard", "-e", script,
      #     in: File::NULL, out: File::NULL, err: File::NULL, chdir: "/")
      #   Process.detach(pid)
      def wait
        @wait = :forever
        self
      end

      # Waits, after setting the contents, until they are replaced or
      # +deadline+ passes, whichever comes first. Returns the Set.
      #
      # +deadline+ is a time on the monotonic clock, as
      # <tt>Process.clock_gettime(Process::CLOCK_MONOTONIC)</tt> returns it,
      # which is what arboard's +Instant+ measures. A deadline already past
      # waits for nothing. One that is NaN, infinite, or too far off for the
      # clock raises +RangeError+ when the write runs.
      #
      # This suits short-lived programs that should not block until the
      # user copies something new. It replaces any earlier #wait or
      # #wait_once.
      #
      # === Example
      #
      #   in_ten_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      #   clipboard.set.wait_until(in_ten_seconds).text("pasteable for ten seconds")
      def wait_until(deadline)
        raise TypeError, "wrong argument type #{deadline.class} (expected Float)" unless deadline.is_a?(Numeric)

        @wait = Float(deadline)
        self
      end

      # Waits, after setting the contents, until another program reads them
      # once. Returns the Set. It replaces any earlier #wait or #wait_until.
      #
      # === Example
      #
      #   clipboard.set.wait_once.text("paste me once")
      def wait_once
        @wait = :once
        self
      end

      # Writes to +selection+, a LinuxClipboardKind, instead of the
      # default. Returns the Set.
      #
      # With Wayland support available, writing the Secondary selection
      # raises Error::ClipboardNotSupported.
      #
      # === Example
      #
      #   clipboard.set.clipboard(Ferro::Arboard::LinuxClipboardKind::Clipboard).text("for Ctrl+V")
      #   clipboard.set.clipboard(Ferro::Arboard::LinuxClipboardKind::Primary).text("for middle-click")
      def clipboard(selection)
        @selection = LinuxClipboardKind.__send__(:variant, selection)
        self
      end

      # Keeps the contents out of desktop clipboard managers' histories.
      # Returns the Set.
      #
      # arboard adds the <tt>x-kde-passwordManagerHint</tt> type to the
      # selection's data, the most widely adopted convention on Linux.
      #
      # === Example
      #
      #   clipboard.set.exclude_from_history.text(password)
      def exclude_from_history
        @exclude_from_history = true
        self
      end
    end

    # Linux options for a Clear.
    #
    # Clipboard#clear empties the default selection only. This module lets
    # a Clear empty any of them, on Linux alone.
    #
    # Mirrors arboard's +ClearExtLinux+
    # (<tt>src/platform/linux/mod.rs:432-459</tt>).
    #
    # === Example
    #
    #   clipboard.clear_with.clipboard(Ferro::Arboard::LinuxClipboardKind::Secondary)
    module ClearExtLinux
      # Empties +selection+, a LinuxClipboardKind. This finishes the
      # Clear.
      #
      # With Wayland support available, clearing the Secondary selection
      # raises Error::ClipboardNotSupported.
      #
      # === Example
      #
      #   clipboard.clear_with.clipboard(Ferro::Arboard::LinuxClipboardKind::Primary)
      def clipboard(selection)
        @clipboard.__send__(:native_clear, LinuxClipboardKind.__send__(:variant, selection))
      end
    end

    class Get
      include GetExtLinux
    end

    class Set
      include SetExtLinux
    end

    class Clear
      include ClearExtLinux
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
