#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2014 the OpenProject Foundation (OPF)
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

require 'spec_helper'

describe PreviewsController do
  it "should connect PUT /projects/:project_id/wiki/preview to wiki#preview" do
    put("/projects/1/wiki/preview").should route_to(controller: 'wiki',
                                                    action: 'preview',
                                                    project_id: '1')
  end

  it "should connect PUT /projects/:project_id/wiki/:id/preview to wiki#preview" do
    put("/projects/1/wiki/1/preview").should route_to(controller: 'wiki',
                                                      action: 'preview',
                                                      project_id: '1',
                                                      id: '1')
  end

  it "should connect PUT news/preview to news#preview" do
    put("/news/preview").should route_to(controller: 'news',
                                         action: 'preview')
  end

  it "should connect PUT /news/:id/preview to news#preview" do
    put("/news/1/preview").should route_to(controller: 'news',
                                           action: 'preview',
                                           id: '1')
  end

  it "should connect PUT /topic/preview to messages#preview" do
    put("/topic/preview").should route_to(controller: 'messages',
                                          action: 'preview')
  end

  it "should connect PUT /topics/:id/preview to messages#preview" do
    put("/topics/1/preview").should route_to(controller: 'messages',
                                             action: 'preview',
                                             id: '1')
  end

  it "should connect PUT /work_packages/preview to work_packages#preview" do
    put("/work_package/preview").should route_to(controller: 'work_packages',
                                                 action: 'preview')
  end 

  it "should connect PUT /work_packages/:id/preview to work_packages#preview" do
    put("/work_packages/1/preview").should route_to(controller: 'work_packages',
                                                    action: 'preview',
                                                    id: '1')
  end
end
