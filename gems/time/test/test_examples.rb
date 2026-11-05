# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

require "tempfile"
require "test_helper"

# Every RDoc example in lib/ runs, and every <tt># => value</tt> and
# <tt># raises Class</tt> in it holds. Most examples are time's own doc
# examples, ported, so this is time's rustdoc as an answer key, and the
# docs a user reads cannot drift from what the gem does.
class TestExamples < Minitest::Test
  # One example section: where it is and its lines of Ruby.
  Section = Data.define(:file, :line, :lines)

  # Where examples are checked, and the values they compare.
  class Context
    def initialize(test, section)
      @test = test
      @section = section
      @expectations = []
    end

    attr_reader :expectations

    # Asserts that +actual+ equals the expectation at +index+, by +==+
    # when it reads as Ruby, and otherwise by its +debug+ text, time's
    # +Debug+, where it has one, as the gem's values do, or +inspect+.
    def __check__(actual, index, binding)
      source, line = @expectations.fetch(index)
      expected = evaluate(source, binding)
      if expected.equal?(UNREADABLE)
        shown = actual.respond_to?(:debug) ? actual.debug : actual.inspect
        @test.assert_equal(source, shown, where(line))
      elsif expected.nil?
        @test.assert_nil(actual, "#{where(line)}: #{source}")
      else
        @test.assert_equal(expected, actual, "#{where(line)}: #{source}")
      end
    end

    # Asserts that the block raises the class named at +index+, with the
    # message given after a colon, if any.
    def __raises__(index, binding)
      source, line = @expectations.fetch(index)
      name, message = source.split(": ", 2)
      error = @test.assert_raises(binding.eval(name), where(line)) { yield }
      @test.assert_equal(message, error.message, where(line)) if message
    end

    # What an expectation that is not Ruby, such as an +inspect+ text,
    # evaluates to.
    UNREADABLE = Object.new.freeze

    # +source+ evaluated in +binding+, or UNREADABLE.
    private def evaluate(source, binding)
      binding.eval(source)
    rescue SyntaxError, NameError
      UNREADABLE
    end

    private def where(line)
      "#{@section.file}:#{line}"
    end
  end

  # Every example section in lib/.
  def self.sections
    Dir.glob(File.join(TimeSuite::LIB, "**", "*.rb")).flat_map do |file|
      lines = File.readlines(file)
      found = []
      lines.each_with_index do |line, index|
        next unless line =~ /^\s*# === Examples?\s*$/

        code = []
        cursor = index + 1
        cursor += 1 while lines[cursor]&.match?(/^\s*#\s*$/)
        while lines[cursor]&.match?(/^\s*#(   |\s*$)/)
          text = lines[cursor].sub(/^\s*#( {3})?/, "").chomp
          code << [text, cursor + 1]
          cursor += 1
        end
        found << Section.new(file: file.delete_prefix("#{TimeSuite::ROOT}/"), line: index + 1, lines: code)
      end
      found
    end
  end

  # The section's Ruby, with each expectation turned into a check.
  private def program(section, context)
    chunks = []
    section.lines.each do |text, line|
      if text =~ /\A\s*# => (.*)\z/
        context.expectations << [$1, line]
        chunks[-1] = "__check__((#{chunks.last}\n), #{context.expectations.size - 1}, binding)"
      elsif text =~ /\A\s*# raises (.*)\z/
        context.expectations << [$1, line]
        chunks[-1] = "__raises__(#{context.expectations.size - 1}, binding) { #{chunks.last}\n }"
      elsif text.strip.empty? || text.strip.start_with?("#")
        next
      else
        code, expectation = split(text)
        code = "#{chunks.pop}\n#{code}" if chain?(text) && !chunks.empty?
        statement = if expectation&.start_with?("=> ")
          context.expectations << [expectation.delete_prefix("=> "), line]
          "__check__((#{code}), #{context.expectations.size - 1}, binding)"
        elsif expectation&.start_with?("raises ")
          context.expectations << [expectation.delete_prefix("raises "), line]
          "__raises__(#{context.expectations.size - 1}, binding) { #{code} }"
        else
          code
        end
        if inside?(text) && !chunks.empty?
          chunks[-1] = "#{chunks.last}\n#{statement}"
        else
          chunks << statement
        end
      end
    end
    chunks.join("\n")
  end

  # A line that continues a method chain from the line above.
  private def chain?(text)
    text.lstrip.start_with?(".")
  end

  # A line inside a multi-line statement such as +begin+ or +if+: indented,
  # or one of the keywords that continue it. Its own expectation checks its
  # own code.
  private def inside?(text)
    text.start_with?(" ") || text.match?(/\A(rescue|else|elsif|ensure|end|when)\b/)
  end

  # The code and the expectation of a line, split at <tt># =></tt> or
  # <tt># raises</tt>.
  private def split(text)
    match = text.match(/\A(.*?)\s+# ((?:=> |raises ).*)\z/)
    match ? [match[1], match[2]] : [text, nil]
  end

  # The +using+ lines of a section, which bring an Ext refinement into
  # scope, and the section without them.
  private def refinements(section)
    usings, lines = section.lines.partition { |text, _| text.start_with?("using ") }
    [usings.map(&:first), section.with(lines:)]
  end

  class << self
    # The runner the last loaded example file left, for #run_section.
    attr_accessor :runner
  end

  # Runs +source+ in +context+. Refinements are lexical, and +using+ works
  # only at the top of a file or in a module body, never in a method or an
  # eval inside one, so a section that brings one in is written to a file
  # of its own and loaded in an anonymous module, where the refinement
  # reaches only that section's code.
  private def run_section(context, usings, source, file, line)
    return context.instance_eval(source, file, line) if usings.empty?

    Tempfile.create(["example", ".rb"]) do |script|
      script.write("#{usings.join("\n")}\nTestExamples.runner = ->(context) { context.instance_exec {\n#{source}\n} }\n")
      script.flush
      load(script.path, true)
    end
    self.class.runner.call(context)
  end

  sections.each do |section|
    define_method("test_#{section.file.tr('/.', '__')}_#{section.line}") do
      context = Context.new(self, section)
      usings, section = refinements(section)
      source = program(section, context)
      deprecated = Warning[:deprecated]
      # An example may call a deprecated method; its warning is the
      # method's own test's business (TestValues).
      Warning[:deprecated] = false
      run_section(context, usings, source, section.file, section.lines.first&.last || section.line)
    ensure
      Warning[:deprecated] = deprecated
    end
  end

  def test_the_examples_are_many
    assert_operator self.class.sections.size, :>, 400
  end
end
