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

class UserMailer < ActionMailer::Base
  helper :application,  # for textilizable
         :work_packages, # for css classes
         :custom_fields # for show_value

  # wrap in a lambda to allow changing at run-time
  default :from => Proc.new { Setting.mail_from }

  def test_mail(user)
    @welcome_url = url_for(:controller => '/welcome')

    headers['X-OpenProject-Type'] = 'Test'

    with_locale_for(user) do
      mail :to => "#{user.name} <#{user.mail}>", :subject => 'OpenProject Test'
    end
  end

  def work_package_added(user, issue)
    @issue = issue

    open_project_headers 'Project'        => @issue.project.identifier,
                         'Issue-Id'       => @issue.id,
                         'Issue-Author'   => @issue.author.login,
                         'Type'           => 'WorkPackage'
    open_project_headers 'Issue-Assignee' => @issue.assigned_to.login if @issue.assigned_to

    message_id @issue, user

    with_locale_for(user) do
      subject = "[#{@issue.project.name} - #{ @issue.to_s }]"
      subject << " (#{@issue.status.name})" if @issue.status
      subject << " #{@issue.subject}"
      mail :to => user.mail, :subject => subject
    end
  end

  def work_package_updated(user, journal, author=User.current)
    # Delayed job do not preserve the closure of the job that is delayed. Thus,
    # if the method is called within a delayed job, it does contain the default
    # user (anonymous) and not the original user that called the method.
    #
    # The mail interceptor 'RemoveSelfNotificationsInterceptor' assumes the
    # orginal user to be available. Otherwise, it cannot fulfill its duty.
    User.current = author if User.current != author

    @journal = journal
    @issue   = journal.journable.reload

    open_project_headers 'Project'        => @issue.project.identifier,
                         'Issue-Id'       => @issue.id,
                         'Issue-Author'   => @issue.author.login,
                         'Type'           => 'WorkPackage'
    open_project_headers 'Issue-Assignee' => @issue.assigned_to.login if @issue.assigned_to

    message_id @journal, user
    references @issue, user

    with_locale_for(user) do
      subject =  "[#{@issue.project.name} - #{@issue.type.name} ##{@issue.id}] "
      subject << "(#{@issue.status.name}) " if @journal.details[:status_id]
      subject << @issue.subject

      mail :to => user.mail, :subject => subject
    end
  end

  def password_lost(token)
    return unless token.user # token's can have no user

    @token = token
    @reset_password_url = url_for(:controller => '/account',
                                  :action     => :lost_password,
                                  :token      => @token.value)

    open_project_headers 'Type' => 'Account'

    user = @token.user
    with_locale_for(user) do
      subject = t(:mail_subject_lost_password, :value => Setting.app_title)
      mail :to => user.mail, :subject => subject
    end
  end

  def news_added(user, news)
    @news = news

    open_project_headers 'Type'    => 'News'
    open_project_headers 'Project' => @news.project.identifier if @news.project

    message_id @news, user

    with_locale_for(user) do
      subject = "#{News.model_name.human}: #{@news.title}"
      subject = "[#{@news.project.name}] #{subject}" if @news.project
      mail :to => user.mail, :subject => subject
    end
  end

  def user_signed_up(token)
    return unless token.user

    @token = token
    @activation_url = url_for(:controller => '/account',
                              :action     => :activate,
                              :token      => @token.value)

    open_project_headers 'Type' => 'Account'

    user = token.user
    with_locale_for(user) do
      subject = t(:mail_subject_register, :value => Setting.app_title)
      mail :to => user.mail, :subject => subject
    end
  end

  def news_comment_added(user, comment)
    @comment = comment
    @news    = @comment.commented

    open_project_headers 'Project' => @news.project.identifier if @news.project

    message_id @comment, user
    references @news, user

    with_locale_for(user) do
      subject = "#{News.model_name.human}: #{@news.title}"
      subject = "Re: [#{@news.project.name}] #{subject}" if @news.project
      mail :to => user.mail, :subject => subject
    end
  end

  def wiki_content_added(user, wiki_content)
    @wiki_content = wiki_content

    open_project_headers 'Project'      => @wiki_content.project.identifier,
                         'Wiki-Page-Id' => @wiki_content.page.id,
                         'Type'         => 'Wiki'

    message_id @wiki_content, user

    with_locale_for(user) do
      subject = "[#{@wiki_content.project.name}] #{t(:mail_subject_wiki_content_added, :id => @wiki_content.page.pretty_title)}"
      mail :to => user.mail, :subject => subject
    end
  end

  def wiki_content_updated(user, wiki_content)
    @wiki_content  = wiki_content
    @wiki_diff_url = url_for(:controller => '/wiki',
                             :action     => :diff,
                             :project_id => wiki_content.project,
                             :id         => wiki_content.page.title,
                             :version    => wiki_content.version)

    open_project_headers 'Project'      => @wiki_content.project.identifier,
                         'Wiki-Page-Id' => @wiki_content.page.id,
                         'Type'         => 'Wiki'

    message_id @wiki_content, user

    with_locale_for(user) do
      subject = "[#{@wiki_content.project.name}] #{t(:mail_subject_wiki_content_updated, :id => @wiki_content.page.pretty_title)}"
      mail :to => user.mail, :subject => subject
    end
  end

  def message_posted(user, message)
    @message     = message
    @message_url = topic_url(@message.root, :r => @message.id, :anchor => "message-#{@message.id}")

    open_project_headers 'Project'      => @message.project.identifier,
                         'Wiki-Page-Id' => @message.parent_id || @message.id,
                         'Type'         => 'Forum'

    message_id @message, user
    references @message.parent, user if @message.parent

    with_locale_for(user) do
      subject = "[#{@message.board.project.name} - #{@message.board.name} - msg#{@message.root.id}] #{@message.subject}"
      mail :to => user.mail, :subject => subject
    end
  end

  def account_activated(user)
    @user = user

    open_project_headers 'Type' => 'Account'

    with_locale_for(user) do
      subject = t(:mail_subject_register, :value => Setting.app_title)
      mail :to => user.mail, :subject => subject
    end
  end

  def account_information(user, password)
    @user     = user
    @password = password

    open_project_headers 'Type' => 'Account'

    with_locale_for(user) do
      subject = t(:mail_subject_register, :value => Setting.app_title)
      mail :to => user.mail, :subject => subject
    end
  end

  def account_activation_requested(admin, user)
    @user           = user
    @activation_url = url_for(:controller => '/users',
                              :action     => :index,
                              :status     => User::STATUSES[:registered],
                              :sort       => 'created_at:desc')

    open_project_headers 'Type' => 'Account'

    with_locale_for(admin) do
      subject = t(:mail_subject_account_activation_request, :value => Setting.app_title)
      mail :to => admin.mail, :subject => subject
    end
  end

  def reminder_mail(user, issues, days)
    @issues = issues
    @days   = days

    @assigned_issues_url = url_for(:controller     => :work_packages,
                                   :action         => :index,
                                   :set_filter     => 1,
                                   :assigned_to_id => user.id,
                                   :sort           => 'due_date:asc')

    open_project_headers 'Type' => 'Issue'

    with_locale_for(user) do
      subject = t(:mail_subject_reminder, :count => @issues.size, :days => @days)
      mail :to => user.mail, :subject => subject
    end
  end

  # Activates/desactivates email deliveries during +block+
  def self.with_deliveries(temporary_state = true, &block)
    old_state = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = temporary_state
    yield
  ensure
    ActionMailer::Base.perform_deliveries = old_state
  end

  def self.generate_message_id(object, user)
    # id + timestamp should reduce the odds of a collision
    # as far as we don't send multiple emails for the same object
    journable = (object.is_a? Journal) ? object.journable : object

    timestamp = self.mail_timestamp(object)
    hash = "openproject"\
           "."\
           "#{journable.class.name.demodulize.underscore}"\
           "-"\
           "#{user.id}"\
           "-"\
           "#{journable.id}"\
           "."\
           "#{timestamp.strftime("%Y%m%d%H%M%S")}"
    host = Setting.mail_from.to_s.gsub(%r{\A.*@}, '')
    host = "#{::Socket.gethostname}.openproject" if host.empty?
    "#{hash}@#{host}"
  end

protected

  # Option 1 to take out an html part: Leave the part out
  # while creating the mail. Since rails internally uses three
  # different ways to create a mail (passing a block, giving parameters
  # with optional template, or passing the body directly), we would have
  # to replicate a lot of rails code to modify all three ways.
  # Therefore, we use option 2: modiyfing the set of parts rails
  # created internally as a result of the above ways, as this is
  # much shorter.
  # On the downside, this might break if ActionMailer changes the signature
  # or semantics of the following funtion. However, we should at least
  # notice this as there are tests for checking the no-html setting.
  def collect_responses_and_parts_order(headers)
    responses, parts_order = super(headers)
    if Setting.plain_text_mail?
      responses.delete_if { |response| response[:content_type]=="text/html" }
      parts_order.delete_if { |part| part == "text/html"} unless parts_order.nil?
    end
    [responses, parts_order]
  end

private

  def self.mail_timestamp(object)
    if object.respond_to? :created_at
      timestamp = object.send(object.respond_to?(:created_at) ? :created_at : :updated_at)
    else
      timestamp = object.send(object.respond_to?(:created_on) ? :created_on : :updated_on)
    end
  end

  def self.host
    if OpenProject::Configuration.rails_relative_url_root.blank?
      Setting.host_name
    else
      Setting.host_name.to_s.gsub(%r{\/.*\z}, '')
    end
  end

  def self.protocol
    Setting.protocol
  end

  def self.default_url_options
    options = super.merge :host => host, :protocol => protocol
    unless OpenProject::Configuration.rails_relative_url_root.blank?
      options[:script_name] = OpenProject::Configuration.rails_relative_url_root
    end

    options
  end

  def message_id(object, user)
    headers['Message-ID'] = "<#{self.class.generate_message_id(object, user)}>"
  end

  def references(object, user)
    headers['References'] = "<#{self.class.generate_message_id(object, user)}>"
  end

  def with_locale_for(user, &block)
    locale = user.language.presence || Setting.default_language.presence || I18n.default_locale
    I18n.with_locale(locale, &block)
  end

  # Prepends given fields with 'X-OpenProject-' to save some duplication
  def open_project_headers(hash)
    hash.each { |key, value| headers["X-OpenProject-#{key}"] = value.to_s }
  end
end

##
# Interceptors
#
# These are registered in config/initializers/register_mail_interceptors.rb
#
# Unfortunately, this results in changes on the interceptor classes during development mode
# not being reflected until a server restart.

class DefaultHeadersInterceptor
  def self.delivering_email(mail)
    mail.headers(default_headers)
  end

  def self.default_headers
    {
      'X-Mailer'           => 'OpenProject',
      'X-OpenProject-Host' => Setting.host_name,
      'X-OpenProject-Site' => Setting.app_title,
      'Precedence'         => 'bulk',
      'Auto-Submitted'     => 'auto-generated'
    }
  end
end

class RemoveSelfNotificationsInterceptor
  def self.delivering_email(mail)
    user_mail = User.current.mail
    # This may be called within a delayed job. Within a delayed job user
    # preferences may not be loaded. Furthermore, some users don't have
    # persisted preferences. Thus, we only load user preferences if preferences
    # are available.
    user_pref = User.current.pref.reload if User.current.pref.persisted?

    if user_pref && user_pref[:no_self_notified]
      mail.to = mail.to.reject {|address| address == user_mail} if mail.to.present?
    end
  end
end

class DoNotSendMailsWithoutReceiverInterceptor
  def self.delivering_email(mail)
    receivers = [mail.to, mail.cc, mail.bcc]
    # the above fields might be empty arrays (if entries have been removed
    # by another interceptor) or nil, therefore checking for blank?
    mail.perform_deliveries = false if receivers.all?(&:blank?)
  end
end


# helper object for `rake redmine:send_reminders`

class DueIssuesReminder
  def initialize(days = nil, project_id = nil, type_id = nil, user_ids = [])
    @days     = days ? days.to_i : 7
    @project  = Project.find_by_id(project_id)
    @type  = Type.find_by_id(type_id)
    @user_ids = user_ids
  end

  def remind_users
    s = ARCondition.new ["#{Status.table_name}.is_closed = ? AND #{WorkPackage.table_name}.due_date <= ?", false, @days.days.from_now.to_date]
    s << "#{WorkPackage.table_name}.assigned_to_id IS NOT NULL"
    s << ["#{WorkPackage.table_name}.assigned_to_id IN (?)", @user_ids] if @user_ids.any?
    s << "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}"
    s << "#{WorkPackage.table_name}.project_id = #{@project.id}" if @project
    s << "#{WorkPackage.table_name}.type_id = #{@type.id}" if @type

    issues_by_assignee = WorkPackage.find(:all, :include => [:status, :assigned_to, :project, :type],
                                          :conditions => s.conditions
                                   ).group_by(&:assigned_to)
    issues_by_assignee.each do |assignee, issues|
      UserMailer.reminder_mail(assignee, issues, @days).deliver if assignee && assignee.active?
    end
  end
end
