# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

# Approved #[allow(clippy::...)] exceptions, by path and line. Each entry
# explains why the code cannot satisfy the lint.

allow "gems/global-hotkey/ext/ferro_global_hotkey/src/manager.rs", line: 43,
  reason: "magnus requires every wrapped type to be Send (magnus 0.9.3 TypedData), and global-hotkey's " \
    "Windows manager holds an HWND, so its wrapper asserts Send and the lint names that field. The handle " \
    "may move: another thread's register and unregister fail through global-hotkey's own errors, and the " \
    "wrapper (owned.rs) defers the destructor to the window's thread, the one DestroyWindow needs " \
    "(plan 004, decision 3)."
