# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"
require "ipaddr"
require "socket"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: MIT OR Apache-2.0
# SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
# SPDX-SnippetComment: ported from url 2.5.8 tests/unit.rs
#++

# url's unit tests, ported. Left out: +size+ (Rust's memory layout) and
# +serde_error_message+ (serde). Windows' path tests run only on Windows.
class TestUnit < Minitest::Test
  include UrlSuite

  WINDOWS = Gem.win_platform?

  private def no_error
    yield
    true
  rescue U::Error, U::ParseError
    false
  end

  def test_relative
    assert_equal "sc://%C3%B1/resources/testharness.js", url("sc://%C3%B1").join("/resources/testharness.js").as_str
    assert_equal "sc://%C3%B1", url("sc://%C3%B1").join("").as_str
  end

  def test_strip_trailing_spaces_from_opaque_path
    query = url("data:space   ?query")
    query.set_query(nil)

    assert_equal "data:space", query.as_str
    hash = url("data:space   #hash")
    hash.set_fragment(nil)

    assert_equal "data:space", hash.as_str
  end

  def test_set_empty_host
    base = url("moz://foo:bar@servo/baz")
    base.set_username("")

    assert_equal "moz://:bar@servo/baz", base.as_str
    base.set_host(nil)

    assert_equal "moz:/baz", base.as_str
    base.set_host("servo")

    assert_equal "moz://servo/baz", base.as_str

    share = url("file://server/share/foo/bar")
    share.set_host(nil)

    assert_equal "file:///share/foo/bar", share.as_str
    share = url("file://server/share/foo/bar")
    share.set_host("foo")

    assert_equal "file://foo/share/foo/bar", share.as_str
  end

  def test_set_empty_username_and_password
    base = url("moz://foo:bar@servo/baz")
    base.set_username("")

    assert_equal "moz://:bar@servo/baz", base.as_str
    base.set_password("")

    assert_equal "moz://servo/baz", base.as_str
    base.set_password(nil)

    assert_equal "moz://servo/baz", base.as_str
  end

  def test_set_empty_password
    base = url("moz://foo:bar@servo/baz")
    base.set_password("")

    assert_equal "moz://foo@servo/baz", base.as_str
    base.set_password(nil)

    assert_equal "moz://foo@servo/baz", base.as_str
  end

  def test_set_empty_hostname
    refute no_error { U::Quirks.set_hostname(url("moz://foo@servo/baz"), "") }, "a URL with a username"
    refute no_error { U::Quirks.set_hostname(url("moz://:pass@servo/baz"), "") }, "a URL with a password"
    base = url("moz://servo/baz")
    U::Quirks.set_hostname(base, "")

    assert_equal "moz:///baz", base.as_str
  end

  def test_set_empty_query
    base = url("moz://example.com/path?query")
    base.set_query("")

    assert_equal "moz://example.com/path?", base.as_str
    base.set_query(nil)

    assert_equal "moz://example.com/path", base.as_str
  end

  private def assert_from_file_path(path, url_path = path)
    converted = Url.from_file_path(path)

    assert_nil converted.host
    assert_equal url_path, converted.path
    assert_equal path.b, converted.to_file_path.b
  end

  def test_new_file_paths
    assert_raises(U::Error) { Url.from_file_path("relative") }
    if WINDOWS
      assert_raises(U::Error) { Url.from_file_path("..\\relative") }
      assert_raises(U::Error) { Url.from_file_path("\\drive-relative") }
      assert_raises(U::Error) { Url.from_file_path("\\\\ucn\\") }
    else
      assert_raises(U::Error) { Url.from_file_path("../relative") }
      assert_from_file_path("/foo/bar")
      assert_from_file_path("/foo/ba\0r", "/foo/ba%00r")
      assert_from_file_path("/foo/ba%00r", "/foo/ba%2500r")
      assert_from_file_path("/foo/ba\\r", "/foo/ba%5Cr")
    end
  end

  def test_new_path_bad_utf8
    skip "Unix paths are bytes; Windows paths are UTF-16" if WINDOWS

    converted = Url.from_file_path("/foo/ba\x80r".b)

    assert_equal "/foo/ba\x80r".b, converted.to_file_path.b
  end

  def test_new_path_windows_fun
    skip "Windows only" unless WINDOWS

    assert_from_file_path("C:\\foo\\bar", "/C:/foo/bar")
    assert_from_file_path("C:\\foo\\ba\0r", "/C:/foo/ba%00r")
    assert_raises(U::Error) { url("file:///C:/foo/ba%80r").to_file_path }
    Url.from_file_path("\\\\?\\C:\\foo\\bar")

    assert_equal "C:\\foo\\bar", url("file:///C%3A/foo/bar").to_file_path
  end

  def test_new_directory_paths
    assert_raises(U::Error) { Url.from_directory_path("relative") }
    if WINDOWS
      assert_raises(U::Error) { Url.from_directory_path("..\\relative") }
      assert_raises(U::Error) { Url.from_directory_path("\\drive-relative") }
      assert_raises(U::Error) { Url.from_directory_path("\\\\ucn\\") }
      converted = Url.from_directory_path("C:\\foo\\bar")

      assert_equal "/C:/foo/bar/", converted.path
    else
      assert_raises(U::Error) { Url.from_directory_path("../relative") }
      converted = Url.from_directory_path("/foo/bar")

      assert_nil converted.host
      assert_equal "/foo/bar/", converted.path
    end
  end

  def test_path_backslash_fun
    special = url("http://foobar.com")
    special.path_segments_mut.push("foo\\bar")

    assert_equal "http://foobar.com/foo%5Cbar", special.as_str
    nonspecial = url("thing://foobar.com")
    nonspecial.path_segments_mut.push("foo\\bar")

    assert_equal "thing://foobar.com/foo\\bar", nonspecial.as_str
  end

  def test_from_str
    assert_instance_of Url, Url.from_str("http://testing.com/this")
  end

  def test_parse_with_params
    assert_equal "http://testing.com/this?dont=clobberme&lang=rust",
      Url.parse_with_params("http://testing.com/this?dont=clobberme", [%w[lang rust]]).as_str
  end

  def test_issue_124
    assert_equal "/a", url("file:a").path
    assert_equal "/...", url("file:...").path
    assert_equal "/", url("file:..").path
  end

  private def check_eq(left, right)
    assert_equal left, right
    assert_equal left.hash, right.hash
    assert left.eql?(right)
  end

  def test_equality
    check_eq(url("https://example.com/"), url("https://example.com:443/"))
    refute_equal url("http://example.com/"), url("http://example.com:8080/")
    refute_equal url("http://example.com/"), url("https://example.com/")
    refute_equal url("http://foo.com/"), url("http://bar.com/")
    check_eq(url("http://foo.com"), url("http://foo.com/"))
  end

  def test_host
    assert_equal U::Host::Domain.new("www.mozilla.org"), url("http://www.mozilla.org").host
    assert_equal U::Host::Ipv4.new(IPAddr.new("1.35.33.49")), url("http://1.35.33.49").host
    assert_equal U::Host::Ipv6.new(IPAddr.new("2001:0db8:85a3:08d3:1319:8a2e:0370:7344")),
      url("http://[2001:0db8:85a3:08d3:1319:8a2e:0370:7344]").host
    assert_equal U::Host::Ipv6.new(IPAddr.new("::")), url("http://[::]").host
    assert_equal U::Host::Ipv6.new(IPAddr.new("::1")), url("http://[::1]").host
    assert_equal U::Host::Ipv4.new(IPAddr.new("1.35.33.49")), url("http://0x1.0X23.0x21.061").host
    assert_equal U::Host::Ipv4.new(IPAddr.new("1.35.33.49")), url("http://0x1232131").host
    assert_equal U::Host::Ipv4.new(IPAddr.new("0.0.0.111")), url("http://111").host
    ["http://1.35.+33.49", "http://2..2.3", "http://42.0x1232131", "http://192.168.0.257"].each do |input|
      assert_raises(U::ParseError, input) { url(input) }
    end
    assert_equal U::Host::Domain.new("foo"), U::Host::Domain.new("foo")
    refute_equal U::Host::Domain.new("foo"), U::Host::Domain.new("bar")
  end

  def test_host_serialization
    assert_equal "[::2]", url("http://[0::2]").host_str
    assert_equal "[::ffff:0:2]", url("http://[0::ffff:0:2]").host_str
  end

  def test_idna
    assert_instance_of Url, url("http://goșu.ro")
    assert_equal U::Host::Domain.new("xn--n3h.net"), url("http://☃.net/").host
    assert_instance_of Url, url("https://r2---sn-huoa-cvhl.googlevideo.com/crossdomain.xml")
  end

  def test_serialization
    {
      "http://example.com/" => "http://example.com/",
      "http://addslash.com" => "http://addslash.com/",
      "http://@emptyuser.com/" => "http://emptyuser.com/",
      "http://:@emptypass.com/" => "http://emptypass.com/",
      "http://user@user.com/" => "http://user@user.com/",
      "http://user:pass@userpass.com/" => "http://user:pass@userpass.com/",
      "http://slashquery.com/path/?q=something" => "http://slashquery.com/path/?q=something",
      "http://noslashquery.com/path?q=something" => "http://noslashquery.com/path?q=something",
    }.each { |input, result| assert_equal result, url(input).as_str }
  end

  def test_form_urlencoded
    pairs = [["foo", "é&"], ["bar", ""], ["foo", "#"]]
    encoded = U::FormUrlencoded::Serializer.new(+"").extend_pairs(pairs).finish

    assert_equal "foo=%C3%A9%26&bar=&foo=%23", encoded
    assert_equal pairs, U::FormUrlencoded.parse(encoded).to_a
  end

  def test_form_serialize
    encoded = U::FormUrlencoded::Serializer.new(+"").append_pair("foo", "é&").append_pair("bar", "")
      .append_pair("foo", "#").append_key_only("json").finish

    assert_equal "foo=%C3%A9%26&bar=&foo=%23&json", encoded
  end

  def test_form_urlencoded_encoding_override
    encoded = U::FormUrlencoded::Serializer.new(+"").encoding_override(lambda(&:upcase))
      .append_pair("foo", "bar").append_key_only("xml").finish

    assert_equal "FOO=BAR&XML", encoded
  end

  # https://github.com/servo/rust-url/issues/61
  def test_issue_61
    secure = url("http://mozilla.org")
    secure.set_scheme("https")

    assert_nil secure.port
    assert_equal 443, secure.port_or_known_default
    assert_nil secure.check_invariants
  end

  # https://github.com/servo/rust-url/issues/197
  def test_issue_197
    skip "Unix only" if WINDOWS

    root = Url.from_file_path("/")

    assert_nil root.check_invariants
    assert_equal url("file:///"), root
    root.path_segments_mut.pop_if_empty
  end

  def test_issue_241
    refute_nil url("mailto:").cannot_be_a_base
  end

  # https://github.com/servo/rust-url/issues/222
  def test_append_trailing_slash
    local = url("http://localhost:6767/foo/bar?a=b")
    local.path_segments_mut.push("")

    assert_nil local.check_invariants
    assert_equal "http://localhost:6767/foo/bar/?a=b", local.to_s
  end

  # https://github.com/servo/rust-url/issues/227
  def test_extend_query_pairs_then_mutate
    local = url("http://localhost:6767/foo/bar")
    local.query_pairs_mut.extend_pairs([%w[auth my-token]])

    assert_nil local.check_invariants
    assert_equal "http://localhost:6767/foo/bar?auth=my-token", local.to_s
    local.path_segments_mut.push("some_other_path")

    assert_nil local.check_invariants
    assert_equal "http://localhost:6767/foo/bar/some_other_path?auth=my-token", local.to_s
  end

  def test_append_empty_segment_then_mutate
    local = url("http://localhost:6767/foo/bar?a=b")
    local.path_segments_mut.push("").pop

    assert_nil local.check_invariants
    assert_equal "http://localhost:6767/foo/bar?a=b", local.to_s
  end

  # https://github.com/servo/rust-url/issues/243
  def test_set_host
    hello = url("https://example.net/hello")
    hello.set_host("foo.com")

    assert_equal "https://foo.com/hello", hello.as_str
    assert_raises(U::ParseError) { hello.set_host(nil) }
    assert_equal "https://foo.com/hello", hello.as_str
    assert_raises(U::ParseError) { hello.set_host("") }
    assert_equal "https://foo.com/hello", hello.as_str

    foobar = url("foobar://example.net/hello")
    foobar.set_host(nil)

    assert_equal "foobar:/hello", foobar.as_str
    foo = url("foo://ș")

    assert_equal "foo://%C8%99", foo.as_str
    foo.set_host("goșu.ro")

    assert_equal "foo://go%C8%99u.ro", foo.as_str
  end

  # https://github.com/servo/rust-url/issues/166
  def test_leading_dots
    assert_equal U::Host::Domain.new(".org"), U::Host.parse(".org")
    assert_equal ".", url("file://./foo").domain
  end

  # https://github.com/servo/rust-url/issues/302
  def test_origin_hash
    origin = url("http://example.net/").origin
    others = [
      "http://example.net:80/",
      "http://example.net:81/",
      "http://example.net",
      "http://example.net/hello",
      "https://example.net",
      "ftp://example.net",
      "file://example.net",
      "http://user@example.net/",
      "http://user:pass@example.net/",
].map { |input| url(input).origin }
    others.each do |other|
      if origin == other
        assert_equal origin.hash, other.hash
      else
        refute_equal origin.hash, other.hash
      end
    end

    opaque = url("file://example.net").origin

    refute_equal opaque.hash, url("file://example.net").origin.hash
    refute_equal opaque.hash, url("file://other").origin.hash
  end

  def test_origin_blob_equality
    assert_equal url("http://example.net/").origin, url("blob:http://example.net/").origin
  end

  def test_origin_opaque
    refute U::Origin.new_opaque.is_tuple
    refute url("blob:malformed//").origin.is_tuple
  end

  def test_origin_unicode_serialization
    {
      "http://😅.com" => "http://😅.com",
      "ftp://😅:🙂@🙂.com" => "ftp://🙂.com",
      "https://user@😅.com" => "https://😅.com",
      "http://😅.🙂:40" => "http://😅.🙂:40",
    }.each { |input, expected| assert_equal expected, url(input).origin.unicode_serialization }
    [
      "http://example.net/",
      "http://example.net:80/",
      "http://example.net:81/",
      "http://example.net",
      "http://example.net/hello",
      "https://example.net",
      "ftp://example.net",
      "file://example.net",
      "http://user@example.net/",
      "http://user:pass@example.net/",
      "http://127.0.0.1",
].each do |input|
      origin = url(input).origin

      assert_equal origin.ascii_serialization, origin.unicode_serialization
    end
  end

  def test_socket_addrs
    [
      ["https://127.0.0.1/", "127.0.0.1", 443],
      ["https://127.0.0.1:9742/", "127.0.0.1", 9742],
      ["custom-protocol://127.0.0.1:9742/", "127.0.0.1", 9742],
      ["custom-protocol://127.0.0.1/", "127.0.0.1", 9743],
      ["https://[::1]/", "::1", 443],
      ["https://[::1]:9742/", "::1", 9742],
      ["custom-protocol://[::1]:9742/", "::1", 9742],
      ["custom-protocol://[::1]/", "::1", 9743],
      ["https://localhost/", "localhost", 443],
      ["https://localhost:9742/", "localhost", 9742],
      ["custom-protocol://localhost:9742/", "localhost", 9742],
      ["custom-protocol://localhost/", "localhost", 9743],
    ].each do |input, host, port|
      parsed = url(input)
      addresses = parsed.socket_addrs { (parsed.scheme == "custom-protocol") ? 9743 : nil }
      first = addresses.first

      assert_equal port, first.ip_port, input
      assert_includes Addrinfo.getaddrinfo(host, port, nil, :STREAM).map(&:ip_address), first.ip_address, input
    end
  end

  def test_no_base_url
    no_base = url("mailto:test@example.net")

    assert no_base.cannot_be_a_base
    assert_nil no_base.path_segments
    assert_raises(U::Error) { no_base.path_segments_mut }
    assert_raises(U::ParseError) { no_base.set_host("foo") }
    assert_raises(U::Error) { no_base.set_ip_host(IPAddr.new("127.0.0.1")) }
    no_base.set_path("/foo")

    assert_equal "%2Ffoo", no_base.path
  end

  def test_domain
    assert_nil url("https://127.0.0.1/").domain
    assert_nil url("mailto:test@example.net").domain
    assert_equal "example.com", url("https://example.com/").domain
  end

  def test_query
    products = url("https://example.com/products?page=2#fragment")

    assert_equal "page=2", products.query
    assert_equal %w[page 2], products.query_pairs.first
    assert_nil url("https://example.com/products").query
    assert_equal 0, url("https://example.com/products").query_pairs.count
    spanish = url("https://example.com/?country=español")

    assert_equal "country=espa%C3%B1ol", spanish.query
    assert_equal %w[country español], spanish.query_pairs.first
    sorted = url("https://example.com/products?page=2&sort=desc")

    assert_equal "page=2&sort=desc", sorted.query
    assert_equal [%w[page 2], %w[sort desc]], sorted.query_pairs.to_a
  end

  def test_fragment
    assert_equal "fragment", url("https://example.com/#fragment").fragment
    assert_nil url("https://example.com/").fragment
  end

  def test_set_ip_host
    example = url("http://example.com")
    example.set_ip_host(IPAddr.new("127.0.0.1"))

    assert_equal "127.0.0.1", example.host_str
    example.set_ip_host(IPAddr.new("::1"))

    assert_equal "[::1]", example.host_str
  end

  def test_set_href
    existing = url("https://existing.url")

    assert_raises(U::ParseError) { U::Quirks.set_href(existing, "mal//formed") }
    full = "https://user:pass@domain.com:9742/path/file.ext?key=val&key2=val2#fragment"
    U::Quirks.set_href(existing, full)

    assert_equal url(full), existing
  end

  def test_domain_encoding_quirks
    [
      ["http://example.com", "", ""],
      ["😅.🙂", "xn--j28h.xn--938h", "😅.🙂"],
      ["example.com", "example.com", "example.com"],
      ["mailto:test@example.net", "", ""],
].each do |input, ascii, unicode|
      assert_equal ascii, U::Quirks.domain_to_ascii(input)
      assert_equal unicode, U::Quirks.domain_to_unicode(input)
    end
  end

  def test_expose_internals
    parts = U::Quirks.internal_components(url("https://example.com/path/file.ext?key=val&key2=val2#fragment"))

    assert_equal U::Quirks::InternalComponents.new(scheme_end: 5, username_end: 8, host_start: 8, host_end: 19,
      port: nil, path_start: 19, query_start: 33, fragment_start: 51), parts
  end

  def test_windows_unc_path
    skip "Windows only" unless WINDOWS

    assert_equal "file://host/share/path/file.txt", Url.from_file_path("\\\\host\\share\\path\\file.txt").as_str
    assert_equal "file://xn--hst-sna/share/path/file.txt", Url.from_file_path("\\\\höst\\share\\path\\file.txt").as_str
    unc = Url.from_file_path("\\\\192.168.0.1\\share\\path\\file.txt")

    assert_equal U::Host::Ipv4.new(IPAddr.new("192.168.0.1")), unc.host
    assert_equal "\\\\192.168.0.1\\share\\path\\file.txt", unc.to_file_path
    assert_equal "file://host/share/path/file.txt",
      Url.from_file_path("\\\\?\\UNC\\host\\share\\path\\file.txt").as_str
    assert_raises(U::Error) { Url.from_file_path("\\\\.\\some\\path\\file.txt") }
  end

  def test_syntax_violation_callback
    violations = []
    parsed = Url.options.syntax_violation_callback(-> (violation) { violations << violation })
      .parse("http:////mozilla.org:42")

    assert_equal 42, parsed.port
    assert_equal [U::SyntaxViolation::ExpectedDoubleSlash], violations
    assert_equal "expected //", violations.first.description
    assert_equal "expected //", violations.first.to_s
  end

  def test_syntax_violation_callback_lifetimes
    violations = []
    report = -> (violation) { violations << violation }

    assert_equal 42, Url.options.syntax_violation_callback(report).parse("http:////mozilla.org:42").port
    assert_equal [U::SyntaxViolation::ExpectedDoubleSlash], violations.slice!(0..)
    assert_equal "/path", Url.options.syntax_violation_callback(report).parse("http://mozilla.org\\path").path
    assert_equal [U::SyntaxViolation::Backslash], violations
  end

  def test_syntax_violation_callback_types
    v = U::SyntaxViolation
    [
      ["http://mozilla.org/\\foo", v::Backslash, "backslash"],
      [" http://mozilla.org", v::C0SpaceIgnored, "leading or trailing control or space character are ignored in URLs"],
      [
        "http://user:pass@mozilla.org",
        v::EmbeddedCredentials,
        "embedding authentication information (username or password) in an URL is not recommended",
],
      ["http:///mozilla.org", v::ExpectedDoubleSlash, "expected //"],
      ["file:/foo.txt", v::ExpectedFileDoubleSlash, "expected // after file:"],
      ["file://mozilla.org/c:/file.txt", v::FileWithHostAndWindowsDrive, "file: with host and Windows drive letter"],
      ["http://mozilla.org/^", v::NonUrlCodePoint, "non-URL code point"],
      ["http://mozilla.org/#\x000", v::NullInFragment, "NULL characters are ignored in URL fragment identifiers"],
      ["http://mozilla.org/%1", v::PercentDecode, "expected 2 hex digits after %"],
      ["http://mozilla.org\t/foo", v::TabOrNewlineIgnored, "tabs or newlines are ignored in URLs"],
      ["http://user@:pass@mozilla.org", v::UnencodedAtSign, "unencoded @ sign in username or password"],
    ].each do |input, violation, description|
      last = nil
      Url.options.syntax_violation_callback(-> (found) { last = found }).parse(input)

      assert_same violation, last, input
      assert_equal description, last.description
      assert_equal description, last.to_s
    end
  end

  def test_options_reuse
    violations = []
    options = Url.options.syntax_violation_callback(-> (violation) { violations << violation })
    first = options.parse("http:////mozilla.org")
    options = options.base_url(first)

    assert_equal "http://mozilla.org/sub/path", options.parse("/sub\\path").as_str
    assert_equal [U::SyntaxViolation::ExpectedDoubleSlash, U::SyntaxViolation::Backslash], violations
  end

  # https://github.com/servo/rust-url/issues/505
  def test_url_from_file_path
    if WINDOWS
      assert_equal "C:\\", Url.from_file_path("c:///").to_file_path
    else
      assert_equal "/c:/", Url.from_file_path("/c:/").to_file_path
    end
  end

  def test_non_special_path
    db = url("postgres://postgres@localhost/")

    assert_equal "postgres://postgres@localhost/", db.as_str
    db.set_path("diesel_foo")

    assert_equal "postgres://postgres@localhost/diesel_foo", db.as_str
    assert_equal "/diesel_foo", db.path
  end

  def test_non_special_path2
    db = url("postgres://postgres@localhost/")
    db.set_path("")

    assert_equal "", db.path
    assert_equal "postgres://postgres@localhost", db.as_str
    db.set_path("foo")

    assert_equal "/foo", db.path
    assert_equal "postgres://postgres@localhost/foo", db.as_str
    db.set_path("/bar")

    assert_equal "/bar", db.path
    assert_equal "postgres://postgres@localhost/bar", db.as_str
  end

  def test_non_special_path3
    db = url("postgres://postgres@localhost/")
    db.set_path("/")

    assert_equal "postgres://postgres@localhost/", db.as_str
    assert_equal "/", db.path
    db.set_path("/foo")

    assert_equal "postgres://postgres@localhost/foo", db.as_str
    assert_equal "/foo", db.path
  end

  def test_set_scheme_to_file_with_host
    local = url("http://localhost:6767/foo/bar")

    assert_raises(U::Error) { local.set_scheme("file") }
    assert_equal "http://localhost:6767/foo/bar", local.to_s
  end

  def test_set_scheme_empty_err
    local = url("http://localhost:6767/foo/bar")

    assert_raises(U::Error) { local.set_scheme("") }
    assert_equal "http://localhost:6767/foo/bar", local.to_s
  end

  def test_no_panic
    odd = url("arhttpsps:/.//eom/dae.com/\\\\t\\:")
    U::Quirks.set_hostname(odd, "//eom/datcom/\\\\t\\://eom/data.cs")
  end

  def test_null_host_with_leading_empty_path_segment
    odd = url("m:/.//\\")

    assert_equal odd, url(odd.as_str)
  end

  def test_pop_if_empty_in_bounds
    url("m://").path_segments_mut.pop_if_empty.pop
  end

  def test_slicing
    [
      {
full: "https://user:pass@domain.com:9742/path/file.ext?key=val&key2=val2#fragment",
scheme: "https",
username: "user",
password: "pass",
host: "domain.com",
port: "9742",
path: "/path/file.ext",
query: "key=val&key2=val2",
fragment: "fragment",
},
      {
full: "https://domain.com:9742/path/file.ext#fragment",
scheme: "https",
host: "domain.com",
port: "9742",
path: "/path/file.ext",
fragment: "fragment",
},
      {
full: "https://domain.com:9742/path/file.ext",
scheme: "https",
host: "domain.com",
port: "9742",
path: "/path/file.ext",
},
      { full: "blob:blob-info", scheme: "blob", path: "blob-info" },
    ].each do |expected|
      parsed = url(expected[:full])

      assert_equal expected[:full], parsed[nil..nil]
      %i[scheme username password host port path query fragment].each do |part|
        name = part.to_s.capitalize
        before = Position.const_get("Before#{name}")
        after = Position.const_get("After#{name}")

        assert_equal expected.fetch(part, ""), parsed[before...after], "#{expected[:full]} #{part}"
      end
      assert_equal expected[:full], parsed[...Position::AfterFragment]
    end
  end

  def test_make_relative
    [
      ["http://127.0.0.1:8080/test", "http://127.0.0.1:8080/test", ""],
      ["http://127.0.0.1:8080/test", "http://127.0.0.1:8080/test/", "test/"],
      ["http://127.0.0.1:8080/test/", "http://127.0.0.1:8080/test", "../test"],
      ["http://127.0.0.1:8080/", "http://127.0.0.1:8080/?foo=bar#123", "?foo=bar#123"],
      ["http://127.0.0.1:8080/", "http://127.0.0.1:8080/test/video", "test/video"],
      ["http://127.0.0.1:8080/test", "http://127.0.0.1:8080/test/video", "test/video"],
      ["http://127.0.0.1:8080/test/", "http://127.0.0.1:8080/test/video", "video"],
      ["http://127.0.0.1:8080/test", "http://127.0.0.1:8080/test2/video", "test2/video"],
      ["http://127.0.0.1:8080/test/", "http://127.0.0.1:8080/test2/video", "../test2/video"],
      ["http://127.0.0.1:8080/test/bla", "http://127.0.0.1:8080/test2/video", "../test2/video"],
      ["http://127.0.0.1:8080/test/bla/", "http://127.0.0.1:8080/test2/video", "../../test2/video"],
      ["http://127.0.0.1:8080/test/?foo=bar#123", "http://127.0.0.1:8080/test/video", "video"],
      ["http://127.0.0.1:8080/test/", "http://127.0.0.1:8080/test/video?baz=meh#456", "video?baz=meh#456"],
      ["http://127.0.0.1:8080/test", "http://127.0.0.1:8080/test?baz=meh#456", "?baz=meh#456"],
      ["http://127.0.0.1:8080/test/", "http://127.0.0.1:8080/test?baz=meh#456", "../test?baz=meh#456"],
      ["http://127.0.0.1:8080/test/", "http://127.0.0.1:8080/test/?baz=meh#456", "?baz=meh#456"],
      ["http://127.0.0.1:8080/test/?foo=bar#123", "http://127.0.0.1:8080/test/video?baz=meh#456", "video?baz=meh#456"],
      ["http://127.0.0.1:8080/file.txt", "http://127.0.0.1:8080/test/file.txt", "test/file.txt"],
      ["http://127.0.0.1:8080/not_equal.txt", "http://127.0.0.1:8080/test/file.txt", "test/file.txt"],
    ].each do |base, uri, relative|
      assert_equal relative, url(base).make_relative(url(uri)), "base: #{base}, uri: #{uri}"
      assert_equal uri, url(base).join(relative).as_str, "base: #{base}, uri: #{uri}"
    end
    [
      ["http://127.0.0.1:8080/", "https://127.0.0.1:8080/test/"],
      ["http://127.0.0.1:8080/", "http://127.0.0.1:8081/test/"],
      ["http://127.0.0.1:8080/", "http://127.0.0.2:8080/test/"],
      ["mailto:a@example.com", "mailto:b@example.com"],
]
      .each { |base, uri| assert_nil url(base).make_relative(url(uri)), "base: #{base}, uri: #{uri}" }
  end

  def test_has_authority
    refute url("mailto:joe@example.com").has_authority
    refute url("unix:/run/foo.socket").has_authority
    assert url("file:///tmp/foo").has_authority
    assert url("http://example.com/tmp/foo").has_authority
  end

  def test_authority
    {
      "mailto:joe@example.com" => "",
      "unix:/run/foo.socket" => "",
      "file:///tmp/foo" => "",
      "http://example.com/tmp/foo" => "example.com",
      "ftp://127.0.0.1:21/" => "127.0.0.1",
      "ftp://user@127.0.0.1:2121/" => "user@127.0.0.1:2121",
      "https://:@example.com/" => "example.com",
      "https://:password@[::1]:8080/" => ":password@[::1]:8080",
      "gopher://user:@àlex.example.com:70" => "user@%C3%A0lex.example.com:70",
      "irc://àlex:àlex@àlex.рф.example.com:6667/foo" => "%C3%A0lex:%C3%A0lex@%C3%A0lex.%D1%80%D1%84.example.com:6667",
      "https://àlex:àlex@àlex.рф.example.com:443/foo" => "%C3%A0lex:%C3%A0lex@xn--lex-8ka.xn--p1ai.example.com",
    }.each { |input, authority| assert_equal authority, url(input).authority, input }
  end

  # https://github.com/servo/rust-url/issues/838
  def test_file_with_drive
    drive = url("fIlE:p:?../")

    assert_equal "file:///p:?../", drive.to_s
    assert_equal "/p:", drive.path
    {
      "a" => "file:///p:/a",
      "" => "file:///p:?../",
      "?x" => "file:///p:?x",
      "." => "file:///p:/",
      ".." => "file:///p:/",
      "../" => "file:///p:/",
    }.each { |input, expected| assert_equal expected, drive.join(input).to_s }
  end

  def test_file_with_drive_and_path
    drive = url("fIlE:p:/x|?../")

    assert_equal "file:///p:/x|?../", drive.to_s
    assert_equal "/p:/x|", drive.path
    assert_equal "file:///p:/a", drive.join("a").to_s
  end

  def test_issue_864
    empty = url("file://")
    empty.set_path("x")

    assert_nil empty.check_invariants
  end

  def test_issue_974
    port = url("http://example.com:8000")
    begin
      U::Quirks.set_port(port, "\u00009000")
    rescue U::Error
      nil
    end

    assert_equal 8000, port.port
  end

  def test_parse_url_with_single_byte_control_host
    first = url("l://\x01:")

    assert_equal first, url(first.as_str)
  end
end

#--
# SPDX-SnippetEnd
#++
