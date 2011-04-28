require File.dirname(__FILE__) + '/../../qti_helper'

describe "Converting Blackboard Vista qti" do

  it "should mock the manifest node correctly" do
    manifest_node=get_manifest_node('multiple_choice', :interaction_type => 'extendedTextInteraction', :bb_question_type => 'Calculated')
    manifest_node.at_css("instructureMetadata").should == manifest_node
    manifest_node['identifier'].should == nil
    manifest_node['href'].should == 'multiple_choice.xml'
    if title = manifest_node.at_css('title langstring')
      title.text.should == nil
    end
    if type = manifest_node.at_css('interactiontype')
      type.text.downcase.should == 'extendedtextinteraction'
    end
    if type = manifest_node.at_css('instructureMetadata instructureField[name=quiz_type]')
      type['value'].downcase.should == 'calculated'
    end
    if type = manifest_node.at_css('instructureField[name=bb8_assessment_type]')
      type['value'].downcase.should == 'calculated'
    end
  end

  it "should convert multiple choice" do
    manifest_node=get_manifest_node('multiple_choice', :interaction_type => 'choiceInteraction')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::MULTIPLE_CHOICE
  end

  it "should convert true/false questions" do
    manifest_node=get_manifest_node('true_false', :interaction_type => 'choiceInteraction')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::TRUE_FALSE
  end

  it "should convert multiple choice questions with multiple correct answers (multiple answer)" do
    manifest_node=get_manifest_node('multiple_answer', :interaction_type => 'choiceInteraction')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::MULTIPLE_ANSWER
  end

  it "should convert essay questions" do
    manifest_node=get_manifest_node('essay', :interaction_type => 'extendedTextInteraction')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash.should == VistaExpected::ESSAY
  end

  it "should convert short answer questions" do
    manifest_node=get_manifest_node('short_answer', :interaction_type => 'extendedTextInteraction')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::SHORT_ANSWER
  end

  it "should convert matching questions" do
    manifest_node=get_manifest_node('matching', :interaction_type => 'associateInteraction', :bb_question_type => 'WCT_Matching')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    # make sure the ids are correctly referencing each other
    matches = {}
    hash[:matches].each {|m| matches[m[:match_id]] = m[:text]}
    hash[:answers].each do |a|
      matches[a[:match_id]].should == a[:text].sub('left', 'right')
    end

    # compare everything else without the ids
    hash[:answers].each {|a|a.delete(:id); a.delete(:match_id)}
    hash[:matches].each {|m|m.delete(:match_id)}
    hash.should == VistaExpected::MATCHING
  end

  it "should convert the assessments into quizzes" do
    manifest_node=get_manifest_node('assessment', :quiz_type => 'examination')
    a = Qti::AssessmentTestConverter.new(manifest_node, vista_question_dir, true)
    a.create_instructure_quiz
    a.quiz.should == VistaExpected::ASSESSMENT
  end
  
  it "should convert simple calculated questions" do
    manifest_node=get_manifest_node('calculated_simple', :interaction_type => 'extendedTextInteraction', :bb_question_type => 'Calculated')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::CALCULATED_SIMPLE
  end

  it "should convert complex calculated questions" do
    manifest_node=get_manifest_node('calculated_complex', :interaction_type => 'extendedTextInteraction', :bb_question_type => 'Calculated')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::CALCULATED_COMPLEX
  end

  it "should convert combination to multiple choice" do
    manifest_node=get_manifest_node('combination', :interaction_type => 'choiceInteraction', :bb_question_type => 'WCT_Combination')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::COMBINATION
  end
  
  it "should convert fill in multiple blanks questions" do
    manifest_node=get_manifest_node('fill_in_the_blank', :interaction_type => 'extendedTextInteraction', :bb_question_type => 'WCT_FillInTheBlank')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash[:answers].each {|a|a.delete(:id)}
    hash.should == VistaExpected::FILL_IN_MULTIPLE_BLANKS
  end
  
  it "should mark jumbled sentence as not supported" do
    manifest_node=get_manifest_node('jumbled_sentence', :interaction_type => nil, :bb_question_type => 'WCT_JumbledSentence')
    hash = Qti::ChoiceInteraction.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>vista_question_dir)
    hash.should == VistaExpected::JUMBLED_SENTENCE
  end


end


module VistaExpected
  # the multiple choice example minus the ids for the answers because those are random.
  MULTIPLE_CHOICE = {:points_possible=>1,
                     :question_text=>"The answer is nose.",
                     :question_type=>"multiple_choice_question",
                     :answers=>
                             [{:text=>"nose", :weight=>100, :migration_id=>"MC0"},
                              {:text=>"ear", :weight=>0, :migration_id=>"MC1"},
                              {:text=>"eye", :weight=>0, :migration_id=>"MC2"},
                              {:text=>"mouth", :weight=>0, :migration_id=>"MC3"}],
                     :migration_id=>"4609865476341",
                     :correct_comments=>"",
                     :question_name=>"Multiple Choice",
                     :incorrect_comments=>""}

  # removed ids on the answers
  TRUE_FALSE = {:correct_comments=>"",
                :points_possible=>1,
                :question_name=>"True/False",
                :question_text=>"I am wearing a black hat.",
                :incorrect_comments=>"",
                :answers=>
                        [{:text=>"true", :weight=>100, :migration_id=>"true"},
                         {:text=>"false", :weight=>0, :migration_id=>"false"}],
                :question_type=>"true_false_question",
                :migration_id=>"4609865577341"}

  # removed ids on the answers
  MULTIPLE_ANSWER = {:migration_id=>"4609865392341",
                     :correct_comments=>"",
                     :points_possible=>1,
                     :question_name=>"Multiple Answer",
                     :answers=>
                             [{:migration_id=>"MC0",
                               :text=>"house",
                               :comments=>"house: right",
                               :weight=>100},
                              {:migration_id=>"MC1",
                               :text=>"garage",
                               :comments=>"garage: right",
                               :weight=>100},
                              {:migration_id=>"MC2",
                               :text=>"barn",
                               :comments=>"barn: wrong",
                               :weight=>0},
                              {:migration_id=>"MC3",
                               :text=>"pond",
                               :comments=>"pond: wrong",
                               :weight=>0}],
                     :question_text=>"The answers are house and garage.",
                     :incorrect_comments=>"",
                     :question_type=>"multiple_answers_question"}

  ESSAY = {:question_text=>"Who likes to use Blackboard?",
           :incorrect_comments=>"",
           :question_type=>"essay_question",
           :answers=>[],
           :migration_id=>"4609842537341",
           :correct_comments=>"",
           :example_solution=>"Nobody.",
           :points_possible=>1,
           :question_name=>"Essay Question"}

  # removed ids on the answers
  SHORT_ANSWER = {:question_text=>"We all live in what?",
                  :incorrect_comments=>"",
                  :question_type=>"short_answer_question",
                  :answers=>
                          [{:text=>"A yellow submarine.", :comments=>"", :weight=>100}],
                  :migration_id=>"4609865550341",
                  :correct_comments=>"",
                  :points_possible=>1,
                  :question_name=>"Short Answer"}

  # removed ids on the answers
  MATCHING = {:correct_comments=>"",
              :points_possible=>1,
              :question_name=>"Matching",
              :question_text=>"Match these.",
              :answers=>
                      [{:right=>"right 1", :text=>"left 1", :comments=>""},
                       {:right=>"right 2", :text=>"left 2", :comments=>""},
                       {:right=>"right 3", :text=>"left 3", :comments=>""},
                       {:right=>"right 4", :text=>"left 4", :comments=>""}],
              :incorrect_comments=>"",
              :question_type=>"matching_question",
              :matches=>
                      [{:text=>"right 1"},
                       {:text=>"right 2"},
                       {:text=>"right 3"},
                       {:text=>"right 4"}],
              :migration_id=>"4609865194341"}

  ASSESSMENT = {:time_limit=>60,
                :question_count=>11,
                :title=>"Blackboard Vista Export Test",
                :quiz_name=>"Blackboard Vista Export Test",
                :quiz_type=>"assignment",
                :allowed_attempts=>1,
                :migration_id=>"2f207fc5-0a34-0287-01c7-bcc0a626db16.4609765293341_R",
                :questions=>
                        [{:question_type=>"question_reference",
                          :migration_id=>"4609823478341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609842344341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609842537341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609842630341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609842882341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609865194341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609865392341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609865476341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609865550341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609865577341",
                          :points_possible=>10.0},
                         {:question_type=>"question_reference",
                          :migration_id=>"4609885376341",
                          :points_possible=>10.0}],
                :points_possible=>"237.0",
                :grading=>
                        {
                                :migration_id=>"2f207fc5-0a34-0287-01c7-bcc0a626db16.4609765293341_R",
                                :title=>"Blackboard Vista Export Test",
                                :points_possible=>"237.0",
                                :grade_type=>"numeric",
                                :due_date=>nil,
                                :weight=>nil
                        }
  }


  CALCULATED_SIMPLE = {:answer_tolerance=>0,
                       :migration_id=>"4609842344341",
                       :imported_formula=>"10-[x]",
                       :correct_comments=>"",
                       :answers=>
                               [{:weight=>100, :answer=>1, :variables=>[{:value=>9, :name=>"x"}]},
                                {:weight=>100, :answer=>8, :variables=>[{:value=>2, :name=>"x"}]},
                                {:weight=>100, :answer=>16, :variables=>[{:value=>-6, :name=>"x"}]},
                                {:weight=>100, :answer=>6, :variables=>[{:value=>4, :name=>"x"}]},
                                {:weight=>100, :answer=>16, :variables=>[{:value=>-6, :name=>"x"}]},
                                {:weight=>100, :answer=>10, :variables=>[{:value=>0, :name=>"x"}]},
                                {:weight=>100, :answer=>15, :variables=>[{:value=>-5, :name=>"x"}]},
                                {:weight=>100, :answer=>3, :variables=>[{:value=>7, :name=>"x"}]},
                                {:weight=>100, :answer=>10, :variables=>[{:value=>0, :name=>"x"}]},
                                {:weight=>100, :answer=>18, :variables=>[{:value=>-8, :name=>"x"}]}],
                       :question_bank_name=>"Export Test",
                       :points_possible=>100,
                       :question_name=>"Calculated Question 2",
                       :question_text=>"What is 10 - ?",
                       :incorrect_comments=>"",
                       :formulas=>[],
                       :general_comments=>"General Feedback.",
                       :question_type=>"calculated_question",
                       :variables=>[{:scale=>0, :min=>-10, :max=>10, :name=>"x"}]}

  CALCULATED_COMPLEX = {:general_comments=>"Right answer.",
                        :question_type=>"calculated_question",
                        :imported_formula=>
                                "(10*[F])**(-1) * (1000*[F]*[r]*[i]**(-1) * (1-(1 ([i]/200))**(-2*([Y]-10)))   1000*[F]*(1 ([i]/200))**(-2*([Y]-10))) * (1 ([i]/100)*([n]/360))",
                        :migration_id=>"4609823478341",
                        :answers=>
                                [{:weight=>100,
                                  :answer=>96.29,
                                  :variables=>
                                          [{:value=>5.43, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>37, :name=>"F"},
                                           {:value=>26, :name=>"Y"},
                                           {:value=>59, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>112.493,
                                  :variables=>
                                          [{:value=>5.22, :name=>"i"},
                                           {:value=>6, :name=>"r"},
                                           {:value=>45, :name=>"F"},
                                           {:value=>35, :name=>"Y"},
                                           {:value=>104, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>101.325,
                                  :variables=>
                                          [{:value=>5.94, :name=>"i"},
                                           {:value=>6, :name=>"r"},
                                           {:value=>31, :name=>"F"},
                                           {:value=>35, :name=>"Y"},
                                           {:value=>33, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>114.763,
                                  :variables=>
                                          [{:value=>4.1, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>29, :name=>"F"},
                                           {:value=>34, :name=>"Y"},
                                           {:value=>85, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>105.937,
                                  :variables=>
                                          [{:value=>4.48, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>34, :name=>"F"},
                                           {:value=>25, :name=>"Y"},
                                           {:value=>23, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>102.414,
                                  :variables=>
                                          [{:value=>4.87, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>20, :name=>"F"},
                                           {:value=>25, :name=>"Y"},
                                           {:value=>76, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>113.719,
                                  :variables=>
                                          [{:value=>5.04, :name=>"i"},
                                           {:value=>6, :name=>"r"},
                                           {:value=>29, :name=>"F"},
                                           {:value=>31, :name=>"Y"},
                                           {:value=>87, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>102.09,
                                  :variables=>
                                          [{:value=>4.88, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>39, :name=>"F"},
                                           {:value=>20, :name=>"Y"},
                                           {:value=>84, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>106.801,
                                  :variables=>
                                          [{:value=>4.52, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>32, :name=>"F"},
                                           {:value=>26, :name=>"Y"},
                                           {:value=>104, :name=>"n"}]},
                                 {:weight=>100,
                                  :answer=>101.954,
                                  :variables=>
                                          [{:value=>4.9, :name=>"i"},
                                           {:value=>5, :name=>"r"},
                                           {:value=>44, :name=>"F"},
                                           {:value=>39, :name=>"Y"},
                                           {:value=>30, :name=>"n"}]}],
                        :variables=>
                                [{:scale=>0, :min=>20, :max=>50, :name=>"F"},
                                 {:scale=>0, :min=>5, :max=>7, :name=>"r"},
                                 {:scale=>2, :min=>4, :max=>6, :name=>"i"},
                                 {:scale=>0, :min=>20, :max=>40, :name=>"Y"},
                                 {:scale=>0, :min=>20, :max=>120, :name=>"n"}],
                        :correct_comments=>"",
                        :question_bank_name=>"Export Test",
                        :points_possible=>100,
                        :question_name=>"Calculated Question ",
                        :formulas=>[],
                        :question_text=>
                                "Based on her excellent performance as a district sales manager, Maria receives a sizable bonus at work. Since her generous salary is more than enough to provide for the needs of her family, she decides to use the bonus to buy a bond as an investment. The par value of the bond that Maria would like to purchase is $ thousand. The bond pays % interest, compounded semiannually (with payment on January 1 and July 1) and matures on July 1, 20. Maria wants a return of %, compounded semiannually. How much would she be willing to pay for the bond if she buys it  days after the July 2010 interest anniversary? Give your answer in the format of a quoted bond price, as a percentage of par to three decimal places -- like you would see in the Wall Street Journal. Use the formula discussed in class -- and from the book, NOT the HP 12c bond feature. (Write only the digits, to three decimal palces, e.g. 114.451 and no $, commas, formulas, etc.)",
                        :answer_tolerance=>0.1,
                        :incorrect_comments=>""}

  COMBINATION = {:migration_id=>"4609885376341",
                 :correct_comments=>"",
                 :answers=>[{:weight=>100, :text=>"B, C", :migration_id=>"MC0"}],
                 :points_possible=>1,
                 :question_name=>"Combination",
                 :question_text=>"This should just be a multiple answer. B and C are correct<br></br>\nA. wrong 1<br></br>\nB. right 1<br></br>\nC. right 2<br></br>\nD. wrong 2<br></br>\nE. wrong 3<br></br>\n",
                 :incorrect_comments=>"",
                 :question_type=>"multiple_choice_question"}

  FILL_IN_MULTIPLE_BLANKS = {:question_type=>"fill_in_multiple_blanks_question",
                             :migration_id=>"4609842630341",
                             :answers=>
                                     [{:comments=>"", :text=>"family", :weight=>100, :blank_id=>"family"},
                                      {:comments=>"", :text=>"poor", :weight=>100, :blank_id=>"poor"},
                                      {:comments=>"", :text=>"sad", :weight=>100, :blank_id=>"poor"}],
                             :correct_comments=>"",
                             :points_possible=>1,
                             :question_name=>"Fill in the blank",
                             :question_text=>"I'm just a [poor] boy from a poor [family]",
                             :incorrect_comments=>""}

  JUMBLED_SENTENCE = {:question_text=>"",
                      :incorrect_comments=>"",
                      :question_type=>"WCT_JumbledSentence",
                      :answers=>[],
                      :migration_id=>"4609842882341",
                      :correct_comments=>"",
                      :unsupported=>true,
                      :points_possible=>1,
                      :question_name=>"Jumbled Sentence"}
end