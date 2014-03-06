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

require "digest/md5"

class Attachment < ActiveRecord::Base
  belongs_to :container, :polymorphic => true

  belongs_to :author, :class_name => "User", :foreign_key => "author_id"

  attr_protected :author_id

  validates_presence_of :container, :filename, :author
  validates_length_of :filename, :maximum => 255
  validates_length_of :disk_filename, :maximum => 255

  validate :filesize_below_allowed_maximum

  before_save :copy_file_to_destination
  after_destroy :delete_file_on_disk

  acts_as_journalized
  acts_as_event title: :filename,
                url: (Proc.new do |o|
                        { :controller => '/attachments', :action => 'download', :id => o.id, :filename => o.filename }
                      end)

  cattr_accessor :storage_path

  self.storage_path = OpenProject::Configuration['attachments_storage_path'] || Rails.root.join('files').to_s

  def filesize_below_allowed_maximum
    if self.filesize > Setting.attachment_max_size.to_i.kilobytes
      errors.add(:base, :too_long, :count => Setting.attachment_max_size.to_i.kilobytes)
    end
  end

  def file=(incoming_file)
    unless incoming_file.nil?
      @temp_file = incoming_file
      if @temp_file.size > 0
        # Incomming_file might be a String if you parse an incomming mail having an attachment
        # It is a Mail::Part.decoded String then, which doesn't have the usual file methods.
        if @temp_file.respond_to?(:original_filename)
          self.filename = @temp_file.original_filename
          self.filename.force_encoding("UTF-8") if filename.respond_to?(:force_encoding)
        end
        if @temp_file.respond_to?(:content_type)
          self.content_type = @temp_file.content_type.to_s.chomp
        end
        if content_type.blank? && filename.present?
          self.content_type = Redmine::MimeType.of(filename)
        end
        self.filesize = @temp_file.size
      end
    end
  end

  def filename=(arg)
    write_attribute :filename, sanitize_filename(arg.to_s)
    if new_record? && disk_filename.blank?
      self.disk_filename = Attachment.disk_filename(filename)
    end
    filename
  end

  def file
    nil
  end

  # Copies the temporary file to its final location
  # and computes its MD5 hash
  def copy_file_to_destination
    if @temp_file && (@temp_file.size > 0)
      logger.info("Saving attachment '#{self.diskfile}' (#{@temp_file.size} bytes)")
      md5 = Digest::MD5.new
      File.open(diskfile, "wb") do |f|
        # @temp_file might be a String if you parse an incomming mail having an attachment
        # It is a Mail::Part.decoded String then, which doesn't have the usual file methods.
        if @temp_file.is_a? String
          f.write(@temp_file)
          md5.update(@temp_file)
        else
          buffer = ""
          while (buffer = @temp_file.read(8192))
            f.write(buffer)
            md5.update(buffer)
          end
        end
      end
      self.digest = md5.hexdigest
    end
    # Don't save the content type if it's longer than the authorized length
    if self.content_type && self.content_type.length > 255
      self.content_type = nil
    end
  end

  # Deletes file on the disk
  def delete_file_on_disk
    File.delete(diskfile) if filename.present? && File.exist?(diskfile)
  end

  # Returns file's location on disk
  def diskfile
    File.join(self.class.storage_path, disk_filename)
  end

  def increment_download
    increment!(:downloads)
  end

  def project
    #not every container has a project (example: LandingPage)
    container.respond_to?(:project)? container.project : nil
  end

  def visible?(user=User.current)
    container.attachments_visible?(user)
  end

  def deletable?(user=User.current)
    container.attachments_deletable?(user)
  end

  def image?
    self.filename =~ /\.(jpe?g|gif|png)\z/i
  end

  def is_text?
    Redmine::MimeType.is_type?('text', filename)
  end

  def is_diff?
    self.filename =~ /\.(patch|diff)\z/i
  end

  # Returns true if the file is readable
  def readable?
    File.readable?(diskfile)
  end

  # Bulk attaches a set of files to an object
  #
  # Returns a Hash of the results:
  # :files => array of the attached files
  # :unsaved => array of the files that could not be attached
  def self.attach_files(obj, attachments)
    attached = []
    if attachments && attachments.is_a?(Hash)
      attachments.each_value do |attachment|
        file = attachment['file']
        next unless file && file.size > 0
        a = Attachment.create(:container => obj,
                              :file => file,
                              :description => attachment['description'].to_s.strip,
                              :author => User.current)

        if a.new_record?
          obj.unsaved_attachments ||= []
          obj.unsaved_attachments << a
        else
          attached << a
        end
      end
    end
    {:files => attached, :unsaved => obj.unsaved_attachments}
  end

private

  def sanitize_filename(value)
    # get only the filename, not the whole path
    just_filename = value.gsub(/\A.*(\\|\/)/, '')
    # NOTE: File.basename doesn't work right with Windows paths on Unix
    # INCORRECT: just_filename = File.basename(value.gsub('\\\\', '/'))

    # Finally, replace all non alphanumeric, hyphens or periods with underscore
    @filename = just_filename.gsub(/[^\w\.\-]/,'_')
  end

  # Returns an ASCII or hashed filename
  def self.disk_filename(filename)
    timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
    ascii = ''
    if filename =~ %r{\A[a-zA-Z0-9_\.\-]*\z}
      ascii = filename
    else
      ascii = Digest::MD5.hexdigest(filename)
      # keep the extension if any
      ascii << $1 if filename =~ %r{(\.[a-zA-Z0-9]+)\z}
    end
    while File.exist?(File.join(storage_path, "#{timestamp}_#{ascii}"))
      timestamp.succ!
    end
    "#{timestamp}_#{ascii}"
  end
end
