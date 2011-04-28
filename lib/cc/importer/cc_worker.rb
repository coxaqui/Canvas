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
module Canvas
  module MigrationWorker
    class CCWorker < Struct.new(:migration_id)

      def perform
        cm = ContentMigration.find migration_id
        settings = cm.migration_settings.clone
        settings[:content_migration_id] = migration_id
        settings[:user_id] = cm.user_id
        settings[:attachment_id] = cm.attachment.id rescue nil

        converter = CC::Importer::CCConverter.new(settings)
        course = converter.export
        export_folder_path = course[:export_folder_path]
        overview_file_path = course[:overview_file_path]

        if overview_file_path
          file = File.new(overview_file_path)
          Canvas::MigrationWorker::upload_overview_file(file, cm)
        end
        if export_folder_path
          Canvas::MigrationWorker::upload_exported_data(export_folder_path, cm)
          Canvas::MigrationWorker::clear_exported_data(export_folder_path)
        end

        cm.migration_settings[:migration_ids_to_import] = {:copy=>{:assessment_questions=>true}}
        cm.workflow_state = :exported
        cm.progress = 0
        cm.save
      end

      def self.enqueue(content_migration)
        Delayed::Job.enqueue(new(content_migration.id),
                             :priority => Delayed::LOW_PRIORITY,
                             :max_attempts => 1)
      end
    end
  end
end
