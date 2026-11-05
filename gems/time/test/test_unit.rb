# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "test_helper"

# The Ruby side of time's units (plan 010, batch 2): every +per+ and
# +per_t+ against time-core's documented values, the refusals Rust's
# compiler stands for, ordering across units and Unit's variants, and the
# deprecated Convert.
class TestUnit < Minitest::Test
  include TimeSuite

  U = Ferro::Time::Unit

  # Each unit and its length in nanoseconds, smallest first, from
  # time-core's <tt>Nanosecond per</tt> table (<tt>src/unit.rs:201-210</tt>).
  LENGTHS = {
    U::Nanosecond => 1,
    U::Microsecond => 1_000,
    U::Millisecond => 1_000_000,
    U::Second => 1_000_000_000,
    U::Minute => 60_000_000_000,
    U::Hour => 3_600_000_000_000,
    U::Day => 86_400_000_000_000,
    U::Week => 604_800_000_000_000,
  }.freeze

  VARIANTS = [
    U::Unit::Nanosecond,
    U::Unit::Microsecond,
    U::Unit::Millisecond,
    U::Unit::Second,
    U::Unit::Minute,
    U::Unit::Hour,
    U::Unit::Day,
    U::Unit::Week,
].freeze

  def test_per_answers_how_many_of_a_unit_fit_in_a_larger_one
    pairs = 0
    LENGTHS.each do |small, small_ns|
      LENGTHS.each do |large, large_ns|
        next if large_ns < small_ns

        pairs += 1
        ratio = large_ns / small_ns
        assert_equal ratio, small.per(large), "#{small.inspect}.per(#{large.inspect})"
        assert_equal ratio, small.per_t(Integer, large)
        assert_kind_of Integer, small.per_t(Integer, large)
        assert_equal ratio.to_f, small.per_t(Float, large)
        assert_kind_of Float, small.per_t(Float, large)
      end
    end
    assert_equal 36, pairs
  end

  def test_time_cores_documented_ratios
    assert_equal 60, U::Second.per(U::Minute)
    assert_equal 168, U::Hour.per(U::Week)
    assert_equal 10_080, U::Minute.per(U::Week)
    assert_equal 1, U::Week.per(U::Week)
    assert_in_delta 1_000.0, U::Millisecond.per_t(Float, U::Second)
  end

  def test_a_smaller_unit_is_refused_as_rusts_compiler_refuses_it
    error = assert_raises(TypeError) { U::Second.per(U::Nanosecond) }
    assert_equal "`Nanosecond` is not an integer multiple of `Second`", error.message
    error = assert_raises(TypeError) { U::Week.per_t(Float, U::Day) }
    assert_equal "`Day` is not an integer multiple of `Week`", error.message
  end

  def test_only_a_unit_struct_has_a_multiple
    error = assert_raises(TypeError) { U::Second.per(U::Unit::Minute) }
    assert_equal "`Unit` is not an integer multiple of `Second`", error.message
    error = assert_raises(TypeError) { U::Second.per(60) }
    assert_equal "`Integer` is not an integer multiple of `Second`", error.message
    refute_respond_to U::Unit::Second, :per
  end

  def test_per_t_takes_integer_or_float_as_its_output
    error = assert_raises(TypeError) { U::Second.per_t(String, U::Minute) }
    assert_equal "`Minute` is not an integer multiple of `Second`", error.message
    assert_raises(TypeError) { U::Second.per_t(Rational, U::Minute) }
    assert_raises(TypeError) { U::Second.per_t(1, U::Minute) }
  end

  def test_units_order_from_smallest_to_largest
    units = LENGTHS.keys
    units.each_with_index do |left, i|
      units.each_with_index do |right, j|
        assert_equal i <=> j, left <=> right, "#{left.inspect} <=> #{right.inspect}"
        assert_equal i == j, left == right
      end
    end
    assert_operator U::Nanosecond, :<, U::Week
    assert_equal units, units.reverse.sort
  end

  def test_variants_order_and_equal_the_units_they_name
    units = LENGTHS.keys
    VARIANTS.each_with_index do |variant, i|
      VARIANTS.each_with_index do |other, j|
        assert_equal i <=> j, variant <=> other
      end
      units.each_with_index do |unit, j|
        assert_equal i <=> j, variant <=> unit, "#{variant.inspect} <=> #{unit.inspect}"
        assert_equal j <=> i, unit <=> variant, "#{unit.inspect} <=> #{variant.inspect}"
        assert_equal i == j, variant == unit
        assert_equal i == j, unit == variant
      end
    end
  end

  def test_a_variant_and_its_unit_stay_two_values
    refute_same U::Second, U::Unit::Second
    refute U::Second.eql?(U::Unit::Second)
    assert_equal 2, { U::Second => 1, U::Unit::Second => 2 }.size
  end

  def test_anything_else_does_not_compare
    assert_nil U::Second <=> 1
    assert_nil U::Unit::Second <=> :Second
    refute_equal U::Second, 1
    assert_raises(ArgumentError) { U::Second < 1 }
  end

  def test_debug_is_time_cores_debug
    assert_equal "Minute", U::Minute.debug
    assert_equal "Minute", U::Unit::Minute.debug
    assert_equal "Nanosecond", U::Nanosecond.debug
  end

  def test_units_and_variants_are_frozen_and_shareable
    (LENGTHS.keys + VARIANTS).each do |value|
      assert_predicate value, :frozen?
      assert Ractor.shareable?(value), value.inspect
    end
  end

  def test_no_new_units
    assert_raises(NoMethodError) { U::Unit.new(8, :Fortnight) }
    assert_raises(NameError) { U::Value }
    assert_raises(NoMethodError) { U::Second.class.new(8, :Fortnight) }
    assert_raises(NoMethodError) { U::Unit.allocate }
    assert_raises(NoMethodError) { U::Second.class.allocate }
  end

  def test_convert_is_unit_and_warns
    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    _, err = capture_io { assert_same U, Ferro::Time::Convert }
    assert_match(/Ferro::Time::Convert is deprecated/, err)
  ensure
    Warning[:deprecated] = deprecated
  end
end
