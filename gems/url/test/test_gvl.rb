# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# socket_addrs resolves through the system's resolver, which can wait for
# DNS, so it runs the lookup on a thread of its own and waits with Ruby's
# global VM lock released, where an interrupt ends the wait; every other
# call keeps the lock (plan 005, decision 11, and Follow-up: the GVL is
# never held). The native layer counts each release.
#
# The lookups resolve localhost, which the system answers without the
# network. The private Native.gvl_hold_lookups holds every lookup that
# starts until a test lets it go, so a test decides when one finishes and
# no pass condition reads a clock; Native.gvl_refuse_threads makes the
# lookup thread fail to start, as an operating system out of threads
# would, so the lookup runs on the calling thread. Both switches are
# global, so each test that sets one runs in a child Ruby, which a
# deadlock cannot outlive (UrlSuite#in_child).
class TestGvl < Minitest::Test
  include UrlSuite

  NATIVE = Ferro::Url.const_get(:Native)

  private def releases
    before = NATIVE.gvl_releases
    yield
    NATIVE.gvl_releases - before
  end

  # Starts a thread that calls socket_addrs on localhost while lookups are
  # held, and returns once it sleeps in the released wait.
  HELD_LOOKUP = <<~RUBY
    native = Ferro::Url.const_get(:Native)
    native.gvl_hold_lookups(true)
    waiter = Thread.new { Ferro::Url::Url.parse("https://localhost/").socket_addrs.map(&:ip_address) }
    waiter.report_on_exception = false
    Thread.pass until waiter.status == "sleep"
  RUBY

  # Ruby asks an exception for its backtrace while raising it, with the
  # thread marked as raising (setup_exception, eval.c:542-543, and
  # rb_get_backtrace, error.c:1929, at v4.0.9), and a thread so marked
  # runs no interrupts (thread.c:2625), so the one Thread#wakeup makes
  # pending there stays pending. rb_thread_call_without_gvl2 skips its work
  # while any interrupt is pending (thread.c:320-327), so the gem's
  # previous wait retried forever with the GVL held. Here the releaser
  # thread lets the lookup go only once the reader sleeps in the released
  # wait, so the addresses prove the other thread ran during the call; a
  # wait that held the GVL would never end, and the child would be killed.
  WHILE_RAISING = <<~RUBY
    class WhileRaising < StandardError
      attr_reader :value

      def self.run(&block)
        raise new(&block)
      rescue WhileRaising => e
        e.value
      end

      def initialize(&block)
        super("raising")
        @block = block
      end

      def backtrace
        block, @block = @block, nil
        @value = block.call if block
        super
      end
    end

    native = Ferro::Url.const_get(:Native)
    native.gvl_hold_lookups(true)
    reader = Thread.current
    releaser = Thread.new do
      Thread.pass until reader.status == "sleep"
      native.gvl_hold_lookups(false)
    end
    addresses = WhileRaising.run do
      Thread.current.wakeup
      Ferro::Url::Url.parse("https://localhost/").socket_addrs.map(&:ip_address)
    end
    releaser.join
  RUBY

  private def assert_loopback(addresses)
    refute_empty addresses
    addresses.each { |address| assert_predicate IPAddr.new(address), :loopback? }
  end

  def test_socket_addrs_releases_the_lock_once
    assert_equal 1, releases { url("https://localhost/").socket_addrs }
  end

  def test_a_lookup_that_gets_a_thread_does_not_run_on_the_calling_thread
    before = NATIVE.gvl_fallbacks
    url("https://localhost/").socket_addrs

    assert_equal before, NATIVE.gvl_fallbacks
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

  # The main thread runs only while the waiter's lookup is held, and lets
  # it go itself, so the waiter's addresses prove it ran during the wait.
  def test_other_threads_run_during_the_wait
    addresses = in_child(<<~RUBY)
      #{HELD_LOOKUP}
      native.gvl_hold_lookups(false)
      waiter.value
    RUBY

    assert_loopback addresses
  end

  def test_a_lookup_made_while_raising_with_an_interrupt_pending_waits_with_the_gvl_released
    assert_loopback in_child("#{WHILE_RAISING}\naddresses")
  end

  # The lookup stays held until the child ends, so only the interrupt can
  # have ended the wait.
  def test_thread_raise_ends_a_lookup_wait
    error = in_child(<<~RUBY)
      #{HELD_LOOKUP}
      waiter.raise(ArgumentError, "stop")
      begin
        waiter.join
        nil
      rescue ArgumentError => e
        e.message
      end
    RUBY

    assert_equal "stop", error
  end

  def test_thread_kill_ends_a_lookup_wait
    status = in_child(<<~RUBY)
      #{HELD_LOOKUP}
      waiter.kill
      waiter.join
      waiter.status
    RUBY

    assert_equal false, status
  end

  def test_timeout_ends_a_lookup_wait
    error = in_child(<<~RUBY)
      require "timeout"
      native = Ferro::Url.const_get(:Native)
      native.gvl_hold_lookups(true)
      begin
        Timeout.timeout(0.2) { Ferro::Url::Url.parse("https://localhost/").socket_addrs }
      rescue Timeout::Error => e
        e.class.name
      end
    RUBY

    assert_equal "Timeout::Error", error
  end

  # An interrupt that raises nothing runs the unblocking function and ends
  # the wait without an answer; Ruby handles it and the wait starts again
  # (gvl.rs drive). Each wait counts a release, so a count that grew while
  # the thread sleeps again shows the second wait, and the addresses show
  # it still waited for the lookup.
  def test_a_wakeup_that_raises_nothing_leaves_the_lookup_waiting
    addresses = in_child(<<~RUBY)
      #{HELD_LOOKUP}
      before = native.gvl_releases
      waiter.wakeup
      Thread.pass until native.gvl_releases > before && waiter.status == "sleep"
      native.gvl_hold_lookups(false)
      waiter.value
    RUBY

    assert_loopback addresses
  end

  def test_a_lookup_runs_on_the_calling_thread_when_no_thread_starts
    released, fallbacks, addresses = in_child(<<~RUBY)
      native = Ferro::Url.const_get(:Native)
      native.gvl_refuse_threads(true)
      before = native.gvl_releases
      addresses = Ferro::Url::Url.parse("https://localhost/").socket_addrs.map(&:ip_address)
      [native.gvl_releases - before, native.gvl_fallbacks, addresses]
    RUBY

    assert_equal 1, released
    assert_equal 1, fallbacks
    assert_loopback addresses
  end

  # The fallback has no unblocking function, but still runs with the GVL
  # released when an interrupt is pending: the releaser lets the lookup go
  # while the reader sleeps in it on its own thread.
  def test_a_lookup_on_the_calling_thread_made_while_raising_releases_the_gvl
    fallbacks, addresses = in_child(<<~RUBY)
      Ferro::Url.const_get(:Native).gvl_refuse_threads(true)
      #{WHILE_RAISING}
      [native.gvl_fallbacks, addresses]
    RUBY

    assert_equal 1, fallbacks
    assert_loopback addresses
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
