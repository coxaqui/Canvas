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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe CourseSection, "moving to new course" do
  
  it "should transfer enrollments to the new root account" do
    account1 = Account.create!(:name => "1")
    account2 = Account.create!(:name => "2")
    course1 = account1.courses.create!
    course2 = account2.courses.create!
    course3 = account2.courses.create!
    cs = course1.course_sections.create!
    u = User.create!
    u.register!
    e = course1.enroll_user(u, 'StudentEnrollment', :section => cs)
    e.workflow_state = 'active'
    e.save!
    course1.reload
    
    course1.course_sections.find_by_id(cs.id).should_not be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    e.root_account.should eql(account1)
    e.course.should eql(course1)
    
    cs.move_to_course(course2)
    course1.reload
    course2.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should be_nil
    course2.course_sections.find_by_id(cs.id).should_not be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    e.root_account.should eql(account2)
    e.course.should eql(course2)
    
    cs.move_to_course(course3)
    course1.reload
    course2.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should_not be_nil
    e.root_account.should eql(account2)
    e.course.should eql(course3)
    
    cs.move_to_course(course1)
    course1.reload
    course2.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should_not be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    e.root_account.should eql(account1)
    e.course.should eql(course1)

    cs.move_to_course(course1)
    course1.reload
    course2.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should_not be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    e.root_account.should eql(account1)
    e.course.should eql(course1)
  end
  
  it "should crosslist and uncrosslist" do
    account1 = Account.create!(:name => "1")
    account2 = Account.create!(:name => "2")
    account3 = Account.create!(:name => "3")
    course1 = account1.courses.create!
    course2 = account2.courses.create!
    course3 = account3.courses.create!
    course2.assert_section
    course3.assert_section
    cs = course1.course_sections.create!
    u = User.create!
    u.register!
    e = course2.enroll_user(u, 'StudentEnrollment')
    e.workflow_state = 'active'
    e.save!
    e = course1.enroll_user(u, 'StudentEnrollment', :section => cs)
    e.workflow_state = 'active'
    e.save!
    course1.reload
    course2.reload
    course3.workflow_state = 'active'
    course3.save
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should_not be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    cs.account.should be_nil
    cs.nonxlist_course.should be_nil
    e.root_account.should eql(account1)
    cs.crosslisted?.should be_false
    course1.workflow_state.should == 'created'
    course2.workflow_state.should == 'created'
    course3.workflow_state.should == 'created'
    
    cs.crosslist_to_course(course2)
    course1.reload
    course2.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should be_nil
    course2.course_sections.find_by_id(cs.id).should_not be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    cs.account.should eql(account1)
    cs.nonxlist_course.should eql(course1)
    e.root_account.should eql(account2)
    cs.crosslisted?.should be_true
    course1.workflow_state.should == 'deleted'
    course2.workflow_state.should == 'created'
    course3.workflow_state.should == 'created'
      
    cs.crosslist_to_course(course3)
    course1.reload
    course2.reload
    course3.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should_not be_nil
    cs.account.should eql(account1)
    cs.nonxlist_course.should eql(course1)
    e.root_account.should eql(account3)
    cs.crosslisted?.should be_true
    course1.workflow_state.should == 'deleted'
    course2.workflow_state.should == 'created'
    course3.workflow_state.should == 'created'
      
    cs.uncrosslist
    course1.reload
    course2.reload
    course3.reload
    cs.reload
    e.reload
    
    course1.course_sections.find_by_id(cs.id).should_not be_nil
    course2.course_sections.find_by_id(cs.id).should be_nil
    course3.course_sections.find_by_id(cs.id).should be_nil
    cs.account.should be_nil
    cs.nonxlist_course.should be_nil
    e.root_account.should eql(account1)
    cs.crosslisted?.should be_false
    course1.workflow_state.should == 'created'
    course2.workflow_state.should == 'created'
    course3.workflow_state.should == 'created'
  end
  
end
