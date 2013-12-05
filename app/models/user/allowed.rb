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

      @permissions ||= Hash.new

      permissions = if @permissions[project]
        @permissions[project]
      else
        permissions = self.class.allowed(action, project).where(id: id).select('permissions')

        permissions = permissions.map { |p| YAML::load(p.permissions) }.flatten

        @permissions[project] = permissions
      end

      #binding.pry

      (permissions & Array(action)).count > 0
      #
#      return true if self.admin?
#
#      if Array === action
#        action.any? { |a| allowed_in_context(a, project) }
#      else
#        cached_permissions(project).include?(action)
#      end
    end

    def allowed_in_projects(action)
      @project_ids ||= Hash.new do |h, k|
        h[k] = User.allowed(k).where(id: self.id).where("permissions LIKE '%#{k}%'").select("members.project_id")
      end

      @project_ids[action]
    end

    private

    def cached_permissions(project)
      @cached_permissions ||= Hash.new do |hash, context|
        hash[context] = permissions_for_context(context)
      end

      @cached_permissions[project]
    end

    def permissions_for_context(project)
      roles = Role.arel_table
      members = Member.arel_table
      member_roles = MemberRole.arel_table

      joins = roles.join(member_roles, Arel::Nodes::OuterJoin)
                   .on(member_roles[:role_id].eq(roles[:id]))
                   .join(members, Arel::Nodes::OuterJoin)
                   .on(member_roles[:member_id].eq(members[:id]))

      membership_of_user = members[:user_id].eq(self.id)

      condition = membership_of_user

      if project
        membership_in_project = members[:project_id].eq(project.id)

        condition = condition.and membership_in_project

        if project.is_public?
          no_member = members[:id].eq(nil)
          no_member_role = roles[:id].eq(Role.non_member.id)
          non_member_condition = roles.grouping(no_member.and(no_member_role))

          condition = condition.or non_member_condition
        end
      end


      if anonymous?
        condition = condition.or roles[:id].eq(Role.anonymous.id)
      end

      roles = Role.select(:permissions).joins(joins.join_sources).where(condition).all

      roles.map(&:permissions).flatten.uniq
    end
  end

  module ClassMethods
    def register_allowance_evaluator(filter)
      self.registered_allowance_evaluators ||= []

      registered_allowance_evaluators << filter
    end

    def allowed(action, context = nil)
#      scope = self.where(Arel::Nodes::Equality.new(1, 1))
#
#      condition = Arel::Nodes::Equality.new(1, 0)
#
#      registered_allowance_evaluators.each do |evaluator|
#        if evaluator.applicable?(action, context)
#          scope = evaluator.joins(scope, action, context)
#          condition = evaluator.condition(condition, action, context)
#        end
#      end
#
#      scope.where(condition)
      members = Member.arel_table
      member_roles = MemberRole.arel_table
      roles = Role.arel_table
      users = User.arel_table

      members_join_condition = users['id'].eq(members['user_id']).and(users['type'].eq('User'))
      members_join_condition = members_join_condition.and(members['project_id'].eq(context.id)) if context

      member_roles_join_condition = member_roles['member_id'].eq(members['id'])

      member_in_project_condition = members.grouping(members['project_id'].not_eq(nil).and(member_roles['role_id'].eq(roles['id'])))

      roles_join_condition = member_in_project_condition

      if context && context.is_public?
        non_member_condition = members.grouping(members['project_id'].eq(nil).and(roles['id'].eq(Role.non_member.id)).and(users['type'].eq('User')))
        anonymous_condition = members.grouping(members['project_id'].eq(nil).and(roles['id'].eq(Role.anonymous.id)).and(users['id'].eq(User.anonymous.id)))

        roles_join_condition = roles_join_condition
                                .or(non_member_condition)
                                .or(anonymous_condition)
      elsif context.nil?
        anonymous_condition = members.grouping(members['project_id'].eq(nil).and(roles['id'].eq(Role.anonymous.id)).and(users['id'].eq(User.anonymous.id)))

        roles_join_condition = roles_join_condition
                                .or(anonymous_condition)
      end

      users_joins = users.join(members, Arel::Nodes::OuterJoin)
                         .on(members_join_condition)
                         .join(member_roles, Arel::Nodes::OuterJoin)
                         .on(member_roles_join_condition)
                         .join(roles, Arel::Nodes::OuterJoin)
                         .on(roles_join_condition)

      User.joins(users_joins.join_sources)
        .where(roles['permissions'].not_eq(nil))
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
