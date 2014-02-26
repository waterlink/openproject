class Allowance
  module Visitable
    def self.included(base)
      base.class_attribute :visitor_class

      base.visitor_class = base
    end

    def accept(visitor)
      visitor.visit(self)
    end

    def visitor_class
      self.class.visitor_class
    end
  end
end
