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

module User::Allowed
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)

    base.class_attribute :registered_allowance_evaluators
  end

  module InstanceMethods

    # Return true if the user is allowed to do the specified action on a specific context
    # Action can be:
    # * a parameter-like Hash (eg. :controller => '/projects', :action => 'edit')
    # * a permission Symbol (eg. :edit_project)
    # Context can be:
    # * a project : returns true if user is allowed to do the specified action on this project
    # * a group of projects : returns true if user is allowed on every project
    # * nil with options[:global] set : check if user has at least one role allowed for this action,
    #   or falls back to Non Member / Anonymous permissions depending if the user is logged
    def allowed_to?(action, context, options={})
      if action.is_a?(Hash) && action[:controller]
        if action[:controller].to_s.starts_with?("/")
          action = action.dup
          action[:controller] = action[:controller][1..-1]
        end

        action = Redmine::AccessControl.allowed_symbols(action)
      end

      if context.is_a?(Project)
        allowed_to_in_project?(action, context, options)
      elsif context.is_a?(Array)
        # Authorize if user is authorized on every element of the array
        context.present? && context.all? do |project|
          allowed_to?(action, project ,options)
        end
      elsif options[:global]
        allowed_to_globally?(action, options)
      else
        false
      end
    end

    def allowed_to_in_project?(action, project, options = {})
      # No action allowed on archived projects
      return false unless project.active?
      # No action allowed on disabled modules

      case action
      when Symbol
        return false unless project.allows_to?(action)
      when Array
        action = action.select { |a| project.allows_to?(a) }

        return false if action.empty?
      end

      allowed_in_context(action, project)
    end

    # Is the user allowed to do the specified action on any project?
    # See allowed_to? for the actions and valid options.
    def allowed_to_globally?(action, options = {})
      allowed_in_context(action, nil)
    end

    def allowed_in_context(action, project)
      self.class.allowed(action, project).where(id: id).count == 1
    end
  end

  module ClassMethods
    def register_allowance_evaluator(filter)
      self.registered_allowance_evaluators ||= []

      registered_allowance_evaluators << filter
    end

    def allowed(action, context = nil)
      scopes = Hash.new do |h, k|
        h[k] = User.where(Arel::Nodes::Equality.new(1, 1))
      end

      condition = Arel::Nodes::Equality.new(1, 0)

      registered_allowance_evaluators.each do |evaluator|
        if evaluator.applicable?(action, context)
          scopes[evaluator.identifier] = scopes[evaluator.identifier].merge(evaluator.joins(action, context))
          condition = evaluator.condition(condition, action, context)
        end
      end

      scope = User.where("1=1")

      scopes.values.each do |join|
        scope = scope.merge(join)
      end

      scope.where(condition)
    end
  end
end
