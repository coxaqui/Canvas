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
  module LearningOutcomes
    def create_learning_outcomes(document=nil)
      return nil unless LearningOutcome.active.find_all_by_context_id_and_context_type(@course.id, 'Course').count > 0
      return nil unless @course.learning_outcome_groups.find_by_learning_outcome_group_id(nil)

      root_group = @course.learning_outcome_groups.find_by_learning_outcome_group_id(nil)
      
      if document
        outcomes_file = nil
        rel_path = nil
      else
        outcomes_file = File.new(File.join(@canvas_resource_dir, CCHelper::LEARNING_OUTCOMES), 'w')
        rel_path = File.join(CCHelper::COURSE_SETTINGS_DIR, CCHelper::LEARNING_OUTCOMES)
        document = Builder::XmlMarkup.new(:target=>outcomes_file, :indent=>2)
      end

      document.instruct!
      document.learningOutcomes(
          "xmlns" => CCHelper::CANVAS_NAMESPACE,
          "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
          "xsi:schemaLocation"=> "#{CCHelper::CANVAS_NAMESPACE} #{CCHelper::XSD_URI}"
      ) do |outs_node|
        process_outcome_group_content(outs_node, root_group)
      end

      outcomes_file.close if outcomes_file
      rel_path
    end

    def process_outcome_group(node, group)
      migration_id = CCHelper.create_key(group)
      node.learningOutcomeGroup(:identifier=>migration_id) do |group_node|
        group_node.title group.title unless group.title.blank?
        group_node.description CCHelper.html_content(group.description, @course, @manifest.exporter.user) unless group.description.blank?
        group_node.learningOutcomes do |lo_node|
          process_outcome_group_content(lo_node, group)
        end
      end
    end

    def process_outcome_group_content(node, group)
      group.sorted_content.each do |item|
        if item.is_a? LearningOutcome
          process_learning_outcome(node, item)
        else
          process_outcome_group(node, item)
        end
      end
    end

    def process_learning_outcome(node, item)
      migration_id = CCHelper.create_key(item)
      node.learningOutcome(:identifier=>migration_id) do |out_node|
        out_node.title item.short_description unless item.short_description.blank?
        out_node.description CCHelper.html_content(item.description, @course, @manifest.exporter.user) unless item.description.blank?
        criterion = item.data[:rubric_criterion]
        if criterion
          out_node.points_possible criterion[:points_possible] if criterion[:points_possible]
          out_node.mastery_points criterion[:mastery_points] if criterion[:mastery_points]
          if criterion[:ratings] && criterion[:ratings].length > 0
            out_node.ratings do |ratings_node|
              criterion[:ratings].each do |rating|
                ratings_node.rating do |rating_node|
                  rating_node.description rating[:description]
                  rating_node.points rating[:points]
                end
              end
            end
          end
        end
      end
    end

  end
end