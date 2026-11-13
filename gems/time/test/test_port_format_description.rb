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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/format_description.rs
#++

# time's own tests in <tt>tests/integration/format_description.rs</tt>,
# ported: each method is the Rust test of the same name. Rust's
# +matches!+ and its <tt>TryFrom<Item></tt> for a slice or a +Vec+ are
# Ruby patterns here, since each variant's field is positional, and <tt>slice == item</tt> is not ported, since Ruby's Array keeps
# its own equality (plan 009, decision 8).
class TestPortFormatDescription < Minitest::Test
  include TimeSuite

  FD = T::FormatDescription
  B = FD::BorrowedFormatItem
  O = FD::OwnedFormatItem

  private def year_component
    FD::Component::CalendarYearFullExtendedRange.new(FD::Modifier::CalendarYearFullExtendedRange.default)
  end

  # <tt>format_description.rs:4</tt>, +borrowed_format_item_component_conversions+.
  def test_borrowed_format_item_component_conversions
    component = year_component
    item = B.from(component)
    assert((item in B::Component[^component]))
    assert_equal component, FD::Component.try_from(item)
    assert_raises(T::Error::DifferentVariant) { FD::Component.try_from(B::StringLiteral.new("")) }
    refute((B::StringLiteral.new("") in B::Compound[_]))
  end

  # <tt>format_description.rs:16</tt>, +borrowed_format_item_compound_conversions+.
  def test_borrowed_format_item_compound_conversions
    compound = [B::StringLiteral.new("")]
    item = B.from(compound)
    assert((item in B::Compound[^compound]))
  end

  # <tt>format_description.rs:24</tt>, +borrowed_format_item_equality+.
  def test_borrowed_format_item_equality
    component = year_component
    compound = [B::StringLiteral.new("")]
    component_item = B.from(component)
    compound_item = B.from(compound)

    assert_equal component, component_item
    assert_equal component_item, component
    assert_equal compound_item, compound
  end

  # <tt>format_description.rs:39</tt>, +owned_format_item_component_conversions+.
  def test_owned_format_item_component_conversions
    component = year_component
    item = O.from(component)
    assert((item in O::Component[^component]))
    assert_equal component, FD::Component.try_from(item)
    assert_raises(T::Error::DifferentVariant) { FD::Component.try_from(O::StringLiteral.new("")) }
    refute((O::StringLiteral.new("") in O::Compound[_]))
  end

  # <tt>format_description.rs:61</tt>, +owned_format_item_compound_conversions+.
  def test_owned_format_item_compound_conversions
    compound = [O::StringLiteral.new("")]
    item = O.from(compound)
    assert((item in O::Compound[^compound]))
  end

  # <tt>format_description.rs:71</tt>, +owned_format_item_equality+.
  def test_owned_format_item_equality
    component = year_component
    compound = O.from([B::StringLiteral.new("")])
    component_item = O.from(component)

    assert_equal component, component_item
    assert_equal component_item, component
    assert_equal compound, [O::StringLiteral.new("")]
  end
end

#--
# SPDX-SnippetEnd
#++
