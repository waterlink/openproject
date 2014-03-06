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
require File.expand_path('../../test_helper', __FILE__)

class AttachmentTest < ActiveSupport::TestCase
  fixtures :all

  def test_create
    a = Attachment.new(:container => WorkPackage.find(1),
                       :file => uploaded_test_file("testfile.txt", "text/plain"),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.txt', a.filename
    assert_equal 59, a.filesize
    assert_equal 'text/plain', a.content_type
    assert_equal 0, a.downloads
    assert_equal '1478adae0d4eb06d35897518540e25d6', a.digest
    assert File.exist?(a.diskfile)
  end

  def test_create_should_auto_assign_content_type
    a = Attachment.new(:container => WorkPackage.find(1),
                       :file => uploaded_test_file("testfile.txt", ""),
                       :author => User.find(1))
    assert a.save
    assert_equal 'text/plain', a.content_type
  end

  def test_identical_attachments_at_the_same_time_should_not_overwrite
    a1 = Attachment.create!(:container => WorkPackage.find(1),
                            :file => uploaded_test_file("testfile.txt", ""),
                            :author => User.find(1))
    a2 = Attachment.create!(:container => WorkPackage.find(1),
                            :file => uploaded_test_file("testfile.txt", ""),
                            :author => User.find(1))
    assert a1.disk_filename != a2.disk_filename
  end

  def test_diskfilename
    assert Attachment.disk_filename("test_file.txt") =~ /\A\d{12}_test_file.txt\z/
    assert_equal 'test_file.txt', Attachment.disk_filename("test_file.txt")[13..-1]
    assert_equal '770c509475505f37c2b8fb6030434d6b.txt', Attachment.disk_filename("test_accentué.txt")[13..-1]
    assert_equal 'f8139524ebb8f32e51976982cd20a85d', Attachment.disk_filename("test_accentué")[13..-1]
    assert_equal 'cbb5b0f30978ba03731d61f9f6d10011', Attachment.disk_filename("test_accentué.ça")[13..-1]
  end

  def test_dynamic_storage_path
    # store the current storage path in order to reset it after the test
    original_storage_path = Attachment.storage_path

    attachment = Attachment.new
    # we don't care about the individual filename
    attachment.stub(:disk_filename).and_return 'filename'

    # storage path set to a static string
    Attachment.storage_path = 'static'
    assert_equal 'static', Attachment.storage_path
    assert_equal 'static/filename', attachment.diskfile

    something_dynamic = 'public'

    # storage path set to a lambda containing something dynamic
    # should get evaluated on each access
    Attachment.storage_path = lambda { something_dynamic }

    assert_equal 'public', Attachment.storage_path
    assert_equal 'public/filename', attachment.diskfile

    something_dynamic = 'secret'

    assert_equal 'secret', Attachment.storage_path
    assert_equal 'secret/filename', attachment.diskfile

  ensure
    Attachment.storage_path = original_storage_path
  end

  context "Attachmnet#attach_files" do
    should "add unsaved files to the object as unsaved attachments" do
      # Max size of 0 to force Attachment creation failures
      with_settings(:attachment_max_size => 0) do
        @issue = WorkPackage.find(1)
        response = Attachment.attach_files(@issue, {
                                             '1' => {'file' => mock_file, 'description' => 'test'},
                                             '2' => {'file' => mock_file, 'description' => 'test'}
                                           })

        assert response[:unsaved].present?
        assert_equal 2, response[:unsaved].length
        assert response[:unsaved].first.new_record?
        assert response[:unsaved].second.new_record?
        assert_equal response[:unsaved], @issue.unsaved_attachments
      end
    end
  end
end
