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

class Allowance
#  def self.roles(user: nil, project: nil, permission: nil)
#  end

  def self.scope(name, &block)
    allowance = scope_instance(name)

    allowance.instance_eval(&block) if block_given?

    allowance
  end

  # Removes the scope from the known scopes.
  # Mostly used for testing for now.
  def self.drop_scope(name)
    drop_scope_instance(name)
  end

  def table(name, definition = nil)
    table_class = definition || Class.new(Allowance::Table::Base) do
      table name.to_s.singularize.camelize.constantize
    end

    new_table = table_class.new(self)

    instance_variable_set("@#{name}".to_sym, new_table)
    add_table name, table_class.model

    define_singleton_method name do
      instance_variable_get("@#{name}".to_sym)
    end
  end

  def condition(name, definition, options = {})
    define_condition(name, definition, only_if: options[:if])
  end

  def alter_condition(name, new_condition)
    if self.respond_to?(name)
      orig_condition = self.send(name)
      new_condition = instance_of_condition(new_condition)

      visitor = Visitor::ConditionModifier.new(self, orig_condition, new_condition)
      visitor.visit(@scope_target)
    end

    define_condition(name, new_condition)
  end

  def scope_target(table)
    @scope_target = table
  end

  def scope(options = {})
    #TODO: check how to circumvent the uniq
    @scope_target.to_ar_scope(options).uniq
  end

  def tables(klass = nil)
    @tables ||= {}

    if klass
      @tables[klass]
    else
      @tables.values
    end
  end

  def condition_name(instance)
    @conditions[instance]
  end

  def arel_table(klass)
    self.send(tables(klass)).table
  end

  def has_table?(table_class)
    tables(table_class).present?
  end

  def print
    visitor = Visitor::ToS.new(self)
    visitor.visit(@scope_target)
    #@scope_target.accept(visitor)
  end

  private

  def define_condition(name, definition, only_if: nil)
    instance = instance_of_condition(definition, only_if: only_if)

    instance_variable_set("@#{name}".to_sym, instance)
    add_condition(name, instance)

    define_singleton_method name do
      instance_variable_get("@#{name}".to_sym)
    end
  end

  def instance_of_condition(definition, only_if: nil)
    if definition.is_a?(Class)
      definition.new(self, only_if: only_if)
    else
      definition.if = only_if
      definition
    end
  end

  def self.scope_instance(name)
    @scopes ||= {}

    @scopes[name] ||= begin
      allowance = Allowance.new

      add_scope_method(name, allowance)

      allowance
    end

    @scopes[name]
  end

  def self.drop_scope_instance(name)
    return unless @scopes[name]

    @scopes.delete(name)

    eigenclass.send(:remove_method, name)
  end

  def add_table(name, model)
    @tables ||= {}

    @tables[model] = name
  end

  def add_condition(name, instance)
    @conditions ||= {}

    @conditions[instance] = name
  end

  def self.add_scope_method(name, allowance)
    method_body = ->(options = {}) { allowance.scope(options) }

    eigenclass.send(:define_method, name, method_body)
  end

  def self.eigenclass
    class << self; self; end;
  end
end
