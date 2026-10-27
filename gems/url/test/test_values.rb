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
      -> { U::Quirks.set_protocol(mailto, "https") } => "url::quirks::set_protocol",
      -> { U::Quirks.set_username(mailto, "x") } => "url::quirks::set_username",
      -> { U::Quirks.set_password(mailto, "x") } => "url::quirks::set_password",
      -> { U::Quirks.set_host(mailto, "x") } => "url::quirks::set_host",
      -> { U::Quirks.set_hostname(mailto, "x") } => "url::quirks::set_hostname",
      -> { U::Quirks.set_port(mailto, "80") } => "url::quirks::set_port",
    }.each do |call, function|
      error = assert_raises(U::Error, function) { call.call }

      assert_equal "#{function} returned Err(())", error.message
    end
    assert_equal "mailto:rms@example.net", mailto.as_str
  end

  def test_check_invariants_holds_for_urls_own_values
    assert_nil url("https://user:pass@example.com:8080/a?b#c").check_invariants
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

  def test_inspect_is_urls_debug_text
    assert_equal 'Url { scheme: "https", cannot_be_a_base: false, username: "", password: None, ' \
      'host: Some(Domain("example.net")), port: None, path: "/", query: None, fragment: None }',
      url("https://example.net/").inspect
  end

  def test_into_string_is_deprecated
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    value = nil
    _, warnings = capture_io { value = url("https://example.net/").into_string }

    assert_equal "https://example.net/", value
    assert_match "Ferro::Url::Url#into_string is deprecated since url 2.3.0; use #to_s", warnings
  ensure
    Warning[:deprecated] = deprecated
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
      -> { U::Quirks.set_hash(frozen, "g") },
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
    assert_match(/\AOpaqueOrigin\(\d+\)\z/, opaque.value.inspect)
    assert_raises(NoMethodError) { U::OpaqueOrigin.new(nil) }
    assert_raises(TypeError) { U::Origin::Opaque.new(:fake).ascii_serialization }
  end

  def test_positions_order_as_url_declares_them
    assert_equal Position.constants.min_by { |name| Position.const_get(name) }, :BeforeScheme
    assert_operator Position::AfterPath, :<, Position::BeforeQuery
    assert_equal "Ferro::Url::Position::BeforePath", Position::BeforePath.inspect
    assert_nil Position::BeforePath <=> 1
  end

  def test_slicing_takes_exclusive_and_open_ranges_only
    target = url("https://example.com/a?b#c")

    assert_equal "/a?b", target[Position::BeforePath...Position::AfterQuery]
    assert_equal "/a?b#c", target[Position::BeforePath..]
    assert_equal "https://example.com/a?b", target[...Position::AfterQuery]
    assert_raises(TypeError) { target[Position::BeforePath..Position::AfterQuery] }
    assert_raises(TypeError) { target[0...3] }
    assert_raises(TypeError) { target[Position::BeforePath] }
    error = assert_raises(U::Error) { target[Position::AfterPath...Position::BeforePath] }

    assert_equal "the slice starts at Position::AfterPath (byte 21) but ends at Position::BeforePath (byte 19)",
      error.message
    assert_equal "", target[Position::AfterPassword...Position::BeforePassword]
  end

  def test_syntax_violations_are_frozen_constants_with_urls_text
    assert_equal "expected //", U::SyntaxViolation::ExpectedDoubleSlash.to_s
    assert_equal "Ferro::Url::SyntaxViolation::Backslash", U::SyntaxViolation::Backslash.inspect
    assert_predicate U::SyntaxViolation::Backslash, :frozen?
    assert_raises(NoMethodError) { U::SyntaxViolation.new(:Backslash) }
  end

  def test_a_string_serializer_changes_its_target_in_place
    target = +"a=1"
    serializer = U::FormUrlencoded::Serializer.new(target)
    serializer.append_pair("b", "2")

    assert_equal "a=1&b=2", target
    assert_same target, serializer.finish
    error = assert_raises(U::Error) { serializer.append_pair("c", "3") }
    assert_equal "url::form_urlencoded::Serializer finished", error.message
    error = assert_raises(U::Error) { serializer.finish }
    assert_equal "url::form_urlencoded::Serializer double finish", error.message
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

  def test_a_suffix_cannot_start_inside_a_character
    error = assert_raises(ArgumentError) { U::FormUrlencoded::Serializer.for_suffix(+"é", 1) }

    assert_equal "start position 1 is inside a character of the target", error.message
    target = +"é"
    serializer = U::FormUrlencoded::Serializer.for_suffix(target, 2)
    target.replace("aé")
    assert_raises(ArgumentError) { serializer.clear }
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
    assert_equal [%w[x 1]], pairs.to_a
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

  def test_socket_addrs_errors
    error = assert_raises(IOError) { url("data:text/plain,hi").socket_addrs }

    assert_equal "No host name in the URL", error.message
    error = assert_raises(IOError) { url("custom://127.0.0.1/").socket_addrs }
    assert_equal "No port number in the URL", error.message
    assert_raises(IOError) { url("http://does-not-exist.invalid/").socket_addrs }
  end

  def test_the_quirks_getters
    target = url("https://user:pass@example.com:8080/a?b#c")
    q = U::Quirks

    assert_equal [
      "https://user:pass@example.com:8080/a?b#c",
      "https://example.com:8080",
      "https:",
      "user",
      "pass",
      "example.com:8080",
      "example.com",
      "8080",
      "/a",
      "?b",
      "#c",
],
      %i[href origin protocol username password host hostname port pathname search hash].map { |name| q.public_send(name, target) }
  end
end
