# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT
#++

module Ferro
  module Rfd
    # rfd panicked: it could not do what you asked.
    #
    # rfd reports no errors. A dialog the user cancels returns +nil+, and a
    # dialog that cannot open at all usually does too. A few calls it
    # cannot complete end in a Rust panic instead, which would end your
    # Ruby process.
    #
    # This class carries those panics as an exception you can rescue, with
    # the message <tt>rfd panicked: ...</tt> and rfd's own text:
    #
    # - A panic caught inside rfd. FileHandle#read raises one through
    #   Future#value when the file cannot be read, since rfd unwraps the
    #   read.
    # - On macOS, a dialog started off the main thread while no
    #   application runs its event loop. rfd would panic there after
    #   creating the application on the wrong thread, so ferro-rfd raises
    #   the same error first.
    #
    # Other refusals raise Ruby's own classes, as ADR 001's error rule has
    # it: +ArgumentError+ for an argument rfd would panic on (a window
    # handle the platform cannot take, or on Linux a NUL byte in a
    # filter), with rfd's panic text, and for a window number that names
    # none of your app's windows; +ThreadError+ for a wait that could never
    # finish, as Future#value on macOS for a sheet that needs the main
    # thread it would block; +IOError+ for a dialog or Future already used.
    #
    # rfd has no error type, so this class is ferro-rfd's own.
    #
    # === Examples
    #
    #   Thread.new do
    #     Ferro::Rfd::FileDialog.new.pick_file
    #   rescue Ferro::Rfd::Error => e
    #     warn e.message # on macOS, without a running app: "rfd panicked: You are running RFD in NonWindowed environment, ..."
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
