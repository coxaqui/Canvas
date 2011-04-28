#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class CourseSection < ActiveRecord::Base
  include Workflow
  include EnrollmentDateRestrictions
  
  attr_protected :sis_source_id, :sis_batch_id, :course_id, :abstract_course_id,
      :root_account_id, :enrollment_term_id, :sis_cross_listed_section_id, :sis_cross_listed_section_sis_batch_id
  belongs_to :course
  belongs_to :nonxlist_course, :class_name => 'Course'
  belongs_to :root_account, :class_name => 'Account'
  belongs_to :sis_cross_listed_section
  belongs_to :abstract_course
  belongs_to :enrollment_term
  belongs_to :account
  has_many :enrollments, :include => :user, :conditions => ['enrollments.workflow_state != ?', 'deleted'], :dependent => :destroy
  has_many :course_account_associations
  
  adheres_to_policy
  before_validation :infer_defaults
  validates_presence_of :course_id
  
  set_policy do
    given {|user, session| self.cached_course_grants_right?(user, session, :manage_admin_users) }
    set { can :read and can :create and can :update and can :delete }
    
    given {|user, session| self.enrollments.find_by_user_id(user.id) }
    set { can :read }
  end
  
  def section_code
    self.name ||= read_attribute(:section_code)
  end
  
  def infer_defaults
    self.root_account_id ||= (self.course.root_account_id rescue nil) || (self.abstract_course.root_account_id rescue nil) || Account.default.id
    self.assert_course unless self.course
    raise "Course required" unless self.course
    self.root_account_id = self.course.root_account_id || (self.abstract_course.root_account_id rescue nil) || Account.default.id
    self.abstract_course_id ||= self.course.abstract_course_id
    # This is messy, and I hate it.
    # The SIS import actually gives us three names for a section
    #   and I don't know which one is best, or which one to show.
    name_had_changed = name_changed?
    # Here's the current plan:
    # - if it's from the SIS, long_section_code seems like the best bet
    # - otherwise, just use name
    # - use the method display_name to consolidate this logic
    self.name ||= self.course.name if self.default_section
    self.name ||= "#{self.course.name} #{Date.today.to_s}"
    self.section_code ||= self.name
    self.long_section_code ||= self.name
    if name_had_changed
      self.section_code = self.name
      self.long_section_code = self.name
    end
    self.enrollment_term ||= self.root_account.default_enrollment_term
  end
  
  def defined_by_sis?
    !!self.sis_source_id
  end
  
  # NOTE: Don't assume the section_name contains the course name
  # it might include it if the SIS specifies, but you shouldn't 
  # assume that this method on its own will be enough for a user
  # to recognize their course from a list
  # The only place this is used by itself right now is when listing
  # enrollments within a course
  def display_name
    @section_display_name ||= defined_by_sis? ? 
      (self.long_section_code || self.name || self.section_code) : 
      (self.name || self.section_code || self.long_section_code)
  end
  
  def assert_course
    self.course ||= Course.create!(:name => self.name || self.section_code || self.long_section_code, :root_account => self.root_account, :abstract_course => self.abstract_course)
  end
  
  def move_to_course(course)
    return self if self.course == course
    self.course = course
    root_account_change = (self.root_account != course.root_account)
    self.root_account = course.root_account if root_account_change
    self.save!
    user_ids = self.enrollments.map(&:user_id).uniq
    if root_account_change
      self.enrollments.update_all :course_id => course.id, :root_account_id => self.root_account.id
      User.send_later_if_production(:update_account_associations, user_ids)
    else
      self.enrollments.update_all :course_id => course.id
    end
    Enrollment.send_later(:recompute_final_score, user_ids, course.id)
    self
  end
  
  def crosslist_to_course(course)
    return self if self.course == course
    unless self.nonxlist_course
      self.nonxlist_course = self.course 
      self.account = self.course.account
      self.save!
    end
    self.move_to_course(course)
    if (self.nonxlist_course.course_sections.active.count == 0 ||
        (self.nonxlist_course.course_sections.active.count == 1 &&
         self.nonxlist_course.course_sections.active.first.enrollments.count == 0)) &&
       self.nonxlist_course.workflow_state == "created"
      self.nonxlist_course.workflow_state = "deleted"
      self.nonxlist_course.save!
    end
  end
  
  def uncrosslist
    return unless self.nonxlist_course
    if self.nonxlist_course.workflow_state == "deleted"
      self.nonxlist_course.workflow_state = "created"
      self.nonxlist_course.save!
    end
    self.move_to_course(self.nonxlist_course)
    self.nonxlist_course = nil
    self.account = nil
    self.save!
  end
  
  def crosslisted?
    return !!self.nonxlist_course
  end
  
  def destroy_course_if_no_more_sections
    if self.deleted? && self.course.course_sections.active.empty?
      self.course.destroy
    end
  end
  
  def deletable?
    self.enrollments.count == 0
  end
  
  def enroll_user(user, type, state='invited')
    self.course.enroll_user(user, type, :enrollment_state => state, :section => self)
  end
  
  workflow do
    state :active
    state :deleted
  end
  
  alias_method :destroy!, :destroy
  def destroy
    self.workflow_state = 'deleted'
    save!
  end
  
  named_scope :active, lambda {
    { :conditions => ['course_sections.workflow_state != ?', 'deleted'] }
  }
  
  named_scope :sis_sections, lambda{|account, *source_ids|
    {:conditions => {:root_account_id => account.id, :sis_source_id => source_ids}, :order => :sis_source_id}
  }
end
