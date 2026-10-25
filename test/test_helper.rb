# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

# The root tests cover Ferro's tooling (tasks/ and .agents/), not its gems;
# each gem's tests live in gems/<name>/test.
require "minitest/autorun"
require "stringio"

# The tests make throwaway git repositories and delete them in teardown.
# After a commit, git starts `git maintenance run --auto` in the background
# (maintenance.autoDetach, on by default since git 2.47), which creates and
# removes .git/objects/maintenance.lock while teardown deletes the
# directory, so the removal can fail on a file that vanished (seen on
# macOS CI). Every git the tests run, directly or through the tasks they
# test, skips that work.
ENV["GIT_CONFIG_COUNT"] = "2"
ENV["GIT_CONFIG_KEY_0"] = "maintenance.auto"
ENV["GIT_CONFIG_VALUE_0"] = "false"
ENV["GIT_CONFIG_KEY_1"] = "gc.auto"
ENV["GIT_CONFIG_VALUE_1"] = "0"
