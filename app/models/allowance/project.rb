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

Allowance.scope :projects do
  table :users
  table :members
  table :member_roles
  table :roles
  table :projects
  table :enabled_modules

  scope_target projects

  condition :projects_members, Allowance::Condition::ProjectsMembers
  condition :member_roles_id_equal, Allowance::Condition::MemberRolesIdEqual
  condition :member_or_public_project, Allowance::Condition::MemberOrPublicProject
  condition :role_permitted, Allowance::Condition::RolePermitted
  condition :any_role, Allowance::Condition::AnyRole
  condition :project_active, Allowance::Condition::ProjectActive
  condition :enabled_modules_of_project, Allowance::Condition::EnabledModulesOfProject
  condition :permission_module_active, Allowance::Condition::PermissionsModuleActive
  condition :queried_user_is_admin, Allowance::Condition::QueriedUserIsAdmin

  allowed_member_or_public_project = member_or_public_project.and(role_permitted)
  project_and_module_active = project_active.and(permission_module_active)
  has_role_or_admin = any_role.or(queried_user_is_admin)

  projects.left_join(members)
          .on(projects_members)
          .left_join(member_roles)
          .on(member_roles_id_equal)
          .left_join(roles)
          .on(allowed_member_or_public_project)
          .left_join(enabled_modules)
          .on(enabled_modules_of_project)#.and(permission_module_active))
          .where(has_role_or_admin.and(project_and_module_active))#active))#(project_and_module_active))
end
