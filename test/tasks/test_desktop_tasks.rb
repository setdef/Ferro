# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require "json"
require "open3"
require "rbconfig"

# The test tasks sort each gem's desktop tests from the rest (plan 014):
# the core tasks never run a file in a gem's test/desktop/ and take
# FERRO_DESKTOP from their test processes; the desktop tasks run only those
# files, and only when FERRO_DESKTOP is 1; and the gate sets it before any
# test runs. Each test loads the real Rakefile in a child rake, with sh
# recording its commands in place of running them, and every task's
# prerequisites taken away, so nothing compiles or runs.
class TestDesktopTasks < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  CHILD = <<~RUBY
    require "rake"
    require "json"
    $commands = []
    Rake::FileUtilsExt.define_method(:sh) { |*command, **| $commands << command }
    Rake.application.init("rake", [])
    Rake.application.load_rakefile
    result = eval($stdin.read, TOPLEVEL_BINDING)
    print "\\n", JSON.generate(result)
  RUBY

  # The value of +script+ in a child rake with the Rakefile loaded, as
  # JSON, and what the child printed before it, with +env+ added to its
  # environment.
  private def in_rake(script, env = {})
    output, errors, status = Open3.capture3(env, RbConfig.ruby, "-e", CHILD, stdin_data: script, chdir: ROOT)
    assert status.success?, errors
    printed, _, json = output.rpartition("\n")
    [JSON.parse(json), printed]
  end

  # Runs the task +name+ alone, without its prerequisites, and returns the
  # commands it ran (each the environment, then the command) and what it
  # printed.
  private def invoke_alone(name, env = {})
    in_rake(<<~RUBY, env)
      task = Rake::Task[#{name.dump}]
      task.clear_prerequisites
      task.invoke
      $commands
    RUBY
  end

  # The files each Minitest task in +names+ runs, from the command its
  # :cmd task prints, by name. One child loads the Rakefile for them all,
  # since a load takes seconds on Windows.
  private def files_of(names)
    printed, = in_rake(<<~RUBY)
      require "stringio"
      #{names.inspect}.to_h do |name|
        out = StringIO.new
        $stdout = out
        Rake::Task["\#{name}:cmd"].invoke
        [name, out.string]
      ensure
        $stdout = STDOUT
      end
    RUBY
    printed.transform_values do |command|
      command.scan(/require "([^"]+)"/).flatten - ["tasks/test_watchdog", "tasks/desktop", "minitest/autorun"]
    end
  end

  private def gems_with_desktop_tests
    Dir.glob("gems/*/test/desktop/**/test_*.rb", base: ROOT).map { |path| path.split("/")[1] }.uniq.sort
  end

  def test_some_gem_has_desktop_tests
    refute_empty gems_with_desktop_tests
  end

  def test_the_core_tasks_run_every_test_file_but_the_desktop_ones
    expected = {}
    Dir.glob("gems/*", base: ROOT).each do |dir|
      gem = File.basename(dir)
      all = Dir.glob("#{dir}/test/**/test_*.rb", base: ROOT)
      desktop = Dir.glob("#{dir}/test/desktop/**/test_*.rb", base: ROOT)
      expected["test:ruby:core:#{gem}"] = (all - desktop).sort
      expected["test:ruby:desktop:#{gem}"] = desktop.sort unless desktop.empty?
    end

    files_of(expected.keys).each { |name, files| assert_equal expected.fetch(name), files.sort, name }
  end

  def test_no_core_task_reaches_a_desktop_task
    reached, = in_rake(<<~RUBY)
      seen = {}
      walk = lambda do |task|
        next if seen[task.name]

        seen[task.name] = true
        task.prerequisite_tasks.each(&walk)
      end
      walk.call(Rake::Task["test:core"])
      seen.keys
    RUBY

    assert_includes reached, "test:ruby:core:arboard"
    assert_empty reached.grep(/desktop/)
  end

  def test_a_desktop_task_runs_nothing_without_the_variable_and_says_why
    gems_with_desktop_tests.each do |gem|
      commands, printed = invoke_alone("test:ruby:desktop:#{gem}", "FERRO_DESKTOP" => nil)

      assert_empty commands, gem
      assert_includes printed, "test:desktop:#{gem}: skipped, since its tests would use this session's desktop " \
        "(set FERRO_DESKTOP=1 to run them; the gate does)"
    end
  end

  def test_with_the_variable_a_desktop_task_gives_it_to_its_test_process
    gems_with_desktop_tests.each do |gem|
      commands, = invoke_alone("test:ruby:desktop:#{gem}", "FERRO_DESKTOP" => "1")

      assert_equal 1, commands.size, gem
      env, command = commands.first
      assert_equal({ "FERRO_DESKTOP" => "1" }, env)
      assert_includes command, "Desktop.skip_each_test_without_a_session"
    end
  end

  def test_a_core_task_takes_the_variable_from_its_test_process
    commands, = invoke_alone("test:ruby:core:arboard", "FERRO_DESKTOP" => "1")

    assert_equal 1, commands.size
    env, command = commands.first
    assert_equal({ "FERRO_DESKTOP" => nil }, env)
    refute_includes command, "Desktop.skip_each_test_without_a_session"
  end

  def test_the_gate_lets_the_desktop_tests_run_before_anything_else
    first, = in_rake(<<~RUBY)
      ["default", *Rake::Task.tasks.map(&:name).grep(/\\Agate:/)].to_h { |name| [name, Rake::Task[name].prerequisites.first] }
    RUBY

    first.each { |name, prerequisite| assert_equal "test:allow_desktop", prerequisite, name }
    assert_operator first.size, :>, 1
    set, = in_rake(%(Rake::Task["test:allow_desktop"].invoke; ENV["FERRO_DESKTOP"]), "FERRO_DESKTOP" => nil)
    assert_equal "1", set
  end

  def test_each_gem_task_runs_its_core_tests_then_its_desktop_tests
    prerequisites, = in_rake(%(Rake::Task["test:arboard"].prerequisites))

    assert_equal %w[test:core:arboard test:desktop:arboard], prerequisites
  end
end
