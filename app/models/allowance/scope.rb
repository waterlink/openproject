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
  module Scope
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      private

#      def allowed(permission = nil, project = nil, admin_pass: true)
#        user_joins

#        condition = role_permitted(permission, admin_pass: admin_pass)
#        Allowance.users({permission: permission, project: project, admin_pass: true})
#                 .where(condition)
#        scope = User.scoped
#
#        scope = scope.merge(user_permission_in(project, permission, admin_pass: admin_pass))
#
#        scope.merge(module_permission_active(permission))
#      end

      def role_permitted(permission, admin_pass: true)
        action_condition = Role.permitted(permission).where_values
        condition = roles_table.grouping(action_condition)

        if admin_pass
          admin_condition = users_table[:admin].eq(true)
          condition = condition.or(admin_condition)
        end

        condition
      end

      def user_permission_in(project, permission, admin_pass: true)
        joined_tables = user_joins(user: nil,
                                   project: project,
                                   permission: permission,
                                   admin_pass: admin_pass).join_sources

        condition = role_permitted(permission, admin_pass: admin_pass)

        User.joins(joined_tables).where(condition)
      end

      def permission_in(user, project = nil, permission = nil)
        joined_tables = project_joins(user: user,
                                      project: project,
                                      permission: permission).join_sources

        Project.joins(joined_tables).where(role_exists_condition)
      end

      def public_project_condition(user)
        no_project_member = members_table[:project_id].eq(nil)

        role_is = if user.anonymous?
                    roles_table[:id].eq(Role.anonymous.id)
                  else
                    roles_table[:id].eq(Role.non_member.id)
                  end

        members_table.grouping(no_project_member.and(role_is).and(Project.public.where_values))
      end

      private

#      def user_joins(user: nil, project: nil, permission: nil, admin_pass: true)
#        Allowance.scope :users do
#          table :users
#          table :members
#          table :member_roles
#          table :roles
#          table :projects
#          table :enabled_modules
#
#          scope_target users
#
#          condition :users_memberships, Allowance::Condition::UsersMemberships
#          condition :member_roles_id_equal, Allowance::Condition::MemberRolesIdEqual
#          condition :project_member_or_fallback, Allowance::Condition::ProjectMemberOrFallback
#          condition :members_projects_id_equal, Allowance::Condition::MemberProjectsIdEqual
#          condition :module_enabled, Allowance::Condition::ModuleEnabled
#
#          users.left_join(members)
#               .on(users_memberships)
#               .left_join(member_roles)
#               .on(member_roles_id_equal)
#               .left_join(roles)
#               .on(project_member_or_fallback)
#               .left_join(projects)
#               .on(members_projects_id_equal)
#               .left_join(enabled_modules)
#               .on(module_enabled)
#        end
#        Table::User.left_join(Table::Member.on(
#
#        users_table.join(members_table, Arel::Nodes::OuterJoin)
#                   .on(members_user_join_condition(project))
#                   .join(member_roles_table, Arel::Nodes::OuterJoin)
#                   .on(member_roles_join_condition)
#                   .join(roles_table, Arel::Nodes::OuterJoin)
#                   .on(member_or_fallback_user_condition(project: project, permission: permission, admin_pass: admin_pass))
#                   .join(projects_table, Arel::Nodes::OuterJoin)
#                   .on(members_project_join_condition)
#      end

      def project_joins(user: nil, project: nil, permission: nil)
        projects_table.join(members_table, Arel::Nodes::OuterJoin)
                      .on(members_project_join_condition(user: user, project: project))
                      .join(member_roles_table, Arel::Nodes::OuterJoin)
                      .on(member_roles_join_condition)
                      .join(roles_table, Arel::Nodes::OuterJoin)
                      .on(roles_join_condition(user: user, permission: permission))
      end

      def role_exists_condition
        roles_table[:id].not_eq(nil)
      end

      def members_project_id_equal_condition
        members_table[:project_id].eq(projects_table[:id])
      end

      def members_user_join_condition(project)
        condition = users_table[:id].eq(members_table[:user_id])
        condition = condition.and(users_table[:type].eq('User'))

        condition = condition.and(members_table[:project_id].eq(project.id)) if project.present?

        condition
      end

      def members_project_join_condition(user: nil, project: nil)
        condition = projects_table[:id].eq(members_table[:project_id])
        condition = condition.and(members_table[:user_id].eq(user.id)) if user.present?

        condition = condition.and(members_table[:project_id].eq(project.id)) if project.present?

        condition
      end

      def member_roles_join_condition
        member_roles_table[:member_id].eq(members_table[:id])
      end

      def roles_join_condition(user: nil, permission: nil)
        condition = members_table[:project_id].not_eq(nil)
        condition = condition.and(member_roles_table[:role_id].eq(roles_table[:id]))

        condition = members_table.grouping(condition)

        condition = condition.or(public_project_condition(user)) if user

        if permission.present?
          action_condition = role_permitted(permission, admin_pass: false)
          condition = condition.and(action_condition)
        end

        condition
      end

      def member_or_fallback_user_condition(project: project, permission: permission, admin_pass: true)
        member_in_project_condition = members_table.grouping(members_table[:project_id].not_eq(nil).and(member_roles_table[:role_id].eq(roles_table[:id])))

        roles_join_condition = member_in_project_condition

        if project.nil? || project.is_public?
          is_not_builtin_user_condition = users_table[:type].eq('User')
          is_anonymous_user_condition = users_table[:id].eq(User.anonymous.id)

          non_member_condition = members_table.grouping(members_table[:project_id].eq(nil).and(roles_table[:id].eq(Role.non_member.id)).and(is_not_builtin_user_condition))
          anonymous_condition = members_table.grouping(members_table[:project_id].eq(nil).and(roles_table[:id].eq(Role.anonymous.id)).and(is_anonymous_user_condition))

          roles_join_condition = roles_join_condition
                                  .or(non_member_condition)
                                  .or(anonymous_condition)
        end

        action_condition = role_permitted(permission, admin_pass: admin_pass)
        roles_join_condition = roles_join_condition.and(action_condition)
      end

      def module_permission_active(permission)
        perm = Redmine::AccessControl.permission(permission)

        if perm.present? && perm.project_module.present?
          # If the permission belongs to a project module,
          # make sure the module is enabled
          Project.unscoped.joins(:enabled_modules)
                          .where(enabled_modules: { name: perm.project_module })
        else
          Project.unscoped
        end
      end

#      def roles_table
#        Role.arel_table
#      end
#
#      def members_table
#        Member.arel_table
#      end
#
#      def projects_table
#        Project.arel_table
#      end
#
#      def member_roles_table
#        MemberRole.arel_table
#      end
#
#      def users_table
#        User.arel_table
#      end
    end
  end
end

