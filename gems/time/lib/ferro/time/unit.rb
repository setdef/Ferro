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
    # SPDX-SnippetComment: the units of time, per, per_t, Unit, and their
    #   docs from time-core 0.1.9 src/unit.rs, which time 0.3.55 re-exports
    #   as time::unit
    #++

    # Conversion between units of time.
    #
    # Code that turns seconds into nanoseconds, or weeks into minutes,
    # tends to grow its own constants, and a wrong count of zeros in
    # <tt>1_000_000_000</tt> hides in plain sight. time names each unit
    # and answers how many of one fit in another.
    #
    # Each unit, Unit::Nanosecond to Unit::Week, is a frozen value. Ask
    # the smaller unit how many of it fit in a larger one with +per+:
    # <tt>Unit::Nanosecond.per(Unit::Second)</tt> is one billion. Units
    # order from smallest to largest, and Unit::Unit names them as an enum.
    #
    # Mirrors time's +unit+ module, which is time-core's
    # (<tt>time-core-0.1.9/src/unit.rs</tt>, re-exported at
    # <tt>src/lib.rs:139</tt>), plan 010. Rust's units take a const +N+
    # that defaults to 1; +per+ exists only for 1, so the gem binds that
    # unit and no other (plan 010, decision 12).
    #
    # === Examples
    #
    #   unit = Ferro::Time::Unit
    #   unit::Nanosecond.per(unit::Second) # => 1_000_000_000
    #   unit::Second.per(unit::Day) # => 86_400
    #   unit::Millisecond.per_t(Float, unit::Second) # => 1000.0
    #   unit::Second < unit::Minute # => true
    module Unit
      # What every unit of time shares: +per+, +per_t+, ordering, and
      # +inspect+. Private to the gem; the eight constants are its only
      # instances.
      class Value # :nodoc:
        include Comparable

        private_class_method :new

        class << self
          # The eight constants are the only units.
          undef_method :allocate
        end

        # Creates the unit at +place+, from 0 for Nanosecond to 7 for Week.
        def initialize(place, name)
          @place = place
          @name = name
          freeze
        end

        # Obtain the number of times this unit can fit into +larger+, an
        # Integer. If +larger+ is smaller than this unit, Rust fails to
        # compile; this raises +TypeError+ with time's diagnostic. Mirrors
        # time's +per+ (<tt>time-core-0.1.9/src/unit.rs:38-56</tt>), whose
        # return type is the smallest unsigned integer type that holds the
        # value, and Ruby has one Integer.
        #
        # [larger] One of the units of time, such as Unit::Second.
        #
        # === Example
        #
        #   unit = Ferro::Time::Unit
        #   unit::Nanosecond.per(unit::Second) # => 1_000_000_000
        #   unit::Second.per(unit::Nanosecond)
        #   # raises TypeError: `Nanosecond` is not an integer multiple of `Second`
        def per(larger)
          Native.unit_per(@name, Ferro::Time::Unit.__send__(:name_of, larger, @name))
        end

        # Obtain the number of times this unit can fit into +larger+, as
        # +output+: Integer or Float. Rust takes the output type as a type
        # parameter, <tt>per_t::<f64></tt>; Ruby has one Integer, which is
        # every integer type's answer, and one Float, which is +f64+'s.
        # Anything else, or a +larger+ smaller than this unit, raises
        # +TypeError+ with time's diagnostic, as Rust fails to compile.
        # Mirrors time's +per_t+ (<tt>time-core-0.1.9/src/unit.rs:58-71</tt>).
        #
        # [output] Integer or Float, the class itself.
        # [larger] One of the units of time.
        #
        # === Example
        #
        #   unit = Ferro::Time::Unit
        #   unit::Microsecond.per_t(Integer, unit::Week) # => 604_800_000_000
        #   unit::Hour.per_t(Float, unit::Day) # => 24.0
        def per_t(output, larger)
          name = Ferro::Time::Unit.__send__(:name_of, larger, @name)
          return Native.unit_per_integer(@name, name) if output.equal?(Integer)
          return Native.unit_per_float(@name, name) if output.equal?(Float)

          raise TypeError, "`#{name}` is not an integer multiple of `#{@name}`"
        end

        # Orders units from smallest to largest, and against Unit::Unit's
        # variants by the unit each names, as time's +PartialOrd+ does;
        # +nil+ for anything else.
        #
        # [other] Object.
        #
        # === Example
        #
        #   unit = Ferro::Time::Unit
        #   unit::Day <=> unit::Hour # => 1
        #   unit::Day == unit::Unit::Day # => true
        def <=>(other)
          Ferro::Time::Unit.__send__(:compare, [false, @place], other)
        end

        # The constant that holds this unit.
        #
        # === Example
        #
        #   Ferro::Time::Unit::Second.inspect # => "Ferro::Time::Unit::Second"
        def inspect
          "Ferro::Time::Unit::#{@name}"
        end

        # The unit's name, which +per+ hands the native layer.
        private attr_reader :name

        # Where the unit sits from Nanosecond (0) to Week (7).
        private attr_reader :place
      end
      private_constant :Value

      # A unit of time representing exactly one nanosecond.
      Nanosecond = Value.__send__(:new, 0, :Nanosecond)
      # A unit of time representing exactly one microsecond.
      Microsecond = Value.__send__(:new, 1, :Microsecond)
      # A unit of time representing exactly one millisecond.
      Millisecond = Value.__send__(:new, 2, :Millisecond)
      # A unit of time representing exactly one second.
      Second = Value.__send__(:new, 3, :Second)
      # A unit of time representing exactly one minute.
      Minute = Value.__send__(:new, 4, :Minute)
      # A unit of time representing exactly one hour.
      Hour = Value.__send__(:new, 5, :Hour)
      # A unit of time representing exactly one day.
      Day = Value.__send__(:new, 6, :Day)
      # A unit of time representing exactly one week.
      Week = Value.__send__(:new, 7, :Week)

      # A statically-known multiple of a given unit of time.
      #
      # Code that stores or passes a unit, a setting that says "round to
      # the minute", needs the unit as a value of one type. Unit::Unit is
      # that enum: eight frozen variants, Unit::Unit::Nanosecond to
      # Unit::Unit::Week, ordered from smallest to largest.
      #
      # A variant equals and compares with the unit it names, as time's
      # +PartialEq+ and +PartialOrd+ say, so
      # <tt>Unit::Unit::Second == Unit::Second</tt>. They stay two values,
      # as Rust keeps the variant and the struct two types: neither is
      # +eql?+ to the other, and a variant has no +per+.
      #
      # Mirrors time's <tt>unit::Unit</tt>
      # (<tt>time-core-0.1.9/src/unit.rs:289-311</tt>). Rust's +N+ is 1
      # here, as for the units (plan 010, decision 12).
      #
      # === Example
      #
      #   unit = Ferro::Time::Unit
      #   unit::Unit::Minute > unit::Unit::Second # => true
      #   unit::Unit::Minute == unit::Minute # => true
      #   unit::Unit::Minute.eql?(unit::Minute) # => false
      class Unit
        include Comparable

        private_class_method :new

        class << self
          # The eight constants are the only variants.
          undef_method :allocate
        end

        # Creates the variant at +place+, from 0 for Nanosecond to 7 for
        # Week. The constants are the only instances.
        #
        # [place] Integer.
        # [name] Symbol, the variant's name.
        def initialize(place, name)
          @place = place
          @name = name
          freeze
        end

        # Orders variants from smallest to largest, as time derives +Ord+,
        # and against the units by the unit each names; +nil+ for anything
        # else.
        #
        # [other] Object.
        #
        # === Example
        #
        #   Ferro::Time::Unit::Unit::Week <=> Ferro::Time::Unit::Day # => 1
        def <=>(other)
          Ferro::Time::Unit.__send__(:compare, [true, @place], other)
        end

        # The constant that holds this variant.
        #
        # === Example
        #
        #   Ferro::Time::Unit::Unit::Hour.inspect # => "Ferro::Time::Unit::Unit::Hour"
        def inspect
          "Ferro::Time::Unit::Unit::#{@name}"
        end

        # Where the variant sits from Nanosecond (0) to Week (7).
        private attr_reader :place

        # Nanosecond.
        Nanosecond = new(0, :Nanosecond)
        # Microsecond.
        Microsecond = new(1, :Microsecond)
        # Millisecond.
        Millisecond = new(2, :Millisecond)
        # Second.
        Second = new(3, :Second)
        # Minute.
        Minute = new(4, :Minute)
        # Hour.
        Hour = new(5, :Hour)
        # Day.
        Day = new(6, :Day)
        # Week.
        Week = new(7, :Week)
      end

      class << self
        # The name of the unit +larger+ for +per+ and +per_t+, refusing
        # anything but a unit of time with time's diagnostic, as Rust fails
        # to compile a type without +MultipleOf+.
        private def name_of(larger, small)
          return larger.__send__(:name) if larger.is_a?(Value)

          type = larger.is_a?(Ferro::Time::Unit::Unit) ? "Unit" : larger.class.name
          raise TypeError, "`#{type}` is not an integer multiple of `#{small}`"
        end

        # time's +PartialOrd+ between +side+, a unit or variant as the
        # native layer reads it, and +other+, or +nil+ if +other+ is
        # neither.
        private def compare(side, other)
          right = case other
            when Value then [false, other.__send__(:place)]
            when Ferro::Time::Unit::Unit then [true, other.__send__(:place)]
          end
          Native.unit_cmp(side[0], side[1], right[0], right[1]) if right
        end
      end
    end

    # The units of time under their name before time 0.3.48.
    #
    # Deprecated: import from Unit instead. It is the same module, and
    # naming it warns, in the :deprecated category, as rustc warns where
    # Rust code names it. Mirrors time's deprecated +convert+ module
    # (<tt>src/lib.rs:93-97</tt>).
    Convert = Unit
    deprecate_constant :Convert

    #--
    # SPDX-SnippetEnd
    #++
  end
end
