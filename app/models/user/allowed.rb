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

#   SELECT
#   	"users".login,
#   	"roles".name,
#   	"roles".permissions
#   FROM "users"
#   LEFT OUTER JOIN "members"
#   	ON "users"."id" = "members"."user_id" AND "users"."type" = 'User' AND "members"."project_id" = 5
#   LEFT OUTER JOIN "member_roles"
#   	ON "member_roles"."member_id" = "members"."id"
#   LEFT OUTER JOIN "roles"
#   	ON (
#   		"members"."project_id" IS NULL AND "roles"."id" = 2 AND "users"."id" = 9998) /* Anonymous */
#   		OR ("members"."project_id" IS NOT NULL AND "member_roles"."role_id" = "roles"."id") /* member in project */
#   		OR ("members"."project_id" IS NULL AND "roles"."id" = 1 AND "users"."type" = 'User' ) /* non member */
#   WHERE "users"."type" IN ('User', 'AnonymousUser', 'DeletedUser')
#   AND "users"."id" = 5170 /* 5170 */
#   AND "roles".permissions IS NOT NULL

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
          allowed_to?(action, project, options)
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

      return true if self.admin?

      permissions = allowance_cache.fetch(project) do
        self.allowed_roles(nil, project)
      end

      Array(action).any? { |action| permissions.any? { |role| role.allowed_to?(action) } }
    end

    def reload(options = nil)
      allowance_cache.clear

      super
    end

    def allowed_roles(action, project = nil)
      Role.find_by_sql(User.allowed(action, project).where(id: self.id).select("roles.*").to_sql)
    end

    def allowance_cache
      @allowance_cache ||= ::User::AllowedCache.new
    end
  end

  module ClassMethods
    def allowed(action = nil, context = nil, admin_pass: true)
      Allowance.users(project: context, permission: action, admin_pass: admin_pass)
    end
  end
end
#   SELECT
#   	"users".login,
#   	"roles".name,
#   	"roles".permissions
#   FROM "users"
#   LEFT OUTER JOIN "members"
#   	ON "users"."id" = "members"."user_id" AND "users"."type" = 'User' AND "members"."project_id" = 5
#   LEFT OUTER JOIN "member_roles"
#   	ON "member_roles"."member_id" = "members"."id"
#   LEFT OUTER JOIN "roles"
#   	ON (
#   		"members"."project_id" IS NULL AND "roles"."id" = 2 AND "users"."id" = 9998) /* Anonymous */
#   		OR ("members"."project_id" IS NOT NULL AND "member_roles"."role_id" = "roles"."id") /* member in project */
#   		OR ("members"."project_id" IS NULL AND "roles"."id" = 1 AND "users"."type" = 'User' ) /* non member */
#   WHERE "users"."type" IN ('User', 'AnonymousUser', 'DeletedUser')
#   AND "users"."id" = 5170 /* 5170 */
#   AND "roles".permissions IS NOT NULL
#
#
#   SELECT "users".* FROM "users"
#   LEFT OUTER JOIN "members"
#     ON "users"."id" = "members"."user_id" AND "users"."type" = 'User' AND "members"."project_id" = 185
#   LEFT OUTER JOIN "member_roles"
#     ON "member_roles"."member_id" = "members"."id"
#   LEFT OUTER JOIN "roles"
#     ON ((("members"."project_id" IS NOT NULL AND "member_roles"."role_id" = "roles"."id") /* member in project */
#     OR ("members"."project_id" IS NOT NULL AND "roles"."id" = 467 AND "users"."type" = 'User')) /* non member */
#     OR ("members"."project_id" IS NULL AND "roles"."id" = 469 AND "users"."id" = 471)) /* Anonymous */
#   WHERE "users"."type" IN ('User', 'AnonymousUser', 'DeletedUser', 'SystemUser')
#   AND "users"."id" = 469
#   AND ("roles"."permissions" IS NOT NULL)
