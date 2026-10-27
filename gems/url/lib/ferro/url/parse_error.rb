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
    # SPDX-SnippetComment: ParseError, its variants, and their Display text
    #   from url 2.5.8 src/parser.rs:50-99
    #++

    # Errors that can occur during parsing.
    #
    # A URL fails to parse for a handful of reasons, each with its own
    # remedy: a relative reference needs a base, a port must be a number
    # under 65536, a host cannot be empty. One error for all of them would
    # leave you guessing which.
    #
    # Each of url's variants is a subclass with url's message, the text a
    # Tauri app shows for a bad argument. url may add variants in the
    # future; one this gem does not know yet raises this class itself, with
    # url's message.
    #
    # Mirrors url's +ParseError+ (<tt>src/parser.rs:50-99</tt>).
    #
    # === Examples
    #
    #   begin
    #     Ferro::Url::Url.parse("../main.css")
    #   rescue Ferro::Url::ParseError::RelativeUrlWithoutBase => e
    #     e.message # => "relative URL without a base"
    #   end
    #
    #   begin
    #     Ferro::Url::Url.parse("http://[:::1]")
    #   rescue Ferro::Url::ParseError => e
    #     e.class # => Ferro::Url::ParseError::InvalidIpv6Address
    #   end
    class ParseError < StandardError
      # url's message for each variant, by class name.
      MESSAGES = {
        EmptyHost: "empty host",
        IdnaError: "invalid international domain name",
        InvalidPort: "invalid port number",
        InvalidIpv4Address: "invalid IPv4 address",
        InvalidIpv6Address: "invalid IPv6 address",
        InvalidDomainCharacter: "invalid domain character",
        RelativeUrlWithoutBase: "relative URL without a base",
        RelativeUrlWithCannotBeABaseBase: "relative URL with a cannot-be-a-base base",
        SetHostOnCannotBeABaseUrl: "a cannot-be-a-base URL doesn’t have a host to set",
        Overflow: "URLs more than 4 GB are not supported",
      }.freeze
      private_constant :MESSAGES

      # Creates the error. Without a +message+, or with +nil+, a variant's
      # message is url's.
      #
      # [message] String, the error message.
      #
      # === Example
      #
      #   Ferro::Url::ParseError::EmptyHost.new.message # => "empty host"
      def initialize(message = nil)
        super(message || MESSAGES[self.class.name.to_s.split("::").last.to_s.to_sym])
      end

      # The host is empty, where a URL needs one: <tt>http://</tt>.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://") # raises Ferro::Url::ParseError::EmptyHost
      class EmptyHost < ParseError
      end

      # The domain failed IDNA processing (UTS #46): "invalid international
      # domain name".
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://xn--a/") # raises Ferro::Url::ParseError::IdnaError
      class IdnaError < ParseError
      end

      # The port is not a number from 0 to 65535: "invalid port number".
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://example.com:99999/") # raises Ferro::Url::ParseError::InvalidPort
      class InvalidPort < ParseError
      end

      # A host that ends in a number is not a valid IPv4 address.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://1.2.3.4.5/") # raises Ferro::Url::ParseError::InvalidIpv4Address
      class InvalidIpv4Address < ParseError
      end

      # A bracketed host is not a valid IPv6 address.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("http://[:::1]") # raises Ferro::Url::ParseError::InvalidIpv6Address
      class InvalidIpv6Address < ParseError
      end

      # The host holds a character no host may: "invalid domain character".
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("foo://exa mple/") # raises Ferro::Url::ParseError::InvalidDomainCharacter
      class InvalidDomainCharacter < ParseError
      end

      # A relative reference with no base URL to resolve it against.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("../main.css") # raises Ferro::Url::ParseError::RelativeUrlWithoutBase
      class RelativeUrlWithoutBase < ParseError
      end

      # A relative reference whose base is a cannot-be-a-base URL, such as a
      # <tt>data:</tt> URL.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("data:text/plain,Stuff").join("other") # raises Ferro::Url::ParseError::RelativeUrlWithCannotBeABaseBase
      class RelativeUrlWithCannotBeABaseBase < ParseError
      end

      # Url#set_host on a cannot-be-a-base URL, which has no host to set.
      #
      # === Example
      #
      #   Ferro::Url::Url.parse("mailto:rms@example.net").set_host("example.com")
      #   # raises Ferro::Url::ParseError::SetHostOnCannotBeABaseUrl
      class SetHostOnCannotBeABaseUrl < ParseError
      end

      # The URL would be longer than 4 GB, which url does not support.
      #
      # === Example
      #
      #   Ferro::Url::ParseError::Overflow.new.message # => "URLs more than 4 GB are not supported"
      class Overflow < ParseError
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
