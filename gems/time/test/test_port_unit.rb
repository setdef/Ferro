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
# SPDX-SnippetComment: the test cases of time 0.3.55 tests/integration/convert.rs
#++

# time's own tests in <tt>tests/integration/convert.rs</tt>, ported whole.
# The file is named for the deprecated +convert+ module and imports
# +time::unit+.
class TestPortUnit < Minitest::Test
  include TimeSuite

  # <tt>convert.rs:4-7</tt>, +issue_749+.
  def test_issue_749
    assert_equal 1_000_000_000, T::Unit::Nanosecond.per(T::Unit::Second)
  end
end

#--
# SPDX-SnippetEnd
#++
