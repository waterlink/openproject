module Allowance::Condition
  class Concatenation < Base

    attr_accessor :first,
                  :second

    def initialize(scope, first, second)
      self.first = first
      self.second = second

      super(scope)
    end

    def arel_statement(options)
      if apply_condition?(options)
        concat([first, second], options)
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
      case conditions.size
      when 0
        nil
      when 1
        conditions.first
      when 2
        conditions.first.send(method, conditions.second)
      end
    end

    def self.concatenation_method(method = nil)
      @method ||= method
    end
  end
end
