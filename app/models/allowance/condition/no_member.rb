module Allowance::Condition
  class NoMember < Base
    table Member

    def arel_statement(project: nil, **ignored)
      #if project.nil? || project.is_public?
        members[:id].eq(nil)
      #end
    end
  end
end
