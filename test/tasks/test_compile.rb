# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "open3"
require "rbconfig"

# rb_sys's rb_sys:env:default task, shared by every extension task, set
# RB_SYS_CARGO_MANIFEST_DIR once per rake run to the first gem's crate, and
# each Makefile's ?= let that win, so the second gem compiled the first
# gem's crate and shipped a stale extension (plan 002, decision 14). This
# loads the real Rakefile, with every gem's extension task, in a child
# rake and runs the task.
class TestCompile < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  CHILD = <<~RUBY
    require "rake"
    Rake.application.init("rake", [])
    Rake.application.load_rakefile
    Rake::Task["rb_sys:env:default"].invoke
    print ENV.fetch("RB_SYS_CARGO_MANIFEST_DIR", "unset"), "|", ENV.fetch("RB_SYS_CARGO_PROFILE", "unset")
  RUBY

  def test_the_shared_env_task_leaves_each_makefile_its_own_crate
    env = { "RB_SYS_CARGO_MANIFEST_DIR" => nil, "RB_SYS_CARGO_PROFILE" => nil }
    output, errors, status = Open3.capture3(env, RbConfig.ruby, "-e", CHILD, chdir: ROOT)

    assert status.success?, errors
    manifest_dir, profile = output.split("|")

    assert_equal "unset", manifest_dir
    assert_equal "release", profile
  end
end
