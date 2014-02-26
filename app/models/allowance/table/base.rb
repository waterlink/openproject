#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2013 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module Allowance::Table
  class Base

    include Allowance::Visitable
    self.visitor_class = ::Allowance::Table::Base

    def initialize(scope)
      @scope = scope
    end

    def left_join(other_table, options = {})
      join = Allowance::Join.new(other_table, Arel::Nodes::OuterJoin)

      if options[:after] || options[:before]
        reference_table = options[:after] || options[:before]

        index = joins.index { |j| j.table == reference_table }
        index = index + 1 if options[:after]

        joins.insert(index, join)
      else
        joins << join
      end

      @current_join = join

      # return self for chainability
      self
    end

    def inner_join(other_table)
      joins << ::Allowance::Join.new(other_table, Arel::Nodes::InnerJoin)

      @current_join = join

      # return self for chainability
      self
    end

    def on(condition)
      @current_join.condition = condition

      @current_join = nil

      # return self for chainability
      self
    end

    def where(condition)
      where_conditions << condition

      # return self for chainability
      self
    end

    def to_ar_scope(options = {})
      join_sources = joins_to_arel(options)
      where_sources = wheres_to_arel(options)

      model.joins(join_sources)
           .where(where_sources)
    end

    def table
      @table ||= self.class.arel_table
    end

    def joins
      @joins ||= []
    end

    def model
      self.class.model
    end

    def where_conditions
      @where_conditions ||= []
    end

    protected

    def self.table(name)
      @table = name
    end

    def self.arel_table
      @table.arel_table
    end

    def self.model
      @table
    end

    private

    def joins_to_arel(options)
      arel_joins = table

      joins.each do |join|
        table = join.table.table

        arel_joins = arel_joins.join(table, join.type)
                               .on(join.condition.to_arel(options))
      end

      arel_joins.join_sources
    end

    def wheres_to_arel(options)
      wheres = Arel::Nodes::Equality.new(1, 1)

      where_conditions.each do |condition|
        wheres = wheres.and(condition.to_arel(options))
      end

      wheres
    end

    def inner_joins
      @inner_joins ||= []
    end
  end
end
