#-- encoding: UTF-8
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

class PreviewsController < ApplicationController

  before_filter :disable_api

  def update
    texts, attachments, obj = parse_preview_data

    render partial: 'common/preview',
           locals: { texts: texts, attachments: attachments, previewed: obj }
  end

  private

  def parse_preview_data
    preview_params = params.fetch(:preview)
    preview_object = preview_params[:param]
    preview_attributes = Array(preview_params[:values])

    texts = preview_attributes.each_with_object([]) do |attribute, list|
      text = params[preview_object][attribute]
      list << text unless text.blank?
    end

    obj = parse_previewed_object(preview_object, preview_params)

    attachments = previewed_object_attachments(obj)

    return texts, attachments, obj
  end

  def parse_previewed_object(preview_object, preview_params)
    preview_class = (preview_params[:class] ? preview_params[:class]
                                            : preview_object.to_s.classify)

    if preview_class
      preview_class = preview_class.constantize

      case [preview_class]
      when [WikiPage]
        project = Project.find(preview_params[:project_id])
        project.wiki.find_page(params[:id]).content
      else
        obj_id = params[:id].to_i
        obj_id ? preview_class.find_by_id(obj_id) : nil
      end
    end
  end

  def previewed_object_attachments(obj)
    case obj.class
    when WikiPage
      obj.page.attachments
    else
      (obj && obj.respond_to?('attachable')) ? obj.attachments : nil
    end
  end
end
