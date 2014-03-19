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

describe NewsController do
  render_views

  include BecomeMember

  let(:user)    { FactoryGirl.create(:admin)   }
  let(:project) { FactoryGirl.create(:project) }
  let(:news)    { FactoryGirl.create(:news)    }

  before do
    User.stub(:current).and_return user
  end

  describe "#index" do
    it "renders index" do
      get :index

      expect(response).to be_success
      expect(response).to render_template 'index'

      expect(assigns(:project)).to be_nil
      expect(assigns(:newss)).to_not be_nil
    end

    it "renders index with project" do
      get :index, project_id: project.id

      expect(response).to be_success
      expect(response).to render_template 'index'
      expect(assigns(:newss)).to_not be_nil
    end
  end

  describe "#show" do
    it "renders show" do
      get :show, id: news.id

      expect(response).to be_success
      expect(response).to render_template 'show'

      expect(response.body).to have_selector('h2', text: news.title)
    end

    it "renders show with slug" do
      get :show, id: "#{news.id}-some-news-title"

      expect(response).to be_success
      expect(response).to render_template 'show'

      expect(response.body).to have_selector('h2', text: news.title)
    end

    it "renders error if news item is not found" do
      get :show, id: -1

      expect(response).to be_not_found
    end
  end

  describe "#new" do
    it "renders new" do
      get :new, project_id: project.id

      expect(response).to be_success
      expect(response).to render_template 'new'
    end
  end

  describe "#create" do
    it "persists a news item and delivers email notifications" do
      ActionMailer::Base.deliveries.clear

      become_member_with_permissions(project, user)

      with_settings notified_events: ['news_added'] do
        post :create, project_id: project.id, news: { title: 'NewsControllerTest',
                                                description: 'This is the description',
                                                    summary: '' }
        expect(response).to redirect_to project_news_index_path(project)

        news = News.find_by_title!('NewsControllerTest')
        expect(news).to_not be_nil
        expect(news.description).to eq 'This is the description'
        expect(news.author).to eq user
        expect(news.project).to eq project

        expect(ActionMailer::Base.deliveries).to have(1).element
      end
    end

    it "doesn't persist if validations fail" do
      post :create, project_id: project.id, news: { title: '',
                                              description: 'This is the description',
                                                  summary: '' }

      expect(response).to be_success
      expect(response).to render_template 'new'
      expect(assigns(:news)).to_not be_nil
      expect(assigns(:news)).to be_new_record

      expect(response.body).to have_selector('div#errorExplanation', text: /1 error/)
    end
  end

  describe "#edit" do
    it 'renders edit' do
      get :edit, id: news.id
      expect(response).to be_success
      expect(response).to render_template 'edit'
    end
  end

  describe "#update" do
    it 'updates the news element' do
      put :update, id: news.id, news: { description: 'Description changed by test_post_edit' }

      expect(response).to redirect_to news_path(news)

      news.reload
      expect(news.description).to eq 'Description changed by test_post_edit'
    end
  end

  describe "#destroy" do
    it "deletes the news element and redirects to the news overview page" do
      delete :destroy, id: news.id

      expect(response).to redirect_to project_news_index_path(news.project)
      expect { news.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  describe 'preview' do
    let(:description) { "News description" }

    it_behaves_like 'valid preview' do
      let(:preview_texts) { [description] }
      let(:preview_params) { { news: { description: description } } }
    end
  end
end
