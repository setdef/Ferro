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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/month_iter.rs
#++

# time's own tests in <tt>tests/integration/month_iter.rs</tt>, ported whole: each
# method is the Rust test of the same name, run for every start its
# +rstest+ template lists (and every value of a second +#[values]+ list),
# so a failure names the case. A +#[should_panic(expected = "infinite")]+
# test asserts the +RangeError+ the gem raises instead, with time's
# message (plan 010, decision 8).
class TestPortMonthIter < Minitest::Test
  include TimeSuite

  MONTHS = Month.const_get(:ALL)

  # Runs the block once for each start in the +all_months+ template.
  private def each_start(&)
    MONTHS.each(&)
  end

  # Asserts the block raises the +RangeError+ that stands for time's
  # panic, whose message names the iterator as infinite.
  private def assert_infinite(&)
    error = assert_raises(RangeError, &)
    assert_match(/infinite/, error.message)
  end

  # <tt>month_iter.rs:17-22</tt>, +new+.
  def test_new
    each_start do |start|
      iter = T::Iter::MonthIter.new(start)
      assert_equal start, iter.next
      assert_equal start.next, iter.next
    end
  end

  # <tt>month_iter.rs:24-29</tt>, +iter_from+.
  def test_iter_from
    each_start do |start|
      iter = Month.iter_from(start)
      assert_equal start, iter.next
      assert_equal start.next, iter.next
    end
  end

  # <tt>month_iter.rs:31-34</tt>, +size_hint+.
  def test_size_hint
    each_start do |start|
      assert_equal [(2 ** 64) - 1, nil], T::Iter::MonthIter.new(start).size_hint
    end
  end

  # <tt>month_iter.rs:36-39</tt>, +max+.
  def test_max
    each_start { |start| assert_equal Month::December, T::Iter::MonthIter.new(start).max }
  end

  # <tt>month_iter.rs:41-44</tt>, +min+.
  def test_min
    each_start { |start| assert_equal Month::January, T::Iter::MonthIter.new(start).min }
  end

  # <tt>month_iter.rs:46-49</tt>, +is_sorted+.
  def test_is_sorted
    each_start { |start| refute T::Iter::MonthIter.new(start).is_sorted }
  end

  # <tt>month_iter.rs:51-55</tt>, +nth+.
  def test_nth
    each_start do |start|
      (1..12).each do |n|
        assert_equal start.nth_next(n), T::Iter::MonthIter.new(start).nth(n), "#{start.inspect} nth(#{n})"
      end
    end
  end

  # <tt>month_iter.rs:57-67</tt>, +any_checks_all_months+.
  def test_any_checks_all_months
    each_start do |start|
      MONTHS.each do |target|
        assert(T::Iter::MonthIter.new(start).any { |month| month == target }, "#{start.inspect} #{target.inspect}")
      end
    end
  end

  # <tt>month_iter.rs:69-72</tt>, +any_terminates+.
  def test_any_terminates
    each_start { |start| refute(T::Iter::MonthIter.new(start).any { false }) }
  end

  # <tt>month_iter.rs:74-84</tt>, +all_checks_all_months+.
  def test_all_checks_all_months
    each_start do |start|
      MONTHS.each do |excludes|
        refute(T::Iter::MonthIter.new(start).all { |month| month != excludes }, "#{start.inspect} #{excludes.inspect}")
      end
    end
  end

  # <tt>month_iter.rs:86-89</tt>, +all_terminates+.
  def test_all_terminates
    each_start { |start| assert(T::Iter::MonthIter.new(start).all { true }) }
  end

  # <tt>month_iter.rs:124-128</tt>, +count_panics+.
  def test_count_panics
    each_start { |start| assert_infinite { T::Iter::MonthIter.new(start).count } }
  end

  # <tt>month_iter.rs:130-134</tt>, +last_panics+.
  def test_last_panics
    each_start { |start| assert_infinite { T::Iter::MonthIter.new(start).last } }
  end

  # <tt>month_iter.rs:91-96</tt>, +rev_next+.
  def test_rev_next
    each_start do |start|
      iter = T::Iter::MonthIter.new(start).rev
      assert_equal start, iter.next
      assert_equal start.previous, iter.next
    end
  end

  # <tt>month_iter.rs:98-102</tt>, +rev_nth+.
  def test_rev_nth
    each_start do |start|
      (0..11).each do |n|
        assert_equal start.nth_prev(n), T::Iter::MonthIter.new(start).rev.nth(n), "#{start.inspect} nth(#{n})"
      end
    end
  end

  # <tt>month_iter.rs:104-107</tt>, +rev_size_hint+.
  def test_rev_size_hint
    each_start do |start|
      assert_equal [(2 ** 64) - 1, nil], T::Iter::MonthIter.new(start).rev.size_hint
    end
  end

  # <tt>month_iter.rs:109-112</tt>, +rev_max+.
  def test_rev_max
    each_start { |start| assert_equal Month::December, T::Iter::MonthIter.new(start).rev.max }
  end

  # <tt>month_iter.rs:114-117</tt>, +rev_min+.
  def test_rev_min
    each_start { |start| assert_equal Month::January, T::Iter::MonthIter.new(start).rev.min }
  end

  # <tt>month_iter.rs:119-122</tt>, +rev_is_sorted+.
  def test_rev_is_sorted
    each_start { |start| refute T::Iter::MonthIter.new(start).rev.is_sorted }
  end

  # <tt>month_iter.rs:148-158</tt>, +rev_any_checks_all_months+.
  def test_rev_any_checks_all_months
    each_start do |start|
      MONTHS.each do |target|
        assert(T::Iter::MonthIter.new(start).rev.any { |month| month == target }, "#{start.inspect} #{target.inspect}")
      end
    end
  end

  # <tt>month_iter.rs:160-163</tt>, +rev_any_terminates+.
  def test_rev_any_terminates
    each_start { |start| refute(T::Iter::MonthIter.new(start).rev.any { false }) }
  end

  # <tt>month_iter.rs:165-175</tt>, +rev_all_checks_all_months+.
  def test_rev_all_checks_all_months
    each_start do |start|
      MONTHS.each do |excludes|
        refute(T::Iter::MonthIter.new(start).rev.all { |month| month != excludes }, "#{start.inspect} #{excludes.inspect}")
      end
    end
  end

  # <tt>month_iter.rs:177-180</tt>, +rev_all_terminates+.
  def test_rev_all_terminates
    each_start { |start| assert(T::Iter::MonthIter.new(start).rev.all { true }) }
  end

  # <tt>month_iter.rs:136-140</tt>, +rev_count_panics+.
  def test_rev_count_panics
    each_start { |start| assert_infinite { T::Iter::MonthIter.new(start).rev.count } }
  end

  # <tt>month_iter.rs:142-146</tt>, +rev_last_panics+.
  def test_rev_last_panics
    each_start { |start| assert_infinite { T::Iter::MonthIter.new(start).rev.last } }
  end
end

#--
# SPDX-SnippetEnd
#++
