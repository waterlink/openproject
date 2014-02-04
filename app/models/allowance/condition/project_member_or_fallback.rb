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
    table Member
    table MemberRole
    table User
    table Role

    def arel_statement(project: nil, permission: nil, admin_pass: true, **extra)
      member_in_project_condition = members.grouping(members[:project_id].not_eq(nil).and(member_roles[:role_id].eq(roles[:id])))

      roles_join_condition = member_in_project_condition

      if project.nil? || project.is_public?
        is_not_builtin_user_condition = users[:status].eq(::User::STATUSES[:active])
        is_anonymous_user_condition = users[:id].eq(User.anonymous.id)

        non_member_condition = members.grouping(members[:project_id].eq(nil).and(roles[:id].eq(Role.non_member.id)).and(is_not_builtin_user_condition))
        anonymous_condition = members.grouping(members[:project_id].eq(nil).and(roles[:id].eq(Role.anonymous.id)).and(is_anonymous_user_condition))

        roles_join_condition = roles_join_condition
                                .or(non_member_condition)
                                .or(anonymous_condition)
      end

      roles_join_condition
    end
  end
end
