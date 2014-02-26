module Allowance::Visitor
  class ToS
    def initialize(scope)
      @scope = scope
    end

    def visit(subject)
      send(method_name(subject), subject)
    end

    def visit_Allowance(allowance)
      allowance.to_s
    end

    def visit_Allowance_Table_Base(subject)
      ret = get_table_name(subject.model)

      subject.joins.each do |join|
        ret += visit(join)
      end

      ret += where_conditions(subject)

      ret
    end

    def visit_Allowance_Join(join)
      ret = if join.type == Arel::Nodes::OuterJoin
               "\nLEFT OUTER JOIN "
             else
               "\nINNER JOIN "
             end

      ret += get_table_name(join.table.model)

      ret += "\nON " + visit(join.condition)

      ret
    end

    def visit_Allowance_Condition_Base(condition)
      get_condition_name(condition)
    end

    def visit_Allowance_Condition_AndConcatenation(condition)
      first = visit(condition.first)
      second = visit(condition.second)
      #first = get_condition_name(condition.first)
      #second = get_condition_name(condition.second)

      "#{first} AND #{second}"
    end

    def visit_Allowance_Condition_OrConcatenation(condition)
      first = visit(condition.first)
      second = visit(condition.second)
      #first = get_condition_name(condition.first)
      #second = get_condition_name(condition.second)

      "#{first} OR #{second}"
    end

    private

    attr_reader :scope

    def where_conditions(subject)
      return "" if subject.where_conditions.empty?

      ret = "\nWHERE "

      ret += subject.where_conditions.map do |condition|
        visit(condition)
      end.join(" AND ")

      ret
    end

    def get_condition_name(condition)
      condition.class.to_s
    end

    def get_table_name(model)
      scope.tables(model).to_s
    end

    def method_name(subject)
      "visit_#{subject.visitor_class.to_s.gsub(/::/,'_')}".intern
    end
  end
end
