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

class SearchController < ApplicationController
  before_filter :find_optional_project

  include MessagesHelper

  def index
    @question = params[:q] || ""
    @question.strip!
    @all_words = params[:all_words] || (params[:submit] ? false : true)
    @titles_only = !params[:titles_only].nil?

    projects_to_search =
      case params[:scope]
      when 'all'
        nil
      when 'my_projects'
        User.current.memberships.collect(&:project)
      when 'subprojects'
        @project ? (@project.self_and_descendants.active) : nil
      else
        @project
      end

    offset = begin
      Time.at(Rational(params[:offset])) if params[:offset]
    rescue; end

    # quick jump to an work_package
    if @question.match(/\A#?(\d+)\z/) && WorkPackage.visible.find_by_id($1.to_i)
      redirect_to work_package_path(:id => $1)
      return
    end

    @object_types = Redmine::Search.available_search_types.dup
    if projects_to_search.is_a? Project
      # don't search projects
      @object_types.delete('projects')
      # only show what the user is allowed to view
      @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
    end

    @scope = @object_types.select {|t| params[t]}
    @scope = @object_types if @scope.empty?

    # extract tokens from the question
    # eg. hello "bye bye" => ["hello", "bye bye"]
    # NOTE: it is not even relatively readable
    # maybe: @question.scan_query_tokens
    @tokens = @question.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
    # tokens must be at least 2 characters long
    @tokens = @tokens.uniq.select {|w| w.length > 1 }

    # NOTE: @tokens.any?
    if !@tokens.empty?
      # no more than 5 tokens to search for
      @tokens.slice! 5..-1 if @tokens.size > 5

      @results = []
      @results_by_type = Hash.new {|h,k| h[k] = 0}

      limit = 10
      @scope.each do |s|
        r, c = s.singularize.camelcase.constantize.search(@tokens, projects_to_search,
          :all_words => @all_words,
          :titles_only => @titles_only,
          :limit => (limit+1),
          :offset => offset,
          :before => params[:previous].nil?)
        @results += r
        @results_by_type[s] += c
      end
      @results = @results.sort {|a,b| b.event_datetime <=> a.event_datetime}
      if params[:previous].nil?
        @pagination_previous_date = @results[0].event_datetime if offset && @results[0]
        if @results.size > limit
          @pagination_next_date = @results[limit-1].event_datetime
          @results = @results[0, limit]
        end
      else
        @pagination_next_date = @results[-1].event_datetime if offset && @results[-1]
        if @results.size > limit
          @pagination_previous_date = @results[-(limit)].event_datetime
          @results = @results[-(limit), limit]
        end
      end
    else
      @question = ""
    end
    render :layout => false if request.xhr?
  end

private
  def find_optional_project
    return true unless params[:project_id]
    @project = Project.find(params[:project_id])
    check_project_privacy
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
