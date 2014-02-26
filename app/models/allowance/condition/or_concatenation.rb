module Allowance::Condition
  class OrConcatenation < Concatenation
    concatenation_method :or

    self.visitor_class = self
  end
end
