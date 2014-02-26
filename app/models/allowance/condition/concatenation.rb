module Allowance::Condition
  class Concatenation < Base

    attr_accessor :first,
                  :second

    def initialize(scope, first, second)
      @first = first
      @second = second

      super(scope)
    end

    def arel_statement(options)
      if apply_condition?(options)
        concat([@first, @second], options)
      else
        nil
      end
    end

    private

    def concat(conditions, options)
      arel_conditions = conditions.map { |condition| condition.to_arel(options) }
                                  .compact

      concat_conditions(self.class.concatenation_method, arel_conditions)
    end

    def concat_conditions(method, conditions)
      return nil if conditions.empty?

      concatenation = conditions.first

      conditions[1..-1].each do |concat_condition|
        concatenation = concatenation.send(method, concat_condition)
      end

      concatenation
    end

    def self.concatenation_method(method = nil)
      @method ||= method
    end
  end
end
