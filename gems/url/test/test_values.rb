# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "ipaddr"

# What the binding adds around url's API: its errors, values, builders,
# callbacks, and the refusals of what Rust would panic on (plan 005).
class TestValues < Minitest::Test
  include UrlSuite

  def test_each_parse_error_variant_raises_its_class_with_urls_message
    {
      "http://" => [U::ParseError::EmptyHost, "empty host"],
      "http://xn--a/" => [U::ParseError::IdnaError, "invalid international domain name"],
      "http://example.com:99999/" => [U::ParseError::InvalidPort, "invalid port number"],
      "http://1.2.3.4.5/" => [U::ParseError::InvalidIpv4Address, "invalid IPv4 address"],
      "http://[:::1]" => [U::ParseError::InvalidIpv6Address, "invalid IPv6 address"],
      "foo://exa mple/" => [U::ParseError::InvalidDomainCharacter, "invalid domain character"],
      "../main.css" => [U::ParseError::RelativeUrlWithoutBase, "relative URL without a base"],
    }.each do |input, (error_class, message)|
      error = assert_raises(error_class, input) { url(input) }

      assert_equal message, error.message
      assert_equal message, error_class.new.message
      assert_kind_of U::ParseError, error
    end
    cannot = assert_raises(U::ParseError::RelativeUrlWithCannotBeABaseBase) { url("data:text/plain,Stuff").join("x") }
    assert_equal "relative URL with a cannot-be-a-base base", cannot.message
    host = assert_raises(U::ParseError::SetHostOnCannotBeABaseUrl) { url("mailto:a@b").set_host("c") }
    assert_equal "a cannot-be-a-base URL doesn’t have a host to set", host.message
    assert_equal "URLs more than 4 GB are not supported", U::ParseError::Overflow.new.message
  end

  def test_each_unit_error_raises_error_naming_its_function
    mailto = url("mailto:rms@example.net")
    {
      -> { mailto.set_port(80) } => "url::Url::set_port",
      -> { mailto.set_ip_host(IPAddr.new("127.0.0.1")) } => "url::Url::set_ip_host",
      -> { mailto.set_password("x") } => "url::Url::set_password",
      -> { mailto.set_username("x") } => "url::Url::set_username",
      -> { mailto.set_scheme("https") } => "url::Url::set_scheme",
      -> { mailto.path_segments_mut } => "url::Url::path_segments_mut",
      -> { Url.from_file_path("relative") } => "url::Url::from_file_path",
      -> { Url.from_directory_path("relative") } => "url::Url::from_directory_path",
      -> { url("http://host/x").to_file_path } => "url::Url::to_file_path",
    }.each do |call, function|
      error = assert_raises(U::Error, function) { call.call }

      assert_equal "#{function} returned Err(())", error.message
    end
    assert_equal "mailto:rms@example.net", mailto.as_str
  end

  def test_a_url_is_comparable_and_hashes_by_its_serialization
    a = url("http://a/")
    b = url("http://b/")

    assert_operator a, :<, b
    assert_nil a <=> "http://a/"
    refute_equal a, "http://a/"
    assert_equal({ a => 1 }[url("http://a")], 1)
    refute_respond_to a, :to_str
    assert_equal "http://a/", a.to_s
  end

  def test_debug_is_urls_debug_text
    assert_equal 'Url { scheme: "https", cannot_be_a_base: false, username: "", password: None, ' \
      'host: Some(Domain("example.net")), port: None, path: "/", query: None, fragment: None }',
      url("https://example.net/").debug
    assert_equal 'Url { scheme: "https", cannot_be_a_base: false, username: "u", password: Some("p"), ' \
      'host: Some(Ipv6(::1)), port: Some(8080), path: "/a", query: Some("b"), fragment: Some("c") }',
      url("https://u:p@[::1]:8080/a?b#c").debug
    assert_equal 'Domain("example.com")', U::Host.parse("example.com").debug
    assert_equal "Ipv4(1.2.3.4)", U::Host.parse("1.2.3.4").debug
    assert_equal "Ipv6(::1)", U::Host.parse("[::1]").debug
    assert_equal 'Tuple("https", Domain("example.com"), 8443)', url("https://example.com:8443/").origin.debug
    opaque = U::Origin.new_opaque

    assert_match(/\AOpaqueOrigin\(\d+\)\z/, opaque.value.debug)
    assert_equal "Opaque(#{opaque.value.debug})", opaque.debug
    assert_equal "BeforePath", Position::BeforePath.debug
    assert_equal "AfterFragment", Position::AfterFragment.debug
    assert_equal "Backslash", U::SyntaxViolation::Backslash.debug
    assert_equal "UnencodedAtSign", U::SyntaxViolation::UnencodedAtSign.debug
    %i[
      EmptyHost
      IdnaError
      InvalidPort
      InvalidIpv4Address
      InvalidIpv6Address
      InvalidDomainCharacter
      RelativeUrlWithoutBase
      RelativeUrlWithCannotBeABaseBase
      SetHostOnCannotBeABaseUrl
      Overflow
].each do |variant|
      assert_equal variant.to_s, U::ParseError.const_get(variant).new.debug
    end
    assert_equal "RelativeUrlWithoutBase", assert_raises(U::ParseError) { url("x") }.debug
  end

  def test_inspect_is_rubys
    assert_match(/\A#<Ferro::Url::Url:0x\h+ /, url("https://example.net/").inspect)
    assert_equal '#<data Ferro::Url::Host::Domain domain="example.com">', U::Host.parse("example.com").inspect
    assert_match(/\A#<Ferro::Url::OpaqueOrigin:0x\h+ /, U::Origin.new_opaque.value.inspect)
    assert_match(/\A#<Ferro::Url::Position:0x\h+ /, Position::BeforePath.inspect)
    assert_match(/\A#<Ferro::Url::SyntaxViolation:0x\h+ /, U::SyntaxViolation::Backslash.inspect)
  end

  def test_hidden_and_deprecated_items_are_not_bound
    target = url("https://example.net/")

    refute_respond_to target, :into_string
    refute_respond_to target, :check_invariants
    refute U.const_defined?(:Quirks, false)
  end

  def test_dup_copies_the_url
    original = url("http://x/")
    copy = original.dup
    copy.set_path("/y")

    assert_equal "http://x/", original.as_str
    assert_equal "http://x/y", copy.as_str
    assert_equal "http://x/", original.clone.as_str
  end

  def test_a_frozen_url_refuses_every_change
    frozen = url("http://x/?q#f").freeze
    [
      -> { frozen.set_path("/y") },
      -> { frozen.set_query(nil) },
      -> { frozen.set_fragment(nil) },
      -> { frozen.set_port(1) },
      -> { frozen.set_host("y") },
      -> { frozen.set_ip_host(IPAddr.new("::1")) },
      -> { frozen.set_password("p") },
      -> { frozen.set_username("u") },
      -> { frozen.set_scheme("https") },
      -> { frozen.query_pairs_mut },
      -> { frozen.path_segments_mut },
      -> { frozen.query_pairs_mut { flunk "the block runs" } },
      -> { frozen.path_segments_mut { flunk "the block runs" } },
    ].each { |change| assert_raises(FrozenError) { change.call } }
    assert_equal "http://x/?q#f", frozen.as_str

    live = url("http://x/")
    segments = live.path_segments_mut
    query = live.query_pairs_mut
    live.freeze

    assert_raises(FrozenError) { segments.push("a") }
    assert_raises(FrozenError) { query.append_pair("a", "b") }
    assert_equal "http://x/?", live.as_str
  end

  def test_a_frozen_urls_native_value_refuses_every_change_by_any_route
    [
      url("http://a/").freeze,
      Ractor.make_shareable(url("http://a/")),
      url("http://a/").freeze.clone,
      url("http://a/").clone(freeze: true),
    ].each do |shared|
      thief = url("http://b/")
      thief.__send__(:initialize_native, shared.__send__(:native))
      [
        -> { thief.set_path("/x") },
        -> { thief.set_query("q") },
        -> { thief.set_fragment("f") },
        -> { thief.set_port(1) },
        -> { thief.set_host("y") },
        -> { thief.set_ip_host(IPAddr.new("::1")) },
        -> { thief.set_password("p") },
        -> { thief.set_username("u") },
        -> { thief.set_scheme("https") },
        -> { thief.query_pairs_mut },
        -> { thief.path_segments_mut },
      ].each do |change|
        error = assert_raises(FrozenError) { change.call }

        assert_equal "can't modify frozen Ferro::Url::Native::Url", error.message
      end
      assert_equal "http://a/", shared.as_str
    end
  end

  def test_an_unfrozen_copy_of_a_frozen_url_changes
    frozen = url("http://a/").freeze
    [frozen.dup, frozen.clone(freeze: false)].each do |copy|
      copy.set_path("/x")

      assert_equal "http://a/x", copy.as_str
    end
    assert_equal "http://a/", frozen.as_str
  end

  def test_url_new_is_private
    assert_raises(NoMethodError) { Url.new }
  end

  def test_parse_options_setters_return_a_new_value
    base = url("https://example.net/a/")
    options = Url.options
    with_base = options.base_url(base)

    refute_same options, with_base
    assert_predicate with_base, :frozen?
    assert_raises(U::ParseError::RelativeUrlWithoutBase) { options.parse("b") }
    assert_equal "https://example.net/a/b", with_base.parse("b").as_str
    assert_equal "https://example.net/a/b", with_base.base_url(base).parse("b").as_str
    assert_raises(U::ParseError::RelativeUrlWithoutBase) { with_base.base_url(nil).parse("b") }
    assert_raises(TypeError) { options.base_url("https://example.net/") }
    assert_raises(TypeError) { options.encoding_override(42) }
    assert_raises(TypeError) { options.syntax_violation_callback(:nope) }
  end

  def test_the_encoding_override_reaches_the_query
    latin1 = -> (text) { text.encode("ISO-8859-1").b }

    assert_equal "q=%E9", Url.options.encoding_override(latin1).parse("http://example.com/?q=é").query
    assert_equal "q=%C3%A9", Url.options.parse("http://example.com/?q=é").query
    error = assert_raises(TypeError) { Url.options.encoding_override(-> (_) { 1 }).parse("http://e/?q") }
    assert_match "an encoding override must return a String", error.message
  end

  def test_an_exception_from_a_parse_callback_stops_it_and_is_raised_after_url
    calls = 0
    error = assert_raises(RuntimeError) do
      Url.options.syntax_violation_callback(lambda { |_|
        calls += 1
        raise "boom"
      }).parse("http:////example.com\\a\\b")
    end

    assert_equal "boom", error.message
    assert_equal 1, calls
    caught = catch(:done) { Url.options.encoding_override(-> (_) { throw :done, :thrown }).parse("http://e/?q") }

    assert_equal :thrown, caught
  end

  def test_a_callback_may_change_the_base_without_changing_the_parse
    base = url("https://example.net/a/")
    report = lambda { |_|
      base.set_path("/changed/")
    }

    assert_equal "https://example.net/a/b/c", Url.options.base_url(base).syntax_violation_callback(report).parse("b\\c").as_str
    assert_equal "https://example.net/changed/", base.as_str
  end

  def test_hosts_are_values_ordered_as_url_derives
    domain = U::Host.parse("example.com")
    v4 = U::Host.parse("1.2.3.4")
    v6 = U::Host.parse("[::1]")

    assert_equal [domain, v4, v6], [v6, domain, v4].sort
    assert_equal "1.2.3.4", v4.to_s
    assert_equal "[::1]", v6.to_s
    assert_equal IPAddr.new("::1"), v6.address
    assert_equal U::Host::Domain.new("B%C3%BCcher"), U::Host.parse_opaque("Bücher")
    assert_raises(U::ParseError::InvalidIpv6Address) { U::Host.parse("[x") }
    assert_raises(U::ParseError::InvalidDomainCharacter) { U::Host.parse_opaque("a b") }
    assert_nil domain <=> "example.com"
    assert_raises(TypeError) { U::Host::Ipv4.new(IPAddr.new("::1")).to_s }
    assert_raises(TypeError) { U::Host::Ipv4.new("1.2.3.4").to_s }
  end

  def test_origins_are_values_and_opaque_ones_equal_only_their_copies
    tuple = url("https://example.com:8443/").origin

    assert_equal U::Origin::Tuple.new("https", U::Host::Domain.new("example.com"), 8443), tuple
    assert tuple.is_tuple
    assert_equal "https://example.com:8443", tuple.ascii_serialization
    assert_equal "https://example.com", U::Origin::Tuple.new("https", U::Host::Domain.new("example.com"), 443)
      .ascii_serialization

    opaque = U::Origin.new_opaque

    assert_equal opaque, opaque.dup
    assert_equal opaque.value.hash, opaque.value.dup.hash
    refute_equal opaque, U::Origin.new_opaque
    refute opaque.is_tuple
    assert_equal "null", opaque.ascii_serialization
    assert_raises(NoMethodError) { U::OpaqueOrigin.new(nil) }
    assert_raises(TypeError) { U::Origin::Opaque.new(:fake).ascii_serialization }
  end

  def test_positions_order_as_url_declares_them
    assert_equal Position.constants.min_by { |name| Position.const_get(name) }, :BeforeScheme
    assert_equal(-1, Position::AfterPath <=> Position::BeforeQuery)
    refute_respond_to Position::AfterPath, :<
    assert_nil Position::BeforePath <=> 1
  end

  def test_slicing_takes_exclusive_and_open_ranges_only
    target = url("https://example.com/a?b#c")

    assert_equal "/a?b", target[Position::BeforePath...Position::AfterQuery]
    assert_equal "/a?b#c", target[Position::BeforePath..]
    assert_equal "https://example.com/a?b", target[...Position::AfterQuery]
    error = assert_raises(TypeError) { target[Position::BeforePath..Position::AfterQuery] }

    assert_equal "url has no Index<RangeInclusive<Position>>; use an exclusive range (...)", error.message
    error = assert_raises(TypeError) { target[..Position::AfterQuery] }

    assert_equal "url has no Index<RangeToInclusive<Position>>; use an exclusive range (...)", error.message
    assert_equal "https://example.com/a?b#c", target[nil..nil]
    assert_raises(TypeError) { target[0...3] }
    assert_raises(TypeError) { target[Position::BeforePath] }
    error = assert_raises(RangeError) { target[Position::AfterPath...Position::BeforePath] }

    assert_equal "byte range starts at 21 but ends at 19", error.message
    assert_equal "", target[Position::AfterPassword...Position::BeforePassword]
  end

  def test_syntax_violations_are_frozen_constants_with_urls_text
    assert_equal "expected //", U::SyntaxViolation::ExpectedDoubleSlash.to_s
    assert_predicate U::SyntaxViolation::Backslash, :frozen?
    assert_raises(NoMethodError) { U::SyntaxViolation.new(:Backslash) }
  end

  def test_a_string_serializer_changes_its_target_in_place
    target = +"a=1"
    serializer = U::FormUrlencoded::Serializer.new(target)
    serializer.append_pair("b", "2")

    assert_equal "a=1&b=2", target
    assert_same target, serializer.finish
    %i[clear append_pair append_key_only extend_pairs extend_keys_only].each do |method|
      arguments = { append_pair: %w[c 3], append_key_only: ["c"], extend_pairs: [[%w[c 3]]], extend_keys_only: [["c"]] }
      error = assert_raises(IOError, method.to_s) { serializer.public_send(method, *arguments.fetch(method, [])) }

      assert_equal "url::form_urlencoded::Serializer finished", error.message
    end
    error = assert_raises(IOError) { serializer.finish }

    assert_equal "url::form_urlencoded::Serializer double finish", error.message
    assert_same serializer, serializer.encoding_override(nil)
    assert_equal "a=1&b=2", target
    assert_raises(FrozenError) { U::FormUrlencoded::Serializer.new("frozen").append_pair("a", "b") }
  end

  def test_for_suffix_keeps_the_prefix_and_refuses_a_start_past_the_end
    target = +"?"
    U::FormUrlencoded::Serializer.for_suffix(target, 1).append_pair("q", "1").append_key_only("flag").clear
      .append_pair("r", "2")

    assert_equal "?r=2", target
    error = assert_raises(ArgumentError) { U::FormUrlencoded::Serializer.for_suffix(+"ab", 3) }
    assert_equal "invalid length 3 for target of length 2", error.message
  end

  def test_a_url_query_serializer_keeps_the_fragment_and_finishes_with_the_url
    target = url("https://example.net/?lang=fr#nav")
    serializer = target.query_pairs_mut.extend_keys_only(%w[a b])

    assert_equal "https://example.net/?lang=fr&a&b#nav", target.as_str
    assert_same target, serializer.finish
    target.query_pairs_mut.clear

    assert_equal "https://example.net/?#nav", target.as_str
  end

  def test_a_serializers_encodings_are_computed_first_in_form_urlencodeds_order
    seen = []
    encoding = lambda { |text|
      seen << text
      text.upcase
    }
    target = url("http://x/#f")
    target.query_pairs_mut.encoding_override(encoding).extend_pairs({ "a" => "b", "c" => "d" })

    assert_equal %w[a b c d], seen
    assert_equal "http://x/?A=B&C=D#f", target.as_str
    error = assert_raises(RuntimeError) do
      target.query_pairs_mut.encoding_override(-> (_) { raise "boom" }).append_pair("e", "f")
    end
    assert_equal "boom", error.message
    assert_equal "http://x/?A=B&C=D#f", target.as_str
  end

  def test_query_pairs_mut_gives_the_url_a_query_as_url_does
    target = url("http://a/b#f")

    assert_same target, target.query_pairs_mut.finish
    assert_equal "http://a/b?#f", target.as_str
    assert_equal "", target.query
  end

  def test_a_suffix_inside_a_character_is_refused_only_where_clear_would_panic
    target = +"é"
    serializer = U::FormUrlencoded::Serializer.for_suffix(target, 1).append_pair("q", "1")

    assert_equal "é&q=1", target
    error = assert_raises(ArgumentError) { serializer.clear }

    assert_equal "assertion failed: self.is_char_boundary(new_len)", error.message
    assert_equal "é&q=1", target
    target = +"é"
    serializer = U::FormUrlencoded::Serializer.for_suffix(target, 2)
    target.replace("aé")
    assert_raises(ArgumentError) { serializer.clear }
  end

  def test_path_segments_mut_with_a_block_drops_the_guard_when_the_block_ends
    target = url("https://github.com/servo/rust-url/")
    kept = nil
    result = target.path_segments_mut do |segments|
      kept = segments
      segments.pop_if_empty.push("pulls")
      :done
    end

    assert_equal :done, result
    assert_equal "https://github.com/servo/rust-url/pulls", target.as_str
    [
      -> { kept.clear },
      -> { kept.pop_if_empty },
      -> { kept.pop },
      -> { kept.push("x") },
      -> { kept.extend(["x"]) },
      -> { kept.debug },
].each do |call|
      error = assert_raises(IOError) { call.call }

      assert_equal "PathSegmentsMut dropped at the end of Url#path_segments_mut's block", error.message
    end
    assert_equal "https://github.com/servo/rust-url/pulls", target.as_str
    assert_raises(RuntimeError) do
      target.path_segments_mut do |segments|
        kept = segments
        raise "boom"
      end
    end
    assert_raises(IOError) { kept.pop }
    assert_raises(U::Error) { url("mailto:a@b").path_segments_mut { flunk "the block runs" } }
  end

  def test_path_segments_mut_with_a_block_drops_the_guard_on_break_and_throw
    target = url("https://example.com/a")
    kept = nil
    result = target.path_segments_mut do |segments|
      kept = segments
      segments.push("b")
      break :broken
    end

    assert_equal :broken, result
    assert_raises(IOError) { kept.push("c") }
    caught = catch(:out) do
      target.path_segments_mut do |segments|
        kept = segments
        segments.push("c")
        throw :out, :thrown
      end
    end

    assert_equal :thrown, caught
    assert_raises(IOError) { kept.debug }
    assert_equal "https://example.com/a/b/c", target.as_str
  end

  def test_query_pairs_mut_with_a_block_drops_the_serializer_on_break_and_throw
    target = url("https://example.net/#nav")
    kept = nil
    result = target.query_pairs_mut do |query|
      kept = query
      query.append_pair("a", "1")
      break :broken
    end

    assert_equal :broken, result
    assert_raises(IOError) { kept.append_pair("x", "y") }
    caught = catch(:out) do
      target.query_pairs_mut do |query|
        kept = query
        query.append_pair("b", "2")
        throw :out, :thrown
      end
    end

    assert_equal :thrown, caught
    assert_raises(IOError) { kept.finish }
    assert_equal "https://example.net/?a=1&b=2#nav", target.as_str
  end

  def test_query_pairs_mut_with_a_block_drops_the_serializer_when_the_block_ends
    target = url("https://example.net/?lang=fr#nav")
    kept = nil
    result = target.query_pairs_mut do |query|
      kept = query
      query.append_pair("foo", "bar")
      :done
    end

    assert_equal :done, result
    assert_equal "https://example.net/?lang=fr&foo=bar#nav", target.as_str
    [-> { kept.append_pair("a", "b") }, -> { kept.clear }, -> { kept.finish }, -> { kept.encoding_override(nil) }]
      .each do |call|
        error = assert_raises(IOError) { call.call }

        assert_equal "url::form_urlencoded::Serializer dropped at the end of Url#query_pairs_mut's block", error.message
    end
    assert_same target, target.query_pairs_mut(&:finish)
    assert_equal "https://example.net/?lang=fr&foo=bar#nav", target.as_str
  end

  def test_path_segments_mut_debug_is_the_guards_debug_text
    fresh = 'PathSegmentsMut { url: Url { scheme: "https", cannot_be_a_base: false, username: "", password: None, ' \
      'host: Some(Domain("example.com")), port: None, path: "/a", query: None, fragment: None }, ' \
      'after_first_slash: 20, after_path: "", old_after_path_position: 21 }'
    pushed = fresh.sub('path: "/a"', 'path: "/a/d"')
    target = url("https://example.com/a")
    target.path_segments_mut do |segments|
      assert_equal fresh, segments.debug
      segments.push("d")

      assert_equal pushed, segments.debug
    end
    segments = url("https://example.com/a").path_segments_mut

    assert_equal fresh, segments.debug
    assert_equal pushed, segments.push("d").debug
  end

  def test_path_segments_mut_debug_refuses_where_urls_debug_would_panic_with_its_text
    [
      ["https://example.com/a?b", [], "start byte index 22 is out of bounds for string of length 21"],
      ["https://example.com/abc?q", [:pop], "end byte index 23 is out of bounds for string of length 20"],
      ["https://example.com/abc#f", [:clear], "end byte index 23 is out of bounds for string of length 20"],
      ["https://example.com/a#c", [], "start byte index 22 is out of bounds for string of length 21"],
      ["https://example.com/a?b#c", [[:push, "x"]], "start byte index 24 is out of bounds for string of length 23"],
      ["https://example.com/a?bcd#e", [[:push, "x"]], "end byte index 25 is out of bounds for string of length 23"],
    ].each do |input, calls, message|
      segments = url(input).path_segments_mut
      calls.each { |call| segments.public_send(*call) }
      error = nil
      _, err = capture_subprocess_io { error = assert_raises(ArgumentError) { segments.debug } }

      assert_equal message, error.message, input
      assert_empty err, "#{input}: no panic reaches Rust's panic hook"
    end
  end

  def test_path_segments_mut_debug_answers_urls_wrong_bytes_where_it_would_not_panic
    segments = url("https://example.com/a?b").path_segments_mut.push("xyz")
    text = nil
    _, err = capture_subprocess_io { text = segments.debug }

    assert_equal 'PathSegmentsMut { url: Url { scheme: "https", cannot_be_a_base: false, username: "", password: None, ' \
      'host: Some(Domain("example.com")), port: None, path: "/a", query: Some("xyz"), fragment: None }, ' \
      'after_first_slash: 20, after_path: "?b", old_after_path_position: 21 }', text
    assert_empty err
  end

  def test_path_segments_mut_debug_keeps_copies_of_the_segments_it_was_given
    target = url("https://example.com/a")
    segment = +"b"
    segments = [+"c", +"d"]
    guard = target.path_segments_mut.push(segment).extend(segments)
    expected = guard.debug
    segment << "changed"
    segments[0] << "changed"
    segments << "e"

    assert_equal "https://example.com/a/b/c/d", target.as_str
    assert_equal expected, guard.debug
    assert_includes expected, 'path: "/a/b/c/d"'
  end

  def test_path_segments_mut_returns_itself
    target = url("https://github.com/servo/rust-url/")
    segments = target.path_segments_mut

    assert_same segments, segments.pop_if_empty.push("pulls")
    assert_equal "https://github.com/servo/rust-url/pulls", target.as_str
    segments.clear.extend(%w[a b])

    assert_equal "https://github.com/a/b", target.as_str
  end

  def test_path_segments_and_query_pairs_keep_what_they_read
    target = url("https://example.com/a/b?x=1")
    segments = target.path_segments
    pairs = target.query_pairs
    target.set_path("/c")
    target.set_query(nil)

    assert_equal %w[a b], segments.to_a
    assert_instance_of U::FormUrlencoded::Parse, pairs
    assert_equal [%w[x 1]], pairs.to_a
  end

  def test_parse_is_an_iterator_whose_copies_keep_their_place
    pairs = U::FormUrlencoded.parse("a=1&&b=2&c")

    assert_kind_of Enumerable, pairs
    assert_equal %w[a 1], pairs.next
    copy = pairs.dup

    assert_equal [%w[b 2], ["c", ""]], pairs.to_a
    assert_nil pairs.next
    assert_empty pairs.to_a
    assert_equal %w[b 2], copy.next
    assert_equal [%w[c]], copy.map { |name, _value| [name] }
    assert_instance_of Enumerator, U::FormUrlencoded.parse("a").each
  end

  def test_byte_serialize_is_an_iterator_with_urls_debug_and_size_hint
    chunks = U::FormUrlencoded.byte_serialize("a b")

    assert_kind_of Enumerable, chunks
    assert_equal "ByteSerialize { bytes: [97, 32, 98] }", chunks.debug
    assert_equal [1, 3], chunks.size_hint
    assert_equal "a", chunks.next
    assert_equal "ByteSerialize { bytes: [32, 98] }", chunks.debug
    assert_equal [1, 2], chunks.size_hint
    assert_equal %w[+ b], chunks.to_a
    assert_nil chunks.next
    assert_equal "ByteSerialize { bytes: [] }", chunks.debug
    assert_equal [0, 0], chunks.size_hint
    assert_raises(TypeError) { chunks.dup }
    assert_raises(TypeError) { chunks.clone }
  end

  def test_form_urlencoded_parse_and_byte_serialize_take_bytes
    assert_equal [["�", "1"]], U::FormUrlencoded.parse("%FF=1").to_a
    assert_equal [["�", ""]], U::FormUrlencoded.parse("\xFF".b).to_a
    assert_equal "%FF", U::FormUrlencoded.byte_serialize("\xFF".b).to_a.join
    assert_equal %w[bar + %26 + baz], U::FormUrlencoded.byte_serialize("bar & baz").to_a
  end

  def test_parse_with_params_takes_any_enumerable_of_pairs
    assert_equal "https://example.net/?a=1&b=2", Url.parse_with_params("https://example.net", { "a" => "1", "b" => "2" }).as_str
    assert_equal "https://example.net/?a=1", Url.parse_with_params("https://example.net", [%w[a 1]].each).as_str
  end

  def test_from_str_and_try_from_are_parse
    assert_equal url("https://example.net/"), Url.from_str("https://example.net")
    assert_equal url("https://example.net/"), Url.try_from("https://example.net")
    assert_raises(U::ParseError::RelativeUrlWithoutBase) { Url.try_from("x") }
  end

  def test_from_file_path_takes_to_path
    skip "Unix paths" if Gem.win_platform?
    assert_equal "file:///tmp/a%20b", Url.from_file_path(Pathname.new("/tmp/a b")).as_str
    assert_raises(TypeError) { Url.from_file_path(42) }
  end

  def test_set_ip_host_takes_an_ipaddr
    target = url("http://example.com/")

    assert_raises(TypeError) { target.set_ip_host("127.0.0.1") }
    target.set_ip_host(IPAddr.new("10.0.0.1"))

    assert_equal "http://10.0.0.1/", target.as_str
  end

  def test_socket_addrs_resolves_the_url_as_it_was_when_called
    target = url("custom://127.0.0.1/")
    addresses = target.socket_addrs do
      target.set_port(80)
      9743
    end

    assert_equal 9743, addresses.first.ip_port
    assert_equal "custom://127.0.0.1:80/", target.as_str
  end

  def test_socket_addrs_errors
    error = assert_raises(IOError) { url("data:text/plain,hi").socket_addrs }

    assert_equal "No host name in the URL", error.message
    error = assert_raises(IOError) { url("custom://127.0.0.1/").socket_addrs }
    assert_equal "No port number in the URL", error.message
    assert_raises(IOError) { url("http://does-not-exist.invalid/").socket_addrs }
  end
end
