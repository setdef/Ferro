# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "zlib"

# The builder, read back through notify-rust's own fields and Debug text,
# so a setter that never reached notify-rust fails. build_pattern ports
# notify-rust 4.18.2's tests/realworld.rs:85-110.
class TestNotification < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  private def notification
    NotifyRust::Notification.new
  end

  def test_a_new_notification_is_empty_but_for_the_executables_name
    fresh = notification

    assert_equal File.basename(RbConfig.ruby), fresh.appname
    assert_equal "", fresh.summary
    assert_nil fresh.subtitle
    assert_equal "", fresh.body
    assert_equal "", fresh.icon
    assert_equal [], fresh.actions
    assert_same NotifyRust::Timeout::Default, fresh.timeout
  end

  # impl Default for Notification is what Notification::new returns
  # (src/notification.rs:123-125, 572-625).
  def test_default_is_a_new_notification
    default = NotifyRust::Notification.default

    assert_instance_of NotifyRust::Notification, default
    assert_equal notification.debug, default.debug
  end

  # Ruby's allocator makes the notification empty; notify-rust builds it in
  # initialize, where a panic can raise instead of aborting the process. An
  # object only allocated breaks Ruby's rules, not notify-rust's, so it
  # raises Ruby's TypeError in Ruby's words, as Time.allocate.year does.
  def test_an_allocated_but_uninitialized_notification_raises_rubys_type_error
    allocated = NotifyRust::Notification.allocate
    error = assert_raises(TypeError) { allocated.summary }

    assert_equal "uninitialized Ferro::NotifyRust::Notification", error.message
    assert_raises(TypeError) { allocated.summary("x") }
    assert_raises(TypeError) { allocated.debug }
  end

  def test_setters_reach_notify_rusts_fields_and_return_the_notification
    built = notification.appname("thunderbird").summary("Category:email").subtitle("inbox").body("Hi")
      .icon("thunderbird").action("default", "Open").action("archive", "Archive").timeout(6000)

    assert_kind_of NotifyRust::Notification, built
    assert_equal "thunderbird", built.appname
    assert_equal "Category:email", built.summary
    assert_equal "inbox", built.subtitle
    assert_equal "Hi", built.body
    assert_equal "thunderbird", built.icon
    assert_equal %w[default Open archive Archive], built.actions
    assert_equal NotifyRust::Timeout::Milliseconds.new(6000), built.timeout
  end

  def test_a_second_summary_replaces_the_first
    assert_equal "invocation type 3", notification.summary("this is the summary").summary("invocation type 3").summary
  end

  def test_timeout_takes_a_timeout_or_milliseconds_as_from_reads_them
    assert_same NotifyRust::Timeout::Never, notification.timeout(0).timeout
    assert_same NotifyRust::Timeout::Default, notification.timeout(-1).timeout
    assert_same NotifyRust::Timeout::Never, notification.timeout(NotifyRust::Timeout::Never).timeout
    assert_equal NotifyRust::Timeout::Milliseconds.new(2500), notification.timeout(2.5).timeout,
      "a Numeric other than an Integer is a Duration in seconds"
    assert_raises(TypeError) { notification.timeout("never") }
  end

  # The timeout field holds a Timeout (src/notification.rs:101), so
  # assigning it takes nothing else, while the setter takes anything
  # Into<Timeout> (:361), as in Rust.
  def test_the_timeout_field_takes_only_a_timeout
    built = notification

    assert_raises(TypeError) { built.timeout = 5 }
    assert_raises(TypeError) { built.timeout = 5.0 }
    assert_same NotifyRust::Timeout::Default, built.timeout
  end

  def test_id_reaches_notify_rust
    assert_includes notification.id(42).debug, "id: Some(42)"
    assert_raises(RangeError) { notification.id(-1) }
  end

  def test_auto_icon_names_the_executable
    assert_equal File.basename(RbConfig.ruby), notification.auto_icon.icon
  end

  def test_build_pattern
    assert_equal "foo", notification.summary("foo").finalize.summary

    built = notification
    built.body = "foo"
    assert_equal "foo", built.body
    built.icon = "foo"
    assert_equal "foo", built.icon
    built.summary = "foo"
    assert_equal "foo", built.summary
    built.timeout = NotifyRust::Timeout::Milliseconds.new(42)
    assert_equal NotifyRust::Timeout::Milliseconds.new(21 * 2), built.timeout
  end

  def test_field_writers_take_what_the_field_holds
    built = notification.subtitle("x")
    built.subtitle = nil
    built.appname = "app"
    built.actions = %w[ok OK]

    assert_nil built.subtitle
    assert_equal "app", built.appname
    assert_equal %w[ok OK], built.actions
    assert_raises(TypeError) { built.timeout = 5 }
    assert_raises(TypeError) { built.summary = nil }
  end

  def test_setters_take_strings_as_ruby_does
    assert_raises(TypeError) { notification.summary(1) }
    assert_raises(TypeError) { notification.subtitle(nil) }
    assert_raises(TypeError) { notification.action("ok", nil) }
  end

  def test_dup_and_finalize_copy_the_notification
    original = notification.summary("one")
    copy = original.dup.summary("two")
    finalized = original.finalize.summary("three")

    assert_equal %w[one two three], [original.summary, copy.summary, finalized.summary]
  end

  def test_a_frozen_notification_refuses_its_setters_and_can_be_shared
    frozen = notification.summary("shared").freeze

    assert_raises(FrozenError) { frozen.summary("changed") }
    assert_raises(FrozenError) { frozen.body = "changed" }
    assert_equal "shared", frozen.summary
    assert Ractor.shareable?(Ractor.make_shareable(frozen))
  end

  # initialize is a native method too: run again on a frozen notification,
  # it would replace the notification with a new one.
  def test_a_frozen_notification_refuses_to_be_initialized_again
    frozen = notification.summary("x").freeze

    assert_raises(FrozenError) { frozen.__send__(:initialize) }
    assert_equal "x", frozen.summary
    thawed = notification.summary("x")
    thawed.__send__(:initialize)

    assert_equal "", thawed.summary, "an unfrozen notification may still be initialized again"
  end

  def test_debug_is_notify_rusts_debug_text_and_inspect_stays_rubys
    built = notification.summary("Hi")

    assert_match(/\ANotification \{ appname: ".*", summary: "Hi", subtitle: None,/, built.debug)
    assert_match(/\A#<Ferro::NotifyRust::Notification:0x\h+>\z/, built.inspect)
  end

  # notify-rust deprecates the actions setter, "please use .action() only"
  # (src/notification.rs:442), so it is not bound (ADR 001, 2026-11-05).
  # The field it sets is public and not deprecated, so it reads and
  # writes.
  def test_the_deprecated_actions_setter_is_not_bound
    built = notification.action("a", "A")

    assert_raises(ArgumentError) { built.actions(%w[b B]) }
    built.actions = %w[b B]

    assert_equal %w[b B], built.actions
  end

  def test_image_path_and_sound_name_reach_the_platforms_field
    built = notification.image_path("/tmp/chart.png").sound_name("Ping")

    if PLATFORM == :linux
      assert_includes built.hints, NotifyRust::Hint::ImagePath.new("/tmp/chart.png")
      assert_includes built.hints, NotifyRust::Hint::SoundName.new("Ping")
    else
      assert_includes built.debug, 'path_to_image: Some("/tmp/chart.png")'
      assert_includes built.debug, 'sound_name: Some("Ping")'
    end
  end

  def test_linux_hints_are_a_set_and_custom_hints_keep_one_per_name
    skip_unless_platform(:linux)
    hint = NotifyRust::Hint
    built = notification.hint(hint::Resident.new(true)).hint(hint::Resident.new(true))
      .hint(hint::Custom.new("foo", "bar1")).hint(hint::Custom.new("foo", "bar2")).urgency(urgency::Critical)

    assert_equal Set[hint::Resident.new(true), hint::Urgency.new(urgency::Critical)], built.hints
    assert_includes built.debug, %(("foo", String): Custom("foo", "bar2"))
    refute_includes built.debug, "bar1"
    assert_raises(TypeError) { built.hint("resident") }
  end

  def test_linux_hints_can_be_assigned
    skip_unless_platform(:linux)
    built = notification.hint(NotifyRust::Hint::Resident.new(true))
    built.hints = [NotifyRust::Hint::Transient.new(true)]

    assert_equal Set[NotifyRust::Hint::Transient.new(true)], built.hints
  end

  # A one-pixel PNG, written with Zlib, for Image.open.
  private def png(path, pixel)
    chunk = lambda do |type, data|
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
    File.binwrite(path, "\x89PNG\r\n\x1a\n".b + chunk.call("IHDR", [1, 1, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
      chunk.call("IDAT", Zlib::Deflate.deflate("\0#{pixel}".b)) + chunk.call("IEND", ""))
  end

  def test_linux_images_from_pixels_and_files
    skip_unless_platform(:linux)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "red.png")
      png(path, "\xFF\x00\x00".b)
      image = NotifyRust::Image.open(path)

      assert_equal NotifyRust::Image.from_rgb(1, 1, "\xFF\x00\x00".b), image
      assert_equal image.hash, NotifyRust::Image.from_rgb(1, 1, "\xFF\x00\x00".b).hash
      assert_predicate image, :frozen?
      assert_equal "Image { width: 1, height: 1, rowstride: 3, alpha: false, bits_per_sample: 8, channels: 3, " \
        "data: [255, 0, 0] }", image.debug
      assert_match(/\A#<Ferro::NotifyRust::Image:0x\h+>\z/, image.inspect)
      hinted = notification.image(path).hints.first

      assert_equal NotifyRust::Hint::ImageData.new(image), hinted
      assert_predicate hinted.value, :frozen?
      assert_equal "ImageData(#{image.debug})", hinted.debug
      assert_includes notification.image_data(image).hints, NotifyRust::Hint::ImageData.new(image)
    end
  end

  # Each ImageError keeps the Debug text of the error notify-rust returned
  # (src/image.rs:127); one Ruby code made is rebuilt where the variant
  # holds nothing, and CantOpen, which holds the image crate's error, has
  # none.
  def test_linux_image_errors_are_notify_rusts
    skip_unless_platform(:linux)
    image = NotifyRust::Image
    wrong = assert_raises(NotifyRust::ImageError::WrongDataSize) { image.from_rgba(1, 1, "\0\0\0") }

    assert_equal "The given bytes don't match the width, height and channel count\n", wrong.message
    assert_equal "WrongDataSize", wrong.debug
    assert_equal "The given image is too big. DBus only has 32 bits for width / height\n",
      assert_raises(NotifyRust::ImageError::TooBig) { image.from_rgb(0x1000_0000, 1, "") }.message
    cant_open = assert_raises(NotifyRust::ImageError::CantOpen) { image.open("/no/such.png") }

    assert_match(/\ACan't open given path /, cant_open.message)
    assert_match(/\ACantOpen\(IoError\(/, cant_open.debug)
    from_image = assert_raises(NotifyRust::Error::Image) { notification.image("/no/such.png") }

    assert_match(/\ACan't open given path /, from_image.message)
    assert_match(/\AError \{ kind: Image\(CantOpen\(IoError\(/, from_image.debug)
    assert_equal %w[TooBig CantConvert], [NotifyRust::ImageError::TooBig.new.debug, NotifyRust::ImageError::CantConvert.new.debug]
    assert_nil NotifyRust::ImageError::CantOpen.new("x").debug
  end

  def test_windows_app_id_and_urgency_reach_notify_rust
    skip_unless_platform(:windows)
    built = notification.app_id("Example.App").urgency(urgency::Critical)

    assert_includes built.debug, 'app_id: Some("Example.App")'
    assert_includes built.debug, "urgency: Some(Critical)"
  end
end
