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

Allowance.scope :principals do
  table :principals
  table :users #TODO: remove - handled by principal
  table :members
  table :member_roles
  table :roles
  table :projects
  table :enabled_modules

  scope_target principals

  condition :users_memberships, Allowance::Condition::UsersMemberships
  condition :member_roles_id_equal, Allowance::Condition::MemberRolesIdEqual
  condition :is_member, Allowance::Condition::IsMember
  condition :no_member, Allowance::Condition::NoMember
  condition :member_roles_role_id_equal, Allowance::Condition::MemberInProject
  condition :active_non_member_in_project, Allowance::Condition::ActiveNonMemberInProject
  condition :anonymous_in_project, Allowance::Condition::AnonymousInProject

  condition :enabled_modules_of_project, Allowance::Condition::EnabledModulesOfProject
  condition :project_active, Allowance::Condition::ProjectActive
  condition :project_public, Allowance::Condition::PublicProject, if: ->(project: nil, **ignored) { project.present? }
  condition :projects_members, Allowance::Condition::ProjectsMembers
  condition :project_nil, Allowance::Condition::ProjectNil

  condition :permission_module_active, Allowance::Condition::PermissionsModuleActive

  condition :role_permitted, Allowance::Condition::RolePermitted
  condition :user_is_admin, Allowance::Condition::UserIsAdmin
  condition :any_role, Allowance::Condition::AnyRole
  condition :limit_to_project, Allowance::Condition::LimitToProject

  condition :member_in_project, member_roles_role_id_equal.and(is_member.and(project_active))
  condition :no_member_in_public_active_project, no_member.and(project_public)
  condition :member_in_inactive_project, is_member.and(project_nil)
  condition :fallback_project_condition, no_member_in_public_active_project.or(member_in_inactive_project)
  condition :fallback_role, fallback_project_condition.and(active_non_member_in_project.or(anonymous_in_project))
  condition :member_or_fallback, member_in_project.or(fallback_role)

  condition :permission_active, permission_module_active
  condition :permitted_in_project, permission_active.and(role_permitted)
  condition :permitted_role_for_project, member_or_fallback.and(permitted_in_project)

  condition :any_role_or_admin, any_role.or(user_is_admin)

  condition :project_join, (projects_members.or(project_public)).and(project_active.and(limit_to_project))

  condition :member_or_public_project, project_join

  principals.left_join(members)
            .on(users_memberships)
            .left_join(projects)
            .on(member_or_public_project)
            .left_join(enabled_modules)
            .on(enabled_modules_of_project)
            .left_join(member_roles)
            .on(member_roles_id_equal)
            .left_join(roles)
            .on(permitted_role_for_project)
            .where(any_role_or_admin)
end
