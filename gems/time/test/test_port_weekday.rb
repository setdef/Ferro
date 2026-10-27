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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/weekday.rs
#++

# time's own tests in <tt>tests/integration/weekday.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortWeekday < Minitest::Test
  include TimeSuite

  # Asserts +actual+ is +expected+, which may be +nil+, as Rust's
  # +assert_eq!+ compares an +Option+.
  private def assert_case(expected, actual, message = nil)
    return assert_nil(actual, message) if expected.nil?

    assert_equal expected, actual, message
  end

  # The block's value, or +nil+ when it raises time's error, as Rust's
  # +Result::ok+ turns an +Err+ into +None+.
  private def ok
    yield
  rescue T::Error
    nil
  end

  # Names a deprecated method quietly, since the tests run under -w.
  private def quietly
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = false
    yield
  ensure
    Warning[:deprecated] = deprecated
  end

  # <tt>weekday.rs:12</tt>, +previous+.
  def test_previous
    [
      [Weekday::Sunday, Weekday::Saturday],
      [Weekday::Monday, Weekday::Sunday],
      [Weekday::Tuesday, Weekday::Monday],
      [Weekday::Wednesday, Weekday::Tuesday],
      [Weekday::Thursday, Weekday::Wednesday],
      [Weekday::Friday, Weekday::Thursday],
      [Weekday::Saturday, Weekday::Friday],
    ].each do |current, expected|
      assert_case expected, current.previous
    end
  end

  # <tt>weekday.rs:24</tt>, +next+.
  def test_next
    [
      [Weekday::Sunday, Weekday::Monday],
      [Weekday::Monday, Weekday::Tuesday],
      [Weekday::Tuesday, Weekday::Wednesday],
      [Weekday::Wednesday, Weekday::Thursday],
      [Weekday::Thursday, Weekday::Friday],
      [Weekday::Friday, Weekday::Saturday],
      [Weekday::Saturday, Weekday::Sunday],
    ].each do |current, expected|
      assert_case expected, current.next
    end
  end

  # <tt>weekday.rs:47</tt>, +nth_next+.
  def test_nth_next
    [
      [Weekday::Sunday, 0, Weekday::Sunday],
      [Weekday::Sunday, 1, Weekday::Monday],
      [Weekday::Sunday, 2, Weekday::Tuesday],
      [Weekday::Sunday, 3, Weekday::Wednesday],
      [Weekday::Sunday, 4, Weekday::Thursday],
      [Weekday::Sunday, 5, Weekday::Friday],
      [Weekday::Sunday, 6, Weekday::Saturday],
      [Weekday::Monday, 0, Weekday::Monday],
      [Weekday::Monday, 1, Weekday::Tuesday],
      [Weekday::Monday, 2, Weekday::Wednesday],
      [Weekday::Monday, 3, Weekday::Thursday],
      [Weekday::Monday, 4, Weekday::Friday],
      [Weekday::Monday, 5, Weekday::Saturday],
      [Weekday::Monday, 6, Weekday::Sunday],
      [Weekday::Sunday, 7, Weekday::Sunday],
      [Weekday::Sunday, 255, Weekday::Wednesday],
      [Weekday::Monday, 7, Weekday::Monday],
      [Weekday::Monday, 255, Weekday::Thursday],
    ].each do |current, n, expected|
      assert_case expected, current.nth_next(n)
    end
  end

  # <tt>weekday.rs:70</tt>, +nth_prev+.
  def test_nth_prev
    [
      [Weekday::Sunday, 0, Weekday::Sunday],
      [Weekday::Sunday, 1, Weekday::Saturday],
      [Weekday::Sunday, 2, Weekday::Friday],
      [Weekday::Sunday, 3, Weekday::Thursday],
      [Weekday::Sunday, 4, Weekday::Wednesday],
      [Weekday::Sunday, 5, Weekday::Tuesday],
      [Weekday::Sunday, 6, Weekday::Monday],
      [Weekday::Monday, 0, Weekday::Monday],
      [Weekday::Monday, 1, Weekday::Sunday],
      [Weekday::Monday, 2, Weekday::Saturday],
      [Weekday::Monday, 3, Weekday::Friday],
      [Weekday::Monday, 4, Weekday::Thursday],
      [Weekday::Monday, 5, Weekday::Wednesday],
      [Weekday::Monday, 6, Weekday::Tuesday],
      [Weekday::Sunday, 7, Weekday::Sunday],
      [Weekday::Sunday, 255, Weekday::Thursday],
      [Weekday::Monday, 7, Weekday::Monday],
      [Weekday::Monday, 255, Weekday::Friday],
    ].each do |current, n, expected|
      assert_case expected, current.nth_prev(n)
    end
  end

  # <tt>weekday.rs:82</tt>, +number_from_monday+.
  def test_number_from_monday
    [
      [Weekday::Monday, 1],
      [Weekday::Tuesday, 2],
      [Weekday::Wednesday, 3],
      [Weekday::Thursday, 4],
      [Weekday::Friday, 5],
      [Weekday::Saturday, 6],
      [Weekday::Sunday, 7],
    ].each do |weekday, expected|
      assert_case expected, weekday.number_from_monday
    end
  end

  # <tt>weekday.rs:94</tt>, +number_from_sunday+.
  def test_number_from_sunday
    [
      [Weekday::Sunday, 1],
      [Weekday::Monday, 2],
      [Weekday::Tuesday, 3],
      [Weekday::Wednesday, 4],
      [Weekday::Thursday, 5],
      [Weekday::Friday, 6],
      [Weekday::Saturday, 7],
    ].each do |weekday, expected|
      assert_case expected, weekday.number_from_sunday
    end
  end

  # <tt>weekday.rs:106</tt>, +number_days_from_monday+.
  def test_number_days_from_monday
    [
      [Weekday::Monday, 0],
      [Weekday::Tuesday, 1],
      [Weekday::Wednesday, 2],
      [Weekday::Thursday, 3],
      [Weekday::Friday, 4],
      [Weekday::Saturday, 5],
      [Weekday::Sunday, 6],
    ].each do |weekday, expected|
      assert_case expected, weekday.number_days_from_monday
    end
  end

  # <tt>weekday.rs:118</tt>, +number_days_from_sunday+.
  def test_number_days_from_sunday
    [
      [Weekday::Sunday, 0],
      [Weekday::Monday, 1],
      [Weekday::Tuesday, 2],
      [Weekday::Wednesday, 3],
      [Weekday::Thursday, 4],
      [Weekday::Friday, 5],
      [Weekday::Saturday, 6],
    ].each do |weekday, expected|
      assert_case expected, weekday.number_days_from_sunday
    end
  end

  # <tt>weekday.rs:130</tt>, +display+.
  def test_display
    [
      [Weekday::Monday, "Monday"],
      [Weekday::Tuesday, "Tuesday"],
      [Weekday::Wednesday, "Wednesday"],
      [Weekday::Thursday, "Thursday"],
      [Weekday::Friday, "Friday"],
      [Weekday::Saturday, "Saturday"],
      [Weekday::Sunday, "Sunday"],
    ].each do |weekday, expected|
      assert_case expected, weekday.to_s
    end
  end

  # <tt>weekday.rs:143</tt>, +from_str+.
  def test_from_str
    [
      ["Monday", Weekday::Monday],
      ["Tuesday", Weekday::Tuesday],
      ["Wednesday", Weekday::Wednesday],
      ["Thursday", Weekday::Thursday],
      ["Friday", Weekday::Friday],
      ["Saturday", Weekday::Saturday],
      ["Sunday", Weekday::Sunday],
      ["foo", :err],
    ].each do |text, expected|
      if expected == :err
        assert_raises(T::Error::InvalidVariant) { Weekday.from_str(text) }
      else
        assert_case expected, Weekday.from_str(text)
      end
    end
  end
end

#--
# SPDX-SnippetEnd
#++
