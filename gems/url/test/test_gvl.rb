# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# socket_addrs resolves through the system's resolver, which can wait for
# DNS, so it runs the lookup on a thread of its own and waits with Ruby's
# global VM lock released, where an interrupt ends the wait; every other
# call keeps the lock (plan 005, decision 11). The native layer counts each
# wait, and its private gvl_sleep runs a sleep through the same wait, as a
# lookup that never answers would.
class TestGvl < Minitest::Test
  include UrlSuite

  NATIVE = Ferro::Url.const_get(:Native)

  private def releases
    before = NATIVE.gvl_releases
    yield
    NATIVE.gvl_releases - before
  end

  def test_socket_addrs_releases_the_lock_once
    assert_equal 1, releases { url("https://localhost/").socket_addrs }
  end

  def test_other_calls_keep_the_lock
    assert_equal 0, releases {
      target = url("https://example.com/a")
      target.join("b")
      target.set_path("/c")
      target.query_pairs_mut.append_pair("d", "e")
      target.origin
    }
  end

  def test_other_threads_run_during_the_wait
    count = 0
    counter = Thread.new { loop { count += 1 } }
    NATIVE.gvl_sleep(0.3)
    counter.kill

    assert_operator count, :>, 1000
  end

  def test_an_interrupt_ends_the_wait
    require "timeout"

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(Timeout::Error) { Timeout.timeout(0.2) { NATIVE.gvl_sleep(10.0) } }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5

    waiter = Thread.new { NATIVE.gvl_sleep(10.0) }
    waiter.report_on_exception = false
    sleep 0.1
    waiter.raise(ArgumentError, "stop")
    assert_raises(ArgumentError) { waiter.join(5) }
  end

  def test_the_block_runs_only_when_url_would_ask_for_a_port
    calls = 0
    port = lambda do
      calls += 1
      9743
    end
    url("https://127.0.0.1/").socket_addrs(&port)

    assert_equal 0, calls
    assert_equal 9743, url("custom://127.0.0.1/").socket_addrs(&port).first.ip_port
    assert_equal 1, calls
    assert_raises(IOError) { url("data:text/plain,x").socket_addrs(&port) }
    assert_equal 1, calls
  end
end
