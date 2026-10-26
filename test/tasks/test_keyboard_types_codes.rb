# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"
require_relative "../../tasks/keyboard_types_codes"

# The generator for ferro-global-hotkey's Code constants (plan 004,
# decision 8), and the file it wrote.
class TestKeyboardTypesCodes < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  SOURCE = <<~RUST
    pub enum Code {
        /// <kbd>`~</kbd> on a US keyboard.
        #[doc(alias = "Backtick")]
        Backquote,
        WakeUp,
        #[deprecated = "marked as legacy in the spec, use Meta instead"]
        Hyper,
        /// Use [`NumLock`][Code::NumLock] for <kbd>,&lt;</kbd><br/>(<span class="unicode">x</span>)
        Abort,
    }
  RUST

  def test_variants_keep_their_order_docs_and_deprecations
    variants = KeyboardTypesCodes.variants(SOURCE)

    assert_equal %w[Backquote WakeUp Hyper Abort], variants.map(&:name)
    assert_equal ["<kbd>`~</kbd> on a US keyboard."], variants.first.docs
    assert_equal "marked as legacy in the spec, use Meta instead", variants[2].deprecated
    assert_nil variants[1].deprecated
  end

  def test_rustdoc_markup_becomes_rdoc
    assert_equal "Use NumLock for <tt>,<</tt>; (x)", KeyboardTypesCodes.rdoc(KeyboardTypesCodes.variants(SOURCE).last.docs.first)
  end

  def test_constants_number_from_zero_and_say_what_is_undocumented_or_deprecated
    text = KeyboardTypesCodes.constants(KeyboardTypesCodes.variants(SOURCE))

    assert_includes text, "Backquote = new(:Backquote, 0)"
    assert_includes text, "Abort = new(:Abort, 3)"
    assert_includes text, "+WakeUp+; keyboard-types describes it no further."
    assert_includes text, "# Deprecated: marked as legacy in the spec, use Meta instead."
  end

  def test_the_committed_code_rb_is_what_the_generator_writes
    dir, version = Dir.chdir(ROOT) { KeyboardTypesCodes.locked }
    expected = KeyboardTypesCodes.render(KeyboardTypesCodes.variants(File.read(File.join(dir, "src/code.rs"))), version)

    assert_equal expected, File.read(File.join(ROOT, KeyboardTypesCodes::TARGET)),
      "code.rb is stale: run bundle exec rake codes:global-hotkey"
  end
end
