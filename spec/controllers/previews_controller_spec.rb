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
  let(:project) { FactoryGirl.create(:project) }
  let(:user)    { FactoryGirl.create(:user,
                                     member_in_project: project)   }

  before { User.stub(:current).and_return user }

  shared_examples_for 'valid preview' do
    before do
      ot = defined?(object_type) ? object_type : nil

      put :update,
          { id: project.id,
            preview: { param: type,
                       values: values,
                       :class =>  ot } }.merge(params)
    end
   
    it { expect(response).to render_template('common/_preview') }

    describe 'preview view' do
      render_views

      it 'renders all texts' do
        texts.each do |text|
          expect(response.body).to have_selector('fieldset.preview', text: text) 
        end
      end
    end
  end

  describe 'work_packages' do
    let(:type) { :work_package }
    let(:values) { [:description, :notes] }
    let(:params) { { work_package: { description: "Preview this description",
                                     notes: "Preview this note" } } }

    it_behaves_like 'valid preview' do
      let(:texts) { ["Preview this description", "Preview this note"] }
    end

    describe 'preview.js' do
      before do
        xhr :put, :update,
            { id: project.id,
              preview: { param: type,
                         values: values } }.merge(params)
      end

      it { expect(response).to render_template('common/_preview',
                                               format: ["html"],
                                               layout: false ) }
    end
  end

  describe 'message' do
    let(:type) { :message }
    let(:values) { [:content] }
    let(:params) { { message: { content: "Preview this content" } } }

    it_behaves_like 'valid preview' do
      let(:texts) { ["Preview this content"] }
    end
  end

  describe 'news' do
    let(:type) { :content }
    let(:values) { [:text] }
    let(:object_type) { WikiContent }
    let(:params) { { content: { text: "Preview this text" } } }

    it_behaves_like 'valid preview' do
      let(:texts) { ["Preview this text"] }
    end
  end
end
