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

require 'spec_helper'

require_relative 'shared/allows_concatenation'

describe Allowance::Condition::UserIsAdmin do

  include Spec::Allowance::Condition::AllowsConcatenation

  let(:scope) do
    double('scope', :has_table? => true,
                    :arel_table => users_table)
  end
  let(:klass) { Allowance::Condition::UserIsAdmin }
  let(:instance) { klass.new(scope) }
  let(:users_table) { User.arel_table }
  let(:nil_options) { { admin_pass: false } }
  let(:non_nil_options) { { admin_pass: true } }
  let(:non_nil_arel) { users_table[:admin].eq(true) }

  it_should_behave_like "allows concatenation"
  it_should_behave_like "requires models", User

  describe :to_arel do
    it 'returns an arel statement if noting is passed (admin_pass true by default)' do
      expect(instance.to_arel.to_sql).to eq non_nil_arel.to_sql
    end
  end
end

