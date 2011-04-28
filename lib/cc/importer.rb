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

module CC
  module Importer
    include CC::CCHelper
    include Canvas::XMLHelper
  end
end

require_dependency 'cc/importer/learning_outcomes_converter'
require_dependency 'cc/importer/wiki_converter'
require_dependency 'cc/importer/assignment_converter'
require_dependency 'cc/importer/topic_converter'
require_dependency 'cc/importer/webcontent_converter'
require_dependency 'cc/importer/course_settings'
require_dependency 'cc/importer/cc_converter'
