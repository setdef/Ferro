# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT OR Apache-2.0
#++

module Ferro
  module Time
    #--
    # SPDX-SnippetBegin
    # SPDX-License-Identifier: MIT OR Apache-2.0
    # SPDX-SnippetCopyrightText: Jacob Pratt et al.
    # SPDX-SnippetComment: the iterators, their methods, and their docs from
    #   time 0.3.55 src/iter/*.rs
    #++

    # Iterator types.
    #
    # A calendar program walks days, months, and weekdays: every date in a
    # billing period, every month from this one on, every weekday of a
    # rota. Stepping by hand with Date#next_day or Month#next works until
    # the end of the range, the wrap from December to January, or the
    # count of what is left needs its own code.
    #
    # This module holds time's iterators. Iter::DateIter walks the dates
    # from a start to an end, inclusive, from either end. Iter::MonthIter
    # and Iter::WeekdayIter cycle forever, forward or, through +rev+,
    # backward (Iter::Rev). Make them with Date#iter_to, Month.iter_from,
    # and Weekday.iter_from, or with each class's +new+.
    #
    # Each iterator is time's, not Ruby's Enumerator. Its +next+ returns the
    # next item, or +nil+ once a DateIter is done (Rust's +Option+), never
    # +StopIteration+, and advances the iterator in place. Each also
    # includes Enumerable, whose methods walk a copy from the iterator's
    # current place and leave the iterator where it was (plan 010,
    # decision 4). time's own methods keep their Rust names: +nth+,
    # +next_back+, +len+, +size_hint+, +all+, +any+, +is_sorted+.
    #
    # Iterators are mutable, so they are not shareable between Ractors.
    #
    # Mirrors time's +iter+ module (<tt>src/iter/mod.rs</tt>), plan 010.
    #
    # === Examples
    #
    #   t = Ferro::Time
    #   start = t::Date.from_calendar_date(2019, t::Month::January, 1)
    #   start.iter_to(t::Date.from_calendar_date(2019, t::Month::January, 3)).map(&:to_s)
    #   # => ["2019-01-01", "2019-01-02", "2019-01-03"]
    #
    #   t::Month.iter_from(t::Month::November).first(3)
    #   # => [Ferro::Time::Month::November, Ferro::Time::Month::December, Ferro::Time::Month::January]
    module Iter
      # Ruby's FrozenError for a frozen iterator, before anything changes:
      # the native layer's own check words it without the iterator.
      # Private to the gem.
      module Frozen # :nodoc:
        # Raises FrozenError, worded as Ruby words it, if this iterator is
        # frozen.
        private def check_frozen
          raise FrozenError.new("can't modify frozen #{self.class}: #{inspect}", receiver: self) if frozen?
        end
      end
      private_constant :Frozen

      # An iterator over a range of Dates, yielding each day from start to
      # end inclusive.
      #
      # A range of days has two ends, a known length, and edges at Date::MIN
      # and Date::MAX that a hand-written loop steps past. A DateIter knows
      # all three: take days from the front with #next or from the back
      # with #next_back, skip ahead with #nth, and ask #len how many are
      # left. Once it is done it stays done, from both ends.
      #
      # If the start is after the end, the iterator is empty.
      #
      # Enumerable's methods walk a copy, so <tt>iter.first(3)</tt> twice
      # gives the same three dates. #each without a block returns an
      # Enumerator whose +size+ is #len. A DateIter equals another with the
      # same place and end, as time derives +PartialEq+; +dup+ copies it.
      #
      # Mirrors time's <tt>iter::DateIter</tt>
      # (<tt>src/iter/date_iter.rs</tt>).
      #
      # === Examples
      #
      #   t = Ferro::Time
      #   iter = t::Iter::DateIter.new(t::Date.from_calendar_date(2019, t::Month::January, 1),
      #     t::Date.from_calendar_date(2019, t::Month::January, 3))
      #   iter.next.to_s # => "2019-01-01"
      #   iter.next.to_s # => "2019-01-02"
      #   iter.next.to_s # => "2019-01-03"
      #   iter.next # => nil
      #
      #   iter = t::Date.from_calendar_date(2019, t::Month::January, 1)
      #     .iter_to(t::Date.from_calendar_date(2019, t::Month::January, 5))
      #   iter.next_back.to_s # => "2019-01-05"
      #   iter.len # => 4
      class DateIter
        include Enumerable
        include Frozen

        # Create a new DateIter from +start+ to +end_date+ inclusive. If
        # +start+ is after +end_date+, the iterator will be empty. Mirrors
        # time's <tt>DateIter::new</tt> (<tt>src/iter/date_iter.rs:16-40</tt>).
        #
        # [start] Date.
        # [end_date] Date, time's +end+, which is a Ruby keyword.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   t::Iter::DateIter.new(jan[3], jan[1]).next # => nil
        def initialize(start, end_date)
          check_frozen
          Native.date_iter_initialize(self, start, end_date)
        end

        # The next date from the front, or +nil+ when none is left. Mirrors
        # time's <tt>Iterator::next</tt> (<tt>src/iter/date_iter.rs:69-82</tt>).
        #
        # === Example
        #
        #   t = Ferro::Time
        #   d = t::Date.from_calendar_date(2019, t::Month::June, 15)
        #   iter = d.iter_to(d)
        #   iter.next == d # => true
        #   iter.next # => nil
        def next
          check_frozen
          Native.date_iter_step(self, :next)
        end

        # The next date from the back, or +nil+ when none is left. Mirrors
        # time's <tt>DoubleEndedIterator::next_back</tt>
        # (<tt>src/iter/date_iter.rs:157-169</tt>).
        #
        # === Example
        #
        #   t = Ferro::Time
        #   iter = t::Date.from_calendar_date(2019, t::Month::January, 1)
        #     .iter_to(t::Date.from_calendar_date(2019, t::Month::January, 5))
        #   iter.next_back.to_s # => "2019-01-05"
        def next_back
          check_frozen
          Native.date_iter_step(self, :next_back)
        end

        # The date +n+ places from the front, skipping the +n+ before it,
        # or +nil+ when fewer are left, which leaves the iterator done.
        # Mirrors time's <tt>Iterator::nth</tt>
        # (<tt>src/iter/date_iter.rs:100-138</tt>).
        #
        # [n] Integer, from 0.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   iter = t::Date.from_calendar_date(2019, t::Month::January, 1)
        #     .iter_to(t::Date.from_calendar_date(2019, t::Month::January, 5))
        #   iter.nth(2).to_s # => "2019-01-03"
        #   iter.next.to_s # => "2019-01-04"
        def nth(n)
          check_frozen
          Native.date_iter_nth(self, :nth, n)
        end

        # The date +n+ places from the back, skipping the +n+ after it, or
        # +nil+ when fewer are left. Mirrors time's
        # <tt>DoubleEndedIterator::nth_back</tt>
        # (<tt>src/iter/date_iter.rs:171-204</tt>).
        #
        # [n] Integer, from 0.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   iter = t::Date.from_calendar_date(2019, t::Month::January, 1)
        #     .iter_to(t::Date.from_calendar_date(2019, t::Month::January, 5))
        #   iter.nth_back(2).to_s # => "2019-01-03"
        def nth_back(n)
          check_frozen
          Native.date_iter_nth(self, :nth_back, n)
        end

        # How many dates are left. Mirrors time's
        # <tt>ExactSizeIterator::len</tt> (<tt>src/iter/date_iter.rs:207-216</tt>).
        #
        # === Example
        #
        #   t = Ferro::Time
        #   iter = t::Date.from_calendar_date(2019, t::Month::January, 1)
        #     .iter_to(t::Date.from_calendar_date(2019, t::Month::January, 5))
        #   iter.len # => 5
        def len
          Native.date_iter_count(self, :len)
        end

        # The bounds on how many dates are left, <tt>[lower, upper]</tt>,
        # both #len. Mirrors time's <tt>Iterator::size_hint</tt>
        # (<tt>src/iter/date_iter.rs:84-88</tt>).
        #
        # === Example
        #
        #   t = Ferro::Time
        #   d = t::Date.from_calendar_date(2019, t::Month::January, 1)
        #   d.iter_to(d).size_hint # => [1, 1]
        def size_hint
          Native.date_iter_size_hint(self)
        end

        # How many dates are left, without walking them: time's
        # <tt>Iterator::count</tt> (<tt>src/iter/date_iter.rs:90-93</tt>).
        # With an argument or a block, Enumerable#count over a copy.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   iter = t::Date.from_calendar_date(-9999, t::Month::January, 1)
        #     .iter_to(t::Date.from_calendar_date(-9999, t::Month::December, 31))
        #   iter.count # => 365
        def count(*args, &block)
          return super if block || !args.empty?

          Native.date_iter_count(self, :count)
        end

        # The last date, or +nil+ when the iterator is empty, without
        # changing the iterator. Mirrors time's <tt>Iterator::last</tt>
        # (<tt>src/iter/date_iter.rs:95-98</tt>).
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   jan[1].iter_to(jan[5]).last.to_s # => "2019-01-05"
        def last
          Native.date_iter_end(self, :last)
        end

        # The latest date left, or +nil+: time's <tt>Iterator::max</tt>
        # (<tt>src/iter/date_iter.rs:140-143</tt>). With an argument or a
        # block, Enumerable#max over a copy.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   jan[1].iter_to(jan[5]).max.to_s # => "2019-01-05"
        def max(*args, &block)
          return super unless Iter.__send__(:bare?, args, block)

          Native.date_iter_end(self, :max)
        end

        # The earliest date left, or +nil+: time's <tt>Iterator::min</tt>
        # (<tt>src/iter/date_iter.rs:145-148</tt>). With an argument or a
        # block, Enumerable#min over a copy.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   jan[5].iter_to(jan[1]).min # => nil
        def min(*args, &block)
          return super unless Iter.__send__(:bare?, args, block)

          Native.date_iter_end(self, :min)
        end

        # Whether the dates are in order, which they always are. Mirrors
        # time's <tt>Iterator::is_sorted</tt>
        # (<tt>src/iter/date_iter.rs:150-153</tt>).
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   jan[5].iter_to(jan[1]).is_sorted # => true
        def is_sorted
          Native.date_iter_is_sorted(self)
        end

        # Yields each date left, in order, from a copy, so this iterator
        # keeps its place, as a Rust <tt>for</tt> loop over
        # <tt>iter.clone()</tt>. Without a block, returns an Enumerator
        # whose +size+ is #len.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   iter = jan[1].iter_to(jan[3])
        #   iter.each.size # => 3
        #   iter.each { |date| date } # => iter
        def each
          return enum_for(:each) { len } unless block_given?

          copy = dup
          while (date = copy.next)
            yield date
          end
          self
        end

        # Yields each date left, latest first, from a copy taken through
        # #next_back, so this iterator keeps its place. It stands for
        # Rust's <tt>iter.rev()</tt>, core's adapter over time's
        # <tt>DoubleEndedIterator</tt>, and walks one date at a time rather
        # than gathering them first, as Enumerable's would. Without a block,
        # returns an Enumerator whose +size+ is #len.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   jan[1].iter_to(t::Date::MAX).reverse_each.first(2).map(&:to_s) # => ["9999-12-31", "9999-12-30"]
        def reverse_each
          return enum_for(:reverse_each) { len } unless block_given?

          copy = dup
          while (date = copy.next_back)
            yield date
          end
          self
        end

        # Whether +other+ is a DateIter at the same place with the same
        # end, as time derives +PartialEq+.
        #
        # [other] Object.
        def ==(other)
          other.is_a?(DateIter) && Native.date_iter_eq(self, other)
        end

        # time's derived +Debug+.
        #
        # === Example
        #
        #   t = Ferro::Time
        #   jan = ->(day) { t::Date.from_calendar_date(2019, t::Month::January, day) }
        #   jan[1].iter_to(jan[3]).inspect # => "DateIter { front: 2019-01-01, back: Some(2019-01-03) }"
        def inspect
          Native.date_iter_debug(self)
        end
      end

      # An infinite iterator over Months.
      #
      # A schedule that repeats every month, or a report that walks back
      # from this month, wraps from December to January and back without
      # end. A MonthIter does the wrapping: #next gives this month, then the
      # following ones, forever, and #rev runs backward instead.
      #
      # It never ends, so time refuses what only an end could answer:
      # #count and #last raise +RangeError+ with time's message where Rust
      # panics. time's #all, #any, #max, and #min answer at once, since a
      # cycle holds each month once. Enumerable's methods walk a copy and
      # run until they have their answer, so use #first, #take, or #lazy,
      # and #all and #any rather than Enumerable's +all?+ and +any?+, which
      # never stop when the answer is +true+ or +false+ respectively.
      #
      # Mirrors time's <tt>iter::MonthIter</tt>
      # (<tt>src/iter/month_iter.rs</tt>).
      #
      # === Examples
      #
      #   t = Ferro::Time
      #   iter = t::Iter::MonthIter.new(t::Month::January)
      #   iter.next # => Ferro::Time::Month::January
      #   iter.next # => Ferro::Time::Month::February
      #   iter.next # => Ferro::Time::Month::March
      #
      #   iter = t::Iter::MonthIter.new(t::Month::January).rev
      #   iter.next # => Ferro::Time::Month::January
      #   iter.next # => Ferro::Time::Month::December
      #   iter.next # => Ferro::Time::Month::November
      class MonthIter
        include Enumerable
        include Frozen

        # Create a new MonthIter starting at +start+. Mirrors time's
        # <tt>MonthIter::new</tt> (<tt>src/iter/month_iter.rs:21-34</tt>).
        #
        # [start] Month.
        def initialize(start)
          check_frozen
          Native.month_iter_initialize(self, Arguments.month(start))
        end

        # Make the iterator go in reverse order: a new Rev from this
        # iterator's place, leaving this one unchanged. Mirrors time's
        # <tt>MonthIter::rev</tt> (<tt>src/iter/month_iter.rs:36-48</tt>).
        #
        # === Example
        #
        #   Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::January).rev.nth(1) # => Ferro::Time::Month::December
        def rev
          Native.month_iter_rev(self)
        end

        # The next month. Never +nil+. Mirrors time's
        # <tt>Iterator::next</tt> (<tt>src/iter/month_iter.rs:54-59</tt>).
        #
        # === Example
        #
        #   Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::December).next # => Ferro::Time::Month::December
        def next
          check_frozen
          Arguments.month_of(Native.month_iter_next(self))
        end

        # The month +n+ places ahead, skipping the +n+ before it. Mirrors
        # time's <tt>Iterator::nth</tt> (<tt>src/iter/month_iter.rs:66-71</tt>).
        #
        # [n] Integer, from 0.
        #
        # === Example
        #
        #   Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::January).nth(13) # => Ferro::Time::Month::February
        def nth(n)
          check_frozen
          Arguments.month_of(Native.month_iter_nth(self, n))
        end

        # <tt>[usize::MAX, nil]</tt>: no end. Mirrors time's
        # <tt>Iterator::size_hint</tt> (<tt>src/iter/month_iter.rs:61-64</tt>).
        def size_hint
          Native.month_iter_size_hint(self)
        end

        # Raises +RangeError+: the iterator is infinite and cannot be
        # counted, where time panics (<tt>src/iter/month_iter.rs:73-75</tt>).
        # With an argument or a block, Enumerable#count, which never ends.
        #
        # === Example
        #
        #   Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::May).count
        #   # raises RangeError: `MonthIter` is infinite and cannot be counted
        def count(*args, &block)
          return super if block || !args.empty?

          Native.month_iter_infinite(self, :count)
        end

        # Raises +RangeError+: the iterator is infinite and has no last
        # element, where time panics (<tt>src/iter/month_iter.rs:77-79</tt>).
        def last
          Native.month_iter_infinite(self, :last)
        end

        # Whether the block is truthy for every month, testing each of the
        # twelve once, from January, and stopping at the first falsy one.
        # The iterator does not move. Mirrors time's <tt>Iterator::all</tt>
        # (<tt>src/iter/month_iter.rs:81-87</tt>).
        #
        # === Example
        #
        #   iter = Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::May)
        #   iter.all { |month| month.length(2021) >= 28 } # => true
        def all
          Native.month_iter_test(self, :all) { |number| yield Arguments.month_of(number) }
        end

        # Whether the block is truthy for some month, testing each of the
        # twelve once, from January, and stopping at the first truthy one.
        # Mirrors time's <tt>Iterator::any</tt>
        # (<tt>src/iter/month_iter.rs:89-95</tt>).
        #
        # === Example
        #
        #   iter = Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::May)
        #   iter.any { |month| month.length(2021) == 30 } # => true
        def any
          Native.month_iter_test(self, :any) { |number| yield Arguments.month_of(number) }
        end

        # December, the latest month: time's <tt>Iterator::max</tt>
        # (<tt>src/iter/month_iter.rs:97-100</tt>). With an argument or a
        # block, Enumerable#max, which never ends.
        def max(*args, &block)
          return super unless Iter.__send__(:bare?, args, block)

          Arguments.month_of(Native.month_iter_ordered(self, :max))
        end

        # January, the earliest month: time's <tt>Iterator::min</tt>
        # (<tt>src/iter/month_iter.rs:102-105</tt>). With an argument or a
        # block, Enumerable#min, which never ends.
        def min(*args, &block)
          return super unless Iter.__send__(:bare?, args, block)

          Arguments.month_of(Native.month_iter_ordered(self, :min))
        end

        # +false+: December is always followed by January. Mirrors time's
        # <tt>Iterator::is_sorted</tt> (<tt>src/iter/month_iter.rs:107-111</tt>).
        def is_sorted
          Native.month_iter_ordered(self, :is_sorted)
        end

        # Yields each month from this iterator's place, forever, from a
        # copy, so this iterator keeps its place; break out of the block
        # to stop. Without a block, returns an Enumerator whose +size+ is
        # +Float::INFINITY+.
        #
        # === Example
        #
        #   iter = Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::December)
        #   iter.each_slice(2).first
        #   # => [Ferro::Time::Month::December, Ferro::Time::Month::January]
        def each
          return enum_for(:each) { _ = Float::INFINITY } unless block_given?

          copy = dup
          # Not Kernel#loop, which would swallow a StopIteration the block raises.
          while true
            yield copy.next
          end
          self # never reached: only the block's break leaves the loop, as a Rust for loop over a cycle
        end

        # Whether +other+ is a MonthIter at the same month, as time derives
        # +PartialEq+.
        #
        # [other] Object.
        def ==(other)
          other.is_a?(MonthIter) && Native.month_iter_eq(self, other)
        end

        # time's derived +Debug+.
        #
        # === Example
        #
        #   Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::May).inspect # => "MonthIter { current: May }"
        def inspect
          Native.month_iter_debug(self)
        end
      end

      # An infinite iterator over Weekdays.
      #
      # A rota or a reminder that repeats each week wraps from Sunday to
      # Monday without end. A WeekdayIter does the wrapping: #next gives
      # this weekday, then the following ones, forever, and #rev runs
      # backward instead.
      #
      # It never ends, so #count and #last raise +RangeError+ with time's
      # message where Rust panics, and time's #all and #any test each
      # weekday once. Weekday has no order, so a WeekdayIter has no
      # +is_sorted+, and Enumerable's +max+ and +min+ raise
      # +ArgumentError+, as Rust's do not compile. Enumerable's methods
      # walk a copy; use #first, #take, or #lazy to stop.
      #
      # Mirrors time's <tt>iter::WeekdayIter</tt>
      # (<tt>src/iter/weekday_iter.rs</tt>).
      #
      # === Examples
      #
      #   t = Ferro::Time
      #   iter = t::Iter::WeekdayIter.new(t::Weekday::Monday)
      #   iter.next # => Ferro::Time::Weekday::Monday
      #   iter.next # => Ferro::Time::Weekday::Tuesday
      #   iter.next # => Ferro::Time::Weekday::Wednesday
      #
      #   iter = t::Iter::WeekdayIter.new(t::Weekday::Monday).rev
      #   iter.next # => Ferro::Time::Weekday::Monday
      #   iter.next # => Ferro::Time::Weekday::Sunday
      #   iter.next # => Ferro::Time::Weekday::Saturday
      class WeekdayIter
        include Enumerable
        include Frozen

        # Create a new WeekdayIter starting at +start+. Mirrors time's
        # <tt>WeekdayIter::new</tt> (<tt>src/iter/weekday_iter.rs:20-33</tt>).
        #
        # [start] Weekday.
        def initialize(start)
          check_frozen
          Native.weekday_iter_initialize(self, Arguments.weekday(start))
        end

        # Make the iterator go in reverse order: a new Rev from this
        # iterator's place, leaving this one unchanged. Mirrors time's
        # <tt>WeekdayIter::rev</tt> (<tt>src/iter/weekday_iter.rs:35-47</tt>).
        def rev
          Native.weekday_iter_rev(self)
        end

        # The next weekday. Never +nil+. Mirrors time's
        # <tt>Iterator::next</tt> (<tt>src/iter/weekday_iter.rs:53-58</tt>).
        def next
          check_frozen
          Arguments.weekday_of(Native.weekday_iter_next(self))
        end

        # The weekday +n+ places ahead, skipping the +n+ before it. Mirrors
        # time's <tt>Iterator::nth</tt> (<tt>src/iter/weekday_iter.rs:65-70</tt>).
        #
        # [n] Integer, from 0.
        #
        # === Example
        #
        #   Ferro::Time::Iter::WeekdayIter.new(Ferro::Time::Weekday::Monday).nth(8) # => Ferro::Time::Weekday::Tuesday
        def nth(n)
          check_frozen
          Arguments.weekday_of(Native.weekday_iter_nth(self, n))
        end

        # <tt>[usize::MAX, nil]</tt>: no end. Mirrors time's
        # <tt>Iterator::size_hint</tt> (<tt>src/iter/weekday_iter.rs:60-63</tt>).
        def size_hint
          Native.weekday_iter_size_hint(self)
        end

        # Raises +RangeError+: the iterator is infinite and cannot be
        # counted, where time panics (<tt>src/iter/weekday_iter.rs:72-74</tt>).
        # With an argument or a block, Enumerable#count, which never ends.
        def count(*args, &block)
          return super if block || !args.empty?

          Native.weekday_iter_infinite(self, :count)
        end

        # Raises +RangeError+: the iterator is infinite and has no last
        # element, where time panics (<tt>src/iter/weekday_iter.rs:76-78</tt>).
        def last
          Native.weekday_iter_infinite(self, :last)
        end

        # Whether the block is truthy for every weekday, testing each of the
        # seven once, from Monday, and stopping at the first falsy one.
        # Mirrors time's <tt>Iterator::all</tt>
        # (<tt>src/iter/weekday_iter.rs:80-86</tt>).
        def all
          Native.weekday_iter_test(self, :all) { |days| yield Arguments.weekday_of(days) }
        end

        # Whether the block is truthy for some weekday, testing each of the
        # seven once, from Monday, and stopping at the first truthy one.
        # Mirrors time's <tt>Iterator::any</tt>
        # (<tt>src/iter/weekday_iter.rs:88-94</tt>).
        #
        # === Example
        #
        #   iter = Ferro::Time::Iter::WeekdayIter.new(Ferro::Time::Weekday::Friday)
        #   iter.any { |day| day == Ferro::Time::Weekday::Sunday } # => true
        def any
          Native.weekday_iter_test(self, :any) { |days| yield Arguments.weekday_of(days) }
        end

        # Yields each weekday from this iterator's place, forever, from a
        # copy; break out of the block to stop. Without a block, returns an
        # Enumerator whose +size+ is +Float::INFINITY+.
        def each
          return enum_for(:each) { _ = Float::INFINITY } unless block_given?

          copy = dup
          # Not Kernel#loop, which would swallow a StopIteration the block raises.
          while true
            yield copy.next
          end
          self # never reached: only the block's break leaves the loop, as a Rust for loop over a cycle
        end

        # Whether +other+ is a WeekdayIter at the same weekday, as time
        # derives +PartialEq+.
        #
        # [other] Object.
        def ==(other)
          other.is_a?(WeekdayIter) && Native.weekday_iter_eq(self, other)
        end

        # time's derived +Debug+.
        #
        # === Example
        #
        #   Ferro::Time::Iter::WeekdayIter.new(Ferro::Time::Weekday::Friday).inspect # => "WeekdayIter { current: Friday }"
        def inspect
          Native.weekday_iter_debug(self)
        end
      end

      # An iterator that yields the elements of an underlying iterator in
      # reverse order.
      #
      # A report that walks back from this month, or a countdown of the
      # days of the week, runs a cycle backward. MonthIter#rev and
      # WeekdayIter#rev make a Rev from their place, the only way to make
      # one: its first item is the month or weekday the iterator was at,
      # then each one before it, forever.
      #
      # A Rev does what its iterator does, backward. In Rust a reversed
      # month iterator and a reversed weekday iterator are two types,
      # <tt>Rev<MonthIter></tt> and <tt>Rev<WeekdayIter></tt>; here each
      # is a Rev, of a private subclass per type, and they differ where
      # Rust's do. A reversed MonthIter has time's +max+ (December), +min+
      # (January), and +is_sorted+ (+false+). A reversed WeekdayIter has no
      # +is_sorted+, so <tt>respond_to?(:is_sorted)</tt> is +false+, and its
      # +max+ and +min+ are Enumerable's, which raise +ArgumentError+, since
      # weekdays have no order.
      #
      # Mirrors time's <tt>iter::Rev</tt> (<tt>src/iter/mod.rs:11-15</tt>)
      # and its iterators (<tt>src/iter/month_iter.rs:114-174</tt>,
      # <tt>src/iter/weekday_iter.rs:97-142</tt>).
      #
      # === Example
      #
      #   rev = Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::March).rev
      #   rev.first(3) # => [Ferro::Time::Month::March, Ferro::Time::Month::February, Ferro::Time::Month::January]
      #   rev.max # => Ferro::Time::Month::December
      #   rev.inspect # => "Rev { iter: MonthIter { current: March } }"
      #   Ferro::Time::Iter::WeekdayIter.new(Ferro::Time::Weekday::Monday).rev.respond_to?(:is_sorted) # => false
      class Rev
        include Enumerable
        include Frozen

        private_class_method :new

        class << self
          # No Rev of neither kind: dup and clone still copy one, through
          # Ruby's allocator and +initialize_copy+.
          undef_method :allocate
        end

        # The next item from the back: the iterator's place on the first
        # call, then each month or weekday before it. Never +nil+. Mirrors
        # time's <tt>Iterator::next</tt> for <tt>Rev<MonthIter></tt> and
        # <tt>Rev<WeekdayIter></tt> (<tt>src/iter/month_iter.rs:117-122</tt>,
        # <tt>src/iter/weekday_iter.rs:100-105</tt>).
        #
        # === Example
        #
        #   rev = Ferro::Time::Iter::WeekdayIter.new(Ferro::Time::Weekday::Monday).rev
        #   rev.next # => Ferro::Time::Weekday::Monday
        #   rev.next # => Ferro::Time::Weekday::Sunday
        def next
          check_frozen
          item(Native.rev_next(self))
        end

        # The item +n+ places back, skipping the +n+ after it. Mirrors
        # time's <tt>Iterator::nth</tt> (<tt>src/iter/month_iter.rs:129-134</tt>,
        # <tt>src/iter/weekday_iter.rs:112-117</tt>).
        #
        # [n] Integer, from 0.
        #
        # === Example
        #
        #   Ferro::Time::Iter::MonthIter.new(Ferro::Time::Month::January).rev.nth(2) # => Ferro::Time::Month::November
        def nth(n)
          check_frozen
          item(Native.rev_nth(self, n))
        end

        # <tt>[usize::MAX, nil]</tt>: no end. Mirrors time's
        # <tt>Iterator::size_hint</tt> (<tt>src/iter/month_iter.rs:124-127</tt>,
        # <tt>src/iter/weekday_iter.rs:107-110</tt>).
        def size_hint
          Native.rev_size_hint(self)
        end

        # Raises +RangeError+: the iterator is infinite and cannot be
        # counted, where time panics (<tt>src/iter/month_iter.rs:136-138</tt>,
        # <tt>src/iter/weekday_iter.rs:119-121</tt>). With an argument or a
        # block, Enumerable#count, which never ends.
        #
        # === Example
        #
        #   Ferro::Time::Iter::WeekdayIter.new(Ferro::Time::Weekday::Monday).rev.count
        #   # raises RangeError: `Rev<WeekdayIter>` is infinite and cannot be counted
        def count(*args, &block)
          return super if block || !args.empty?

          Native.rev_infinite(self, :count)
        end

        # Raises +RangeError+: the iterator is infinite and has no last
        # element, where time panics (<tt>src/iter/month_iter.rs:140-142</tt>,
        # <tt>src/iter/weekday_iter.rs:123-125</tt>).
        def last
          Native.rev_infinite(self, :last)
        end

        # Whether the block is truthy for every item, testing each month
        # once from January, or each weekday once from Monday, and stopping
        # at the first falsy one. Mirrors time's <tt>Iterator::all</tt>
        # (<tt>src/iter/month_iter.rs:144-150</tt>,
        # <tt>src/iter/weekday_iter.rs:127-133</tt>).
        def all
          Native.rev_test(self, :all) { |number| yield item(number) }
        end

        # Whether the block is truthy for some item, testing each month once
        # from January, or each weekday once from Monday, and stopping at
        # the first truthy one. Mirrors time's <tt>Iterator::any</tt>
        # (<tt>src/iter/month_iter.rs:152-158</tt>,
        # <tt>src/iter/weekday_iter.rs:135-141</tt>).
        def any
          Native.rev_test(self, :any) { |number| yield item(number) }
        end

        # Yields each item from this iterator's place, backward, forever,
        # from a copy; break out of the block to stop. Without a block,
        # returns an Enumerator whose +size+ is +Float::INFINITY+.
        def each
          return enum_for(:each) { _ = Float::INFINITY } unless block_given?

          copy = dup
          # Not Kernel#loop, which would swallow a StopIteration the block raises.
          while true
            yield copy.next
          end
          self # never reached: only the block's break leaves the loop, as a Rust for loop over a cycle
        end

        # Whether +other+ is a Rev of the same kind of iterator at the same
        # place, as time derives +PartialEq+.
        #
        # [other] Object.
        def ==(other)
          other.is_a?(Rev) && Native.rev_eq(self, other)
        end

        # time's derived +Debug+.
        def inspect
          Native.rev_debug(self)
        end

        # The Month or Weekday numbered +number+, as this Rev's iterator
        # counts them.
        private def item(number)
          is_a?(Months) ? Arguments.month_of(number) : Arguments.weekday_of(number)
        end

        # A reversed MonthIter, time's <tt>Rev<MonthIter></tt>, with the
        # overrides only months have. Private to the gem.
        class Months < Rev # :nodoc:
          # December: time's <tt>Iterator::max</tt>
          # (<tt>src/iter/month_iter.rs:160-163</tt>). With an argument or
          # a block, Enumerable#max, which never ends.
          def max(*args, &block)
            return super unless Iter.__send__(:bare?, args, block)

            Arguments.month_of(Native.rev_ordered(self, :max))
          end

          # January: time's <tt>Iterator::min</tt>
          # (<tt>src/iter/month_iter.rs:165-168</tt>). With an argument or
          # a block, Enumerable#min, which never ends.
          def min(*args, &block)
            return super unless Iter.__send__(:bare?, args, block)

            Arguments.month_of(Native.rev_ordered(self, :min))
          end

          # +false+: time's <tt>Iterator::is_sorted</tt>
          # (<tt>src/iter/month_iter.rs:170-173</tt>).
          def is_sorted
            Native.rev_ordered(self, :is_sorted)
          end
        end

        # A reversed WeekdayIter, time's <tt>Rev<WeekdayIter></tt>, which
        # has none of the ordered overrides. Private to the gem.
        class Weekdays < Rev # :nodoc:
        end

        private_constant :Months, :Weekdays
      end

      class << self
        # Whether +max+ or +min+ was called as time's, with no block and no
        # argument but Enumerable's default +nil+.
        private def bare?(args, block)
          block.nil? && (args.empty? || args == [nil])
        end
      end
    end

    #--
    # SPDX-SnippetEnd
    #++
  end
end
