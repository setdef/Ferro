# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require_relative "ferro_notify_rust"
require_relative "builder"

# notify-rust compiles this only for Windows (src/notification.rs:195-200).
return unless Ferro::NotifyRust.const_get(:PLATFORM) == :windows

module Ferro
  module NotifyRust
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: 2017 Hendrik Sollich
    # SPDX-SnippetComment: Notification::app_id from notify-rust 4.18.2
    #   src/notification.rs:195-200 and the toast it reaches,
    #   src/windows.rs:76-79
    #++

    module Builder
      # Sets the app's <tt>System.AppUserModel.ID</tt>, which names the app
      # a toast comes from. Without one, notify-rust shows toasts as
      # PowerShell's. Defined only on Windows. Mirrors
      # <tt>Notification::app_id</tt> (<tt>src/notification.rs:195-200</tt>).
      #
      # [app_id] String.
      #
      # === Example
      #
      #   Ferro::NotifyRust::Notification.new.summary("Build done").app_id("Example.App").show
      def app_id(app_id)
        __send__(:native_app_id, app_id)
        self
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
