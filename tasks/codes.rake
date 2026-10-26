# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require_relative "keyboard_types_codes"

desc "Regenerate ferro-global-hotkey's Hotkey::Code from the keyboard-types its Cargo.lock pins"
task "codes:global-hotkey" do
  KeyboardTypesCodes.write
end
