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
  class ProjectMemberOrFallback < Base
    table Member, :members_table
    table MemberRole, :member_roles_table
    table User, :users_table
    table Role, :roles_table

    def arel_statement(project: nil, permission: nil, admin_pass: true, **extra)
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

#      action_condition = role_permitted(permission, admin_pass: admin_pass)
      roles_join_condition #= roles_join_condition.and(action_condition)
    end

    private

    def role_permitted(permission, admin_pass: true)
      action_condition = Role.permitted(permission).where_values
      condition = roles_table.grouping(action_condition)

      if admin_pass
        admin_condition = users_table[:admin].eq(true)
        condition = condition.or(admin_condition)
      end

      condition
    end
  end
end
