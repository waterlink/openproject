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

# See doc/COPYRIGHT.rdoc for more details.
#++

module OpenProject::Concerns::Preview
  extend ActiveSupport::Concern

  def preview
    texts, attachments, obj = parse_preview_data

    render partial: 'common/preview',
           locals: { texts: texts, attachments: attachments, previewed: obj }
  end

  protected

  def parse_preview_data_helper(param_name, attributes, klass = nil)
    klass ||= param_name.to_s.classify.constantize

    texts = Array(attributes).each_with_object([]) do |attribute, list|
      text = params[param_name][attribute]
      list << text unless text.blank?
    end

    obj = parse_previewed_object(param_name, klass)

    attachments = previewed_object_attachments(obj)

    return texts, attachments, obj
  end

  private

  def parse_previewed_object(param_name, klass)
    id = parse_previewed_id(param_name)
    id ? klass.find_by_id(id) : nil
  end

  def parse_previewed_id(param_name)
    id = params[param_name][:previewed_id] || params[:id]
    
    (id.to_i == 0) ? id : id.to_i
  end

  def previewed_object_attachments(obj)
    is_attachable = obj && (obj.respond_to?('attachable') || obj.respond_to?('attachments'))

    is_attachable ? obj.attachments : nil
  end
end
