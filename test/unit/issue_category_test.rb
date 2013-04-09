#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
#
# Copyright (C) 2012-2013 the OpenProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See doc/COPYRIGHT.rdoc for more details.
#++
require File.expand_path('../../test_helper', __FILE__)

class IssueCategoryTest < ActiveSupport::TestCase
  def setup
    super
    @project = FactoryGirl.create :project
    @category = FactoryGirl.create :issue_category, :project => @project
    @issue = FactoryGirl.create :issue, :category => @category
    assert_equal @issue.category, @category
    assert_equal @category.issues, [@issue]
  end

  def test_create
    (new_cat = IssueCategory.new).force_attributes = {:project_id => @project.id, :name => 'New category'}
    assert new_cat.valid?
    assert new_cat.save
    assert_equal 'New category', new_cat.name
  end

  def test_create_with_group_assignment
    group = FactoryGirl.create :group
    role = FactoryGirl.create :role
    (Member.new.tap do |m|
      m.force_attributes = { :principal => group, :project => @project, :role_ids => [role.id] }
    end).save!
    (new_cat = IssueCategory.new).force_attributes = {:project_id => @project.id, :name => 'Group assignment', :assigned_to_id => group.id}
    assert new_cat.valid?
    assert new_cat.save
    assert_kind_of Group, new_cat.assigned_to
    assert_equal group, new_cat.assigned_to
  end

  # Make sure the category was nullified on the issue
  def test_destroy
    @category.destroy
    assert_nil @issue.reload.category
  end

  # both issue categories must be in the same project
  def test_destroy_with_reassign
    reassign_to = FactoryGirl.create :issue_category, :project => @project
    @category.destroy(reassign_to)
    # Make sure the issue was reassigned
    assert_equal reassign_to, @issue.reload.category
  end
end
