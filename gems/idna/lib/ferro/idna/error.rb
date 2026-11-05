# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Idna
    # A call into idna panicked.
    #
    # idna has one error, Errors, and raises it for what idna itself
    # returns: a domain that fails UTS #46. A panic inside idna would end
    # the Ruby process, so the gem catches it and raises this class instead,
    # with the message <tt>idna panicked: ...</tt>. Errors is not a
    # subclass: rescue the two separately.
    #
    # The inputs idna is known to panic on never reach it. The gem refuses
    # them first with +ArgumentError+ and idna's panic message, so this
    # class is for a panic the gem did not foresee.
    #
    # === Example
    #
    # The rescue is defensive: idna panics on no input the gem passes it.
    #
    #   begin
    #     Ferro::Idna.domain_to_ascii_strict("example.com")
    #   rescue Ferro::Idna::Error => e
    #     warn e.message # => "idna panicked: ..."
    #   end
    class Error < StandardError
    end
  end
end
