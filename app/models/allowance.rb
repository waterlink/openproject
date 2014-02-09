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
    @scopes ||= []

    allowance = Allowance.new

    allowance.instance_eval(&block)

    add_scope_method(name, allowance)

    @scopes << allowance

    allowance
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

  def condition(name, definition)
    instance_variable_set("@#{name}".to_sym, definition.new(self))

    define_singleton_method name do
      instance_variable_get("@#{name}".to_sym)
    end
  end

  def scope_target(table)
    @scope_target = table
  end

  def scope(options = {})
    #TODO: check how to circumvent the uniq
    @scope_target.scope(options).uniq
  end

  def tables(klass = nil)
    @tables ||= {}

    if klass
      @tables[klass]
    else
      @tables.values
    end
  end

  def arel_table(klass)
    self.send(tables(klass)).table
  end

  def has_table?(table_class)
    tables(table_class).present?
  end

  private

  def add_table(name, model)
    @tables ||= {}

    @tables[model] = name
  end

  def self.add_scope_method(name, allowance)
    method_body = ->(options = {}) { allowance.scope(options) }

    eigenclass.send(:define_method, name, method_body)
  end

  def self.eigenclass
    class << self; self; end;
  end
end
