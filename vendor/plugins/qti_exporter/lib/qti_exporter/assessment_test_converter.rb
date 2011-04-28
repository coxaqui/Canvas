module Qti
class AssessmentTestConverter
  include Canvas::XMLHelper
  TEST_FILE = "/home/bracken/projects/QTIMigrationTool/assessments/out/assessmentTests/assmnt_URN-X-WEBCT-VISTA_V2-790EA1350A1A681DE0440003BA07D9B4.xml"
  DEFAULT_POINTS_POSSIBLE = 1

  attr_reader :base_dir, :identifier, :href, :interaction_type, :title, :quiz

  def initialize(manifest_node, base_dir, is_webct=true, converted_questions = [])
    @log = Canvas::Migration::logger
    @manifest_node = manifest_node
    @base_dir = base_dir
    @href = File.join(@base_dir, @manifest_node['href'])
    @is_webct = is_webct
    @converted_questions = converted_questions

    @quiz = {
            :questions=>[],
            :quiz_type=>nil,
            :question_count=>0
    }
  end

  def create_instructure_quiz(converted_questions = [])
    begin
      # Get manifest data
      if md = @manifest_node.at_css("instructureMetadata")
        if item = get_node_att(md, 'instructureField[name=show_score]', 'value')
          @quiz[:show_score] = item =~ /true/i ? true : false
        end
        if item = get_node_att(md, 'instructureField[name=quiz_type]', 'value') || item = get_node_att(md, 'instructureField[name=bb8_assessment_type]', 'value')
          # known possible values: Self-assessment, Survey, Examination (practice is instructure default)
          # BB8: Test, Pool
          @quiz[:quiz_type] = "assignment" if item =~ /examination|test|quiz/i
          if item =~ /pool/i
            # if it's pool we don't need to make a quiz object.
            return nil
          end
        end
        if item = get_node_att(md, 'instructureField[name=which_attempt_to_keep]', 'value')
          # known possible values: Highest, First, Last (highest is instructure default)
          @quiz[:which_attempt_to_keep] = "keep_latest" if item =~ /last/i
        end
        if item = get_node_att(md, 'instructureField[name=max_score]', 'value')
          @quiz[:points_possible] = item
        end
        if item = get_node_att(md, 'instructureField[name=bb8_object_id]', 'value')
          @quiz[:alternate_migration_id] = item
        end
      end

      # Get the actual assessment file
      doc = Nokogiri::XML(open(@href))
      parse_quiz_data(doc)
      
      if @quiz[:quiz_type] == 'assignment'
        grading = {}
        grading[:migration_id] = @quiz[:migration_id]
        grading[:points_possible] = @quiz[:points_possible]
        grading[:weight] = nil
        grading[:due_date] = nil
        grading[:title] = @quiz[:title]
        grading[:grade_type] = 'numeric' if grading[:points_possible]
        @quiz[:grading] = grading
      end
    rescue
      @quiz[:qti_error] = "Error converting QTI quiz: #{$!}: #{$!.backtrace.join("\n\t")}" 
      @log.error "Error converting QTI quiz: #{$!}: #{$!.backtrace.join("\n\t")}"
    end

    @quiz
  end

  def parse_quiz_data(doc)
    @quiz[:title] = @title || get_node_att(doc, 'assessmentTest', 'title')
    @quiz[:quiz_name] = @quiz[:title]
    @quiz[:migration_id] = get_node_att(doc, 'assessmentTest', 'identifier')
    if part = doc.at_css('testPart[identifier=BaseTestPart]')
      if control = part.at_css('itemSessionControl')
        if max = control['maxAttempts']
          max = max.to_i
          # -1 means no limit in instructure, 0 means no limit in QTI
          @quiz[:allowed_attempts] = max >= 1 ? max : -1
        end
        if show = control['showSolution']
          show = show
          @quiz[:show_correct_answers] = show.downcase == "true" ? true : false
        end
        if limit = doc.search('timeLimits').first
          limit = limit['maxTime'].to_i
          #instructure uses minutes, QTI uses seconds
          @quiz[:time_limit] = limit / 60
        end
      end

      process_section(part)
    else
      @quiz[:qti_error] = "Instructure doesn't support QTI importing from this source." 
      @log.error "Attempted to convert QTI from non-supported source. (it wasn't run through the python conversion tool.)"
    end
  end

  def process_section(section)
    group = nil
    questions_list = @quiz[:questions]
    
    if shuffle = get_node_att(section, 'ordering','shuffle')
      @quiz[:shuffle_answers] = true if shuffle =~ /true/i
    end
    if select = section.children.find {|child| child.name == "selection"}
      select = select['select'].to_i
      if select > 0
        group = {:questions=>[], :pick_count => select, :question_type => 'question_group'}
        if weight = get_node_att(section, 'weight','value')
          group[:question_points] = convert_weight_to_points(weight)
        end
        if points = section.at_css('points_per_item')
          group[:question_points] = points.text.to_f
        end
        if bank_id = section.at_css('sourcebank_ref')
          group[:question_bank_migration_id] = bank_id.text
        end
        group[:migration_id] = section['identifier'] && section['identifier'] != "" ? section['identifier'] : rand(100_000)
        questions_list = group[:questions]
      end
    end
    if section['visible'] and section['visible'] =~ /true/i
      if title = section['title']
        #Create an empty question with a title in it
        @quiz[:questions] << {:question_type => 'text_only_question', :question_text => title, :migration_id => rand(100_000)}
      end
    end
    
    section.children.each do |child|
      if child.name == "assessmentSection"
        process_section(child)
      elsif child.name == "assessmentItemRef"
        process_question(child, questions_list)
      end
    end

    # if we didn't get a question weight, and all the questions have the same
    # points possible, use that as the group points possible per question
    if select && select > 0 && group[:question_points].blank? && group[:questions].present?
      migration_ids = group[:questions].map { |q| q[:migration_id] }
      questions = @converted_questions.find_all { |q| migration_ids.include?(q[:migration_id]) }

      points = questions.first ? (questions.first[:points_possible] || 0) : 0
      if points > 0 && questions.size == group[:questions].size && questions.all? { |q| q[:points_possible] == points }
        group[:question_points] = points
      else
      end
    end

    group && group[:question_points] ||= DEFAULT_POINTS_POSSIBLE

    @quiz[:questions] << group if group and (!group[:questions].empty? || group[:question_bank_migration_id])
    
    questions_list
  end
  
  def process_question(item_ref, questions_list)
    question = {:question_type => 'question_reference'}
    questions_list << question
    @quiz[:question_count] += 1
    # The colons are replaced with dashes in the conversion from QTI 1.2
    question[:migration_id] = item_ref['identifier'].gsub(/:/, '-')
    if weight = get_node_att(item_ref, 'weight','value')
      question[:points_possible] = convert_weight_to_points(weight)
    end
  end
  
  # the weight from a webct system is represented as a float like 0.05,
  # but the point value for that float is actually 5. So if it's from
  # webct multiply it by 100
  def convert_weight_to_points(weight)
    begin
      weight = weight.to_f
      if @is_webct
        weight = weight * 100 
      end
    rescue
      weight = DEFAULT_POINTS_POSSIBLE
    end
    weight
  end

end
end
