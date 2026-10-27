# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    # SPDX-SnippetComment: Url, its methods, their docs, and its trait impls
    #   from url 2.5.8 src/lib.rs:226-2872 and src/slicing.rs:13-39
    #++

    # A parsed URL record.
    #
    # Ruby's +URI+ follows RFC 3986. Browsers, and Tauri's url crate,
    # follow the WHATWG URL Standard (https://url.spec.whatwg.org/), which
    # accepts and refuses different strings, normalizes hosts through IDNA,
    # and defines setters that behave as a browser's do. A program that
    # must agree with a browser, or with Tauri, gets subtly different
    # answers from +URI+.
    #
    # A Url is url's record, parsed by url itself. Read its components with
    # #scheme, #host, #path, and the rest; change them with the +set_+
    # methods; resolve references against it with #join. URLs compare,
    # order, and hash by their serialization, as url's do.
    #
    # Some URLs are said to be cannot-be-a-base: they don't have a
    # username, password, host, or port, and their "path" is an arbitrary
    # string rather than slash-separated segments, as a <tt>data:</tt> URL's
    # is.
    #
    # A Url changes in place. +dup+ copies it, as Rust's +Clone+ does. A
    # frozen Url refuses every setter with +FrozenError+;
    # <tt>Ractor.make_shareable</tt> freezes one and lets it cross Ractors.
    # A Rust panic inside url, which would end the Ruby process, raises
    # Error instead, and the Url keeps its value from before the call.
    #
    # Mirrors url's +Url+ (<tt>src/lib.rs:226-2872</tt>).
    #
    # === Examples
    #
    #   url = Ferro::Url::Url.parse("https://github.com/rust-lang/rust/issues?labels=E-easy&state=open")
    #   url.scheme # => "https"
    #   url.host_str # => "github.com"
    #   url.path_segments.to_a # => ["rust-lang", "rust", "issues"]
    #   url.query # => "labels=E-easy&state=open"
    #   url[Ferro::Url::Position::BeforePath..] # => "/rust-lang/rust/issues?labels=E-easy&state=open"
    #
    #   data_url = Ferro::Url::Url.parse("data:text/plain,Hello?World#")
    #   data_url.cannot_be_a_base # => true
    #   data_url.path # => "text/plain,Hello"
    #
    #   this_document = Ferro::Url::Url.parse("http://servo.github.io/rust-url/url/index.html")
    #   this_document.join("../main.css").as_str # => "http://servo.github.io/rust-url/main.css"
    class Url
      include Comparable

      class << self
        # Parses an absolute URL from a string, raising a ParseError
        # variant if it cannot. Mirrors url's <tt>Url::parse</tt>
        # (<tt>src/lib.rs:319-343</tt>).
        #
        # [input] String, UTF-8 text.
        #
        # === Example
        #
        #   Ferro::Url::Url.parse("https://example.net").as_str # => "https://example.net/"
        def parse(input)
          Arguments.url(Native.url_parse(input))
        end

        # Parses an absolute URL from a string and adds params to its query
        # string. Existing params are not removed. Raises a ParseError
        # variant if the string does not parse. Mirrors url's
        # <tt>Url::parse_with_params</tt> (<tt>src/lib.rs:345-385</tt>).
        #
        # [input] String, UTF-8 text.
        # [iter] Enumerable of name and value pairs, such as an Array of
        #   pairs or a Hash.
        #
        # === Example
        #
        #   Ferro::Url::Url.parse_with_params("https://example.net?dont=clobberme",
        #     [["lang", "rust"], ["browser", "servo"]]).as_str
        #   # => "https://example.net/?dont=clobberme&lang=rust&browser=servo"
        def parse_with_params(input, iter)
          Arguments.url(Native.url_parse_with_params(input, Arguments.pairs(iter)))
        end

        # The same as Url.parse, as url's +FromStr+ is
        # (<tt>src/lib.rs:2776-2784</tt>).
        #
        # [input] String, UTF-8 text.
        #
        # === Example
        #
        #   Ferro::Url::Url.from_str("https://example.net/").host_str # => "example.net"
        def from_str(input)
          parse(input)
        end

        # The same as Url.parse, as url's <tt>TryFrom<&str></tt> is
        # (<tt>src/lib.rs:2786-2792</tt>).
        #
        # [input] String, UTF-8 text.
        #
        # === Example
        #
        #   Ferro::Url::Url.try_from("https://example.net/").scheme # => "https"
        def try_from(input)
          parse(input)
        end

        # Returns a default ParseOptions that can fully configure the URL
        # parser. Mirrors url's <tt>Url::options</tt>
        # (<tt>src/lib.rs:607-632</tt>).
        #
        # === Example
        #
        #   api = Ferro::Url::Url.parse("https://api.example.com")
        #   Ferro::Url::Url.options.base_url(api).parse("version.json").as_str
        #   # => "https://api.example.com/version.json"
        def options
          ParseOptions.__send__(:new, nil, nil, nil)
        end

        # Converts a file name into a URL in the +file+ scheme.
        #
        # Raises Error if the given path is not absolute or, on Windows, if
        # the prefix is not a disk prefix (such as <tt>C:</tt>) or a UNC
        # prefix (<tt>\\\\</tt>). Mirrors url's <tt>Url::from_file_path</tt>
        # (<tt>src/lib.rs:2513-2569</tt>).
        #
        # [path] String, or an object with +to_path+, such as a Pathname.
        #
        # === Example
        #
        #   Ferro::Url::Url.from_file_path("/tmp/foo.txt").as_str # => "file:///tmp/foo.txt"
        #   Ferro::Url::Url.from_file_path("../foo.txt") # raises Ferro::Url::Error
        def from_file_path(path)
          Arguments.url(Native.url_from_path(Arguments.path(path), false))
        end

        # Converts a directory name into a URL in the +file+ scheme, with a
        # trailing slash, so that the entire path is considered when using
        # this URL as a base URL.
        #
        # For example, <tt>"index.html"</tt> parsed with
        # <tt>Url.from_directory_path("/var/www")</tt> as the base URL is
        # <tt>file:///var/www/index.html</tt>, while with
        # <tt>Url.from_file_path("/var/www")</tt> it is
        # <tt>file:///var/index.html</tt>, which might not be what was
        # intended. Raises Error as Url.from_file_path does. Mirrors url's
        # <tt>Url::from_directory_path</tt> (<tt>src/lib.rs:2571-2607</tt>).
        #
        # [path] String, or an object with +to_path+.
        #
        # === Example
        #
        #   Ferro::Url::Url.from_directory_path("/var/www").as_str # => "file:///var/www/"
        def from_directory_path(path)
          Arguments.url(Native.url_from_path(Arguments.path(path), true))
        end
      end

      # A Url is made by Url.parse and its siblings, never by Url.new.
      private_class_method :new

      # Parses a string as a URL, with this URL as the base URL, raising a
      # ParseError variant if it cannot.
      #
      # The inverse of this is #make_relative.
      #
      # Notes:
      #
      # - A trailing slash is significant. Without it, the last path
      #   component is considered to be a "file" name to be removed to get
      #   at the "directory" that is used as the base.
      # - A scheme relative special URL
      #   (https://url.spec.whatwg.org/#scheme-relative-special-url-string)
      #   as input replaces everything in the base URL after the scheme.
      # - An absolute URL (with a scheme) as input replaces the whole base
      #   URL (even the scheme).
      #
      # Mirrors url's <tt>Url::join</tt> (<tt>src/lib.rs:413-473</tt>).
      #
      # [input] String, UTF-8 text.
      #
      # === Example
      #
      #   base = Ferro::Url::Url.parse("https://example.net/a/b.html")
      #   base.join("c.png").as_str # => "https://example.net/a/c.png"
      #
      #   base = Ferro::Url::Url.parse("https://example.net/a/b/")
      #   base.join("c.png").as_str # => "https://example.net/a/b/c.png"
      #
      #   base = Ferro::Url::Url.parse("https://alice.com/a")
      #   base.join("//eve.com/b").as_str # => "https://eve.com/b"
      #   base.join("/v1/meta").as_str # => "https://alice.com/v1/meta"
      #   base.join("http://eve.com/b").as_str # => "http://eve.com/b"
      def join(input)
        Arguments.url(Native.url_join(@native, input))
      end

      # Creates a relative URL if possible, with this URL as the base URL.
      #
      # This is the inverse of #join. Returns +nil+ if this URL can't be a
      # base for the given URL. This is for example the case if the scheme,
      # host or port are not the same. Mirrors url's
      # <tt>Url::make_relative</tt> (<tt>src/lib.rs:475-605</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   base = Ferro::Url::Url.parse("https://example.net/a/b.html")
      #   base.make_relative(Ferro::Url::Url.parse("https://example.net/a/c.png")) # => "c.png"
      #
      #   base = Ferro::Url::Url.parse("https://example.net/a/b/")
      #   base.make_relative(Ferro::Url::Url.parse("https://example.net/a/d/c.png")) # => "../d/c.png"
      def make_relative(url)
        Native.url_make_relative(@native, Arguments.native(url))
      end

      # Returns the serialization of this URL. Mirrors url's
      # <tt>Url::as_str</tt> (<tt>src/lib.rs:634-655</tt>), which url's
      # <tt>AsRef<str></tt> also returns.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.net/").as_str # => "https://example.net/"
      def as_str
        Native.url_as_str(@native)
      end

      # Returns the serialization of this URL, as url's +Display+ and
      # <tt>From<Url> for String</tt> do (<tt>src/lib.rs:2794-2807</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.net/").to_s # => "https://example.net/"
      def to_s
        as_str
      end

      # Returns the serialization of this URL.
      #
      # Deprecated since url 2.3.0, which says to use <tt>Into<String></tt>
      # instead; in Ruby that is #to_s. It warns in Ruby's
      # <tt>:deprecated</tt> category. Mirrors url's
      # <tt>Url::into_string</tt> (<tt>src/lib.rs:657-679</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.net/").into_string # => "https://example.net/"
      def into_string
        warn("Ferro::Url::Url#into_string is deprecated since url 2.3.0; use #to_s", category: :deprecated,
          uplevel: 1)
        as_str
      end

      # url's +Debug+ text: the URL's components by name. Mirrors url's
      # <tt>Debug for Url</tt> (<tt>src/lib.rs:2809-2826</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.net/").inspect
      #   # => "Url { scheme: \"https\", cannot_be_a_base: false, username: \"\", password: None, host: Some(Domain(\"example.net\")), port: None, path: \"/\", query: None, fragment: None }"
      def inspect
        Native.url_inspect(@native)
      end

      # Checks the invariants url's own methods assume, returning +nil+, or
      # raising Error with url's description of the first one that does not
      # hold.
      #
      # url marks it hidden: it exists for testing rust-url itself, and a
      # Url from url's own methods always passes. Mirrors url's
      # <tt>Url::check_invariants</tt> (<tt>src/lib.rs:681-809</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.net/").check_invariants # => nil
      def check_invariants
        failure = Native.url_check_invariants(@native)
        raise Error, failure if failure

        nil
      end

      # Returns the origin of this URL (https://url.spec.whatwg.org/#origin).
      #
      # Note: this returns an opaque origin for <tt>file:</tt> URLs, which
      # causes <tt>url.origin != url.origin</tt>. Mirrors url's
      # <tt>Url::origin</tt> (<tt>src/lib.rs:811-885</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("ftp://example.com/foo").origin
      #   # => #<data Ferro::Url::Origin::Tuple scheme="ftp", host=#<data Ferro::Url::Host::Domain domain="example.com">, port=21>
      #   Ferro::Url::Url.parse("blob:https://example.com/foo").origin.ascii_serialization # => "https://example.com"
      #   Ferro::Url::Url.parse("file:///tmp/foo").origin.is_tuple # => false
      def origin
        Arguments.origin(Native.url_origin(@native))
      end

      # Returns the scheme of this URL, lower-cased, as an ASCII string
      # without the <tt>:</tt> delimiter. Mirrors url's
      # <tt>Url::scheme</tt> (<tt>src/lib.rs:887-905</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("file:///tmp/foo").scheme # => "file"
      def scheme
        Native.url_str(@native, :scheme)
      end

      # Returns whether the URL is special (has a special scheme: +ftp+,
      # +file+, +http+, +https+, +ws+, or +wss+). Mirrors url's
      # <tt>Url::is_special</tt> (<tt>src/lib.rs:907-926</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http:///tmp/foo").is_special # => true
      #   Ferro::Url::Url.parse("moz:///tmp/foo").is_special # => false
      def is_special
        Native.url_bool(@native, :is_special)
      end

      # Returns whether the URL has an authority, which can contain a
      # username, password, host, and port number.
      #
      # URLs that do not are either path-only like
      # <tt>unix:/run/foo.socket</tt> or cannot-be-a-base like
      # <tt>data:text/plain,Stuff</tt>. See also #authority. Mirrors url's
      # <tt>Url::has_authority</tt> (<tt>src/lib.rs:928-959</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("ftp://rms@example.com").has_authority # => true
      #   Ferro::Url::Url.parse("unix:/run/foo.socket").has_authority # => false
      def has_authority
        Native.url_bool(@native, :has_authority)
      end

      # Returns the authority of this URL as an ASCII string.
      #
      # Non-ASCII domains are Punycode-encoded per IDNA if this is the host
      # of a special URL, or percent encoded for non-special URLs. IPv6
      # addresses are given between <tt>[</tt> and <tt>]</tt> brackets.
      # Ports are omitted if they match the well known port of a special
      # URL. Username and password are percent-encoded. See also
      # #has_authority. Mirrors url's <tt>Url::authority</tt>
      # (<tt>src/lib.rs:961-1000</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://user:password@example.com/tmp/foo").authority
      #   # => "user:password@example.com"
      #   Ferro::Url::Url.parse("irc://àlex.рф.example.com:6667/foo").authority
      #   # => "%C3%A0lex.%D1%80%D1%84.example.com:6667"
      #   Ferro::Url::Url.parse("http://àlex.рф.example.com:80/foo").authority
      #   # => "xn--lex-8ka.xn--p1ai.example.com"
      def authority
        Native.url_str(@native, :authority)
      end

      # Returns whether this URL is a cannot-be-a-base URL, meaning that
      # parsing a relative URL string with this URL as the base will return
      # an error.
      #
      # This is the case if the scheme and <tt>:</tt> delimiter are not
      # followed by a <tt>/</tt> slash, as is typically the case of
      # <tt>data:</tt> and <tt>mailto:</tt> URLs. Mirrors url's
      # <tt>Url::cannot_be_a_base</tt> (<tt>src/lib.rs:1002-1030</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("unix:/run/foo.socket").cannot_be_a_base # => false
      #   Ferro::Url::Url.parse("data:text/plain,Stuff").cannot_be_a_base # => true
      def cannot_be_a_base
        Native.url_bool(@native, :cannot_be_a_base)
      end

      # Returns the username for this URL (typically the empty string) as a
      # percent-encoded ASCII string. Mirrors url's <tt>Url::username</tt>
      # (<tt>src/lib.rs:1032-1061</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("ftp://rms@example.com").username # => "rms"
      #   Ferro::Url::Url.parse("ftp://:secret123@example.com").username # => ""
      def username
        Native.url_str(@native, :username)
      end

      # Returns the password for this URL, if any, as a percent-encoded
      # ASCII string, or +nil+. Mirrors url's <tt>Url::password</tt>
      # (<tt>src/lib.rs:1063-1099</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("ftp://rms:secret123@example.com").password # => "secret123"
      #   Ferro::Url::Url.parse("ftp://rms@example.com").password # => nil
      def password
        Native.url_option_str(@native, :password)
      end

      # Equivalent to <tt>!url.host.nil?</tt>. Mirrors url's
      # <tt>Url::has_host</tt> (<tt>src/lib.rs:1101-1124</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("ftp://rms@example.com").has_host # => true
      #   Ferro::Url::Url.parse("data:text/plain,Stuff").has_host # => false
      def has_host
        Native.url_bool(@native, :has_host)
      end

      # Returns the string representation of the host (domain or IP
      # address) for this URL, if any, or +nil+.
      #
      # Non-ASCII domains are Punycode-encoded per IDNA if this is the host
      # of a special URL, or percent encoded for non-special URLs. IPv6
      # addresses are given between <tt>[</tt> and <tt>]</tt> brackets.
      # Cannot-be-a-base URLs (typical of <tt>data:</tt> and
      # <tt>mailto:</tt>) and some <tt>file:</tt> URLs don't have a host.
      # See also #host. Mirrors url's <tt>Url::host_str</tt>
      # (<tt>src/lib.rs:1126-1168</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://127.0.0.1/index.html").host_str # => "127.0.0.1"
      #   Ferro::Url::Url.parse("unix:/run/foo.socket").host_str # => nil
      def host_str
        Native.url_option_str(@native, :host_str)
      end

      # Returns the parsed representation of the host for this URL, a Host,
      # or +nil+.
      #
      # Non-ASCII domain labels are Punycode-encoded per IDNA if this is the
      # host of a special URL, or percent encoded for non-special URLs.
      # Cannot-be-a-base URLs and some <tt>file:</tt> URLs don't have a
      # host. See also #host_str. Mirrors url's <tt>Url::host</tt>
      # (<tt>src/lib.rs:1170-1208</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://127.0.0.1/index.html").host
      #   # => #<data Ferro::Url::Host::Ipv4 address=#<IPAddr: IPv4:127.0.0.1/255.255.255.255>>
      #   Ferro::Url::Url.parse("data:text/plain,Stuff").host # => nil
      def host
        parts = Native.url_host(@native)
        parts && Arguments.host(parts)
      end

      # If this URL has a host and it is a domain name (not an IP address),
      # returns it, or +nil+. Non-ASCII domains are Punycode-encoded per
      # IDNA if this is the host of a special URL, or percent encoded for
      # non-special URLs. Mirrors url's <tt>Url::domain</tt>
      # (<tt>src/lib.rs:1210-1242</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://127.0.0.1/").domain # => nil
      #   Ferro::Url::Url.parse("https://subdomain.example.com/").domain # => "subdomain.example.com"
      def domain
        Native.url_option_str(@native, :domain)
      end

      # Returns the port number for this URL, if any, or +nil+.
      #
      # Note that default port numbers are never reflected by the
      # serialization; use #port_or_known_default if you want a default
      # port number returned. Mirrors url's <tt>Url::port</tt>
      # (<tt>src/lib.rs:1244-1271</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.com:443/").port # => nil
      #   Ferro::Url::Url.parse("ssh://example.com:22").port # => 22
      def port
        Native.url_port(@native, false)
      end

      # Returns the port number for this URL, or the default port number if
      # it is known.
      #
      # This method only knows the default port number of the +http+,
      # +https+, +ws+, +wss+ and +ftp+ schemes. For URLs in these schemes,
      # this method always returns an Integer. For other schemes, it is the
      # same as #port. Mirrors url's <tt>Url::port_or_known_default</tt>
      # (<tt>src/lib.rs:1273-1303</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("foo://example.com").port_or_known_default # => nil
      #   Ferro::Url::Url.parse("https://example.com").port_or_known_default # => 443
      def port_or_known_default
        Native.url_port(@native, true)
      end

      # Resolves a URL's host and port number to socket addresses, an Array
      # of Addrinfo.
      #
      # If the URL has the default port number of a scheme that is unknown
      # to url, the block provides an opportunity to supply the actual port
      # number, or +nil+. url calls it only for a URL with a host and no
      # port it knows, and without a block that answer is +nil+. If the host
      # is a domain, it is resolved using the system's resolver, on a thread
      # of its own while this one waits with Ruby's global VM lock released,
      # so other threads run meanwhile. Nothing can cancel the lookup, but
      # an interrupt (Ctrl-C, <tt>Thread#raise</tt>, +Timeout+) ends the
      # wait at once, and the lookup finishes alone, as Ruby's own
      # <tt>Addrinfo.getaddrinfo</tt> leaves its resolver thread.
      #
      # A failure raises the +Errno+ class of its OS error on Unix, or
      # +IOError+ with Rust's message, such as url's
      # <tt>No host name in the URL</tt>. An IPv6 address keeps its scope
      # id, as an Addrinfo can, but not its flow label. Mirrors url's
      # <tt>Url::socket_addrs</tt> (<tt>src/lib.rs:1305-1366</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://127.0.0.1/").socket_addrs # => [#<Addrinfo: 127.0.0.1:443>]
      #
      #   url = Ferro::Url::Url.parse("socks5://127.0.0.1")
      #   url.socket_addrs { url.scheme == "socks5" ? 1080 : nil } # => [#<Addrinfo: 127.0.0.1:1080>]
      def socket_addrs(&default_port_number)
        port = (default_port_number&.call if Native.url_socket_addrs_asks_for_port(@native))
        Native.url_socket_addrs(@native, port).map do |ip, number, scope_id|
          Addrinfo.new(Socket.pack_sockaddr_in(number, scope_id.zero? ? ip : "#{ip}%#{scope_id}"))
        end
      end

      # Returns the path for this URL, as a percent-encoded ASCII string.
      #
      # For cannot-be-a-base URLs, this is an arbitrary string that doesn't
      # start with <tt>/</tt>. For other URLs, this starts with a
      # <tt>/</tt> slash and continues with slash-separated path segments.
      # Mirrors url's <tt>Url::path</tt> (<tt>src/lib.rs:1368-1398</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.com/api/versions?page=2").path # => "/api/versions"
      #   Ferro::Url::Url.parse("https://example.com/countries/việt nam").path # => "/countries/vi%E1%BB%87t%20nam"
      def path
        Native.url_str(@native, :path)
      end

      # Unless this URL is cannot-be-a-base, returns an Enumerator of
      # <tt>/</tt> slash-separated path segments, each as a percent-encoded
      # ASCII string; returns +nil+ for cannot-be-a-base URLs.
      #
      # When an Enumerator is returned, it always yields at least one
      # string (which may be empty). It holds the segments as they were when
      # you called this; a later change to the URL does not reach it.
      # Mirrors url's <tt>Url::path_segments</tt>
      # (<tt>src/lib.rs:1400-1445</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.com/foo/bar").path_segments.to_a # => ["foo", "bar"]
      #   Ferro::Url::Url.parse("https://example.com").path_segments.to_a # => [""]
      #   Ferro::Url::Url.parse("data:text/plain,HelloWorld").path_segments # => nil
      def path_segments
        Native.url_path_segments(@native)&.each
      end

      # Returns this URL's query string, if any, as a percent-encoded ASCII
      # string, or +nil+. Mirrors url's <tt>Url::query</tt>
      # (<tt>src/lib.rs:1447-1483</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.com/products?page=2").query # => "page=2"
      #   Ferro::Url::Url.parse("https://example.com/?country=español").query # => "country=espa%C3%B1ol"
      def query
        Native.url_option_str(@native, :query)
      end

      # Parses the URL's query string, if any, as
      # <tt>application/x-www-form-urlencoded</tt> and returns an Enumerator
      # of <tt>[key, value]</tt> pairs, percent-decoded. It holds the pairs
      # as they were when you called this. Mirrors url's
      # <tt>Url::query_pairs</tt> (<tt>src/lib.rs:1485-1511</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.com/products?page=2&sort=desc").query_pairs.to_a
      #   # => [["page", "2"], ["sort", "desc"]]
      def query_pairs
        Native.url_query_pairs(@native).each
      end

      # Returns this URL's fragment identifier, if any, or +nil+.
      #
      # A fragment is the part of the URL after the <tt>#</tt> symbol. The
      # fragment is optional and, if present, contains a fragment
      # identifier that identifies a secondary resource, such as a section
      # heading of a document. In HTML, the fragment identifier is usually
      # the id attribute of an element that is scrolled to on load.
      # Browsers typically will not send the fragment portion of a URL to
      # the server.
      #
      # Note: the parser did not percent-encode this component, but the
      # input may have been percent-encoded already. Mirrors url's
      # <tt>Url::fragment</tt> (<tt>src/lib.rs:1513-1550</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.com/data.csv#row=4").fragment # => "row=4"
      def fragment
        Native.url_option_str(@native, :fragment)
      end

      # Changes this URL's fragment identifier, or removes it for +nil+.
      # Mirrors url's <tt>Url::set_fragment</tt>
      # (<tt>src/lib.rs:1559-1597</tt>).
      #
      # [fragment] String, or +nil+.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.com/data.csv")
      #   url.set_fragment("cell=4,1-6,2")
      #   url.as_str # => "https://example.com/data.csv#cell=4,1-6,2"
      #   url.set_fragment(nil)
      #   url.as_str # => "https://example.com/data.csv"
      def set_fragment(fragment)
        writable!
        Native.url_set_option_str(@native, :set_fragment, fragment)
      end

      # Changes this URL's query string. If +query+ is +nil+, this URL's
      # query string will be cleared. Mirrors url's <tt>Url::set_query</tt>
      # (<tt>src/lib.rs:1617-1667</tt>).
      #
      # [query] String, or +nil+.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.com/products")
      #   url.set_query("page=2")
      #   url.as_str # => "https://example.com/products?page=2"
      def set_query(query)
        writable!
        Native.url_set_option_str(@native, :set_query, query)
      end

      # Manipulates this URL's query string, viewed as a sequence of
      # name/value pairs in <tt>application/x-www-form-urlencoded</tt>
      # syntax. The return value, a FormUrlencoded::Serializer over a
      # UrlQuery, has a method-chaining API.
      #
      # Calling it gives the URL a query, empty if it had none, as url's
      # does: <tt>http://a/b#f</tt> becomes <tt>http://a/b?#f</tt>. Note:
      # <tt>url.query_pairs_mut.clear</tt> is equivalent to
      # <tt>url.set_query("")</tt>, not <tt>url.set_query(nil)</tt>.
      #
      # In Rust the serializer borrows the URL until it is dropped. Here
      # each call on it changes the URL at once, and the URL stays valid
      # between calls. Mirrors url's <tt>Url::query_pairs_mut</tt>
      # (<tt>src/lib.rs:1669-1719</tt>).
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.net?lang=fr#nav")
      #   url.query_pairs_mut.append_pair("foo", "bar")
      #   url.query # => "lang=fr&foo=bar"
      #   url.as_str # => "https://example.net/?lang=fr&foo=bar#nav"
      #
      #   url.query_pairs_mut.clear.append_pair("foo", "bar & baz").append_pair("saisons", "Été+hiver")
      #   url.query # => "foo=bar+%26+baz&saisons=%C3%89t%C3%A9%2Bhiver"
      def query_pairs_mut
        writable!
        Native.url_query_pairs_mut(@native, [:none], nil)
        FormUrlencoded::Serializer.__send__(:over_url_query, UrlQuery.__send__(:new, self))
      end

      # Changes this URL's path. It percent-encodes the given string if it's
      # not already percent-encoded. Mirrors url's <tt>Url::set_path</tt>
      # (<tt>src/lib.rs:1732-1790</tt>).
      #
      # [path] String.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.com")
      #   url.set_path("api/some comments")
      #   url.as_str # => "https://example.com/api/some%20comments"
      def set_path(path)
        writable!
        Native.url_set_path(@native, path)
      end

      # Returns a PathSegmentsMut with methods to manipulate this URL's path
      # segments, or raises Error if this URL is cannot-be-a-base. Mirrors
      # url's <tt>Url::path_segments_mut</tt> (<tt>src/lib.rs:1792-1802</tt>).
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("http://example.net/foo/index.html")
      #   url.path_segments_mut.pop.push("img").push("2/100%.png")
      #   url.as_str # => "http://example.net/foo/img/2%2F100%25.png"
      #
      #   Ferro::Url::Url.parse("mailto:me@example.com").path_segments_mut # raises Ferro::Url::Error
      def path_segments_mut
        writable!
        Native.url_path_segments_mut(@native, [:none])
        PathSegmentsMut.__send__(:new, self)
      end

      # Changes this URL's port number, or removes it for +nil+.
      #
      # Note that default port numbers are not reflected in the
      # serialization. If this URL is cannot-be-a-base, does not have a
      # host, or has the +file+ scheme, it does nothing and raises Error.
      # Mirrors url's <tt>Url::set_port</tt> (<tt>src/lib.rs:1819-1898</tt>).
      #
      # [port] Integer from 0 to 65535, or +nil+.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("ssh://example.net:2048/")
      #   url.set_port(4096)
      #   url.as_str # => "ssh://example.net:4096/"
      #   Ferro::Url::Url.parse("mailto:rms@example.net").set_port(80) # raises Ferro::Url::Error
      def set_port(port)
        writable!
        Native.url_set_port(@native, port)
      end

      # Changes this URL's host.
      #
      # Removing the host (calling this with +nil+) will also remove any
      # username, password, and port number. If this URL is
      # cannot-be-a-base or there is an error parsing the given +host+, a
      # ParseError variant is raised. Mirrors url's <tt>Url::set_host</tt>
      # (<tt>src/lib.rs:1939-2083</tt>).
      #
      # [host] String, or +nil+.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.net")
      #   url.set_host("rust-lang.org")
      #   url.as_str # => "https://rust-lang.org/"
      #
      #   url = Ferro::Url::Url.parse("foo://example.net")
      #   url.set_host(nil)
      #   url.as_str # => "foo:/"
      #
      #   Ferro::Url::Url.parse("https://example.net").set_host(nil) # raises Ferro::Url::ParseError::EmptyHost
      def set_host(host)
        writable!
        Native.url_set_host(@native, host)
      end

      # Changes this URL's host to the given IP address. If this URL is
      # cannot-be-a-base, it does nothing and raises Error. Compared to
      # #set_host, this skips the host parser. Mirrors url's
      # <tt>Url::set_ip_host</tt> (<tt>src/lib.rs:2128-2177</tt>).
      #
      # [address] IPAddr, IPv4 or IPv6.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("http://example.com")
      #   url.set_ip_host(IPAddr.new("127.0.0.1"))
      #   url.as_str # => "http://127.0.0.1/"
      def set_ip_host(address)
        writable!
        raise TypeError, "wrong argument type #{address.class} (expected IPAddr)" unless address.is_a?(IPAddr)

        Native.url_set_ip_host(@native, address.ipv4? ? 4 : 6, address.to_i)
      end

      # Changes this URL's password, or removes it for +nil+. If this URL is
      # cannot-be-a-base or does not have a host, it does nothing and
      # raises Error. Mirrors url's <tt>Url::set_password</tt>
      # (<tt>src/lib.rs:2179-2262</tt>).
      #
      # [password] String, or +nil+.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("ftp://user1:secret1@example.com")
      #   url.set_password("secret_password")
      #   url.password # => "secret_password"
      def set_password(password)
        writable!
        Native.url_set_password(@native, password)
      end

      # Changes this URL's username. If this URL is cannot-be-a-base or does
      # not have a host, it does nothing and raises Error. Mirrors url's
      # <tt>Url::set_username</tt> (<tt>src/lib.rs:2264-2349</tt>).
      #
      # [username] String.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("ftp://:secre1@example.com/")
      #   url.set_username("user1")
      #   url.as_str # => "ftp://user1:secre1@example.com/"
      def set_username(username)
        writable!
        Native.url_set_str(@native, :set_username, username)
      end

      # Changes this URL's scheme.
      #
      # It does nothing and raises Error under the following circumstances:
      #
      # - If the new scheme is not in <tt>[a-zA-Z][a-zA-Z0-9+.-]+</tt>
      # - If this URL is cannot-be-a-base and the new scheme is one of
      #   +http+, +https+, +ws+, +wss+ or +ftp+
      # - If either the old or new scheme is +http+, +https+, +ws+, +wss+ or
      #   +ftp+ and the other is not one of these
      # - If the new scheme is +file+ and this URL includes credentials or
      #   has a non-null port
      # - If this URL's scheme is +file+ and its host is empty or null
      #
      # See also the URL specification's section on legal scheme state
      # overrides (https://url.spec.whatwg.org/#scheme-state). Mirrors url's
      # <tt>Url::set_scheme</tt> (<tt>src/lib.rs:2351-2511</tt>).
      #
      # [scheme] String.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.net")
      #   url.set_scheme("http")
      #   url.as_str # => "http://example.net/"
      #   Ferro::Url::Url.parse("foo://example.net").set_scheme("https") # raises Ferro::Url::Error
      def set_scheme(scheme)
        writable!
        Native.url_set_str(@native, :set_scheme, scheme)
      end

      # Assuming the URL is in the +file+ scheme or similar, converts its
      # path to an absolute path, a String.
      #
      # Note: this does not actually check the URL's scheme, and may give
      # nonsensical results for other schemes. It is the user's
      # responsibility to check the URL's scheme before calling this.
      #
      # Raises Error if the host is neither empty nor <tt>"localhost"</tt>
      # (except on Windows, where <tt>file:</tt> URLs may have a non-local
      # host), or if the percent-decoded path contains a NUL byte or, for a
      # Windows path, is not UTF-8. Mirrors url's <tt>Url::to_file_path</tt>
      # (<tt>src/lib.rs:2694-2758</tt>).
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("file:///tmp/foo.txt").to_file_path # => "/tmp/foo.txt"
      def to_file_path
        Native.url_to_file_path(@native)
      end

      # Slices the serialization by a Range of Position values, as url's
      # +Index+ impls do (<tt>src/slicing.rs:13-39</tt>): endless
      # (<tt>url[Position::BeforePath..]</tt>), beginless
      # (<tt>url[...Position::AfterQuery]</tt>), bounded and exclusive
      # (<tt>url[Position::BeforeHost...Position::AfterPort]</tt>), or
      # <tt>url[nil..nil]</tt> for the whole serialization.
      #
      # url implements no inclusive range, so a bounded <tt>..</tt> range
      # raises +TypeError+. A range whose start falls after its end in the
      # serialization, where Rust's slicing would panic, raises Error.
      #
      # [range] Range of Position values, either end +nil+.
      #
      # === Example
      #
      #   url = Ferro::Url::Url.parse("https://example.com/a?b#c")
      #   url[...Ferro::Url::Position::AfterQuery] # => "https://example.com/a?b"
      #   url[Ferro::Url::Position::BeforePath...Ferro::Url::Position::AfterQuery] # => "/a?b"
      def [](range)
        raise TypeError, "wrong argument type #{range.class} (expected a Range of Positions)" unless range.is_a?(Range)

        first = range.begin
        last = range.end
        unless [first, last].all? { |position| position.nil? || position.is_a?(Position) }
          raise TypeError, "a Url slices by Position, not #{[first, last].reject(&:nil?).map(&:class).uniq.join(', ')}"
        end
        if first && last && !range.exclude_end?
          raise TypeError, "url has no Index<RangeInclusive<Position>>; use an exclusive range (...)"
        end

        Native.url_slice(@native, first&.__send__(:name), last&.__send__(:name))
      end

      # Whether +other+ is a Url with the same serialization, as url's
      # +PartialEq+ compares (<tt>src/lib.rs:2828-2837</tt>).
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("https://example.net") == Ferro::Url::Url.parse("https://example.net/") # => true
      def ==(other)
        other.is_a?(Url) && as_str == other.as_str
      end

      alias eql? ==

      # Orders URLs by their serialization, as url's +Ord+ does
      # (<tt>src/lib.rs:2839-2853</tt>). +nil+ for anything but a Url.
      #
      # [other] Object.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://a/") < Ferro::Url::Url.parse("http://b/") # => true
      def <=>(other)
        as_str <=> other.as_str if other.is_a?(Url)
      end

      # Hashes by the serialization, as url's +Hash+ does
      # (<tt>src/lib.rs:2855-2864</tt>).
      #
      # === Example
      #
      #   { Ferro::Url::Url.parse("https://example.net") => 1 }[Ferro::Url::Url.parse("https://example.net/")] # => 1
      def hash
        [Url, as_str].hash
      end

      # Holds +native+, a native URL.
      private def initialize_native(native)
        @native = native
      end

      # +dup+ and +clone+ copy the native URL, as url's +Clone+ does.
      private def initialize_copy(source)
        super
        @native = Native.url_clone(source.__send__(:native))
      end

      # The native URL, for the native layer.
      private attr_reader :native

      # Refuses to change a frozen Url, as Ruby refuses to change any frozen
      # object.
      private def writable!
        raise FrozenError.new("can't modify frozen #{self.class}: #{inspect}", receiver: self) if frozen?
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
