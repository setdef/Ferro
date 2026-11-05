# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: Apache-2.0 OR MIT
#++

module Ferro
  module GlobalHotkey
    # The methods of an error class whose Rust variant is a tuple with one
    # field, such as <tt>Error::FailedToRegister(String)</tt>.
    #
    # Rust reaches the field by position, with a pattern:
    # <tt>Err(Error::FailedToRegister(reason)) => ...</tt>. The field has
    # no name, so the class gives it none either: #deconstruct and #to_a
    # return it in a one-element Array, and Ruby's pattern
    # <tt>in Error::FailedToRegister[reason]</tt> reads as Rust's does
    # (ADR 001, amendment of 2026-11-05: tuple variants).
    #
    # Each class that includes this says what its field holds: a String,
    # a Hotkey::HotKey, or an +io::Error+ as a +SystemCallError+ or
    # +IOError+. An error global-hotkey returned carries it; one you build
    # yourself carries what you pass, or +nil+.
    #
    # === Example
    #
    #   begin
    #     manager.register(hotkey)
    #   rescue Ferro::GlobalHotkey::Error => e
    #     case e
    #     in Ferro::GlobalHotkey::Error::AlreadyRegistered[taken] then warn "#{taken} is taken"
    #     in Ferro::GlobalHotkey::Error::FailedToRegister[reason] then warn reason
    #     else raise
    #     end
    #   end
    module TupleVariant # :nodoc:
      # Creates the error.
      #
      # [message] String, the crate's message, or +nil+ for the class name.
      # [field] The variant's field, or +nil+.
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::Error::FailedToRegister.new("Unable to register hotkey: F24", "F24").to_a # => ["F24"]
      def initialize(message = nil, field = nil)
        @field = field
        super(message)
      end

      # The variant's field, in an Array of one, for Ruby's array patterns.
      #
      # === Example
      #
      #   error in Ferro::GlobalHotkey::Error::FailedToRegister[reason]
      def deconstruct
        [@field]
      end

      # The variant's field, in an Array of one, as #deconstruct.
      #
      # === Example
      #
      #   reason, = error.to_a
      def to_a
        deconstruct
      end

      # The crate's +Debug+ text for this variant, which Rust formats from
      # a value it rebuilds from the field; +inspect+ stays Ruby's. An
      # error without its field has no Rust value, so its +debug+ raises
      # +TypeError+.
      #
      # === Example
      #
      #   Ferro::GlobalHotkey::Error::FailedToRegister.new(nil, "F24").debug # => "FailedToRegister(\"F24\")"
      def debug
        Native.error_debug(GlobalHotkey.__send__(:variant_path, self), native_field)
      end

      # The field as the native layer rebuilds it: a hotkey as its parts.
      private def native_field
        field = @field
        field.is_a?(Hotkey::HotKey) ? GlobalHotkey.__send__(:parts, field) : field
      end
    end

    private_constant :TupleVariant

    # The path under this module of the gem's class that +error+ is an
    # instance of, which names the Rust type the native layer rebuilds:
    # <tt>"Error::FailedToRegister"</tt>, or for an instance of a subclass
    # of it, the same.
    def self.variant_path(error) # :nodoc:
      prefix = "#{GlobalHotkey}::"
      ancestor = error.class.ancestors.find { |klass| klass.is_a?(Class) && klass.name&.start_with?(prefix) }
      raise TypeError, "#{error.class} is no error type of #{GlobalHotkey}" unless ancestor

      (ancestor.name || "").delete_prefix(prefix)
    end
    private_class_method :variant_path
  end
end
