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

module WorkPackagesHelper
  include AccessibilityHelper

  def work_package_api_done_ratio_if_enabled(api, issue)
    if Setting.work_package_done_ratio != 'disabled'
      api.done_ratio  issue.done_ratio
    end
  end

  def work_package_breadcrumb
    full_path = if !@project.nil?
                  link_to(t(:label_work_package_plural), project_path(@project, {:jump => current_menu_item}))
                else
                  ancestors_links.unshift(work_package_index_link)
                end

    breadcrumb_paths(*full_path)
  end

  def ancestors_links
    controller.ancestors.map do |parent|
      link_to '#' + h(parent.id), work_package_path(parent.id)
    end
  end

  def work_package_index_link
    # TODO: will need to change to work_package index
    link_to(t(:label_work_package_plural), {controller: :work_packages, action: :index})
  end

  # Displays a link to +work_package+ with its subject.
  # Examples:
  #
  #   link_to_work_package(package)                             # => Defect #6: This is the subject
  #   link_to_work_package(package, :all_link => true)          # => Defect #6: This is the subject (everything within the link)
  #   link_to_work_package(package, :truncate => 9)             # => Defect #6: This i...
  #   link_to_work_package(package, :subject => false)          # => Defect #6
  #   link_to_work_package(package, :type => false)             # => #6: This is the subject
  #   link_to_work_package(package, :project => true)           # => Foo - Defect #6
  #   link_to_work_package(package, :id_only => true)           # => #6
  #   link_to_work_package(package, :subject_only => true)      # => This is the subject (as link)
  def link_to_work_package(package, options = {})

    if options[:subject_only]
      options.merge!(:type => false,
                     :subject => true,
                     :id => false,
                     :all_link => true)
    elsif options[:id_only]
      options.merge!(:type => false,
                     :subject => false,
                     :id => true,
                     :all_link => true)
    else
      options.reverse_merge!(:type => true,
                             :subject => true,
                             :id => true)
    end

    parts = { :prefix => [],
              :hidden_link => [],
              :link => [],
              :suffix => [],
              :title => [],
              :css_class => ['issue'] }

    # Prefix part

    parts[:prefix] << "#{package.project}" if options[:project]

    # Link part

    parts[:link] << h(options[:before_text].to_s) if options[:before_text]

    parts[:link] << h(package.kind.to_s) if options[:type]

    parts[:link] << "##{h(package.id)}" if options[:id]

    # Hidden link part

    if package.closed?
      parts[:hidden_link] << content_tag(:span,
                                         t(:label_closed_work_packages),
                                         :class => "hidden-for-sighted")

      parts[:css_class] << 'closed'
    end

    # Suffix part

    if options[:subject]
      subject = if options[:subject]
                  subject = package.subject
                  if options[:truncate]
                    subject = truncate(subject, :length => options[:truncate])
                  end

                  subject
                end

      parts[:suffix] << h(subject)
    end

    # title part

    parts[:title] << package.subject

    # combining

    prefix = parts[:prefix].join(" ")
    suffix = parts[:suffix].join(" ")
    link = parts[:link].join(" ").strip
    hidden_link = parts[:hidden_link].join("")
    title = parts[:title].join(" ")
    css_class = parts[:css_class].join(" ")

    text = if options[:all_link]
             link_text = [prefix, link].reject(&:empty?).join(" - ")
             link_text = [link_text, suffix].reject(&:empty?).join(": ")
             link_text = [hidden_link, link_text].reject(&:empty?).join("")

             link_to(link_text.html_safe,
                     work_package_path(package),
                     :title => title,
                     :class => css_class)
           else
             link_text = [hidden_link, link].reject(&:empty?).join("")

             html_link = link_to(link_text.html_safe,
                                 work_package_path(package),
                                 :title => title,
                                 :class => css_class)

             [[prefix, html_link].reject(&:empty?).join(" - "),
              suffix].reject(&:empty?).join(": ")
            end.html_safe
  end

  def work_package_quick_info(work_package)
    changed_dates = {}

    journals = work_package.journals.where(["created_at >= ?", Date.today.to_time - 7.day])
                                    .order("created_at desc")

    journals.each do |journal|
      break if changed_dates["start_date"] && changed_dates["due_date"]

      ["start_date", "due_date"].each do |date|
        if changed_dates[date].nil? &&
           journal.changed_data[date] &&
           journal.changed_data[date].first
              changed_dates[date] = " (<del>#{journal.changed_data[date].first}</del>)".html_safe
        end
      end
    end

    link = link_to_work_package(work_package)
    link += " #{work_package.start_date.nil? ? "[?]" : work_package.start_date.to_s}"
    link += changed_dates["start_date"]
    link += " – #{work_package.due_date.nil? ? "[?]" : work_package.due_date.to_s}"
    link += changed_dates["due_date"]

    link
  end

  def work_package_quick_info_with_description(work_package, lines = 3)
    description_lines = work_package.description.to_s.lines.to_a[0,lines]

    if description_lines[lines-1] && work_package.description.to_s.lines.to_a.size > lines
      description_lines[lines-1].strip!

      while !description_lines[lines-1].end_with?("...") do
        description_lines[lines-1] = description_lines[lines-1] + "."
      end
    end

    description = if work_package.description.blank?
                    empty_element_tag
                  else
                    textilizable(description_lines.join(""))
                  end

    link = work_package_quick_info(work_package)

    link += content_tag(:div, :class => 'indent quick_info attributes') do

      responsible = if work_package.responsible_id.present?
                      "<span class='label'>#{WorkPackage.human_attribute_name(:responsible)}:</span> " +
                      "#{work_package.responsible.name}"
                    end

      assignee = if work_package.assigned_to_id.present?
                   "<span class='label'>#{WorkPackage.human_attribute_name(:assigned_to)}:</span> " +
                   "#{work_package.assigned_to.name}"
                 end

      [responsible, assignee].compact.join("<br>").html_safe
    end

    link += content_tag(:div, description, :class => 'indent quick_info description')

    link
  end

  def work_package_list(work_packages, &block)
    ancestors = []
    work_packages.each do |work_package|
      while (ancestors.any? && !work_package.is_descendant_of?(ancestors.last))
        ancestors.pop
      end
      yield work_package, ancestors.size
      ancestors << work_package unless work_package.leaf?
    end
  end

  def send_notification_option
    checked = params["send_notification"] != "0"

    content_tag(:label,
                l(:label_notify_member_plural),
                  :for => 'send_notification') +
    hidden_field_tag('send_notification', '0', :id => nil) +
    check_box_tag('send_notification', '1', checked)
  end

  def render_work_package_tree_row(work_package, level, relation)
    css_classes = ["work-package"]
    css_classes << "work-package-#{work_package.id}"
    css_classes << "idnt" << "idnt-#{level}" if level > 0

    if relation == "root"
      issue_text = link_to("#{work_package.to_s}",
                             'javascript:void(0)',
                             :style => "color:inherit; font-weight: bold; text-decoration:none; cursor:default;")
    else
      title = []

      if relation == "parent"
        title << content_tag(:span, l(:description_parent_work_package), :class => "hidden-for-sighted")
      elsif relation == "child"
        title << content_tag(:span, l(:description_sub_work_package), :class => "hidden-for-sighted")
      end

      issue_text = link_to(work_package.to_s.html_safe, work_package_path(work_package))
    end

    content_tag :tr, :class => css_classes.join(' ') do
      concat content_tag :td, check_box_tag("ids[]", work_package.id, false, :id => nil), :class => 'checkbox'
      concat content_tag :td, issue_text, :class => 'subject'
      concat content_tag :td, h(work_package.status)
      concat content_tag :td, link_to_user(work_package.assigned_to)
      concat content_tag :td, link_to_version(work_package.fixed_version)
    end
  end

  # Returns a string of css classes that apply to the issue
  def work_package_css_classes(work_package)
    #TODO: remove issue once css is cleaned of it
    s = "issue work_package".html_safe
    s << " status-#{work_package.status.position}" if work_package.status
    s << " priority-#{work_package.priority.position}" if work_package.priority
    s << ' closed' if work_package.closed?
    s << ' overdue' if work_package.overdue?
    s << ' child' if work_package.child?
    s << ' parent' unless work_package.leaf?
    s << ' created-by-me' if User.current.logged? && work_package.author_id == User.current.id
    s << ' assigned-to-me' if User.current.logged? && work_package.assigned_to_id == User.current.id
    s
  end

  WorkPackageAttribute = Struct.new(:attribute, :field)

  def work_package_form_all_middle_attributes(form, work_package, locals = {})
    [
      work_package_form_status_attribute(form, work_package, locals),
      work_package_form_priority_attribute(form, work_package, locals),
      work_package_form_assignee_attribute(form, work_package, locals),
      work_package_form_responsible_attribute(form, work_package, locals),
      work_package_form_category_attribute(form, work_package, locals),
      work_package_form_assignable_versions_attribute(form, work_package, locals),
      work_package_form_start_date_attribute(form, work_package, locals),
      work_package_form_due_date_attribute(form, work_package, locals),
      work_package_form_estimated_hours_attribute(form, work_package, locals),
      work_package_form_done_ratio_attribute(form, work_package, locals),
      work_package_form_custom_values_attribute(form, work_package, locals)
    ].flatten.compact
  end

  def work_package_form_minimal_middle_attributes(form, work_package, locals = {})
    [
      work_package_form_status_attribute(form, work_package, locals),
      work_package_form_assignee_attribute(form, work_package, locals),
      work_package_form_assignable_versions_attribute(form, work_package, locals),
      work_package_form_done_ratio_attribute(form, work_package, locals),
    ].flatten.compact
  end

  def work_package_form_top_attributes(form, work_package, locals = {})
    [
      work_package_form_type_attribute(form, work_package, locals),
      work_package_form_subject_attribute(form, work_package, locals),
      work_package_form_parent_attribute(form, work_package, locals),
      work_package_form_description_attribute(form, work_package, locals)
    ].compact
  end

  def work_package_show_attribute_list(work_package)
    main_attributes = work_package_show_main_attributes(work_package)
    custom_field_attributes = work_package_show_custom_fields(work_package)
    core_attributes = (main_attributes | custom_field_attributes).compact

    hook_attributes(work_package, core_attributes).compact
  end

  def group_work_package_attributes(attribute_list)
    attributes = {}
    attributes[:left], attributes[:right] = attribute_list.each_slice((attribute_list.count+1) / 2).to_a

    attributes
  end

  def work_package_show_attributes(work_package)
    group_work_package_attributes work_package_show_attribute_list(work_package)
  end

  def work_package_show_table_row(attribute, klass = nil, attribute_lang = nil, value_lang = nil, &block)
    klass = attribute.to_s.dasherize if klass.nil?

    content = content_tag(:td, :class => [:work_package_attribute_header, klass], :lang => attribute_lang) { "#{WorkPackage.human_attribute_name(attribute)}:" }
    content << content_tag(:td, :class => klass, :lang => value_lang, &block)

    WorkPackageAttribute.new(attribute, content)
  end

  def work_package_show_status_attribute(work_package)
    work_package_show_table_row(:status) do
      work_package.status ?
        work_package.status.name :
        empty_element_tag
    end
  end

  def work_package_show_start_date_attribute(work_package)
    work_package_show_table_row(:start_date, 'start-date') do
      work_package.start_date ?
        format_date(work_package.start_date) :
        empty_element_tag
    end
  end

  def work_package_show_priority_attribute(work_package)
    work_package_show_table_row(:priority) do
      work_package.priority ?
        work_package.priority.name :
        empty_element_tag
    end
  end

  def work_package_show_due_date_attribute(work_package)
    work_package_show_table_row(:due_date) do
      work_package.due_date ?
        format_date(work_package.due_date) :
        empty_element_tag
    end
  end

  def work_package_show_assigned_to_attribute(work_package)
    work_package_show_table_row(:assigned_to) do
      content = avatar(work_package.assigned_to, :size => "14").html_safe
      content << (work_package.assigned_to ? link_to_user(work_package.assigned_to) : empty_element_tag)
      content
    end
  end

  def work_package_show_responsible_attribute(work_package)
    work_package_show_table_row(:responsible) do
      content = avatar(work_package.responsible, :size => "14").html_safe
      content << (work_package.responsible ? link_to_user(work_package.responsible) : empty_element_tag)
      content
    end
  end

  def work_package_show_progress_attribute(work_package)
    return if WorkPackage.done_ratio_disabled?

    work_package_show_table_row(:progress, 'done-ratio') do
      progress_bar work_package.done_ratio, :width => '80px', :legend => work_package.done_ratio.to_s
    end
  end

  def work_package_show_category_attribute(work_package)
    work_package_show_table_row(:category) do
      work_package.category ?
        work_package.category.name :
        empty_element_tag
    end
  end

  def work_package_show_spent_time_attribute(work_package)
    work_package_show_table_row(:spent_time) do
      work_package.spent_hours > 0 ?
        link_to(l_hours(work_package.spent_hours), work_package_time_entries_path(work_package)) :
        empty_element_tag
    end
  end

  def work_package_show_fixed_version_attribute(work_package)
    work_package_show_table_row(:fixed_version) do
      work_package.fixed_version ?
        link_to_version(work_package.fixed_version) :
        empty_element_tag
    end
  end

  def work_package_show_estimated_hours_attribute(work_package)
    work_package_show_table_row(:estimated_hours) do
      work_package.estimated_hours ?
        l_hours(work_package.estimated_hours) :
        empty_element_tag
    end
  end

  def work_package_form_type_attribute(form, work_package, locals = {})
    selectable_types = locals[:project].types.collect {|t| [((t.is_standard) ? '' : t.name), t.id]}

    field = form.select :type_id, selectable_types, :required => true

    url = work_package.new_record? ?
           new_type_project_work_packages_path(locals[:project]) :
           new_type_work_package_path(work_package)

    field += observe_field :work_package_type_id, :url => url,
                                                  :update => :attributes,
                                                  :method => :get,
                                                  :with => "Form.serialize('work_package-form')"

    WorkPackageAttribute.new(:type, field)
  end

  def work_package_form_subject_attribute(form, work_package, locals = {})
    WorkPackageAttribute.new :subject, form.text_field(:subject, :size => 80, :required => true)
  end

  def work_package_form_parent_attribute(form, work_package, locals = {})
    if User.current.allowed_to?(:manage_subtasks, locals[:project])
      field = form.text_field :parent_id, :size => 10, :title => l(:description_autocomplete), :class => 'short'
      field += '<div id="parent_issue_candidates" class="autocomplete"></div>'.html_safe
      field += javascript_tag "observeWorkPackageParentField('#{work_packages_auto_complete_path(:id => work_package, :project_id => locals[:project], :escape => false) }')"

      WorkPackageAttribute.new(:parent_issue, field)
    end
  end

  def work_package_form_description_attribute(form, work_package, locals = {})
    field = form.text_area :description,
                           :cols => 60,
                           :rows => (work_package.description.blank? ? 10 : [[10, work_package.description.length / 50].max, 100].min),
                           :accesskey => accesskey(:edit),
                           :class => 'wiki-edit',
                           :'data-wp_autocomplete_url' => work_packages_auto_complete_path(:project_id => work_package.project, :format => :json)

    WorkPackageAttribute.new(:description, field)
  end

  def work_package_form_status_attribute(form, work_package, locals = {})
    new_statuses = work_package.new_statuses_allowed_to(locals[:user], true)

    field = if new_statuses.any?
              form.select(:status_id, (new_statuses.map {|p| [p.name, p.id]}), :required => true)
            elsif work_package.status
              form.label(:status) + work_package.status.name
            else
              form.label(:status) + empty_element_tag
            end

    WorkPackageAttribute.new(:status, field)
  end

  def work_package_form_priority_attribute(form, work_package, locals = {})
    WorkPackageAttribute.new(:priority,
                             form.select(:priority_id, (locals[:priorities].map {|p| [p.name, p.id]}), {:required => true}, :disabled => attrib_disabled?(work_package, 'priority_id')))
  end

  def work_package_form_assignee_attribute(form, work_package, locals = {})
    WorkPackageAttribute.new(:assignee,
                             form.select(:assigned_to_id, (work_package.assignable_assignees.map {|m| [m.name, m.id]}), :include_blank => true))
  end

  def work_package_form_responsible_attribute(form, work_package, locals = {})
    WorkPackageAttribute.new(:responsible,
                             form.select(:responsible_id, work_package.assignable_responsibles.map {|m| [m.name, m.id]}, :include_blank => true))
  end

  def work_package_form_category_attribute(form, work_package, locals = {})
    unless locals[:project].categories.empty?
      field = form.select(:category_id,
                          (locals[:project].categories.collect {|c| [c.name, c.id]}),
                          :include_blank => true)
      field += prompt_to_remote(icon_wrapper('icon icon-add',t(:label_work_package_category_new)),
                                         t(:label_work_package_category_new),
                                         'category[name]',
                                         project_categories_path(locals[:project]),
                                         :class => 'no-decoration-on-hover',
                                         :title => t(:label_work_package_category_new)) if authorize_for('categories', 'new')

      WorkPackageAttribute.new(:category, field)
    end
  end

  def work_package_form_assignable_versions_attribute(form, work_package, locals = {})
    unless work_package.assignable_versions.empty?
      field = form.select(:fixed_version_id,
                          version_options_for_select(work_package.assignable_versions, work_package.fixed_version),
                          :include_blank => true)
      field += prompt_to_remote(icon_wrapper('icon icon-add',t(:label_version_new)),
                             l(:label_version_new),
                             'version[name]',
                             new_project_version_path(locals[:project]),
                             :class => 'no-decoration-on-hover',
                             :title => l(:label_version_new)) if authorize_for('versions', 'new')

      WorkPackageAttribute.new(:fixed_version, field)
    end
  end

  def work_package_form_start_date_attribute(form, work_package, locals = {})
    start_date_field = form.text_field :start_date, :size => 10, :disabled => attrib_disabled?(work_package, 'start_date'), :class => 'short'
    start_date_field += calendar_for("#{form.object_name}_start_date") unless attrib_disabled?(work_package, 'start_date')

    WorkPackageAttribute.new(:start_date, start_date_field)
  end

  def work_package_form_due_date_attribute(form, work_package, locals = {})
    due_date_field = form.text_field :due_date, :size => 10, :disabled => attrib_disabled?(work_package, 'due_date'), :class => 'short'
    due_date_field += calendar_for("#{form.object_name}_due_date") unless attrib_disabled?(work_package, 'due_date')

    WorkPackageAttribute.new(:due_date, due_date_field)
  end

  def work_package_form_estimated_hours_attribute(form, work_package, locals = {})
    field = form.text_field :estimated_hours,
                            :size => 3,
                            :disabled => attrib_disabled?(work_package, 'estimated_hours'),
                            :value => number_with_precision(work_package.estimated_hours, :precision => 2),
                            :class => 'short',
                            :placeholder => TimeEntry.human_attribute_name(:hours)


    WorkPackageAttribute.new(:estimated_hours, field)
  end

  def work_package_form_done_ratio_attribute(form, work_package, locals = {})
    if !attrib_disabled?(work_package, 'done_ratio') && WorkPackage.use_field_for_done_ratio?

      field = form.select(:done_ratio, ((0..10).to_a.collect {|r| ["#{r*10} %", r*10] }))

      WorkPackageAttribute.new(:done_ratio, field)
    end
  end

  def work_package_form_custom_values_attribute(form, work_package, locals = {})
    work_package.custom_field_values.map do |value|
      field = custom_field_tag_with_label :work_package, value

      WorkPackageAttribute.new(:"work_package_#{value.id}", field)
    end
  end

  def work_package_associations_to_address(associated)
    ret = "".html_safe

    ret += content_tag(:p, l(:text_destroy_with_associated), :class => "bold" )

    ret += content_tag(:ul) do
      associated.inject("".html_safe) do |list, associated_class|
        list += content_tag(:li, associated_class.model_name.human, :class => "decorated")

        list
      end
    end

    ret
  end

  private

  def work_package_show_custom_fields(work_package)
    work_package.custom_field_values.each_with_object([]) do |v, a|
      a << work_package_show_table_row(v.custom_field.name,
                                       "custom_field cf_#{v.custom_field_id}",
                                       v.custom_field.name_locale,
                                       v.custom_field.default_value_locale) do
        v.value.blank? ? empty_element_tag : simple_format_without_paragraph(h(show_value(v)))
      end
    end
  end

  def hook_attributes(work_package, attributes = [])
    call_hook(:work_packages_show_attributes,
              work_package: work_package,
              project: @project,
              attributes: attributes)
    attributes
  end

  def work_package_show_main_attributes(work_package)
    [
       work_package_show_status_attribute(work_package),
       work_package_show_priority_attribute(work_package),
       work_package_show_assigned_to_attribute(work_package),
       work_package_show_responsible_attribute(work_package),
       work_package_show_category_attribute(work_package),
       work_package_show_estimated_hours_attribute(work_package),
       work_package_show_start_date_attribute(work_package),
       work_package_show_due_date_attribute(work_package),
       work_package_show_progress_attribute(work_package),
       work_package_show_spent_time_attribute(work_package),
       work_package_show_fixed_version_attribute(work_package)
     ]
  end
end
