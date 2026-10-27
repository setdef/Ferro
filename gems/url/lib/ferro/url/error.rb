# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Url
    # A url call failed without saying why.
    #
    # Many of url's setters and conversions answer only yes or no: Rust's
    # <tt>Result<(), ()></tt>, an error with nothing in it. Url#set_port
    # cannot set a port on a <tt>mailto:</tt> URL, Url#set_scheme cannot
    # turn +http+ into +foo+, Url.from_file_path cannot take a relative
    # path. Rust's compiler warns a caller who ignores the answer; Ruby
    # would let it pass in silence.
    #
    # So those methods raise this class, which ferro-url adds because url
    # has no error type to raise for them. The message names the url
    # function that refused, as in
    # <tt>url::Url::set_port returned Err(())</tt>. ParseError, url's own
    # error, is not a subclass: rescue it separately.
    #
    # The gem raises this class too where Rust would panic: a
    # FormUrlencoded::Serializer used after +finish+, or a slice of a URL
    # that runs backward. A panic inside url, which would otherwise end the
    # Ruby process, raises it with the message <tt>url panicked: ...</tt>.
    #
    # === Examples
    #
    #   url = Ferro::Url::Url.parse("mailto:rms@example.net")
    #   begin
    #     url.set_port(80)
    #   rescue Ferro::Url::Error => e
    #     e.message # => "url::Url::set_port returned Err(())"
    #   end
    class Error < StandardError
    end
  end
end
