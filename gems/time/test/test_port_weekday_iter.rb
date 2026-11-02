# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

#--
# SPDX-SnippetBegin
# SPDX-License-Identifier: MIT OR Apache-2.0
# SPDX-SnippetCopyrightText: Jacob Pratt et al.
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/weekday_iter.rs
#++

# time's own tests in <tt>tests/integration/weekday_iter.rs</tt>, ported whole: each
# method is the Rust test of the same name, run for every start its
# +rstest+ template lists (and every value of a second +#[values]+ list),
# so a failure names the case. A +#[should_panic(expected = "infinite")]+
# test asserts the +RangeError+ the gem raises instead, with time's
# message (plan 010, decision 8).
class TestPortWeekdayIter < Minitest::Test
  include TimeSuite

  WEEKDAYS = Weekday.const_get(:ALL)

  # Runs the block once for each start in the +all_weekdays+ template.
  private def each_start(&)
    WEEKDAYS.each(&)
  end

  # Asserts the block raises the +RangeError+ that stands for time's
  # panic, whose message names the iterator as infinite.
  private def assert_infinite(&)
    error = assert_raises(RangeError, &)
    assert_match(/infinite/, error.message)
  end

  # <tt>weekday_iter.rs:13-18</tt>, +new+.
  def test_new
    each_start do |start|
      iter = T::Iter::WeekdayIter.new(start)
      assert_equal start, iter.next
      assert_equal start.next, iter.next
    end
  end

  # <tt>weekday_iter.rs:20-25</tt>, +iter_from+.
  def test_iter_from
    each_start do |start|
      iter = Weekday.iter_from(start)
      assert_equal start, iter.next
      assert_equal start.next, iter.next
    end
  end

  # <tt>weekday_iter.rs:27-30</tt>, +size_hint+.
  def test_size_hint
    each_start do |start|
      assert_equal [(2 ** 64) - 1, nil], T::Iter::WeekdayIter.new(start).size_hint
    end
  end

  # <tt>weekday_iter.rs:32-36</tt>, +nth+.
  def test_nth
    each_start do |start|
      (1..7).each do |n|
        assert_equal start.nth_next(n), T::Iter::WeekdayIter.new(start).nth(n), "#{start.inspect} nth(#{n})"
      end
    end
  end

  # <tt>weekday_iter.rs:38-44</tt>, +any_checks_all_weekdays+.
  def test_any_checks_all_weekdays
    each_start do |start|
      WEEKDAYS.each do |target|
        assert(T::Iter::WeekdayIter.new(start).any { |day| day == target }, "#{start.inspect} #{target.inspect}")
      end
    end
  end

  # <tt>weekday_iter.rs:46-49</tt>, +any_terminates+.
  def test_any_terminates
    each_start { |start| refute(T::Iter::WeekdayIter.new(start).any { false }) }
  end

  # <tt>weekday_iter.rs:51-57</tt>, +all_checks_all_weekdays+.
  def test_all_checks_all_weekdays
    each_start do |start|
      WEEKDAYS.each do |excludes|
        refute(T::Iter::WeekdayIter.new(start).all { |day| day != excludes }, "#{start.inspect} #{excludes.inspect}")
      end
    end
  end

  # <tt>weekday_iter.rs:59-62</tt>, +all_terminates+.
  def test_all_terminates
    each_start { |start| assert(T::Iter::WeekdayIter.new(start).all { true }) }
  end

  # <tt>weekday_iter.rs:64-68</tt>, +count_panics+.
  def test_count_panics
    each_start { |start| assert_infinite { T::Iter::WeekdayIter.new(start).count } }
  end

  # <tt>weekday_iter.rs:70-74</tt>, +last_panics+.
  def test_last_panics
    each_start { |start| assert_infinite { T::Iter::WeekdayIter.new(start).last } }
  end

  # <tt>weekday_iter.rs:76-81</tt>, +rev_next+.
  def test_rev_next
    each_start do |start|
      iter = T::Iter::WeekdayIter.new(start).rev
      assert_equal start, iter.next
      assert_equal start.previous, iter.next
    end
  end

  # <tt>weekday_iter.rs:83-90</tt>, +rev_nth+.
  def test_rev_nth
    each_start do |start|
      (1..7).each do |n|
        assert_equal start.nth_prev(n), T::Iter::WeekdayIter.new(start).rev.nth(n), "#{start.inspect} nth(#{n})"
      end
    end
  end

  # <tt>weekday_iter.rs:92-98</tt>, +rev_size_hint+.
  def test_rev_size_hint
    each_start do |start|
      assert_equal [(2 ** 64) - 1, nil], T::Iter::WeekdayIter.new(start).rev.size_hint
    end
  end

  # <tt>weekday_iter.rs:112-118</tt>, +rev_any_checks_all_weekdays+.
  def test_rev_any_checks_all_weekdays
    each_start do |start|
      WEEKDAYS.each do |target|
        assert(T::Iter::WeekdayIter.new(start).rev.any { |day| day == target }, "#{start.inspect} #{target.inspect}")
      end
    end
  end

  # <tt>weekday_iter.rs:120-123</tt>, +rev_any_terminates+.
  def test_rev_any_terminates
    each_start { |start| refute(T::Iter::WeekdayIter.new(start).rev.any { false }) }
  end

  # <tt>weekday_iter.rs:125-131</tt>, +rev_all_checks_all_weekdays+.
  def test_rev_all_checks_all_weekdays
    each_start do |start|
      WEEKDAYS.each do |excludes|
        refute(T::Iter::WeekdayIter.new(start).rev.all { |day| day != excludes }, "#{start.inspect} #{excludes.inspect}")
      end
    end
  end

  # <tt>weekday_iter.rs:133-136</tt>, +rev_all_terminates+.
  def test_rev_all_terminates
    each_start { |start| assert(T::Iter::WeekdayIter.new(start).rev.all { true }) }
  end

  # <tt>weekday_iter.rs:100-104</tt>, +rev_count_panics+.
  def test_rev_count_panics
    each_start { |start| assert_infinite { T::Iter::WeekdayIter.new(start).rev.count } }
  end

  # <tt>weekday_iter.rs:106-110</tt>, +rev_last_panics+.
  def test_rev_last_panics
    each_start { |start| assert_infinite { T::Iter::WeekdayIter.new(start).rev.last } }
  end
end

#--
# SPDX-SnippetEnd
#++
