class Allowance
  class Join < Struct.new(:table, :type, :condition)
    include Allowance::Visitable
  end
end
