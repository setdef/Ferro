# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# notify-rust's enums and their conversions, which every platform has. The
# Urgency tests port notify-rust 4.18.2's tests/conversion.rs, and the
# Timeout ones its doc tests (src/timeout.rs:5-12, :28-33,
# src/notification.rs:341-355).
class TestValues < Minitest::Test
  include NotifySuite

  NotifyRust = Ferro::NotifyRust

  def test_urgency_has_three_frozen_constants
    assert_equal %w[Low Normal Critical], [urgency::Low, urgency::Normal, urgency::Critical].map(&:debug)
    assert [urgency::Low, urgency::Normal, urgency::Critical].all?(&:frozen?)
    assert_raises(NoMethodError) { urgency.new(:Low) }
  end

  # notify-rust derives Debug for each value (src/urgency.rs:27,
  # src/timeout.rs:13, src/response.rs:21, :63, :110, src/hints.rs:39,
  # src/notification_id.rs:19, src/lib.rs:236), and Rust formats the text
  # from the value the Ruby one stands for, quotes and escapes included.
  def test_values_debug_as_notify_rust_derives
    response = NotifyRust::NotificationResponse
    close = NotifyRust::CloseReason

    assert_equal %w[Default Never Milliseconds(6000)],
      [NotifyRust::Timeout::Default, NotifyRust::Timeout::Never, NotifyRust::Timeout::Milliseconds.new(6000)].map(&:debug)
    assert_equal %w[Expired Dismissed CloseAction Other(7)],
      [close::Expired, close::Dismissed, close::CloseAction, close::Other.new(7)].map(&:debug)
    assert_equal ["Default", 'Action("ok")', 'Reply("On \\"my\\" way")', "Closed(Other(4))"],
      [
        response::Default,
        response::Action.new("ok"),
        response::Reply.new('On "my" way'),
        response::Closed.new(close::Other.new(4)),
].map(&:debug)
    assert_equal ['Custom("clicked_a")', "Closed(Expired)"],
      [NotifyRust::ActionResponse::Custom.new("clicked_a"), NotifyRust::ActionResponse::Closed.new(close::Expired)]
        .map(&:debug)
    assert_equal ["Xdg(42)", 'Mac("my-app.status")'],
      [NotifyRust::NotificationId::Xdg.new(42), NotifyRust::NotificationId::Mac.new("my-app.status")].map(&:debug)
    assert_equal 'ServerInformation { name: "dunst", vendor: "knopwob", version: "1.12", spec_version: "1.2" }',
      NotifyRust::ServerInformation.new(name: "dunst", vendor: "knopwob", version: "1.12", spec_version: "1.2").debug
  end

  def test_hints_debug_as_notify_rust_derives
    hint = NotifyRust::Hint

    assert_equal [
      "ActionIcons(true)",
      'Category("email")',
      "X(-12)",
      "Urgency(Critical)",
      'Custom("x-dunst-stack-tag", "volume")',
      'CustomInt("value", 40)',
      "Invalid",
],
      [
        hint::ActionIcons.new(true),
        hint::Category.new("email"),
        hint::X.new(-12),
        hint::Urgency.new(urgency::Critical),
        hint::Custom.new("x-dunst-stack-tag", "volume"),
        hint::CustomInt.new("value", 40),
        hint::Invalid,
].map(&:debug)
  end

  def test_a_value_notify_rust_could_not_hold_has_no_debug
    assert_raises(TypeError) { NotifyRust::NotificationResponse::Action.new(:ok).debug }
    assert_raises(TypeError) { NotifyRust::Hint::Category.new(nil).debug }
    assert_raises(RangeError) { NotifyRust::CloseReason::Other.new(-1).debug }
    assert_raises(RangeError) { NotifyRust::Timeout::Milliseconds.new(2 ** 32).debug }
  end

  def test_inspect_stays_rubys
    assert_match(/\A#<Ferro::NotifyRust::Urgency:0x\h+ @name=:Low>\z/, urgency::Low.inspect)
    assert_match(/\A#<Ferro::NotifyRust::CloseReason::Unit:0x\h+ @name=:Expired>\z/, NotifyRust::CloseReason::Expired.inspect)
    assert_equal "#<data Ferro::NotifyRust::Timeout::Milliseconds value=6000>",
      NotifyRust::Timeout::Milliseconds.new(6000).inspect
    assert_equal '#<data Ferro::NotifyRust::Hint::Category value="email">', NotifyRust::Hint::Category.new("email").inspect
  end

  # Rust reads a tuple variant by position (ADR 001, 2026-11-05), and
  # deconstruct and to_a give the fields in Rust order.
  def test_tuple_variants_are_positional_through_deconstruct_and_to_a
    close = NotifyRust::CloseReason
    hint = NotifyRust::Hint
    {
      NotifyRust::Timeout::Milliseconds.new(6000) => [6000],
      hint::Category.new("email") => ["email"],
      hint::Resident.new(true) => [true],
      hint::X.new(-12) => [-12],
      hint::Urgency.new(urgency::Critical) => [urgency::Critical],
      hint::Custom.new("k", "v") => %w[k v],
      hint::CustomInt.new("n", 40) => ["n", 40],
      close::Other.new(7) => [7],
      NotifyRust::NotificationResponse::Action.new("ok") => ["ok"],
      NotifyRust::NotificationResponse::Closed.new(close::Expired) => [close::Expired],
      NotifyRust::ActionResponse::Custom.new("clicked_a") => ["clicked_a"],
      NotifyRust::ActionResponse::Closed.new(close::Dismissed) => [close::Dismissed],
      NotifyRust::NotificationId::Xdg.new(42) => [42],
    }.each do |variant, fields|
      assert_equal fields, variant.to_a, variant.inspect
      assert_equal variant.deconstruct, variant.to_a
    end

    case NotifyRust::Timeout::Milliseconds.new(6000)
    in NotifyRust::Timeout::Milliseconds[milliseconds] then assert_equal 6000, milliseconds
    end
    ms, = NotifyRust::Timeout::Milliseconds.new(9).to_a
    assert_equal 9, ms
  end

  # Rust gives each variant the discriminant src/urgency.rs:27-35 declares,
  # and the gem asks Rust for it.
  def test_urgency_to_i_is_the_discriminant
    assert_equal [0, 1, 2], [urgency::Low, urgency::Normal, urgency::Critical].map(&:to_i)
    assert_equal [urgency::Low, urgency::Normal, urgency::Critical], (0..2).map { |n| urgency.from(n) }
  end

  def test_urgency_from_int
    assert_equal urgency::Low, urgency.from(0)
    assert_equal urgency::Normal, urgency.from(1)
    assert_equal urgency::Critical, urgency.from(2)
    assert_equal urgency::Critical, urgency.from(900)
    assert_equal urgency::Critical, urgency.from((2 ** 64) - 1)
    assert_raises(RangeError) { urgency.from(-1) }
  end

  def test_urgency_from_option_int
    assert_equal urgency::Normal, urgency.from(nil)
  end

  def test_urgency_from_str
    assert_equal urgency::Low, urgency.try_from("low")
    assert_equal urgency::Low, urgency.try_from("lo")
    assert_equal urgency::Normal, urgency.try_from("medium")
    assert_equal urgency::Normal, urgency.try_from("Normal")
    assert_equal urgency::Normal, urgency.try_from("NoRmaL")
    assert_equal urgency::Critical, urgency.try_from("High")
    assert_equal urgency::Critical, urgency.try_from("Hi")
    assert_equal urgency::Critical, urgency.try_from("Critical")
  end

  def test_an_unknown_urgency_raises_notify_rusts_conversion_error
    error = assert_raises(NotifyRust::Error::Conversion) { urgency.try_from("urgent") }

    assert_equal 'Conversion Error: invalid input "urgent"', error.message
    assert_raises(TypeError) { urgency.try_from(:low) }
  end

  def test_timeout_parses_as_notify_rust_does
    assert_equal NotifyRust::Timeout::Default, NotifyRust::Timeout.from_str("default")
    assert_equal NotifyRust::Timeout::Never, NotifyRust::Timeout.from_str("never")
    assert_equal NotifyRust::Timeout::Milliseconds.new(42), NotifyRust::Timeout.from_str("42")
    error = assert_raises(ArgumentError) { NotifyRust::Timeout.from_str("soon") }
    assert_equal "invalid digit found in string", error.message
  end

  def test_timeout_from_i32
    assert_equal NotifyRust::Timeout::Milliseconds.new(234), NotifyRust::Timeout.from(234)
    assert_equal NotifyRust::Timeout::Default, NotifyRust::Timeout.from(-234)
    assert_equal NotifyRust::Timeout::Never, NotifyRust::Timeout.from(0)
    assert_raises(RangeError) { NotifyRust::Timeout.from(2 ** 31) }
    assert_raises(TypeError) { NotifyRust::Timeout.from("234") }
  end

  # From<Duration> for Timeout (src/timeout.rs:46-56), with the Duration as
  # seconds (ADR 001, 2026-11-05). An Integer is From<i32>'s milliseconds,
  # as an integer literal is in Rust, so a Duration is any other Numeric.
  # Ports the doc tests at src/notification.rs:341-355.
  def test_timeout_from_a_duration_in_seconds
    timeout = NotifyRust::Timeout

    assert_equal timeout::Milliseconds.new(2000), timeout.from(2.0)
    assert_equal timeout::Milliseconds.new(1500), timeout.from(3r / 2)
    assert_same timeout::Never, timeout.from(0.0)
    assert_same timeout::Default, timeout.from(18_446_744_073_709_551.615)
    assert_equal timeout::Milliseconds.new(1), timeout.from(0.0015), "as_millis truncates"
    assert_equal timeout::Milliseconds.new(1500), NotifyRust::Notification.new.timeout(1.5).timeout
    assert_equal "cannot convert float seconds to Duration: value is negative",
      assert_raises(ArgumentError) { timeout.from(-1.0) }.message
    assert_equal "cannot convert float seconds to Duration: value is either too big or NaN",
      assert_raises(ArgumentError) { timeout.from(Float::NAN) }.message
  end

  def test_timeout_as_the_specification_sends_it
    assert_equal(-1, NotifyRust::Timeout::Default.to_i)
    assert_equal 0, NotifyRust::Timeout::Never.to_i
    assert_equal 6000, NotifyRust::Timeout::Milliseconds.new(6000).to_i
    # Rust's `as i32` wraps; notify-rust sends this to the server as -1.
    assert_equal(-1, NotifyRust::Timeout::Milliseconds.new((2 ** 32) - 1).to_i)
    assert_raises(RangeError) { NotifyRust::Timeout::Milliseconds.new(2 ** 32).to_i }
  end

  def test_timeout_defaults_to_default
    assert_same NotifyRust::Timeout::Default, NotifyRust::Timeout.default
    assert_kind_of NotifyRust::Timeout, NotifyRust::Timeout::Milliseconds.new(1)
  end

  def test_close_reason_from_the_specifications_codes
    assert_same NotifyRust::CloseReason::Expired, NotifyRust::CloseReason.from(1)
    assert_same NotifyRust::CloseReason::Dismissed, NotifyRust::CloseReason.from(2)
    assert_same NotifyRust::CloseReason::CloseAction, NotifyRust::CloseReason.from(3)
    assert_equal NotifyRust::CloseReason::Other.new(4), NotifyRust::CloseReason.from(4)
    assert_equal NotifyRust::CloseReason::Other.new(0), NotifyRust::CloseReason.from(0)
  end

  def test_notification_response_from_a_key_is_an_action
    assert_equal NotifyRust::NotificationResponse::Action.new("ok"), NotifyRust::NotificationResponse.from("ok")
    assert NotifyRust::NotificationResponse::Default.is_default_action
    refute NotifyRust::NotificationResponse.from("default").is_default_action
    closed = NotifyRust::NotificationResponse::Closed.new(NotifyRust::CloseReason::Dismissed)

    refute closed.is_default_action
    assert_equal NotifyRust::CloseReason::Dismissed, closed.reason
  end

  def test_action_response_from_a_key_is_custom
    assert_equal NotifyRust::ActionResponse::Custom.new("default"), NotifyRust::ActionResponse.from("default")
    assert_kind_of NotifyRust::ActionResponse, NotifyRust::ActionResponse::Closed.new(NotifyRust::CloseReason::Expired)
  end

  def test_notification_id_from_a_number_or_a_string
    assert_equal NotifyRust::NotificationId::Xdg.new(42), NotifyRust::NotificationId.from(42)
    assert_equal NotifyRust::NotificationId::Mac.new("my-app.status"), NotifyRust::NotificationId.from("my-app.status")
    assert_raises(RangeError) { NotifyRust::NotificationId.from(2 ** 32) }
  end

  def test_hint_from_key_val
    hint = NotifyRust::Hint

    assert_equal hint::ActionIcons.new(true), hint.from_key_val("action-icons", "true")
    assert_equal hint::Category.new("email"), hint.from_key_val("category", "email")
    assert_equal hint::DesktopEntry.new("firefox"), hint.from_key_val("desktop-entry", "firefox")
    assert_equal hint::ImagePath.new("/a.png"), hint.from_key_val("image-path", "/a.png")
    assert_equal hint::Resident.new(false), hint.from_key_val("resident", "false")
    assert_equal hint::SoundFile.new("/a.oga"), hint.from_key_val("sound-file", "/a.oga")
    assert_equal hint::SoundName.new("bell"), hint.from_key_val("sound-name", "bell")
    assert_equal hint::SuppressSound.new(true), hint.from_key_val("suppress-sound", "true")
    assert_equal hint::Transient.new(true), hint.from_key_val("transient", "true")
    assert_equal hint::X.new(-12), hint.from_key_val("x", "-12")
    assert_equal hint::Y.new(7), hint.from_key_val("y", "7")
  end

  def test_hint_from_key_val_raises_notify_rusts_reasons
    hint = NotifyRust::Hint

    assert_equal "unknown name", assert_raises(ArgumentError) { hint.from_key_val("urgency", "low") }.message
    assert_equal "provided string was not `true` or `false`",
      assert_raises(ArgumentError) { hint.from_key_val("resident", "yes") }.message
    assert_equal "invalid digit found in string", assert_raises(ArgumentError) { hint.from_key_val("x", "left") }.message
  end

  def test_hint_accessors_answer_as_notify_rusts_do
    hint = NotifyRust::Hint

    assert hint::Transient.new(true).as_bool
    assert_nil hint::Category.new("email").as_bool
    assert_equal 3, hint::Y.new(3).as_i32
    assert_nil hint::CustomInt.new("value", 3).as_i32
    assert_equal "bell", hint::SoundName.new("bell").as_str
    assert_nil hint::Category.new("email").as_str
    assert_nil hint::Custom.new("k", "v").as_str
    assert_nil hint::Invalid.as_bool
    assert_nil hint::Urgency.new(urgency::Low).as_str
  end

  def test_hints_compare_by_value
    assert_equal NotifyRust::Hint::Category.new("email"), NotifyRust::Hint::Category.new("email")
    refute_equal NotifyRust::Hint::Category.new("email"), NotifyRust::Hint::DesktopEntry.new("email")
    assert_equal 1, [NotifyRust::Hint::Resident.new(true), NotifyRust::Hint::Resident.new(true)].uniq.size
  end

  def test_server_information_holds_four_strings
    info = NotifyRust::ServerInformation.new(name: "dunst", vendor: "knopwob", version: "1.12", spec_version: "1.2")

    assert_equal %w[dunst knopwob 1.12 1.2], info.to_h.values
  end

  # A hint's fields are made before the symbol and the array that hold
  # them, and each allocation can collect. Held in a Vec on Rust's heap,
  # which the collector does not scan, a String was freed before the array
  # read it; GC.stress collects at every allocation, so the child crashes
  # without them on the stack.
  def test_a_hint_keeps_its_fields_through_a_collection
    (hints,) = in_child(<<~RUBY)
      hint = Ferro::NotifyRust::Hint
      GC.stress = true
      hints = 100.times.map do
        [hint.from_key_val("category", "email"), hint.from_key_val("resident", "true")]
      end
      GC.stress = false
      hints.uniq
    RUBY

    assert_equal [[NotifyRust::Hint::Category.new("email"), NotifyRust::Hint::Resident.new(true)]], hints
  end

  # Ports notify-rust 4.18.2's miniver tests (src/miniver.rs:47-56): a
  # Version orders by major, then minor. Rust code outside notify-rust
  # cannot name the type, so Ruby code cannot make one either.
  def test_a_spec_version_orders_by_major_then_minor
    skip_unless_platform(:linux)
    version = -> (major, minor) { NotifyRust::Version.__send__(:new, major, minor) }

    assert_operator version[1, 3], :>=, version[1, 2]
    assert_operator version[1, 2], :>=, version[1, 2]
    assert_equal version[1, 2], version[1, 2]
    assert_operator version[1, 1], :<=, version[1, 2]
    assert_operator version[2, 0], :>, version[1, 9]
    assert_nil version[1, 2] <=> "1.2"
    assert_raises(NoMethodError) { NotifyRust::Version.new(1, 2) }
    assert_raises(NoMethodError) { NotifyRust::Version[1, 2] }
  end

  # notify-rust derives Debug for its DbusStack and miniver's Version
  # (src/xdg/mod.rs:402, src/miniver.rs:4). Without a server
  # SPEC_VERSION, which a Version's text is built on, falls back to 1.1.
  def test_linux_values_debug_as_notify_rust_derives
    skip_unless_platform(:linux)
    (debug,) = in_child(<<~RUBY, "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/nonexistent/bus")
      notify = Ferro::NotifyRust
      [notify::DbusStack::Zbus.debug, notify::DbusStack::Dbus.debug, notify::Version.__send__(:new, 3, 14).debug,
        notify::SPEC_VERSION.debug, notify::DbusStack::Zbus.inspect]
    RUBY

    assert_equal ["Zbus", "Dbus", "Version { major: 3, minor: 14 }", "Version { major: 1, minor: 1 }"], debug.first(4)
    assert_match(/\A#<Ferro::NotifyRust::DbusStack:0x\h+ @name=:Zbus>\z/, debug.last)
  end
end
