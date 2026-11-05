# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "error"
require_relative "hint"
require_relative "server_information"
require_relative "action_response"
require_relative "builder"
require_relative "notification"
require_relative "notification_handle"

# notify-rust compiles these only for its XDG platforms, all(unix,
# not(target_os = "macos")), and the native extension reports which
# platform it was built for.
return unless Ferro::NotifyRust.const_get(:PLATFORM) == :linux

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: the XDG API and its documentation from
    #   notify-rust 4.18.2 src/xdg/mod.rs, src/image.rs, src/hints.rs:53-55,
    #   src/notification.rs:166-171, 202-211, 275-318, 386-390,
    #   515-533, src/lib.rs:226-233, and src/miniver.rs:4-45
    #++

    class Error
      # The D-Bus connection or call failed: no session bus, no
      # notification server, or a server that refused the call. The
      # message is zbus's. Defined only on Linux.
      #
      # === Example
      #
      #   begin
      #     Ferro::NotifyRust::Notification.new.summary("Hi").show
      #   rescue Ferro::NotifyRust::Error::Zbus => e
      #     warn "no notification server: #{e.message}"
      #   end
      class Zbus < Error
      end

      # An image could not be loaded or used; the message is ImageError's.
      # Defined only on Linux.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.image("/no/such.png")
      #   # raises Ferro::NotifyRust::Error::Image, "Can't open given path ...\n"
      class Image < Error
      end
    end

    # An image could not be made.
    #
    # Image's constructors return this error type rather than Error, as
    # notify-rust's do, so each case is a subclass with notify-rust's
    # message. Each message ends with a newline, as notify-rust writes it.
    # #debug answers notify-rust's +Debug+ text for the error. Defined only
    # on Linux.
    #
    # Mirrors notify-rust's +ImageError+ (<tt>src/image.rs:126-165</tt>).
    #
    # === Example
    #
    #   begin
    #     Ferro::NotifyRust::Image.from_rgb(2, 2, "\0" * 3)
    #   rescue Ferro::NotifyRust::ImageError::WrongDataSize => e
    #     warn e.message
    #   end
    class ImageError < StandardError
      # notify-rust's derived +Debug+ text (<tt>src/image.rs:127</tt>) for
      # the error this exception was raised for, formatted by Rust. +nil+
      # for one Ruby code made, except for the subclasses whose variant
      # holds nothing, which Rust formats; CantOpen holds the image
      # crate's error, a value no Ruby value is. +inspect+ stays Ruby's.
      #
      # === Example
      #
      #   begin
      #     Ferro::NotifyRust::Image.from_rgba(1, 1, "\0\0\0")
      #   rescue Ferro::NotifyRust::ImageError => e
      #     e.debug # => "WrongDataSize"
      #   end
      def debug
        @debug
      end

      # The image is too big: D-Bus has only 32 bits for its width and
      # height.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.from_rgb(0x1000_0000, 1, "")
      #   # raises Ferro::NotifyRust::ImageError::TooBig
      class TooBig < ImageError
        # notify-rust's +Debug+ text for the variant, <tt>TooBig</tt>.
        #
        # === Example
        #
        #   Ferro::NotifyRust::ImageError::TooBig.new.debug # => "TooBig"
        def debug
          @debug || Native.image_error_debug(:TooBig)
        end
      end

      # The bytes do not match the width, height, and channel count.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.from_rgba(1, 1, "\0\0\0")
      #   # raises Ferro::NotifyRust::ImageError::WrongDataSize
      class WrongDataSize < ImageError
        # notify-rust's +Debug+ text for the variant, <tt>WrongDataSize</tt>.
        #
        # === Example
        #
        #   Ferro::NotifyRust::ImageError::WrongDataSize.new.debug # => "WrongDataSize"
        def debug
          @debug || Native.image_error_debug(:WrongDataSize)
        end
      end

      # The file could not be opened or decoded; the message names the
      # image crate's reason.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.open("/no/such.png")
      #   # raises Ferro::NotifyRust::ImageError::CantOpen
      class CantOpen < ImageError
      end

      # The file decoded to a pixel format other than 8-bit RGB or RGBA.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.open("grayscale.png")
      #   # raises Ferro::NotifyRust::ImageError::CantConvert
      class CantConvert < ImageError
        # notify-rust's +Debug+ text for the variant, <tt>CantConvert</tt>.
        #
        # === Example
        #
        #   Ferro::NotifyRust::ImageError::CantConvert.new.debug # => "CantConvert"
        def debug
          @debug || Native.image_error_debug(:CantConvert)
        end
      end
    end

    # Raw image data for an inline notification image.
    #
    # An icon name or a path needs the image on disk where the server can
    # read it. A chart you just drew, or an avatar you downloaded, lives in
    # memory. The notification specification lets you send the pixels
    # themselves.
    #
    # Make one from 8-bit RGB or RGBA pixels, row by row from the top-left
    # corner, or by decoding a file, and pass it to Builder#image_data or
    # Hint::ImageData. Images compare by value and are frozen. Defined only
    # on Linux.
    #
    # Mirrors notify-rust's +Image+ (<tt>src/image.rs:19-92</tt>).
    #
    # === Examples
    #
    #   pixels = (0...64).flat_map { |y| (0...64).flat_map { |x| [x + y, x, y] } }.pack("C*")
    #   image = Ferro::NotifyRust::Image.from_rgb(64, 64, pixels)
    #   Ferro::NotifyRust::Notification.new.summary("I can haz image data!").image_data(image).show
    #
    #   Ferro::NotifyRust::Notification.new.image_data(Ferro::NotifyRust::Image.open("chart.png"))
    class Image
      private_class_method :new, :native_from_rgb, :native_from_rgba, :native_open

      # An image of +width+ by +height+ RGB pixels: three bytes each, so
      # +data+ holds <tt>width * height * 3</tt> bytes. Raises
      # ImageError::TooBig for a side over <tt>0x0fff_ffff</tt> and
      # ImageError::WrongDataSize for another byte count. notify-rust checks
      # the count with 32-bit arithmetic that wraps, so a product past
      # <tt>2**31</tt> wraps as it does there. Mirrors
      # <tt>Image::from_rgb</tt> (<tt>src/image.rs:60-65</tt>).
      #
      # [width] Integer within a 32-bit signed range.
      # [height] Integer within a 32-bit signed range.
      # [data] binary String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.from_rgb(1, 1, "\xFF\x00\x00".b) # one red pixel
      def self.from_rgb(width, height, data)
        native_from_rgb(width, height, data).freeze
      end

      # An image of +width+ by +height+ RGBA pixels: four bytes each, alpha
      # last. Raises as ::from_rgb does. Mirrors <tt>Image::from_rgba</tt>
      # (<tt>src/image.rs:67-72</tt>).
      #
      # [width] Integer within a 32-bit signed range.
      # [height] Integer within a 32-bit signed range.
      # [data] binary String of <tt>width * height * 4</tt> bytes.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.from_rgba(1, 1, "\x00\x00\xFF\x80".b) # one half-transparent blue pixel
      def self.from_rgba(width, height, data)
        native_from_rgba(width, height, data).freeze
      end

      # Decodes the image file at +path+, which must decode to 8-bit RGB
      # or RGBA. Raises ImageError::CantOpen when it cannot be read or
      # decoded, and ImageError::CantConvert for another pixel format.
      # Decoding releases Ruby's global VM lock. Mirrors
      # <tt>Image::open</tt> (<tt>src/image.rs:74-78</tt>).
      #
      # [path] String, or an object with +to_path+.
      #
      # === Example
      #
      #   image = Ferro::NotifyRust::Image.open("avatar.png")
      def self.open(path)
        native_open(File.path(path)).freeze
      end

      # Whether +other+ is an Image with the same size, format, and bytes,
      # as notify-rust's derived +PartialEq+ says.
      #
      # [other] any object.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.from_rgb(1, 1, "abc") == Ferro::NotifyRust::Image.from_rgb(1, 1, "abc") # => true
      def ==(other)
        native_equal(other)
      end

      alias eql? ==

      # A hash of the image, equal for equal images, so an Image works as a
      # Hash key and in a Set.
      #
      # === Example
      #
      #   { image => "avatar" }
      def hash
        native_hash
      end

      # notify-rust's derived +Debug+ text (<tt>src/image.rs:20</tt>),
      # formatted by Rust: the size, format, and every byte. +inspect+
      # stays Ruby's.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Image.from_rgb(1, 1, "abc").debug
      #   # => "Image { width: 1, height: 1, rowstride: 3, alpha: false, bits_per_sample: 8, channels: 3, data: [97, 98, 99] }"
      def debug
        native_debug
      end
    end

    module Hint
      # Raw image data, an Image. Builder#image_data adds one. Defined only
      # on Linux.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Hint::ImageData.new(Ferro::NotifyRust::Image.from_rgb(1, 1, "abc"))
      class ImageData < Data.define(:value)
        include Hint

        ##
        # :attr_reader: value
        # The image, an Ferro::NotifyRust::Image.
      end
    end

    # Which D-Bus implementation notify-rust uses.
    #
    # notify-rust can talk to D-Bus through zbus, pure Rust, or dbus-rs,
    # which links the system's libdbus. ferro-notify-rust builds zbus
    # alone, notify-rust's default, so NotifyRust.dbus_stack answers Zbus.
    # Defined only on Linux.
    #
    # Mirrors notify-rust's +DbusStack+ (<tt>src/xdg/mod.rs:401-408</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust.dbus_stack # => Ferro::NotifyRust::DbusStack::Zbus
    class DbusStack
      private_class_method :new

      # Creates the stack named +name+. The two constants are the only
      # instances.
      #
      # [name] Symbol, the notify-rust variant's name.
      def initialize(name)
        @name = name
        freeze
      end

      # notify-rust's derived +Debug+ text for this stack
      # (<tt>src/xdg/mod.rs:402</tt>), formatted by Rust: the variant's
      # name. +inspect+ stays Ruby's.
      #
      # === Example
      #
      #   Ferro::NotifyRust::DbusStack::Zbus.debug # => "Zbus"
      def debug
        Native.dbus_stack_debug(@name)
      end

      # dbus-rs (https://docs.rs/dbus), which ferro-notify-rust does not
      # build.
      Dbus = new(:Dbus)

      # zbus (https://docs.rs/zbus).
      Zbus = new(:Zbus)
    end

    # A notification's answer, or its handle, that arrives later.
    #
    # notify-rust's async methods return Rust futures, values that finish
    # while your program does something else and that you +await+. Ruby
    # has no futures to await.
    #
    # This object holds the work a Rust future would do. As a Rust future
    # does nothing until polled, the work starts when you call #value,
    # which waits for it, as <tt>.await</tt> does, and returns its result.
    # Methods that return one: Builder#show_async,
    # Builder#show_async_at_bus, NotificationHandle#close_async, and
    # NotificationHandle#wait_for_action_async. Defined only on Linux.
    #
    # <tt>.await</tt> takes a Rust future, so a Future works once: the
    # #value that returns its result, or raises the Error it finished
    # with, uses it up, and any later #value raises +IOError+, as a closed
    # IO does (ADR 001, 2026-11-05). One thread waits at a time; another
    # waiting on the same Future gets that +IOError+ once the first has the
    # result. Waiting releases Ruby's global VM lock, and an interrupt
    # (Ctrl-C, <tt>Thread#raise</tt>, +Timeout+) ends the wait and drops
    # the work, as dropping a Rust future does, without using the Future
    # up: call #value again to start the work again. A Rust future is not
    # +Clone+, so neither is this.
    #
    # Mirrors the <tt>impl Future</tt> notify-rust's async methods return
    # (<tt>src/notification.rs:515-533</tt>, <tt>src/xdg/mod.rs:146-238</tt>).
    #
    # === Example
    #
    #   future = Ferro::NotifyRust::Notification.new.summary("Hi").show_async
    #   handle = future.value
    class Future
      private_class_method :new

      # Holds +work+, which runs when #value first runs.
      #
      # [work] the block to run.
      def initialize(&work)
        @work = work
        @lock = Thread::Mutex.new
        @consumed = false
        @done = false
        @value = nil
        @error = nil
      end

      # Raises +TypeError+: a Rust future is not +Clone+, so a copy that
      # shared the work would answer a second time. Ruby words it as it
      # does for +Thread+, which has no allocator either.
      def initialize_copy(_original)
        raise TypeError, "allocator undefined for #{self.class}"
      end

      # Runs the work and returns what it returned: a NotificationHandle
      # from Builder#show_async, +nil+ from the handle's async methods.
      # Raises the Error it raised. Either uses the Future up: a later call
      # raises +IOError+.
      #
      # === Example
      #
      #   handle = Ferro::NotifyRust::Notification.new.summary("Hi").show_async.value
      def value
        @lock.synchronize do
          raise IOError, "#{self.class} consumed by Future#value" if @consumed

          settle unless @done
          @consumed = true
        end
        error = @error
        raise error if error

        _ = @value
      end

      # Runs the work once and keeps its outcome. An interrupt is not an
      # outcome: it propagates, and the work runs again next time.
      private def settle
        @value = @work.call
        @done = true
      rescue Error => e
        @error = e
        @done = true
      end
    end

    module Builder
      # Adds a Hint. A notification holds each distinct hint once, and one
      # Hint::Custom or Hint::CustomInt per name: the last one set. Most
      # hints have no effect on the big XDG desktops. Defined only on
      # Linux; macOS and Windows have no hints. Mirrors
      # <tt>Notification::hint</tt> (<tt>src/notification.rs:275-318</tt>).
      #
      # [hint] Hint.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.hint(Ferro::NotifyRust::Hint::Category.new("email"))
      def hint(hint)
        raise TypeError, "no implicit conversion of #{hint.class} into Ferro::NotifyRust::Hint" unless hint.is_a?(Hint)

        __send__(:native_hint, (_ = hint).__send__(:to_native))
        self
      end

      # The +hints+ field: a Set of the hints notify-rust keeps in its
      # +HashSet+. As notify-rust warns, it does not hold every hint:
      # Hint::Custom and Hint::CustomInt added with #hint are held
      # elsewhere. Defined only on Linux.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.hint(Ferro::NotifyRust::Hint::Resident.new(true)).hints
      #   # => #<Set: {#<data Ferro::NotifyRust::Hint::Resident value=true>}>
      def hints
        Set.new(__send__(:native_field, :hints).map { |tag| Hint.__send__(:from_native, tag) })
      end

      # Assigns the +hints+ field, replacing every hint in it with +hints+,
      # an Enumerable of Hint. Custom hints set with #hint stay. Defined
      # only on Linux.
      #
      # === Example
      #
      #   notification.hints = [Ferro::NotifyRust::Hint::Transient.new(true)]
      def hints=(hints)
        __send__(:native_set_field, :hints, hints.map do |hint|
          raise TypeError, "no implicit conversion of #{hint.class} into Ferro::NotifyRust::Hint" unless hint.is_a?(Hint)

          (_ = hint).__send__(:to_native)
        end)
      end

      # Adds raw image data, as Hint::ImageData. notify-rust names the hint
      # for the server's specification version, which it asks the server
      # for the first time one is sent. Defined only on Linux. Mirrors
      # <tt>Notification::image_data</tt>
      # (<tt>src/notification.rs:166-171</tt>).
      #
      # [image] Image.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.image_data(Ferro::NotifyRust::Image.open("chart.png"))
      def image_data(image)
        __send__(:native_image_data, image)
        self
      end

      # Decodes the image file at +path+ and adds it as Hint::ImageData.
      # Raises Error::Image when it cannot be read or decoded. Defined only
      # on Linux. Mirrors <tt>Notification::image</tt>
      # (<tt>src/notification.rs:202-211</tt>).
      #
      # [path] String, or an object with +to_path+.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("New photo").image("photo.jpg").show
      def image(path)
        __send__(:native_image, File.path(path))
        self
      end

      # Sends a copy of the notification to the server, as Builder#show
      # does, when the Future's +value+ runs, and finishes with its
      # NotificationHandle. Defined only on Linux. Mirrors
      # <tt>Notification::show_async</tt>
      # (<tt>src/notification.rs:515-522</tt>).
      #
      # === Example
      #
      #   handle = Ferro::NotifyRust::Notification.new.summary("Hi").show_async.value
      def show_async
        copy = finalize
        Future.__send__(:new) { copy.__send__(:native_show) }
      end

      # As #show_async, but to the server that owns the bus name
      # <tt>de.hoodie.Notification.</tt> followed by +sub_bus+, its slashes
      # read as dots, instead of the desktop's. notify-rust's own tests use
      # it to talk to a server of their own. The Future raises Error::Msg
      # (<tt>invalid subpath</tt>) for a name D-Bus would refuse. Defined
      # only on Linux. Mirrors <tt>Notification::show_async_at_bus</tt>
      # (<tt>src/notification.rs:524-533</tt>).
      #
      # [sub_bus] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("test").show_async_at_bus("my_test_server").value
      def show_async_at_bus(sub_bus)
        copy = finalize
        sub_bus = NotifyRust.__send__(:string, sub_bus)
        Future.__send__(:new) { copy.__send__(:native_show_async_at_bus, sub_bus) }
      end
    end

    class NotificationHandle
      # The id the server gave the notification. Defined only on Linux.
      # Mirrors <tt>NotificationHandle::id</tt>
      # (<tt>src/xdg/mod.rs:319-327</tt>).
      #
      # === Example
      #
      #   handle = Ferro::NotifyRust::Notification.new.summary("Hi").show
      #   handle.id # => 7
      def id
        native_handle_id
      end

      # Closes the notification on the server. notify-rust ignores the
      # server's error, so this does too. It takes the handle, as
      # notify-rust's takes +self+, so it uses the handle up; #close_async
      # borrows it instead. Defined only on Linux. Mirrors
      # <tt>NotificationHandle::close</tt> (<tt>src/xdg/mod.rs:197-221</tt>).
      #
      # === Example
      #
      #   handle = Ferro::NotifyRust::Notification.new
      #     .summary("oh no")
      #     .hint(Ferro::NotifyRust::Hint::Transient.new(true))
      #     .body("I'll be here till you close me!")
      #     .hint(Ferro::NotifyRust::Hint::Resident.new(true)) # does not work on kde
      #     .timeout(Ferro::NotifyRust::Timeout::Never) # works on kde and gnome
      #     .show
      #   # ... and then later
      #   handle.close
      def close
        native_close
        nil
      end

      # A Future that closes the notification, as #close does, when its
      # +value+ runs. It borrows the handle, as notify-rust's does, so the
      # handle stays usable, and a wait on another thread through
      # #wait_for_action_async ends with CloseReason::CloseAction. The
      # Future raises +IOError+ if the handle is used up before +value+
      # runs. Defined only on Linux. Mirrors
      # <tt>NotificationHandle::close_async</tt>
      # (<tt>src/xdg/mod.rs:223-238</tt>).
      #
      # === Example
      #
      #   handle.close_async.value
      def close_async
        Future.__send__(:new) do
          native_close_async
          nil
        end
      end

      # A Future that waits, when its +value+ runs, for the user to act on
      # the notification and yields the NotificationResponse to the block,
      # as #wait_for_response does. It borrows the handle, as notify-rust's
      # does, so the handle stays usable: another thread may #close_async
      # it meanwhile. Raises +ArgumentError+ without a block, since Rust
      # requires the closure. Defined only on Linux. Mirrors
      # <tt>NotificationHandle::wait_for_action_async</tt>
      # (<tt>src/xdg/mod.rs:146-195</tt>).
      #
      # === Example
      #
      #   future = handle.wait_for_action_async { |response| puts response.debug }
      #   Thread.new { future.value }
      def wait_for_action_async(&block)
        raise ArgumentError, "no block given; wait_for_action_async calls it with the response" unless block

        Future.__send__(:new) do
          tag = native_wait_for_action_async
          block.call(NotificationResponse.__send__(:from_native, tag)) unless tag.nil?
          nil
        end
      end

      # Sends the notification again with the same id, so the server
      # replaces the one it shows; change it first with the Builder
      # setters. Watch out for differences between servers: on Plasma 5,
      # change the appname too, so the old message is really replaced and
      # not just amended. Xfce behaves well. Raises Error::Zbus when the
      # call fails. notify-rust offers no way to cancel it, so an interrupt
      # takes effect once it returns. Defined only on Linux. Mirrors
      # <tt>NotificationHandle::update</tt>
      # (<tt>src/xdg/mod.rs:290-317</tt>).
      #
      # === Example
      #
      #   handle = Ferro::NotifyRust::Notification.new.summary("Latest News").body("Bayern Dortmund 3:2").show
      #   sleep 1.5
      #   handle.summary("Latest News (Correction)").body("Bayern Dortmund 3:3")
      #   handle.update
      def update
        native_update
        nil
      end
    end

    # A notification specification version, such as SPEC_VERSION.
    #
    # The XDG notification specification renamed some hints between
    # versions: raw image data is +icon_data+ in 1.0, +image_data+ in 1.1,
    # and +image-data+ from 1.2, and notify-rust picks the name by the
    # server's version (<tt>src/image.rs:179-185</tt>). Code that sends
    # hints may need to know which version the server speaks, and compare
    # it with another.
    #
    # A Version holds the two numbers and orders by +major+, then +minor+.
    # notify-rust's type sits in a private module, so code outside the
    # crate cannot name it or call a constructor, only copy SPEC_VERSION;
    # here too +new+ and <tt>[]</tt> are private. Defined only on Linux.
    #
    # Mirrors notify-rust's <tt>miniver::Version</tt>
    # (<tt>src/miniver.rs:4-45</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust::SPEC_VERSION.major # => 1
    class Version < Data.define(:major, :minor)
      include Comparable

      private_class_method :new, :[]

      ##
      # :attr_reader: major
      # The major version, an Integer.

      ##
      # :attr_reader: minor
      # The minor version, an Integer.

      # Orders by +major+, then +minor+, as notify-rust's +Ord+ does;
      # +nil+ for anything but a Version.
      #
      # [other] Object, the value to compare with.
      #
      # === Example
      #
      #   Ferro::NotifyRust::SPEC_VERSION <=> Ferro::NotifyRust::SPEC_VERSION # => 0
      def <=>(other)
        return unless other.is_a?(Version)

        [major, minor] <=> [other.major, other.minor]
      end

      # miniver's derived +Debug+ text (<tt>src/miniver.rs:4</tt>),
      # formatted by Rust from a copy of SPEC_VERSION, the one way to the
      # type, given these fields. Reading SPEC_VERSION the first time asks
      # the server, with Ruby's global VM lock released. +inspect+ stays
      # Data's.
      #
      # === Example
      #
      #   Ferro::NotifyRust::SPEC_VERSION.debug # => "Version { major: 1, minor: 2 }"
      def debug
        Native.version_debug(major, minor)
      end
    end

    # SPEC_VERSION asks the server the first time it is named, so it
    # loads then, as notify-rust's lazy static does.
    autoload :SPEC_VERSION, "ferro/notify_rust/spec_version"

    # The capabilities of the running notification server, such as
    # <tt>"actions"</tt>, <tt>"body"</tt>, <tt>"body-markup"</tt>, and
    # <tt>"persistence"</tt>. Raises Error::Zbus when there is no server.
    # Defined only on Linux. Mirrors <tt>get_capabilities</tt>
    # (<tt>src/xdg/mod.rs:487-493</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust.get_capabilities.include?("actions") # => true
    def self.get_capabilities
      Native.get_capabilities
    end

    # The running notification server's ServerInformation. Raises
    # Error::Zbus when there is no server. Defined only on Linux. Mirrors
    # <tt>get_server_information</tt> (<tt>src/xdg/mod.rs:515-523</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust.get_server_information.name # => "dunst"
    def self.get_server_information
      name, vendor, version, spec_version = Native.get_server_information
      ServerInformation.new(name:, vendor:, version:, spec_version:)
    end

    # Waits for the server's signal about the notification with id +id+,
    # then yields an ActionResponse: Custom with the action's key, or
    # Closed with the reason. Returns +nil+. Raises +ArgumentError+
    # without a block, before it waits, since Rust requires the closure.
    #
    # Prefer NotificationHandle#wait_for_action. This opens a connection of
    # its own and waits until the signal comes, with Ruby's global VM lock
    # released; notify-rust offers no way to cancel it, so Ctrl-C and
    # process exit wait for it too. Without a session bus notify-rust
    # panics, which raises Error. Defined only on Linux. Mirrors
    # <tt>handle_action</tt> (<tt>src/xdg/mod.rs:574-586</tt>).
    #
    # [id] Integer, the notification's id.
    #
    # === Example
    #
    #   id = Ferro::NotifyRust::Notification.new.summary("click me").action("ok", "OK").show.id
    #   Ferro::NotifyRust.handle_action(id) { |response| puts response.debug }
    def self.handle_action(id)
      raise ArgumentError, "no block given; handle_action calls it with the response" unless block_given?

      tag = Native.handle_action(id)
      yield ActionResponse.__send__(:from_native, tag) unless tag.nil?
      nil
    end

    # The D-Bus implementation in use: DbusStack::Zbus. Defined only on
    # Linux. Mirrors <tt>dbus_stack</tt> (<tt>src/xdg/mod.rs:451-457</tt>).
    #
    # === Example
    #
    #   Ferro::NotifyRust.dbus_stack # => Ferro::NotifyRust::DbusStack::Zbus
    def self.dbus_stack
      DbusStack.const_get(Native.dbus_stack, false)
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
