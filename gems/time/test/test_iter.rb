# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Ruby side of time's iterators (plan 010, batch 1): argument types,
# Enumerable over a copy, the overrides' argument forms, the sized
# Enumerator, copies and frozen iterators, equality and +inspect+, +all+
# and +any+ with blocks that raise or break, and what a reversed weekday
# iterator cannot do.
class TestIter < Minitest::Test
  include TimeSuite

  I = Ferro::Time::Iter

  private def january(day)
    date(2019, 1, day)
  end

  private def five_days
    january(1).iter_to(january(5))
  end

  def test_arguments_are_checked_as_rusts_types_are
    error = assert_raises(TypeError) { I::DateIter.new(1, january(1)) }
    assert_equal "no implicit conversion of Integer into Ferro::Time::Date", error.message
    assert_raises(TypeError) { january(1).iter_to("2019-01-05") }
    error = assert_raises(TypeError) { I::MonthIter.new(Weekday::Monday) }
    assert_equal "no implicit conversion of Ferro::Time::Weekday into Ferro::Time::Month", error.message
    assert_raises(TypeError) { Weekday.iter_from(Month::May) }
    assert_raises(RangeError) { five_days.nth(-1) }
    assert_raises(RangeError) { Month.iter_from(Month::May).nth(2 ** 64) }
  end

  def test_enumerable_walks_a_copy_from_the_current_place
    iter = five_days
    assert_equal january(1), iter.next
    assert_equal [january(2), january(3)], iter.first(2)
    assert_equal [january(2), january(3)], iter.first(2)
    assert_equal (2..5).map { |day| january(day) }, iter.to_a
    assert_equal january(2), iter.next
    assert_equal %w[2019-01-03 2019-01-04 2019-01-05], iter.map(&:to_s)
    assert_includes iter, january(4)
  end

  def test_each_returns_the_iterator_and_keeps_its_place
    iter = five_days
    seen = []
    assert_same iter, iter.each { |d| seen << d }
    assert_equal 5, seen.size
    assert_equal 5, iter.len
  end

  def test_each_without_a_block_is_an_enumerator_with_times_size
    iter = five_days
    iter.next
    enumerator = iter.each
    assert_kind_of Enumerator, enumerator
    assert_equal 4, enumerator.size
    assert_equal Float::INFINITY, Month.iter_from(Month::May).each.size
    assert_equal Float::INFINITY, Weekday.iter_from(Weekday::Friday).rev.each.size
    assert_equal [january(2), january(3)], enumerator.take(2)
  end

  def test_the_overrides_take_enumerables_arguments_too
    iter = five_days
    assert_equal 1, iter.count(january(3))
    assert_equal 2, iter.count { |d| d.day.even? }
    assert_equal [january(5), january(4)], iter.max(2)
    assert_equal [january(1), january(2)], iter.min(2)
    assert_equal january(1), iter.max { |a, b| b <=> a }
    assert_equal january(5), iter.min { |a, b| b <=> a }
    assert_equal 5, iter.len, "Enumerable's forms walk a copy and consume nothing"
    assert_equal 5, iter.count
    assert_raises(IOError) { iter.len }
    months = Month.iter_from(Month::May)
    assert_equal 1, months.each.lazy.select { |m| m == Month::June }.first(1).size
  end

  def test_an_infinite_iterator_runs_until_the_block_breaks
    seen = []
    Month.iter_from(Month::November).each do |month|
      seen << month
      break if seen.size == 3
    end
    assert_equal [Month::November, Month::December, Month::January], seen
    assert_equal [[Weekday::Sunday, Weekday::Monday]], Weekday.iter_from(Weekday::Sunday).each_slice(2).first(1)
    assert Month.iter_from(Month::May).any? { |m| m == Month::April }
  end

  def test_next_never_ends_for_the_cycles
    months = Month.iter_from(Month::December)
    assert_equal [Month::December] + Month.const_get(:ALL) + [Month::January], Array.new(14) { months.next }
    days = Weekday.iter_from(Weekday::Monday).rev
    assert_equal [Weekday::Monday, Weekday::Sunday, Weekday::Saturday], Array.new(3) { days.next }
  end

  def test_rev_starts_from_the_place_and_consumes_the_iterator
    months = Month.iter_from(Month::January)
    months.next
    rev = months.rev
    assert_equal [Month::February, Month::January, Month::December], rev.first(3)
    error = assert_raises(IOError) { months.next }
    assert_equal "Ferro::Time::Iter::MonthIter consumed by MonthIter#rev", error.message
    assert_kind_of I::Rev, Weekday.iter_from(Weekday::Monday).rev
    assert_raises(NoMethodError) { I::Rev.new }
  end

  # The iterators and the methods of time's that take the iterator by
  # value (iter/date_iter.rs:91-98, :141-154; iter/month_iter.rs:46,
  # :73-111, :136-174; iter/weekday_iter.rs:45, :72-78, :119-125): each
  # uses it up, as a Rust move does.
  private def consumers
    [
      ["DateIter", -> { five_days }, %i[count last max min is_sorted]],
      ["MonthIter", -> { Month.iter_from(Month::May) }, %i[rev max min is_sorted]],
      ["WeekdayIter", -> { Weekday.iter_from(Weekday::Monday) }, %i[rev]],
      ["Rev", -> { Month.iter_from(Month::May).rev }, %i[max min is_sorted]],
    ]
  end

  # A consumed iterator raises IOError on any later use, as a closed IO
  # does (ADR 001, amendment of 2026-11-05; plan 007, Follow-up: the four
  # rulings), naming the method that consumed it.
  def test_a_method_that_takes_the_iterator_by_value_uses_it_up
    consumers.each do |type, make, methods|
      methods.each do |method|
        iter = make.call
        iter.public_send(method)
        {
          next: -> { iter.next },
          nth: -> { iter.nth(0) },
          size_hint: -> { iter.size_hint },
          debug: -> { iter.debug },
          dup: -> { iter.dup },
          clone: -> { iter.clone },
          first: -> { iter.first(1) },
          again: -> { iter.public_send(method) },
          left: -> { iter == make.call },
          right: -> { make.call == iter },
        }.each do |use, call|
          error = assert_raises(IOError, "#{type}##{method}, then #{use}", &call)
          assert_equal "Ferro::Time::Iter::#{type} consumed by #{type}##{method}", error.message
        end
      end
    end
  end

  def test_every_use_of_a_consumed_date_iter_raises
    iter = five_days
    iter.last
    [
      -> { iter.next_back },
      -> { iter.nth_back(0) },
      -> { iter.len },
      -> { iter.each { nil } },
      -> { iter.reverse_each { nil } },
      -> { iter.to_a },
      -> { iter.count(january(1)) },
    ].each { |use| assert_raises(IOError, &use) }
    assert_match(/\A#<Ferro::Time::Iter::DateIter:0x\h+>\z/, iter.inspect, "inspect stays Ruby's, as a closed IO's does")
  end

  def test_every_use_of_a_consumed_cycle_raises
    months = Month.iter_from(Month::May)
    months.is_sorted
    assert_raises(IOError) { months.all { true } }
    assert_raises(IOError) { months.any { true } }
    assert_raises(IOError) { months.count }
    assert_raises(IOError) { months.rev }
  end

  # time panics on count and last of a cycle after the move, so the cycle
  # is used up before the refusal.
  def test_counting_a_cycle_uses_it_up_before_it_refuses
    [
      ["MonthIter", -> { Month.iter_from(Month::May) }],
      ["WeekdayIter", -> { Weekday.iter_from(Weekday::Monday) }],
      ["Rev", -> { Month.iter_from(Month::May).rev }],
      ["Rev", -> { Weekday.iter_from(Weekday::Monday).rev }],
    ].each do |type, make|
      %i[count last].each do |method|
        iter = make.call
        assert_raises(RangeError) { iter.public_send(method) }
        error = assert_raises(IOError) { iter.next }
        assert_equal "Ferro::Time::Iter::#{type} consumed by #{type}##{method}", error.message
      end
    end
  end

  # Rust moves a binding that is not mut, and Ruby closes a frozen IO, so a
  # frozen iterator is consumed like any other.
  def test_a_frozen_iterator_can_be_consumed
    iter = five_days.freeze
    assert_equal january(5), iter.max
    assert_raises(IOError) { iter.len }
    months = Month.iter_from(Month::May).freeze
    assert_equal Month::May, months.rev.next
    assert_raises(IOError) { months.size_hint }
  end

  def test_dup_and_clone_copy_the_iterator
    iter = five_days
    copy = iter.dup
    assert_equal january(1), copy.next
    assert_equal january(1), iter.next
    months = Month.iter_from(Month::May)
    assert_equal months, months.clone
    rev = months.rev
    assert_equal rev, rev.dup
    refute_same rev, rev.dup
  end

  def test_a_frozen_iterator_does_not_advance
    iter = five_days.freeze
    [-> { iter.next }, -> { iter.next_back }, -> { iter.nth(1) }, -> { iter.nth_back(1) }].each do |advance|
      error = assert_raises(FrozenError, &advance)
      assert_equal "can't modify frozen Ferro::Time::Iter::DateIter: #{iter.inspect}", error.message
    end
    assert_equal 5, iter.len
    assert_equal 5, iter.to_a.size
    assert_predicate iter.clone, :frozen?
    refute_predicate iter.dup, :frozen?
    assert_equal january(1), iter.dup.next
    [Month.iter_from(Month::May), Weekday.iter_from(Weekday::Monday), Month.iter_from(Month::May).rev].each do |cycle|
      cycle.freeze
      assert_raises(FrozenError) { cycle.next }
      assert_raises(FrozenError) { cycle.nth(1) }
      assert cycle.all { true }
    end
  end

  def test_initialize_copy_and_initialize_refuse_a_frozen_iterator
    frozen = five_days.freeze
    assert_raises(FrozenError) { frozen.__send__(:initialize_copy, five_days) }
    assert_raises(FrozenError) { frozen.__send__(:initialize, january(1), january(2)) }
    frozen_months = Month.iter_from(Month::May).freeze
    assert_raises(FrozenError) { frozen_months.__send__(:initialize, Month::June) }
    assert_raises(FrozenError) { Month.iter_from(Month::May).rev.freeze.__send__(:initialize_copy, Month.iter_from(Month::May).rev) }
  end

  def test_allocate_makes_values_the_public_api_also_makes
    assert_equal I::DateIter.new(T::Date::MAX, T::Date::MIN), I::DateIter.allocate
    assert_nil I::DateIter.allocate.next
    assert_equal Month.iter_from(Month::January), I::MonthIter.allocate
    assert_equal Weekday.iter_from(Weekday::Monday), I::WeekdayIter.allocate
    assert_raises(NoMethodError) { I::Rev.allocate }
    assert_raises(NoMethodError) { Month.iter_from(Month::May).rev.class.allocate }
  end

  def test_equality_is_times_derived_partial_eq
    assert_equal five_days, five_days
    advanced = five_days
    advanced.next
    refute_equal five_days, advanced
    refute five_days.eql?(five_days)
    refute_equal five_days, five_days.to_a
    refute_equal Month.iter_from(Month::May), Month.iter_from(Month::June)
    refute_equal Month.iter_from(Month::May).rev, Weekday.iter_from(Weekday::Monday).rev
    refute_equal Month.iter_from(Month::May), Month.iter_from(Month::May).rev
  end

  def test_debug_is_times_debug
    iter = five_days
    assert_equal january(5), iter.nth(4)
    # time leaves the front where it was when nth takes the last date.
    assert_equal "DateIter { front: 2019-01-01, back: None }", iter.debug
    assert_equal "Rev { iter: WeekdayIter { current: Sunday } }", Weekday.iter_from(Weekday::Sunday).rev.debug
    assert_match(/\A#<Ferro::Time::Iter::DateIter:0x\h+>\z/, iter.inspect)
  end

  def test_all_and_any_test_each_item_once_from_the_first_and_leave_the_iterator_alone
    months = Month.iter_from(Month::May)
    seen = []
    assert(months.all { |m| seen << m })
    assert_equal Month.const_get(:ALL), seen
    assert_equal Month::May, months.next
    days = []
    refute(Weekday.iter_from(Weekday::Friday).rev.any { |d| (days << d) && false })
    assert_equal Weekday.const_get(:ALL), days
  end

  def test_all_and_any_pass_on_a_raise_or_a_break
    months = Month.iter_from(Month::May)
    error = assert_raises(ZeroDivisionError) { months.all { 1 / 0 } }
    assert_equal "divided by 0", error.message
    assert_equal :done, months.any { break :done }
    count = 0
    assert_equal 3, Weekday.iter_from(Weekday::Monday).all { ((count += 1) == 3) ? (break count) : true }
    assert_raises(LocalJumpError) { months.any }
    assert_equal Month::May, months.next
  end

  def test_a_raise_or_a_break_stops_times_loop_at_once
    iterators = [
      Month.iter_from(Month::May),
      Weekday.iter_from(Weekday::Monday),
      Month.iter_from(Month::May).rev,
      Weekday.iter_from(Weekday::Monday).rev,
]
    iterators.product(%i[all any]).each do |iter, method|
      calls = 0
      assert_raises(ArgumentError) do
        iter.public_send(method) do
          calls += 1
          raise ArgumentError
        end
      end
      assert_equal 1, calls, "#{iter.inspect} #{method} after a raise"
      calls = 0
      result = iter.public_send(method) do
        calls += 1
        break :out
      end
      assert_equal :out, result
      assert_equal 1, calls, "#{iter.inspect} #{method} after a break"
    end
  end

  def test_all_and_any_keep_their_items_through_a_collection
    GC.stress = true
    answer = Month.iter_from(Month::May).rev.all { |m| m.to_s.dup.length.positive? }
  ensure
    GC.stress = false
    assert answer
  end

  def test_a_reversed_weekday_iterator_lacks_what_weekdays_lack
    rev = Weekday.iter_from(Weekday::Monday).rev
    forward = Weekday.iter_from(Weekday::Monday)
    expected = assert_raises(ArgumentError) { forward.max }
    assert_equal expected.message, assert_raises(ArgumentError) { rev.max }.message
    assert_equal expected.message, assert_raises(ArgumentError) { rev.min }.message
    refute_respond_to forward, :is_sorted
    refute_respond_to rev, :is_sorted
    assert_raises(NoMethodError) { rev.__send__(:is_sorted) }
    months = -> { Month.iter_from(Month::May).rev }
    assert_respond_to months.call, :is_sorted
    refute months.call.is_sorted
    assert_equal Month::December, months.call.max
    assert_equal Month::January, months.call.min
  end

  def test_both_kinds_of_rev_are_revs_and_copy_as_their_kind
    months = Month.iter_from(Month::May).rev
    days = Weekday.iter_from(Weekday::Monday).rev
    [months, days].each do |rev|
      assert_kind_of I::Rev, rev
      assert_instance_of rev.class, rev.dup
      assert_equal rev, rev.clone
    end
    refute_equal months.class, days.class
    assert_equal Weekday::Monday, days.dup.next
    error = assert_raises(TypeError) { days.dup.__send__(:initialize_copy, months) }
    assert_equal "initialize_copy should take same class object", error.message
  end

  def test_a_blocks_stop_iteration_leaves_an_infinite_each
    [
      Month.iter_from(Month::May),
      Weekday.iter_from(Weekday::Monday),
      Month.iter_from(Month::May).rev,
      Weekday.iter_from(Weekday::Monday).rev,
].each do |iter|
      calls = 0
      assert_raises(StopIteration, iter.inspect) do
        iter.each do
          calls += 1
          raise StopIteration
        end
      end
      assert_equal 1, calls
    end
  end

  def test_date_iter_reverse_each_walks_back_from_a_copy
    iter = five_days
    iter.next
    assert_equal (2..5).map { |day| january(day) }.reverse, iter.reverse_each.to_a
    assert_equal 4, iter.reverse_each.size
    seen = []
    assert_same iter, iter.reverse_each { |d| seen << d }
    assert_equal 4, seen.size
    assert_equal january(2), iter.next
    assert_equal [T::Date::MAX, T::Date::MAX.previous_day], january(1).iter_to(T::Date::MAX).reverse_each.first(2)
  end

  def test_max_and_min_of_nil_are_times
    assert_equal Month::December, Month.iter_from(Month::May).max(nil)
    assert_equal Month::January, Month.iter_from(Month::May).min(nil)
    assert_equal Month::December, Month.iter_from(Month::May).rev.max(nil)
    assert_equal january(5), five_days.max(nil)
    assert_equal january(1), five_days.min(nil)
  end

  def test_iterators_stay_in_their_ractor
    [five_days, Month.iter_from(Month::May), Weekday.iter_from(Weekday::Monday), Month.iter_from(Month::May).rev]
      .each do |iter|
        refute Ractor.shareable?(iter.freeze)
        assert_raises(Ractor::Error) { Ractor.make_shareable(iter) }
      end
  end
end
