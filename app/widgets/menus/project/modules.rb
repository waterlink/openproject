module Menus::Project
  module Modules
    Redmine::MenuManager.map :'project/modules' do |menu|
      menu.push :overview,
                { :controller => '/projects',
                  :action => 'show',
                  :id => :project },
                :caption => :label_overview

      menu.push :activity,
                { :controller => '/activities',
                  :action => 'index',
                  :project_id => :project },
                :caption => :label_activity

      menu.push :roadmap,
                { :controller => '/versions',
                  :action => 'index',
                  :project_id => :project },
                :caption => :label_roadmap,
                :if => Proc.new { |locals| locals[:project].shared_versions.any? }

      menu.push :issues,
                { :controller => '/issues',
                  :action => 'index',
                  :project_id => :project },
                :caption => :label_issue_plural

      menu.push :new_issue,
                { :controller => '/work_packages',
                  :action => 'new',
                  :type => 'Issue',
                  :project_id => :project },
                :caption => :label_issue_new,
                :parent => :issues,
                :html => { :accesskey => Redmine::AccessKeys.key_for(:new_issue) }

      menu.push :view_all_issues,
                { :controller => '/issues',
                  :action => 'all',
                  :project_id => :project },
                :caption => :label_issue_view_all,
                :parent => :issues

      menu.push :summary_field,
                { :controller => '/issues/reports',
                  :action => 'report',
                  :project_id => :project },
                :caption => :label_workflow_summary,
                :parent => :issues

      menu.push :calendar,
                { :controller => '/calendars',
                  :action => 'show',
                  :project_id => :project },
                :caption => :label_calendar

      menu.push :news,
                { :controller => '/news',
                  :action => 'index',
                  :project_id => :project },
                :caption => :label_news_plural

      menu.push :new_news,
                { :controller => '/news',
                  :action => 'new',
                  :project_id => :project },
                :caption => :label_news_new,
                :parent => :news,
                :if => Proc.new { |locals| User.current.allowed_to?(:manage_news, locals[:project]) }

      menu.push :documents,
                { :controller => '/documents',
                  :action => 'index',
                  :project_id => :project },
                :caption => :label_document_plural

      menu.push :boards,
                { :controller => '/boards',
                  :action => 'index',
                  :project_id => :project },
                :if => Proc.new { |locals| locals[:project].boards.any? },
                :caption => :label_board_plural

      menu.push :files,
                { :controller => '/files',
                  :action => 'index',
                  :project_id => :project },
                :caption => :label_file_plural

      menu.push :repository,
                { :controller => '/repositories',
                  :action => 'show',
                  :project_id => :project },
                :if => Proc.new { |locals| locals[:project].repository && !locals[:project].repository.new_record? }

      # Project menu entries
      # * Timelines
      # ** Reports
      # ** Associations a.k.a. Dependencies
      # ** Reportings
      # ** Planning Elemnts
      # ** Papierkorb

      {}.tap do |options|

        menu.push :timelines_timelines,
                  { :controller => '/timelines/timelines_timelines',
                    :action => 'index',
                    :project_id => :project },
                  :caption => :'timelines.project_menu.timelines'

        options.merge(:parent => :timelines_timelines).tap do |rep_options|

          menu.push :timelines_reports,
                    { :controller => '/timelines/timelines_timelines',
                      :action => 'index',
                      :project_id => :project },
                    rep_options.merge(:caption => :'timelines.project_menu.reports')

          menu.push :timelines_project_associations,
                    { :controller => '/timelines/timelines_project_associations',
                      :action => 'index',
                      :project_id => :project },
                    rep_options.merge(:caption => :'timelines.project_menu.project_associations',
                                      :if => Proc.new { |locals| locals[:project].timelines_project_type.try :allows_association })

          menu.push :timelines_reportings,
                    { :controller => '/timelines/timelines_reportings',
                      :action => 'index',
                      :project_id => :project },
                    rep_options.merge(:caption => :'timelines.project_menu.reportings')

          menu.push :timelines_planning_elements,
                    { :controller => '/timelines/timelines_planning_elements',
                      :action => 'all',
                      :project_id => :project },
                    rep_options.merge(:caption => :'timelines.project_menu.planning_elements')

          menu.push :timelines_recycle_bin,
                    { :controller => '/timelines/timelines_planning_elements',
                      :action => 'recycle_bin',
                      :project_id => :project },
                    rep_options.merge(:caption => :'timelines.project_menu.recycle_bin')

        end
      end

      menu.push :settings,
                { :controller => '/projects',
                  :action => 'settings',
                  :project_id => :project },
                :caption => :label_project_settings,
                :last => true
    end
  end
end
