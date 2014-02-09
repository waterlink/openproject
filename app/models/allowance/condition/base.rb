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

module Allowance::Condition
  class Base
    def initialize(scope)
      @scope = scope
    end

    def to_arel(options = {})
      check_for_valid_scope

      condition = arel_statement(options) if respond_to?(:arel_statement)

      condition = concat(condition, options)

      condition
    end

    def and(other_condition)
      ands << other_condition

      self
    end

    def or(other_condition)
      ors << other_condition

      self
    end

    protected

    def self.table(klass, name = nil)
      name ||= klass.table_name.to_sym

      add_required_table(klass)

      define_method name do
        scope.arel_table(klass)
      end
    end

    def self.add_required_table(klass)
      @required_tables ||= []

      @required_tables << klass
    end

    def required_tables
      self.class.required_tables
    end

    def self.required_tables
      @required_tables ||= []
    end

    private

    def concat(condition, options)
      condition = concat_ors(condition, options)
      condition = concat_ands(condition, options)

      condition
    end

    def concat_ors(condition, options)
      ored_conditions = ors.map { |ored| ored.to_arel(options) }
                           .unshift(condition)
                           .compact

      concat_conditions(:or, ored_conditions)
    end

    def concat_ands(condition, options)
      anded_conditions = ands.map { |anded| anded.to_arel(options) }
                             .unshift(condition)
                             .compact

      concat_conditions(:and, anded_conditions)
    end

    def concat_conditions(method, conditions)
      return nil if conditions.empty?

      concatenation = conditions.first

      conditions[1..-1].each do |concat_condition|
        concatenation = concatenation.send(method, concat_condition)
      end

      concatenation
    end

    def ands
      @ands ||= []
    end

    def ors
      @ors ||= []
    end

    def check_for_valid_scope
      required_tables.each do |klass|
        raise TableMissingInScopeError.new(self, klass) unless scope.has_table?(klass)
      end
    end

    attr_reader :scope
  end
end
