# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# What the binding adds around idna's functions: deny lists, enum values,
# the Result-in-a-tuple pairs, callbacks, sinks, the deprecated API's
# values, and the refusals of inputs idna panics on (plan 006).
class TestValues < Minitest::Test
  include IdnaSuite

  URL = Uts46::AsciiDenyList::URL

  def test_the_crate_functions_follow_the_whatwg_url_standard
    assert_equal "xn--bcher-kva.example", Idna.domain_to_ascii_cow("Bücher.example", URL)
    assert_equal "xn--bcher-kva.example", Idna.domain_to_ascii_from_cow("Bücher.example", URL)
    assert_equal "a_b.example", Idna.domain_to_ascii("a_b.example")
    assert_raises(Idna::Errors) { Idna.domain_to_ascii_cow("a<b.example", URL) }
    assert_equal "a<b.example", Idna.domain_to_ascii_cow("a<b.example", Uts46::AsciiDenyList::EMPTY)
    assert_raises(Idna::Errors) { Idna.domain_to_ascii_strict("a_b.example") }
  end

  def test_bytes_that_are_not_utf8_are_idnas_error
    assert_raises(Idna::Errors) { Idna.domain_to_ascii_cow("\xFF.example".b, URL) }
    assert_equal "example.com", Idna.domain_to_ascii_cow("EXAMPLE.com".b, URL)
    assert_raises(TypeError) { Idna.domain_to_ascii_cow(:example, URL) }
    assert_raises(TypeError) { Idna.domain_to_ascii_cow("example", :URL) }
  end

  def test_a_unicode_result_comes_with_unraised_errors
    text, errors = Idna.domain_to_unicode("xn--a.example")

    assert_equal "�.example", text
    assert_instance_of Idna::Errors, errors
    assert_equal "Errors", errors.message
    assert_equal ["bücher.example", nil], Idna.domain_to_unicode("xn--bcher-kva.example")
  end

  def test_the_root_deny_list_is_the_uts46_one
    assert_same Uts46::AsciiDenyList, Idna::AsciiDenyList
  end

  def test_deny_lists_compare_by_what_they_deny
    list = Uts46::AsciiDenyList

    assert_equal list::URL, list.new(true, "%#/:<>?@[\\]^|")
    assert_equal list::EMPTY, list.new(false, "")
    assert_equal list::STD3, list.new(true, (33..126).map(&:chr).grep(/[^a-zA-Z0-9.-]/).join)
    refute_equal list::URL, list::EMPTY
    refute_equal list::URL, "URL"
    assert_predicate list::URL, :frozen?
    assert_raises(NoMethodError) { list.allocate.__send__(:initialize, nil).native }
  end

  def test_a_custom_deny_list_reaches_idna
    underscore = Uts46::AsciiDenyList.new(false, "_")

    assert_raises(Idna::Errors) { Idna.domain_to_ascii_cow("a_b.example", underscore) }
    assert_equal "a-b.example", Idna.domain_to_ascii_cow("a-b.example", underscore)
    glyphless = Uts46::AsciiDenyList.new(true, "")

    assert_raises(Idna::Errors) { Idna.domain_to_ascii_cow("a b.example", glyphless) }
  end

  def test_what_idna_would_panic_on_raises_argument_error_with_its_message
    {
      "é" => "ASCII deny list must be ASCII.",
      "." => "ASCII deny list must not contain the dot.",
      "-" => "ASCII deny list must not contain the hyphen.",
      "7" => "ASCII deny list must not contain digits.",
      "q" => "ASCII deny list must not contain letters.",
      "Q" => "ASCII deny list must not contain letters.",
      "_a." => "ASCII deny list must not contain letters.",
    }.each do |list, message|
      error = assert_raises(ArgumentError, list) { Uts46::AsciiDenyList.new(false, list) }
      assert_equal message, error.message
    end
  end

  def test_enum_values_are_frozen_constants
    assert_equal "Ferro::Idna::Uts46::Hyphens::CheckFirstLast", Uts46::Hyphens::CheckFirstLast.inspect
    assert_equal "Ferro::Idna::Uts46::DnsLength::VerifyAllowRootDot", Uts46::DnsLength::VerifyAllowRootDot.inspect
    assert_equal "Ferro::Idna::Uts46::ErrorPolicy::MarkErrors", Uts46::ErrorPolicy::MarkErrors.inspect
    assert_equal "Ferro::Idna::Uts46::ProcessingSuccess::WroteToSink", Uts46::ProcessingSuccess::WroteToSink.inspect
    assert_predicate Uts46::Hyphens::Allow, :frozen?
    assert_raises(NoMethodError) { Uts46::Hyphens.new(:Allow) }
    refute_equal Uts46::Hyphens::Allow, Uts46::Hyphens::Check
  end

  def test_each_option_reaches_idna
    uts46 = Uts46::Uts46.new
    ascii = -> (domain, hyphens, length) { uts46.to_ascii(domain, URL, hyphens, length) }

    assert_equal "ab--c.example", ascii.call("ab--c.example", Uts46::Hyphens::CheckFirstLast, Uts46::DnsLength::Ignore)
    assert_raises(Idna::Errors) { ascii.call("ab--c.example", Uts46::Hyphens::Check, Uts46::DnsLength::Ignore) }
    assert_raises(Idna::Errors) { ascii.call("a-.example", Uts46::Hyphens::CheckFirstLast, Uts46::DnsLength::Ignore) }
    assert_equal "a.example.", ascii.call("a.example.", Uts46::Hyphens::Allow, Uts46::DnsLength::VerifyAllowRootDot)
    assert_raises(Idna::Errors) { ascii.call("a.example.", Uts46::Hyphens::Allow, Uts46::DnsLength::Verify) }
    assert_raises(TypeError) { ascii.call("a.example", :Allow, Uts46::DnsLength::Verify) }
    assert_raises(TypeError) { ascii.call("a.example", Uts46::DnsLength::Verify, Uts46::Hyphens::Allow) }
  end

  def test_verify_dns_length
    assert Uts46.verify_dns_length("example.com.", true)
    refute Uts46.verify_dns_length("example.com.", false)
    refute Uts46.verify_dns_length("#{'a' * 64}.com", true)
    refute Uts46.verify_dns_length("a..com", true)
    assert Uts46.verify_dns_length("#{'a.' * 126}a", false)
    refute Uts46.verify_dns_length("#{'a.' * 127}a", false)
  end

  def test_the_user_interface_callback_decides_each_non_ascii_label
    calls = []
    text, errors = Uts46::Uts46.new.to_user_interface("xn--53h.xn--bcher-kva.example", URL,
      Uts46::Hyphens::Allow) do |label, tld, bidi|
      calls << [label, tld, bidi]
      label != "☕"
    end

    assert_equal "xn--53h.bücher.example", text
    assert_nil errors
    assert_equal [["☕", "example", false], ["bücher", "example", false]], calls
  end

  def test_the_callback_may_be_any_callable_but_not_both
    uts46 = Uts46::Uts46.new
    always = -> (*) { true }

    assert_equal ["☕.example", nil], uts46.to_user_interface("xn--53h.example", URL, Uts46::Hyphens::Allow, always)
    assert_raises(ArgumentError) { uts46.to_user_interface("a", URL, Uts46::Hyphens::Allow, always) { true } }
    assert_raises(ArgumentError) { uts46.to_user_interface("a", URL, Uts46::Hyphens::Allow) }
    assert_raises(TypeError) { uts46.to_user_interface("a", URL, Uts46::Hyphens::Allow, 42) }
  end

  def test_an_exception_from_the_callback_stops_it_and_is_raised_after_idna
    calls = 0
    error = assert_raises(RuntimeError) do
      Uts46::Uts46.new.to_user_interface("☕.bücher.example", URL, Uts46::Hyphens::Allow) do
        calls += 1
        raise "boom"
      end
    end

    assert_equal "boom", error.message
    assert_equal 1, calls
  end

  def test_a_throw_from_the_callback_leaves_idna
    caught = catch(:done) do
      Uts46::Uts46.new.to_user_interface("☕.example", URL, Uts46::Hyphens::Allow) { throw :done, :thrown }
    end

    assert_equal :thrown, caught
  end

  def test_process_fills_both_sinks
    display = +"display: "
    lookup = +"lookup: "
    outcome = Uts46::Uts46.new.process("Bücher.example", URL, Uts46::Hyphens::Allow,
      Uts46::ErrorPolicy::MarkErrors, -> (*) { true }, display, lookup)

    assert_same Uts46::ProcessingSuccess::WroteToSink, outcome
    assert_equal "display: bücher.example", display
    assert_equal "lookup: xn--bcher-kva.example", lookup
  end

  def test_process_passes_ascii_through_and_takes_no_ascii_sink
    sink = +""

    assert_same Uts46::ProcessingSuccess::Passthrough,
      Uts46::Uts46.new.process("example.com", URL, Uts46::Hyphens::Allow, Uts46::ErrorPolicy::FailFast,
        -> (*) { false }, sink, nil)
    assert_empty sink
  end

  def test_process_raises_a_validity_error_with_marked_output
    sink = +""
    error = assert_raises(Uts46::ProcessingError::ValidityError) do
      Uts46::Uts46.new.process("xn--a.example", URL, Uts46::Hyphens::Allow, Uts46::ErrorPolicy::MarkErrors,
        -> (*) { true }, sink, nil)
    end

    assert_equal "ValidityError", error.message
    assert_kind_of Uts46::ProcessingError, error
    assert_equal "�.example", sink

    fail_fast = +""
    assert_raises(Uts46::ProcessingError::ValidityError) do
      Uts46::Uts46.new.process("xn--a.example", URL, Uts46::Hyphens::Allow, Uts46::ErrorPolicy::FailFast,
        -> (*) { true }, fail_fast, nil)
    end
    assert_empty fail_fast
  end

  def test_a_sink_is_a_string_you_may_change
    uts46 = Uts46::Uts46.new
    process = -> (sink, ascii) { uts46.process("a", URL, Uts46::Hyphens::Allow, Uts46::ErrorPolicy::FailFast, -> (*) { true }, sink, ascii) }

    assert_raises(FrozenError) { process.call("frozen", nil) }
    assert_raises(FrozenError) { process.call(+"", "frozen") }
    assert_raises(TypeError) { process.call([], nil) }
    assert_equal "SinkError", Uts46::ProcessingError::SinkError.new.message
  end

  def test_uts46_is_a_frozen_default
    assert_predicate Uts46::Uts46.new, :frozen?
    assert_instance_of Uts46::Uts46, Uts46::Uts46.default
  end

  def test_config_setters_return_a_new_config_and_keep_the_receiver
    base = config_class.default
    strict = base.use_std3_ascii_rules(true)

    refute_same base, strict
    assert_predicate strict, :frozen?
    assert_equal "a_b.example", base.to_ascii("a_b.example")
    assert_raises(Idna::Errors) { strict.to_ascii("a_b.example") }
    assert_same base, base.use_idna_2008_rules(false)
    assert_equal ["☕.example", nil], base.to_unicode("xn--53h.example")
    assert_raises(NoMethodError) { config_class.new(false, false, false, false) }
  end

  def test_use_idna_2008_rules_true_raises_idnas_message
    error = assert_raises(ArgumentError) { config_class.default.use_idna_2008_rules(true) }

    assert_equal "IDNA 2008 rules are no longer supported", error.message
  end

  def test_idna_appends_to_out_and_checks_its_whole_length
    out = +"host: "

    assert_nil idna_class.default.to_ascii("☕.example", out)
    assert_equal "host: xn--53h.example", out

    long = +("a" * 250)
    checking = idna_class.new(config_class.default.verify_dns_length(true))
    assert_raises(Idna::Errors) { checking.to_ascii("ü.example", long) }
    assert_equal "#{'a' * 250}xn--tda.example", long
  end

  def test_idna_to_unicode_marks_errors_in_out
    out = +""

    assert_raises(Idna::Errors) { idna_class.default.to_unicode("xn--a.example", out) }
    assert_equal "�.example", out
    assert_raises(FrozenError) { idna_class.default.to_unicode("a", "frozen") }
    assert_raises(TypeError) { idna_class.new(:config) }
  end

  def test_the_deprecated_constants_warn
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    _, warnings = capture_io { [Idna::Config, Idna::Idna] }

    assert_match "constant Ferro::Idna::Config is deprecated", warnings
    assert_match "constant Ferro::Idna::Idna is deprecated", warnings
  ensure
    Warning[:deprecated] = deprecated
  end

  def test_errors_defaults_to_idnas_message
    assert_equal "Errors", Idna::Errors.new.message
    assert_equal "other", Idna::Errors.new("other").message
  end
end
