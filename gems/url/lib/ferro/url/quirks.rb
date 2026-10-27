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
    # SPDX-SnippetComment: the quirks module, its functions, and their docs
    #   from url 2.5.8 src/quirks.rs:9-336
    #++

    # Getters and setters for URL components implemented per
    # https://url.spec.whatwg.org/#api.
    #
    # Unless you need to be interoperable with web browsers, you probably
    # want to use Url's own methods instead.
    #
    # A browser's +URL+ object reads and writes components as strings with
    # their delimiters (<tt>"https:"</tt>, <tt>"?q=1"</tt>), and its setters
    # ignore what they cannot use rather than fail. Code that mirrors a
    # browser, such as a webview's address bar or a port of JavaScript,
    # needs those exact rules, which Url's methods do not follow.
    #
    # Each function here takes a Url. url marks the module hidden from its
    # docs, but it is public, and url's own browser-conformance tests run
    # through it. The setters that return <tt>Result<(), ()></tt> in url
    # raise Error where url returns +Err+; a browser would ignore the
    # failure, so rescue Error to behave as one.
    #
    # Mirrors url's +quirks+ module (<tt>src/quirks.rs</tt>).
    #
    # === Example
    #
    #   quirks = Ferro::Url::Quirks
    #   url = Ferro::Url::Url.parse("https://example.com/a")
    #   quirks.set_search(url, "q=1")
    #   quirks.search(url) # => "?q=1"
    #   quirks.protocol(url) # => "https:"
    module Quirks
      # The URL Standard's +domainToASCII+
      # (https://url.spec.whatwg.org/#dom-url-domaintoascii): the domain's
      # ASCII form, or the empty string when it is not a valid domain.
      # Mirrors url's <tt>quirks::domain_to_ascii</tt>
      # (<tt>src/quirks.rs:62-68</tt>).
      #
      # [domain] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Url::Quirks.domain_to_ascii("Bücher.example") # => "xn--bcher-kva.example"
      def self.domain_to_ascii(domain)
        Native.quirks_domain_to_ascii(domain)
      end

      # The URL Standard's +domainToUnicode+
      # (https://url.spec.whatwg.org/#dom-url-domaintounicode): the domain's
      # Unicode form, or the empty string when it is not a valid domain.
      # Mirrors url's <tt>quirks::domain_to_unicode</tt>
      # (<tt>src/quirks.rs:70-79</tt>).
      #
      # [domain] String, UTF-8 text.
      #
      # === Example
      #
      #   Ferro::Url::Quirks.domain_to_unicode("xn--bcher-kva.example") # => "bücher.example"
      def self.domain_to_unicode(domain)
        Native.quirks_domain_to_unicode(domain)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-href: the
      # serialization, as Url#as_str. Mirrors url's <tt>quirks::href</tt>
      # (<tt>src/quirks.rs:81-84</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.href(url) # => "https://user:pass@example.com:8080/a?b#c"
      def self.href(url)
        Native.quirks_get(Arguments.native(url), :href)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-origin: the
      # origin's ASCII serialization. Mirrors url's
      # <tt>quirks::origin</tt> (<tt>src/quirks.rs:92-95</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.origin(url) # => "https://example.com:8080"
      def self.origin(url)
        Native.quirks_get(Arguments.native(url), :origin)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-protocol: the
      # scheme with its <tt>:</tt>. Mirrors url's
      # <tt>quirks::protocol</tt> (<tt>src/quirks.rs:97-101</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.protocol(url) # => "https:"
      def self.protocol(url)
        Native.quirks_get(Arguments.native(url), :protocol)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-username. Mirrors
      # url's <tt>quirks::username</tt> (<tt>src/quirks.rs:114-118</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.username(url) # => "user"
      def self.username(url)
        Native.quirks_get(Arguments.native(url), :username)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-password: the
      # empty string when there is none. Mirrors url's
      # <tt>quirks::password</tt> (<tt>src/quirks.rs:126-130</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.password(url) # => "pass"
      def self.password(url)
        Native.quirks_get(Arguments.native(url), :password)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-host: the host and
      # port. Mirrors url's <tt>quirks::host</tt>
      # (<tt>src/quirks.rs:142-146</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.host(url) # => "example.com:8080"
      def self.host(url)
        Native.quirks_get(Arguments.native(url), :host)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-hostname: the
      # host, or the empty string. Mirrors url's <tt>quirks::hostname</tt>
      # (<tt>src/quirks.rs:195-199</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.hostname(url) # => "example.com"
      def self.hostname(url)
        Native.quirks_get(Arguments.native(url), :hostname)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-port: the port, or
      # the empty string. Mirrors url's <tt>quirks::port</tt>
      # (<tt>src/quirks.rs:240-244</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.port(url) # => "8080"
      def self.port(url)
        Native.quirks_get(Arguments.native(url), :port)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-pathname: the
      # path. Mirrors url's <tt>quirks::pathname</tt>
      # (<tt>src/quirks.rs:270-274</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.pathname(url) # => "/a"
      def self.pathname(url)
        Native.quirks_get(Arguments.native(url), :pathname)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-search: the query
      # with its <tt>?</tt>, or the empty string for none or an empty one.
      # Mirrors url's <tt>quirks::search</tt>
      # (<tt>src/quirks.rs:299-302</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.search(url) # => "?b"
      def self.search(url)
        Native.quirks_get(Arguments.native(url), :search)
      end

      # Getter for https://url.spec.whatwg.org/#dom-url-hash: the fragment
      # with its <tt>#</tt>, or the empty string for none or an empty one.
      # Mirrors url's <tt>quirks::hash</tt>
      # (<tt>src/quirks.rs:313-316</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://user:pass@example.com:8080/a?b#c")
      #   quirks.hash(url) # => "#c"
      def self.hash(url)
        Native.quirks_get(Arguments.native(url), :hash)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-href: replaces the
      # whole URL with +value+ parsed, raising a ParseError variant if it
      # does not parse. Mirrors url's <tt>quirks::set_href</tt>
      # (<tt>src/quirks.rs:86-90</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_href(url, "http://example.org/")
      def self.set_href(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_href, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-protocol: the
      # scheme, ignoring everything from the first <tt>:</tt>, as the URL
      # Standard's scheme state does. Raises Error where Url#set_scheme
      # would. Mirrors url's <tt>quirks::set_protocol</tt>
      # (<tt>src/quirks.rs:103-112</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_protocol(url, "http:")
      def self.set_protocol(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_protocol, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-username. Raises
      # Error where Url#set_username would. Mirrors url's
      # <tt>quirks::set_username</tt> (<tt>src/quirks.rs:120-124</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_username(url, "admin")
      def self.set_username(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_username, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-password: the
      # empty string removes the password. Raises Error where
      # Url#set_password would. Mirrors url's
      # <tt>quirks::set_password</tt> (<tt>src/quirks.rs:132-140</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_password(url, "")
      def self.set_password(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_password, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-host: a host and
      # optional port, parsed by the URL Standard's strict host rules,
      # without trimming. Raises Error when the URL is cannot-be-a-base or
      # the host does not parse. Mirrors url's <tt>quirks::set_host</tt>
      # (<tt>src/quirks.rs:148-193</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_host(url, "example.org:81")
      def self.set_host(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_host, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-hostname: a host
      # without a port; a <tt>:</tt> in it raises Error, as does a host
      # that does not parse or a cannot-be-a-base URL. Mirrors url's
      # <tt>quirks::set_hostname</tt> (<tt>src/quirks.rs:201-238</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_hostname(url, "example.org")
      def self.set_hostname(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_hostname, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-port: the leading
      # digits of +value+ become the port, and the scheme's default
      # removes it. Raises Error when the URL has no host, an empty one,
      # the +file+ scheme, or +value+ starts with no digit. Mirrors url's
      # <tt>quirks::set_port</tt> (<tt>src/quirks.rs:246-268</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_port(url, "8443")
      def self.set_port(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_port, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-pathname: does
      # nothing for a cannot-be-a-base URL, and adds the leading
      # <tt>/</tt> a special URL needs. Mirrors url's
      # <tt>quirks::set_pathname</tt> (<tt>src/quirks.rs:276-297</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_pathname(url, "b/c")
      def self.set_pathname(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_pathname, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-search: the empty
      # string removes the query, and one leading <tt>?</tt> is dropped.
      # Mirrors url's <tt>quirks::set_search</tt>
      # (<tt>src/quirks.rs:304-311</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_search(url, "?q=1")
      def self.set_search(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_search, value)
      end

      # Setter for https://url.spec.whatwg.org/#dom-url-hash: the empty
      # string removes the fragment, and one leading <tt>#</tt> is
      # dropped. Mirrors url's <tt>quirks::set_hash</tt>
      # (<tt>src/quirks.rs:318-328</tt>).
      #
      # [url] Url.
      # [value] String.
      #
      # === Example
      #
      #   quirks = Ferro::Url::Quirks
      #   url = Ferro::Url::Url.parse("https://example.com/a")
      #   quirks.set_hash(url, "#top")
      def self.set_hash(url, value)
        url.__send__(:writable!)
        Native.quirks_set(Arguments.native(url), :set_hash, value)
      end

      # The internal components and offsets of a URL, which can be useful
      # for implementing efficient serialization for the URL. url builds
      # this only with its +expose_internals+ feature, which this gem turns
      # on. Mirrors url's <tt>quirks::internal_components</tt>
      # (<tt>src/quirks.rs:44-60</tt>).
      #
      # [url] Url.
      #
      # === Example
      #
      #   Ferro::Url::Quirks.internal_components(Ferro::Url::Url.parse("https://example.com/")).path_start # => 19
      def self.internal_components(url)
        scheme_end, username_end, host_start, host_end, port, path_start, query_start, fragment_start =
          Native.quirks_internal_components(Arguments.native(url))
        InternalComponents.new(scheme_end:, username_end:, host_start:, host_end:, port:, path_start:, query_start:,
          fragment_start:)
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end

require_relative "quirks/internal_components"
