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
  class MemberOrPublicProject < Base
    table Member, :members
    table Role, :roles
    table MemberRole, :member_roles

    def arel_statement(permission: nil, user: nil, **extra)
      condition = members[:project_id].not_eq(nil)
      condition = condition.and(member_roles[:role_id].eq(roles[:id]))

      condition = members.grouping(condition)

      condition = condition.or(public_project_condition(user)) if user

      condition
    end

    def public_project_condition(user)
      no_project_member = members[:project_id].eq(nil)

      role_is = if user.anonymous?
                  roles[:id].eq(::Role.anonymous.id)
                else
                  roles[:id].eq(::Role.non_member.id)
                end

      members.grouping(no_project_member.and(role_is).and(Project.public.where_values))
    end
  end
end
