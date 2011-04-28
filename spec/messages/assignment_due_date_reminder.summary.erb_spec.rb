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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/messages_helper')

describe 'assignment_due_date_reminder.summary' do
  it "should render" do
    assignment_model(:title => "Quiz 1")
    user_model
    reminder = @assignment.assignment_reminders.create!(:user => @user)
    reminder.assignment.should_not be_nil
    reminder.assignment.context.should_not be_nil
    @object = reminder
    generate_message(:assignment_due_date_reminder, :summary, @object)
  end
end
