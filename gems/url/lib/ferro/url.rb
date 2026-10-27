# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "url/version"
require_relative "url/ferro_url"
require_relative "url/arguments"
require_relative "url/error"
require_relative "url/parse_error"
require_relative "url/syntax_violation"
require_relative "url/position"
require_relative "url/host"
require_relative "url/opaque_origin"
require_relative "url/origin"
require_relative "url/parse_options"
require_relative "url/url"
require_relative "url/path_segments_mut"
require_relative "url/url_query"
require_relative "url/form_urlencoded"
require_relative "url/quirks"

# Gems that bind Rust crates to Ruby one to one.
#
# Rust has well-tested crates for jobs Ruby's standard library leaves
# alone, such as parsing URLs the way browsers do. Each Ferro gem binds one
# crate, keeps its names and behavior, and adds nothing of its own.
module Ferro
  #--
  # SPDX-SnippetBegin
  # SPDX-License-Identifier: MIT OR Apache-2.0
  # SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
  # SPDX-SnippetComment: the crate overview from url 2.5.8 src/lib.rs:9-129
  #++

  # The URL Standard, through url 2.5.8.
  #
  # rust-url is an implementation of the URL Standard
  # (http://url.spec.whatwg.org/), the rules browsers use to parse, resolve,
  # and serialize URLs. Ruby's +URI+ follows RFC 3986, an older and
  # stricter grammar, so the two disagree about many strings a browser
  # accepts: backslashes, missing slashes, international domains, ports.
  #
  # This module binds url (https://github.com/servo/rust-url), the crate
  # Servo, Firefox's Rust code, and Tauri use, one to one. Parse with
  # Url.parse, which raises a ParseError when URL parsing fails for one of
  # its reasons; read and change components with Url's methods; resolve
  # references against a base with Url#join, as a browser resolves
  # <tt>href="../main.css"</tt>; and encode forms with FormUrlencoded.
  #
  # === Examples
  #
  #   require "ferro/url"
  #
  #   issues = Ferro::Url::Url.parse("https://github.com/rust-lang/rust/issues?labels=E-easy&state=open")
  #   issues.host_str # => "github.com"
  #   issues.query_pairs.to_a # => [["labels", "E-easy"], ["state", "open"]]
  #
  #   Ferro::Url::Url.parse("http://[:::1]")
  #   # raises Ferro::Url::ParseError::InvalidIpv6Address: invalid IPv6 address
  #
  #   page = Ferro::Url::Url.parse("http://servo.github.io/rust-url/url/index.html")
  #   page.join("../main.css").as_str # => "http://servo.github.io/rust-url/main.css"
  module Url
    private_constant :Native, :Arguments
  end

  #--
  # SPDX-SnippetEnd
  #++
end
