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

require 'allowance'

Allowance.scope :users do
  table :users
  table :members
  table :member_roles
  table :roles
  table :projects
  table :enabled_modules

  scope_target users

  condition :users_memberships, Allowance::Condition::UsersMemberships
  condition :member_roles_id_equal, Allowance::Condition::MemberRolesIdEqual
  condition :project_member_or_fallback, Allowance::Condition::ProjectMemberOrFallback
  condition :members_projects_id_equal, Allowance::Condition::MemberProjectsIdEqual
  condition :module_enabled, Allowance::Condition::ModuleEnabled
  condition :role_permitted, Allowance::Condition::RolePermitted
  condition :user_is_admin, Allowance::Condition::UserIsAdmin
  condition :any_role, Allowance::Condition::AnyRole

  any_role_or_admin = any_role.or(user_is_admin)
  permitted_role_for_project = project_member_or_fallback.and(role_permitted)

  users.left_join(members)
       .on(users_memberships)
       .left_join(member_roles)
       .on(member_roles_id_equal)
       .left_join(roles)
       .on(permitted_role_for_project)
       .where(any_role_or_admin)
#               .left_join(projects)
#               .on(members_projects_id_equal)
#               .left_join(enabled_modules)
#               .on(module_enabled)
end
