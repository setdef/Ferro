# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# arboard's Clipboard is Send and Sync (src/lib.rs:510-516), so the
# extension is marked Ractor-safe and a frozen clipboard may be shared
# (plan 001, decision 13). Without rb_ext_ractor_safe, every call from a
# non-main Ractor raises Ractor::UnsafeError.
class TestRactor < Minitest::Test
  include ClipboardSuite

  # With FERRO_TEST_TRACE set, as CI sets it, each Ractor reports each step
  # to stderr as it takes it. Windows CI hung once in Ractor#value with no
  # sign of where the Ractor stopped: in a clipboard call, or after its
  # block returned. The last step printed says which.
  TRACE = !ENV.fetch("FERRO_TEST_TRACE", "").empty?

  private def quietly
    experimental = Warning[:experimental]
    Warning[:experimental] = false
    yield
  ensure
    Warning[:experimental] = experimental
  end

  def test_another_ractor_round_trips_text_through_a_shared_clipboard
    shared = Ractor.make_shareable(Ferro::Arboard::Clipboard.new)

    read = quietly do
      Ractor.new(TRACE, shared) do |trace, clipboard|
        step = -> (name) { warn("ractor: #{name}") if trace }
        step.call("setting text through the shared clipboard")
        clipboard.set_text("from a Ractor")
        step.call("reading it back")
        text = clipboard.get_text
        step.call("returning")
        text
      end.value
    end

    assert_equal "from a Ractor", read
    assert_equal "from a Ractor", clipboard.get_text
  end

  def test_another_ractor_opens_its_own_clipboard_and_rescues_arboards_errors
    raised = quietly do
      Ractor.new(TRACE) do |trace|
        step = -> (name) { warn("ractor: #{name}") if trace }
        step.call("opening a clipboard")
        clipboard = Ferro::Arboard::Clipboard.new
        step.call("clearing it")
        clipboard.clear
        step.call("reading the empty clipboard")
        clipboard.get_text
      rescue Ferro::Arboard::Error::ContentNotAvailable => e
        step.call("rescued #{e.class}; returning")
        e.message
      end.value
    end

    assert_equal NOT_AVAILABLE, raised
  end
end
