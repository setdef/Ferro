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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/date_iter.rs
#++

# time's own tests in <tt>tests/integration/date_iter.rs</tt>, ported
# whole: each method is the Rust test of the same name, with its
# <tt>#[case]</tt>s as rows. Rust's +Vec+ is an Array, its tuples are
# Arrays, and +None+ is +nil+.
class TestPortDateIter < Minitest::Test
  include TimeSuite

  MIN = T::Date::MIN
  MAX = T::Date::MAX
  AFTER_MIN = T::Date::MIN.next_day
  BEFORE_MAX = T::Date::MAX.previous_day

  # Asserts +actual+ is +expected+, which may be +nil+, as Rust's
  # +assert_eq!+ compares an +Option+.
  private def assert_case(expected, actual, message = nil)
    return assert_nil(actual, message) if expected.nil?

    assert_equal expected, actual, message
  end

  # <tt>date_iter.rs:11-29</tt>, +forward+.
  def test_forward
    [
      [date(2019, 1, 1), date(2019, 1, 3), [date(2019, 1, 1), date(2019, 1, 2), date(2019, 1, 3)]],
      [date(2019, 1, 1), date(2019, 1, 1), [date(2019, 1, 1)]],
      [date(2019, 1, 3), date(2019, 1, 1), []],
      [
        date(2019, 12, 30),
        date(2020, 1, 2),
        [date(2019, 12, 30), date(2019, 12, 31), date(2020, 1, 1), date(2020, 1, 2)],
],
      [MIN, AFTER_MIN, [MIN, AFTER_MIN]],
      [BEFORE_MAX, MAX, [BEFORE_MAX, MAX]],
    ].each do |start, finish, expected|
      assert_equal expected, start.iter_to(finish).to_a, "#{start}..#{finish}"
    end
  end

  # <tt>date_iter.rs:31-40</tt>, +double_ended+.
  def test_double_ended
    iter = date(2019, 1, 1).iter_to(date(2019, 1, 5))
    assert_equal date(2019, 1, 1), iter.next
    assert_equal date(2019, 1, 5), iter.next_back
    assert_equal date(2019, 1, 4), iter.next_back
    assert_equal date(2019, 1, 2), iter.next
    assert_equal date(2019, 1, 3), iter.next
    assert_nil iter.next
  end

  # <tt>date_iter.rs:42-49</tt>, +double_ended_to_self+.
  def test_double_ended_to_self
    d = date(2019, 6, 15)
    iter = d.iter_to(d)
    assert_equal d, iter.next_back
    assert_nil iter.next_back
    assert_nil iter.next
  end

  # <tt>date_iter.rs:51-58</tt>, +new+.
  def test_new
    iter = T::Iter::DateIter.new(date(2020, 1, 1), date(2020, 1, 3))
    assert_equal date(2020, 1, 1), iter.next
    assert_equal date(2020, 1, 2), iter.next
    assert_equal date(2020, 1, 3), iter.next
    assert_nil iter.next
  end

  # <tt>date_iter.rs:60-66</tt>, +size_hint+.
  def test_size_hint
    [
      [date(2019, 1, 1), date(2019, 1, 5), [5, 5]],
      [date(2019, 1, 5), date(2019, 1, 1), [0, 0]],
      [date(2019, 1, 1), date(2019, 1, 1), [1, 1]],
    ].each do |start, finish, expected|
      assert_equal expected, start.iter_to(finish).size_hint
    end
  end

  # <tt>date_iter.rs:68-75</tt>, +count+.
  def test_count
    [
      [date(2019, 1, 1), date(2019, 1, 5), 5],
      [date(2019, 1, 1), date(2019, 1, 1), 1],
      [date(2019, 1, 5), date(2019, 1, 1), 0],
      [date(-9999, 1, 1), date(-9999, 12, 31), 365],
    ].each do |start, finish, expected|
      assert_equal expected, start.iter_to(finish).count
    end
  end

  # <tt>date_iter.rs:77-83</tt>, +last+.
  def test_last
    [
      [date(2019, 1, 1), date(2019, 1, 5), date(2019, 1, 5)],
      [date(2019, 1, 1), date(2019, 1, 1), date(2019, 1, 1)],
      [date(2019, 1, 5), date(2019, 1, 1), nil],
    ].each do |start, finish, expected|
      assert_case expected, start.iter_to(finish).last
    end
  end

  # <tt>date_iter.rs:85-91</tt>, +max+.
  def test_max
    [
      [date(2019, 1, 1), date(2019, 1, 5), date(2019, 1, 5)],
      [date(2019, 1, 1), date(2019, 1, 1), date(2019, 1, 1)],
      [date(2019, 1, 5), date(2019, 1, 1), nil],
    ].each do |start, finish, expected|
      assert_case expected, start.iter_to(finish).max
    end
  end

  # <tt>date_iter.rs:93-99</tt>, +min+.
  def test_min
    [
      [date(2019, 1, 1), date(2019, 1, 5), date(2019, 1, 1)],
      [date(2019, 1, 1), date(2019, 1, 1), date(2019, 1, 1)],
      [date(2019, 1, 5), date(2019, 1, 1), nil],
    ].each do |start, finish, expected|
      assert_case expected, start.iter_to(finish).min
    end
  end

  # <tt>date_iter.rs:101-120</tt>, +nth+.
  def test_nth
    [
      [date(2019, 1, 1), date(2019, 1, 5), 0, date(2019, 1, 1)],
      [date(2019, 1, 1), date(2019, 1, 5), 2, date(2019, 1, 3)],
      [date(2019, 1, 1), date(2019, 1, 5), 4, date(2019, 1, 5)],
      [date(2019, 1, 1), date(2019, 1, 5), 5, nil],
      [date(2019, 1, 5), date(2019, 1, 1), 0, nil],
      [MAX, MAX, 0, MAX],
      [MAX, MAX, 1, nil],
      [BEFORE_MAX, MAX, 1, MAX],
      [BEFORE_MAX, MAX, 2, nil],
      [date(2019, 12, 30), date(2020, 1, 1), 2, date(2020, 1, 1)],
      [date(2019, 1, 1), date(2019, 12, 31), 364, date(2019, 12, 31)],
      [date(2020, 1, 1), date(2020, 12, 31), 365, date(2020, 12, 31)],
    ].each do |start, finish, n, expected|
      iter = start.iter_to(finish)
      assert_case expected, iter.nth(n), "#{start}..#{finish} nth(#{n})"
      assert_nil iter.next if (expected.nil? || expected == finish) && start <= finish
    end
  end

  # <tt>date_iter.rs:122-146</tt>, +nth_back+.
  def test_nth_back
    [
      [date(2019, 1, 1), date(2019, 1, 5), 0, date(2019, 1, 5)],
      [date(2019, 1, 1), date(2019, 1, 5), 2, date(2019, 1, 3)],
      [date(2019, 1, 1), date(2019, 1, 5), 4, date(2019, 1, 1)],
      [date(2019, 1, 1), date(2019, 1, 5), 5, nil],
      [date(2019, 1, 5), date(2019, 1, 1), 0, nil],
      [MIN, MIN, 0, MIN],
      [MIN, MIN, 1, nil],
      [MIN, AFTER_MIN, 1, MIN],
      [MIN, AFTER_MIN, 2, nil],
      [date(2019, 12, 30), date(2020, 1, 1), 2, date(2019, 12, 30)],
      [date(2019, 1, 1), date(2019, 12, 31), 364, date(2019, 1, 1)],
      [date(2020, 1, 1), date(2020, 12, 31), 365, date(2020, 1, 1)],
    ].each do |start, finish, n, expected|
      iter = start.iter_to(finish)
      assert_case expected, iter.nth_back(n), "#{start}..#{finish} nth_back(#{n})"
      assert_nil iter.next_back if (expected.nil? || expected == start) && start <= finish
    end
  end

  # <tt>date_iter.rs:148-156</tt>, +nth_mixed+.
  def test_nth_mixed
    iter = date(2019, 1, 1).iter_to(date(2019, 1, 7))
    assert_equal date(2019, 1, 3), iter.nth(2)
    assert_equal date(2019, 1, 6), iter.nth_back(1)
    assert_equal date(2019, 1, 4), iter.next
    assert_equal date(2019, 1, 5), iter.next_back
    assert_nil iter.next
  end

  # <tt>date_iter.rs:158-165</tt>, +nth_back_after_next+.
  def test_nth_back_after_next
    iter = date(2019, 1, 1).iter_to(date(2019, 1, 5))
    assert_equal date(2019, 1, 1), iter.next
    assert_equal date(2019, 1, 3), iter.nth_back(2)
    assert_equal date(2019, 1, 2), iter.next
    assert_nil iter.next
  end

  # <tt>date_iter.rs:167-173</tt>, +len+.
  def test_len
    [
      [date(2019, 1, 1), date(2019, 1, 5), 5],
      [date(2019, 1, 1), date(2019, 1, 1), 1],
      [date(2019, 1, 5), date(2019, 1, 1), 0],
    ].each do |start, finish, expected|
      assert_equal expected, start.iter_to(finish).len
    end
  end

  # <tt>date_iter.rs:175-181</tt>, +is_sorted+.
  def test_is_sorted
    [
      [date(2019, 1, 1), date(2019, 1, 5)],
      [date(2019, 1, 1), date(2019, 1, 1)],
      [date(2019, 1, 5), date(2019, 1, 1)],
    ].each do |start, finish|
      assert start.iter_to(finish).is_sorted
    end
  end

  # <tt>date_iter.rs:183-196</tt>, +fused+.
  def test_fused
    [
      [date(2019, 1, 1), date(2019, 1, 3)],
      [date(2019, 1, 5), date(2019, 1, 1)],
      [MIN, MIN],
      [MAX, MAX],
      [MIN, AFTER_MIN],
      [BEFORE_MAX, MAX],
    ].each do |start, finish|
      iter = start.iter_to(finish)
      nil while iter.next
      assert_nil iter.next
      assert_nil iter.next
      assert_nil iter.next_back
    end
  end

  # <tt>date_iter.rs:198-205</tt>, +boundary_single+.
  def test_boundary_single
    [MIN, MAX].each do |d|
      iter = d.iter_to(d)
      assert_equal d, iter.next
      assert_nil iter.next
    end
  end

  # <tt>date_iter.rs:207-213</tt>, +boundary_two+.
  def test_boundary_two
    iter = MIN.iter_to(AFTER_MIN)
    assert_equal MIN, iter.next
    assert_equal AFTER_MIN, iter.next
    assert_nil iter.next
  end

  # <tt>date_iter.rs:215-227</tt>, +len_after_consumption+.
  def test_len_after_consumption
    iter = date(2019, 1, 1).iter_to(date(2019, 1, 5))
    assert_equal 5, iter.len
    iter.next
    assert_equal 4, iter.len
    iter.next_back
    assert_equal 3, iter.len
    iter.nth(1)
    assert_equal 1, iter.len
    iter.next
    assert_equal 0, iter.len
  end

  # <tt>date_iter.rs:229-244</tt>, +nth_cross_year+.
  def test_nth_cross_year
    [
      [date(2019, 12, 1), date(2020, 1, 31), 15, date(2019, 12, 16), date(2019, 12, 17)],
      [date(2020, 12, 1), date(2021, 1, 31), 15, date(2020, 12, 16), date(2020, 12, 17)],
      [date(2019, 12, 30), date(2020, 1, 5), 2, date(2020, 1, 1), date(2020, 1, 2)],
      [date(2019, 1, 1), date(2025, 1, 1), 400, date(2020, 2, 5), date(2020, 2, 6)],
    ].each do |start, finish, n, expected, next_expected|
      iter = start.iter_to(finish)
      assert_equal expected, iter.nth(n)
      assert_equal next_expected, iter.next
    end
  end

  # <tt>date_iter.rs:246-259</tt>, +nth_back_cross_year+.
  def test_nth_back_cross_year
    [
      [date(2019, 12, 30), date(2020, 1, 10), 9, date(2020, 1, 1), date(2019, 12, 31)],
      [date(2019, 12, 30), date(2020, 1, 5), 5, date(2019, 12, 31), date(2019, 12, 30)],
    ].each do |start, finish, n, expected, next_expected|
      iter = start.iter_to(finish)
      assert_equal expected, iter.nth_back(n)
      assert_equal next_expected, iter.next_back
    end
  end

  # <tt>date_iter.rs:261-267</tt>, +cross_year_span+.
  def test_cross_year_span
    start = date(2019, 12, 30)
    finish = date(2020, 1, 2)
    assert_equal 4, start.iter_to(finish).count
    assert_equal [4, 4], start.iter_to(finish).size_hint
    assert_equal 4, start.iter_to(finish).len
  end
end

#--
# SPDX-SnippetEnd
#++
