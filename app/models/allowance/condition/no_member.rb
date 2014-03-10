module Allowance::Condition
  class NoMember < Base
    table Member

    def arel_statement(**ignored)
      members[:id].eq(nil)
    end
  end
end
