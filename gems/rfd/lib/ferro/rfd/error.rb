# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

module Ferro
  module Rfd
    # rfd could not do what you asked, and would have panicked or hung.
    #
    # rfd reports no errors. A dialog the user cancels returns +nil+, and a
    # dialog that cannot open at all usually does too. A few calls it
    # cannot complete end in a Rust panic instead, which would end your
    # Ruby process, or in a wait that never ends.
    #
    # This class carries those cases as an exception you can rescue:
    #
    # - A panic inside rfd, with the message <tt>rfd panicked: ...</tt>.
    #   FileHandle#read raises one through Future#value when the file
    #   cannot be read, since rfd unwraps the read.
    # - On macOS, a dialog started off the main thread while no
    #   application runs its event loop. rfd would panic; ferro-rfd refuses
    #   first, with rfd's message.
    # - On macOS, Future#value on the main thread while a sheet needs the
    #   main thread's run loop to finish. That wait would never end.
    #
    # rfd has no error type, so this class is ferro-rfd's own.
    #
    # === Examples
    #
    #   Thread.new do
    #     Ferro::Rfd::FileDialog.new.pick_file
    #   rescue Ferro::Rfd::Error => e
    #     warn e.message # on macOS, without a running app: "You are running RFD in NonWindowed environment, ..."
    #   end.join
    #
    #   begin
    #     Ferro::Rfd::FileHandle.new("/no/such/file").read.value
    #   rescue Ferro::Rfd::Error => e
    #     warn e.message # => "rfd panicked: called `Result::unwrap()` on an `Err` value: ..."
    #   end
    class Error < StandardError
    end
  end
end
