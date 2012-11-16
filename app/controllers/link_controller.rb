require 'translation'

class LinkController < ApplicationController
  def index
    load "#{RAILS_ROOT}/lib/translation.rb"
    @translation = ''

    case params['id']
      when nil
        redirect_to :id => 'spanish2english' and return
      when 'spanish2english'
        @from_language = Language.find_by_name('Spanish')
        @to_language = Language.find_by_name('English')
      when 'english2spanish'
        @from_language = Language.find_by_name('English')
        @to_language = Language.find_by_name('Spanish')
      else
        raise "Unknown translation pair"
    end

    if request.post?
      if params['submit'] == 'Delete all links'
        Link.delete_all
      elsif params['submit'] == 'Link'
      elsif params['submit'] == 'Translate'
        to_translate = params['to_translate']
        begin
          @translations = Translation.translate(@from_language, to_translate)
	rescue Translation::NoParseError => e
          @error = "Couldn't parse source phrase"
	rescue RuntimeError => e
          @error = e.inspect
        end
      else
        found_a_link_delete = false
        for key, value in params
          if key.match(/delete_link_([0-9]+)/)
            link_id = $1.to_i
            Link.find(link_id).destroy
            found_a_link_delete = true
          end
        end
        if not found_a_link_delete
          raise "Unknown submit button #{params['submit']}"
        end
      end
    end
  end
  def make_link
    from_rules = params['from_rule_ids'].split(',').collect { |rule_id| Rule.find(rule_id) }
    to_rules =   params['to_rule_ids'  ].split(',').collect { |rule_id| Rule.find(rule_id) }

    argument_mapping = {}
    argument_mapping[1] = 1 if params['arg_1_maps_to'] == 'arg1'
    argument_mapping[1] = 2 if params['arg_1_maps_to'] == 'arg2'
    argument_mapping[1] = 3 if params['arg_1_maps_to'] == 'arg3'
    argument_mapping[1] = 4 if params['arg_1_maps_to'] == 'arg4'
    argument_mapping[2] = 1 if params['arg_2_maps_to'] == 'arg1'
    argument_mapping[2] = 2 if params['arg_2_maps_to'] == 'arg2'
    argument_mapping[2] = 3 if params['arg_2_maps_to'] == 'arg3'
    argument_mapping[2] = 4 if params['arg_2_maps_to'] == 'arg4'
    argument_mapping[3] = 1 if params['arg_3_maps_to'] == 'arg1'
    argument_mapping[3] = 2 if params['arg_3_maps_to'] == 'arg2'
    argument_mapping[3] = 3 if params['arg_3_maps_to'] == 'arg3'
    argument_mapping[3] = 4 if params['arg_3_maps_to'] == 'arg4'
    argument_mapping[4] = 1 if params['arg_4_maps_to'] == 'arg1'
    argument_mapping[4] = 2 if params['arg_4_maps_to'] == 'arg2'
    argument_mapping[4] = 3 if params['arg_4_maps_to'] == 'arg3'
    argument_mapping[4] = 4 if params['arg_4_maps_to'] == 'arg4'

    bidirectional = !params['bidirectional'].nil?

    from_rules.each { |from_rule|
      to_rules.each { |to_rule|
        Link.new(
          :from_language => from_rule.language,
          :from_rule => from_rule,
          :to_language => to_rule.language,
          :to_rule => to_rule,
          :argument_mapping => argument_mapping.inspect,
          :bidirectional => bidirectional
        ).save!
      }
    }
  end
end
