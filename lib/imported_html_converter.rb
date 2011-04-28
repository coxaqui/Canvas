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

class ImportedHtmlConverter
  include TextHelper
  def self.convert(html, context, remove_outer_nodes_if_one_child = false)
    doc = Nokogiri::HTML(html || "")
    attrs = ['rel', 'href', 'src', 'data', 'value']
    course_path = "/#{context.class.to_s.underscore.pluralize}/#{context.id}"
    doc.search("*").each do |node|
      attrs.each do |attr|
        if node[attr]
          val = URI.unescape(node[attr])
          if val =~ /wiki_page_migration_id=(.*)/
            # This would be from a BB9 migration. 
            #todo: refactor migration systems to use new $CANVAS...$ flags
            #todo: FLAG UNFOUND REFERENCES TO re-attempt in second loop?
            if wiki_migration_id = $1
              if linked_wiki = context.wiki.wiki_pages.find_by_migration_id(wiki_migration_id)
                node[attr] = URI::escape("#{course_path}/wiki/#{linked_wiki.url}")
              end
            end
          elsif val =~ /discussion_topic_migration_id=(.*)/
            if topic_migration_id = $1
              if linked_topic = context.discussion_topics.find_by_migration_id(topic_migration_id)
                node[attr] = URI::escape("#{course_path}/discussion_topics/#{linked_topic.id}")
              end
            end
          elsif val =~ %r{(?:\$CANVAS_OBJECT_REFERENCE\$|\$WIKI_REFERENCE\$)/([^/]*)/(.*)}
            type = $1
            migration_id = $2
            type_for_url = type
            type = 'context_modules' if type == 'modules'
            if type == 'wiki'
              if page = context.wiki.wiki_pages.find_by_url(migration_id)
                node[attr] = URI::escape("#{course_path}/wiki/#{page.url}")
              end
            elsif context.respond_to?(type) && context.send(type).respond_to?(:find_by_migration_id)
              if object = context.send(type).find_by_migration_id(migration_id)
                node[attr] = URI::escape("#{course_path}/#{type_for_url}/#{object.id}")
              end
            end
          elsif val =~ %r{\$CANVAS_COURSE_REFERENCE\$/(.*)}
            section = $1
            node[attr] = URI::escape("#{course_path}/#{section}")
          elsif val =~ %r{\$IMS_CC_FILEBASE\$/(.*)}
            rel_path = $1
            if attr == 'href' && node['class'] && node['class'] =~ /instructure_inline_media_comment/
              replace_media_comment_data(node, rel_path, context, course_path)
            else
              node[attr] = replace_relative_file_url(rel_path, context, course_path)
            end
          elsif relative_url?(node[attr])
            node[attr] = replace_relative_file_url(node[attr], context, course_path)
          end
        end
      end
    end

    node = doc.at_css('body')
    if remove_outer_nodes_if_one_child
      node = node.child while node.children.size == 1 && node.child.child
    end
    node.inner_html
  rescue
    ""
  end

  def self.replace_relative_file_url(rel_path, context, course_path)
    new_url = nil
    rel_path, qs = rel_path.split('?', 2)
    if context.respond_to?(:attachment_path_id_lookup) &&
        context.attachment_path_id_lookup &&
        context.attachment_path_id_lookup[rel_path]
      if file = context.attachments.find_by_migration_id(context.attachment_path_id_lookup[rel_path])
        new_url = "/courses/#{context.id}/files/#{file.id}"
        # support other params in the query string, that were exported from the
        # original path components and query string. see
        # CCHelper::file_query_string
        params = Rack::Utils.parse_nested_query(qs.presence || "")
        qs = []
        params.each do |k,v|
          case k
          when /canvas_qs_(.*)/
            qs << "#{Rack::Utils.escape($1)}=#{Rack::Utils.escape(v)}"
          when /canvas_(.*)/
            new_url += "/#{$1}"
          end
        end
        new_url += "?#{qs.join("&")}" if qs.present?
        if params.blank?
          new_url += "/preview"
        end
      end
    end
    unless new_url
      # the rel_path should already be escaped
      new_url = URI::escape("#{course_path}/file_contents/#{Folder.root_folders(context).first.name}/") + rel_path
    end
    new_url
  end

  def self.replace_media_comment_data(node, rel_path, context, course_path)
    if context.respond_to?(:attachment_path_id_lookup) &&
      context.attachment_path_id_lookup &&
        context.attachment_path_id_lookup[rel_path]
      file = context.attachments.find_by_migration_id(context.attachment_path_id_lookup[rel_path])
      if file && file.media_object
        media_id = file.media_object.media_id
        node['href'] = "/media_objects/#{media_id}"
        node['id'] = "media_comment_#{media_id}"
        return
      end
    end
    node['href'] = replace_relative_file_url(rel_path, context, course_path)
  end
  
  def self.relative_url?(url)
    (url.match(/[\/#\?]/) || (url.match(/\./) && !url.match(/@/))) && !url.match(/\A\w+:/) && !url.match(/\A\//)
  end
  
  def self.convert_text(text, context, import_source=:webct)
    instance.format_message(text || "")[0]
  end
  
  def self.instance
    @@instance ||= self.new
  end
end
