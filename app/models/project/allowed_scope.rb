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

module Project::AllowedScope
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def allowed(user, permission = nil)
      scope = Project.active

      scope = scope.merge(module_permission_active(permission))

      return scope if user.admin?

      scope.merge(permission_in(user, permission))
    end

    private

    def module_permission_active(permission)
      perm = Redmine::AccessControl.permission(permission)

      if perm.present? && perm.project_module.present?
        # If the permission belongs to a project module,
        # make sure the module is enabled
        self.unscoped.joins(:enabled_modules)
                     .where(enabled_modules: { name: perm.project_module })
      else
        self.unscoped
      end
    end

    def permission_in(user, permission = nil)
      members = Member.arel_table
      member_roles = MemberRole.arel_table
      roles = Role.arel_table
      projects = self.arel_table

      members_join_condition = projects[:id].eq(members[:project_id]).and(members[:user_id].eq(user.id))

      member_roles_join_condition = member_roles['member_id'].eq(members['id'])

      member_in_project_condition = members.grouping(members['project_id'].not_eq(nil).and(member_roles['role_id'].eq(roles['id'])))

      roles_join_condition = member_in_project_condition

      roles_join_condition = roles_join_condition
                                .or(public_project_condition(user))

      if permission.present?
        action_condition = Role.permitted(permission).where_values
        roles_join_condition = roles_join_condition.and(action_condition)
      end

      project_joins = projects.join(members, Arel::Nodes::OuterJoin)
                              .on(members_join_condition)
                              .join(member_roles, Arel::Nodes::OuterJoin)
                              .on(member_roles_join_condition)
                              .join(roles, Arel::Nodes::OuterJoin)
                              .on(roles_join_condition)

      self.joins(project_joins.join_sources).where(roles[:id].not_eq(nil))
    end

    def public_project_condition(user)
      members = Member.arel_table
      roles = Role.arel_table

      no_project_member = members[:project_id].eq(nil)

      role_is = if user.anonymous?
                  roles[:id].eq(Role.anonymous.id)
                else
                  roles[:id].eq(Role.non_member.id)
                end

      members.grouping(no_project_member.and(role_is).and(Project.public.where_values))
    end
  end
end
