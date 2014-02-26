module Allowance::Condition
  class IsMember < Base
    table Member

    def arel_statement(**ignored)
      members[:id].not_eq(nil)
    end
  end
end

