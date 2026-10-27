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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/month.rs
#++

# time's own tests in <tt>tests/integration/month.rs</tt>, ported: each
# method is the Rust test of the same name, with its cases. Cases that
# need a feature this gem leaves off (large-dates) or a type it defers
# (std's Duration) are left out, as the comments say.
class TestPortMonth < Minitest::Test
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

  # <tt>month.rs:17</tt>, +previous+.
  def test_previous
    [
      [Month::January, Month::December],
      [Month::February, Month::January],
      [Month::March, Month::February],
      [Month::April, Month::March],
      [Month::May, Month::April],
      [Month::June, Month::May],
      [Month::July, Month::June],
      [Month::August, Month::July],
      [Month::September, Month::August],
      [Month::October, Month::September],
      [Month::November, Month::October],
      [Month::December, Month::November],
    ].each do |month, expected|
      assert_case expected, month.previous
    end
  end

  # <tt>month.rs:34</tt>, +next+.
  def test_next
    [
      [Month::January, Month::February],
      [Month::February, Month::March],
      [Month::March, Month::April],
      [Month::April, Month::May],
      [Month::May, Month::June],
      [Month::June, Month::July],
      [Month::July, Month::August],
      [Month::August, Month::September],
      [Month::September, Month::October],
      [Month::October, Month::November],
      [Month::November, Month::December],
      [Month::December, Month::January],
    ].each do |month, expected|
      assert_case expected, month.next
    end
  end

  # <tt>month.rs:67</tt>, +nth_next+.
  def test_nth_next
    [
      [Month::January, 0, Month::January],
      [Month::January, 1, Month::February],
      [Month::January, 2, Month::March],
      [Month::January, 3, Month::April],
      [Month::January, 4, Month::May],
      [Month::January, 5, Month::June],
      [Month::January, 6, Month::July],
      [Month::January, 7, Month::August],
      [Month::January, 8, Month::September],
      [Month::January, 9, Month::October],
      [Month::January, 10, Month::November],
      [Month::January, 11, Month::December],
      [Month::December, 0, Month::December],
      [Month::December, 1, Month::January],
      [Month::December, 2, Month::February],
      [Month::December, 3, Month::March],
      [Month::December, 4, Month::April],
      [Month::December, 5, Month::May],
      [Month::December, 6, Month::June],
      [Month::December, 7, Month::July],
      [Month::December, 8, Month::August],
      [Month::December, 9, Month::September],
      [Month::December, 10, Month::October],
      [Month::December, 11, Month::November],
      [Month::January, 12, Month::January],
      [Month::January, 255, Month::April],
      [Month::December, 12, Month::December],
      [Month::December, 255, Month::March],
    ].each do |month, n, expected|
      assert_case expected, month.nth_next(n)
    end
  end

  # <tt>month.rs:100</tt>, +nth_prev+.
  def test_nth_prev
    [
      [Month::January, 0, Month::January],
      [Month::January, 1, Month::December],
      [Month::January, 2, Month::November],
      [Month::January, 3, Month::October],
      [Month::January, 4, Month::September],
      [Month::January, 5, Month::August],
      [Month::January, 6, Month::July],
      [Month::January, 7, Month::June],
      [Month::January, 8, Month::May],
      [Month::January, 9, Month::April],
      [Month::January, 10, Month::March],
      [Month::January, 11, Month::February],
      [Month::December, 0, Month::December],
      [Month::December, 1, Month::November],
      [Month::December, 2, Month::October],
      [Month::December, 3, Month::September],
      [Month::December, 4, Month::August],
      [Month::December, 5, Month::July],
      [Month::December, 6, Month::June],
      [Month::December, 7, Month::May],
      [Month::December, 8, Month::April],
      [Month::December, 9, Month::March],
      [Month::December, 10, Month::February],
      [Month::December, 11, Month::January],
      [Month::January, 12, Month::January],
      [Month::January, 255, Month::October],
      [Month::December, 12, Month::December],
      [Month::December, 255, Month::September],
    ].each do |month, n, expected|
      assert_case expected, month.nth_prev(n)
    end
  end

  # <tt>month.rs:117</tt>, +display+.
  def test_display
    [
      [Month::January, "January"],
      [Month::February, "February"],
      [Month::March, "March"],
      [Month::April, "April"],
      [Month::May, "May"],
      [Month::June, "June"],
      [Month::July, "July"],
      [Month::August, "August"],
      [Month::September, "September"],
      [Month::October, "October"],
      [Month::November, "November"],
      [Month::December, "December"],
    ].each do |month, expected|
      assert_case expected, month.to_s
    end
  end

  # <tt>month.rs:135</tt>, +from_str+.
  def test_from_str
    [
      ["January", Month::January],
      ["February", Month::February],
      ["March", Month::March],
      ["April", Month::April],
      ["May", Month::May],
      ["June", Month::June],
      ["July", Month::July],
      ["August", Month::August],
      ["September", Month::September],
      ["October", Month::October],
      ["November", Month::November],
      ["December", Month::December],
      ["foo", :err],
    ].each do |text, expected|
      if expected == :err
        assert_raises(T::Error::InvalidVariant) { Month.from_str(text) }
      else
        assert_case expected, Month.from_str(text)
      end
    end
  end

  # <tt>month.rs:152</tt>, +to_u8+.
  def test_to_u8
    [
      [Month::January, 1],
      [Month::February, 2],
      [Month::March, 3],
      [Month::April, 4],
      [Month::May, 5],
      [Month::June, 6],
      [Month::July, 7],
      [Month::August, 8],
      [Month::September, 9],
      [Month::October, 10],
      [Month::November, 11],
      [Month::December, 12],
    ].each do |month, expected|
      assert_case expected, month.to_i
    end
  end

  # <tt>month.rs:169</tt>, +try_from_u8_success+.
  def test_try_from_u8_success
    [
      [1, Month::January],
      [2, Month::February],
      [3, Month::March],
      [4, Month::April],
      [5, Month::May],
      [6, Month::June],
      [7, Month::July],
      [8, Month::August],
      [9, Month::September],
      [10, Month::October],
      [11, Month::November],
      [12, Month::December],
    ].each do |input, expected|
      assert_case expected, Month.try_from(input)
    end
  end

  # <tt>month.rs:176</tt>, +try_from_u8_error+.
  def test_try_from_u8_error
    [
      0,
      13,
    ].each do |input|
      error = assert_raises(T::Error::ComponentRange) { Month.try_from(input) }
      assert_equal "month", error.name
    end
  end
end

#--
# SPDX-SnippetEnd
#++
