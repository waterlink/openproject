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

      unless ors.empty?
        ored_conditions = ors_to_arel(options)

        condition = condition.or(ored_conditions) if ored_conditions
      end

      unless ands.empty?
        anded_conditions = ands_to_arel(options)

        condition = condition.and(anded_conditions) if anded_conditions
      end

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

    def self.table(klass, name = nil)
      name ||= klass.table_name.to_sym

      add_required_table(klass)

      define_method name do
        method_name = scope.tables(klass)

        scope.send(method_name).table
      end
    end

    protected

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

    def ands_to_arel(options)
      and_conditions = ands.first.to_arel(options)

      ands[1..-1].each do |and_condition|
        arel_condition = and_condition.to_arel(options)

        and_conditions = and_conditions.and(arel_condition) if arel_condition
      end

      and_conditions
    end

    def ors_to_arel(options)
      or_conditions = ors.first.to_arel(options)

      ors[1..-1].each do |or_condition|
        arel_condition = or_condition.to_arel(options)

        or_conditions = or_conditions.and(arel_condition) if arel_condition
      end

      or_conditions
    end

    def ands
      @ands ||= []
    end

    def ors
      @ors ||= []
    end

    def check_for_valid_scope
      all_tables_exist = required_tables.all? do |klass|
        scope.tables(klass).present?
      end

      raise "Not all required tables are defined in the current scope for #{self}" unless all_tables_exist
    end

    attr_reader :scope
  end
end
