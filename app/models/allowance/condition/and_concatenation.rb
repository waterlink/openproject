module Allowance::Condition
  class AndConcatenation < Concatenation
    concatenation_method :and

    self.visitor_class = self
  end
end
