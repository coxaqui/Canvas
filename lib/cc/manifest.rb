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
  class Manifest
    include CCHelper
    
    attr_accessor :exporter, :weblinks, :basic_ltis

    def initialize(exporter)
      @exporter = exporter
      @file = nil
      @document = nil
      @weblinks = []
      @basic_ltis = []
    end
    
    def course
      @exporter.course
    end
    
    def export_dir
      @exporter.export_dir
    end
    
    def zip_file
      @exporter.zip_file
    end

    def close
      @file.close if @file
      @document = nil
      @file
    end
    
    def create_document
      @file = File.new(File.join(export_dir, MANIFEST), 'w')
      @document = Builder::XmlMarkup.new(:target=>@file, :indent=>2)
      @document.instruct!
      @document.manifest("identifier" => create_key(course, "common_cartridge_"),
                         "xmlns" => "http://www.imsglobal.org/xsd/imsccv1p1/imscp_v1p1",
                         "xmlns:lom"=>"http://ltsc.ieee.org/xsd/imsccv1p1/LOM/resource",
                         "xmlns:lomimscc"=>"http://ltsc.ieee.org/xsd/imsccv1p1/LOM/manifest",
                         "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
                         "xsi:schemaLocation"=>"http://www.imsglobal.org/xsd/imsccv1p1/imscp_v1p1 http://www.imsglobal.org/profile/cc/ccv1p1/ccv1p1_imscp_v1p2_v1p0.xsd http://ltsc.ieee.org/xsd/imsccv1p1/LOM/resource http://www.imsglobal.org/profile/cc/ccv1p1/LOM/ccv1p1_lomresource_v1p0.xsd http://ltsc.ieee.org/xsd/imsccv1p1/LOM/manifest http://www.imsglobal.org/profile/cc/ccv1p1/LOM/ccv1p1_lommanifest_v1p0.xsd"
      ) do |manifest_node|
        
        manifest_node.metadata do |md|
          create_metadata(md)
        end
        set_progress(5)
        
        Organization.create_organizations(self, manifest_node)
        set_progress(10)

        Resource.create_resources(self, manifest_node)

      end #manifest
    end

    def create_metadata(md)
      md.schema "IMS Common Cartridge"
      md.schemaversion "1.1.0"
      md.lomimscc :lom do |lom|
        lom.lomimscc :general do |general|
          general.lomimscc :title do |title|
            title.lomimscc :string, course.name
          end
        end
        lom.lomimscc :lifeCycle do |general|
          general.lomimscc :contribute do |title|
            title.lomimscc :date do |date|
              date.lomimscc :dateTime, ims_date
            end
          end
        end
        lom.lomimscc :rights do |rights|
          rights.lomimscc :copyrightAndOtherRestrictions do |node|
            node.lomimscc :value, "yes"
          end
          rights.lomimscc :description do |desc|
            desc.lomimscc :string, "#{course.license_data[:readable_license]} - #{course.license_data[:license_url]}"
          end
        end
      end
    end
    
    def set_progress(progress)
      @exporter.set_progress(progress)
    end
  end
end
