module Allowance::Visitor
  class ConditionModifier
    def initialize(scope, orig_condition, new_condition)
      @scope = scope
      @orig_condition = orig_condition
      @new_condition = new_condition
    end

    def visit(subject)
      send(method_name(subject), subject)
    end

    def visit_Allowance_Table_Base(table)
      table.joins.each do |join|
        visit(join)
      end

      table.where_conditions.each_with_index do |condition, index|
        table.where_conditions[index] = visit(condition)
      end
    end

    def visit_Allowance_Join(join)
      join.condition = visit(join.condition)
    end

    def visit_Allowance_Condition_Base(condition)
      replace_original_else(condition) do |condition|
        condition
      end
    end

    def visit_Allowance_Condition_AndConcatenation(condition)
      visit_concatenated(condition)
    end

    def visit_Allowance_Condition_OrConcatenation(condition)
      visit_concatenated(condition)
    end

    private

    attr_reader :scope,
                :new_condition,
                :orig_condition

    def method_name(subject)
      "visit_#{subject.visitor_class.to_s.gsub(/::/,'_')}".intern
    end

    def visit_concatenated(condition)
      replace_original_else(condition) do |condition|
        condition.first = visit(condition.first)
        condition.second = visit(condition.second)

        condition
      end
    end

    def replace_original_else(condition, &block)
      if condition == orig_condition
        new_condition
      else
        block.call(condition)
      end
    end
  end
end
