module Translation
  unless defined?(EXPECT_RULE)
    EXPECT_RULE='EXPECT_RULE'
    EXPECT_PARENS_OPEN='EXPECT_PARENS_OPEN'
    EXPECT_CHILD_OR_PARENS_CLOSE='EXPECT_CHILD_OR_PARENS_CLOSE'
  end

  class NoParseError < Exception; end

  def self.translate(from_language, to_translate)
    to_translate = to_translate.clone # so we're not overwriting the input
    to_translate.gsub! /!/, 'bang'
    to_translate.gsub! /\?/, 'qmark'
    to_translate.gsub! /,/, 'comma'
    to_translate.gsub! /t-shirt/, 't_shirt'
    script_name = "sh parsing/5_parse_#{from_language.name.downcase}"
    output = 'not assigned'
    IO.popen(script_name, 'w+') { |f|
      f.puts "\" #{to_translate} \""
      output = f.readline
      output += f.readline
      output += f.readline
      # read too much and Windows will block
    }
#    output = `cd #{RAILS_ROOT}/parsing; echo "\\" #{to_translate} \\"" | #{script_name}`
    translations = Translation.parse_parse(from_language, output)
  end
  def self.parse_parse(language, parser_output)
    lines = parser_output.split("\n")

    line = lines.shift
    raise "Expected READY, got #{line}" if line != "READY"
    
    line = lines.shift
    raise NoParseError.new if line == 'No parse'
    raise "Expected PARSE_0:, got #{line}" if line != "PARSE_0:"
    
    line = lines.shift
    raise "Expected SingleFrame:, got #{line}" if not line.match(/^SingleFrame:(.*)/)

    all_rules = []
    rule_out = {}
    parse = $1
    parse.gsub!(/\bbang\b/i, '!')
    parse.gsub!(/\bqmark\b/i, '?')
    parse.gsub!(/\bcomma\b/i, ',')
    parse.gsub!(/\bt_shirt/i, 't-shirt')
    root = name_rules(language.id, parse.split(/ /), all_rules, rule_out)
#    rule_texts = []
#    all_rules.each { |rule|
#      children = rule.values.first
#      children_w_parens = add_parens(children)
#      rule_texts.push "#{rule.keys.first} --> #{children_w_parens.join(', ')}."
#    }
#
#    rules = []
#    rule_texts.collect { |rule_text|
#      rule = Rule.find(:first, :conditions => ['language_id=? and rule_text=?',
#        language.id, rule_text]) or raise "Couldn't find rule with text #{rule_text} in #{language.name}"
#      rules.push rule.rule_text
#    }
#    return rules.inspect
#return [rule_out]
    translated_trees = translate_tree(rule_out)
    return translated_trees
  end
  def self.translate_tree(tree_in, target_pos='start', depth=0)
    new_trees = []
    raise "Bad tree" if tree_in.keys.length != 1
#return [tree_in.clone] if depth == 0

    from_rule = tree_in.keys.first
    links = Link.find(:all, :conditions =>
      ['from_rule_id=? or (to_rule_id=? and bidirectional=1)',
      from_rule.id, from_rule.id])
    links.each { |link|
      link.reverse! if link.to_language == from_rule.language
    }
#raise [target_pos, tree_in, links].inspect unless %w[start start2 s np d n].include?(target_pos) #if from_rule.rule_text.match(/^vp/)
#raise [from_rule, links].inspect if target_pos == 'np' and !from_rule.rule_text.match(/yo/)
    if links == []
#      if tree_in.values.first.length == 1
#raise "Passing to rule #{tree_in.values.first.first.inspect} with target_pos #{target_pos}"
#        return translate_tree(tree_in.values.first.first, target_pos, depth + 1)
#      else
        raise "Couldn't find links for rule #{from_rule.inspect}"
#      end
    end
    given_children = tree_in.values.first
    links.each { |link|
      link.to_rule.source_features = from_rule.source_features
      childrens_possibilities = []
      children_target_poses = link.to_rule.poses
      children_target_features = link.to_rule.features
      if children_target_poses[0] != target_pos
        # handle the "?qué está haciendo la mujer?" case
        if children_target_poses.index(target_pos)
          # just jump a level
          source_child = given_children[children_target_poses.index(target_pos) - 1]
# hmm shouldn't be 'returning', might be other links to consider?
source_child = given_children[0]
#raise [target_pos, children_target_poses, given_children].inspect
          return translate_tree(source_child, target_pos, depth + 1)
        else
#            raise "Uh oh, this link #{link.inspect} doesn't match expected POS #{target_pos} and neither do any of the link's target's children's POSes"
        end
      else
        mapping = link.argument_mapping or raise "Link #{link.inspect} missing argument mapping"
        children_target_poses.each_with_index { |child_target_pos, target_argument_index|
          next if target_argument_index == 0
          if mapping.invert[target_argument_index]
            source_child = given_children[mapping.invert[target_argument_index] - 1]
            childrens_possibilities_additions = translate_tree(source_child, child_target_pos, depth + 1)
#original_possibilities = childrens_possibilities_additions.clone
            childrens_possibilities_additions.reject! { |possible_tree|
              possible_tree.keys.first.poses[0] != child_target_pos
            }
#raise "Uh oh no possibilities because no trees has pos #{child_target_pos}; originally was #{original_possibilities.inspect}" if childrens_possibilities_additions.length == 0 and !%w[s start2].include?(child_target_pos)
            childrens_possibilities.push childrens_possibilities_additions
          else # anything can fill the target argument
            childrens_possibilities_addition = []
            # TODO: next line's condition only works when there are only two languages
            all_target_rules = Rule.find(:all, :conditions => ['language_id!=?', from_rule.language.id])
            all_target_rules.each { |possible_target_rule|
              if possible_target_rule.parent_pos == child_target_pos and
              possible_target_rule.poses.length == 1
                childrens_possibilities_addition.push({possible_target_rule => []})
                else
                 #puts "Compared #{possible_target_rule.parent_pos.inspect} with #{target_pos.inspect}"
              end
            }
            childrens_possibilities.push childrens_possibilities_addition
            raise "Couldn't find expansions of #{child_target_pos.inspect}" if childrens_possibilities_addition.length == 0
          end
        } # next children target pos
      end
#        if target_children_poses.length == 1 and given_children.length == 1
#          given_children.each { |child|
#            children_possibility = translate_tree(child)
#            new_trees.push({ translated_rule => children_possibility })
#          }
#        else
#          raise "Don't know how to handle #{given_children.length} given children and #{target_children_poses.length} target children for source rule #{from_rule.inspect} to (one possible) target rule #{translated_rule.inspect}"
#        end
#        tree_in.values.first.each { |child|
#        childrens_possibilities.push translate_tree(child)
#      }

      if childrens_possibilities.length == 0
        new_trees.push({ link.to_rule => [] })
      else
        possibilities_multiplied = cartesian_multiply(childrens_possibilities)
        possibilities_multiplied.each { |children_possibility|
          new_trees.push({ link.to_rule => children_possibility })
        }
      end
    } # next link
#raise new_trees.inspect if depth == 3 && !%w[np].include?(target_pos)
    return new_trees
  end
  def self.meets_feature_requirements(rule, requirements)
    parent_features = rule.parent_features
    requirements.each { |feature_index, feature_value|
      if parent_features[feature_index] and
      parent_features[feature_index] != feature_value
        return false
      end
    }
    return true
  end
  def self.cartesian_multiply(list_of_lists)
    return [] if list_of_lists.empty?
    results = list_of_lists[0].collect { |element| [element] }
  
    list_of_lists[1..-1].each { |list|
      new_results = []
      results.each { |old_result|
        list.each { |element|
          new_results.push old_result + [element]
        }
      }
      results = new_results
    }
    results
  end
  
  def self.name_rules(language_id, tokens, all_rules, rule_hierarchy_out)
    state = EXPECT_RULE
    children = []
    children_rule_hierarchies = []
    while tokens.length > 0
      token = tokens.shift
      #puts "Next token: #{token}"
  
      if state == EXPECT_RULE && token.match(/^\[(.*)\]$/)
        parent = $1.downcase
        state = EXPECT_PARENS_OPEN
        #puts "Read parent #{parent}"
      elsif state == EXPECT_PARENS_OPEN && token == '('
        state = EXPECT_CHILD_OR_PARENS_CLOSE
        #puts "Read parens open"
      elsif state == EXPECT_CHILD_OR_PARENS_CLOSE && token == ')'
        #puts "Read parens close"
        new_rule = { parent => children }
        all_rules.push new_rule
        children_truncated = children.collect { |child|
          child[0..(child.index('-') ? child.index('-') - 1 : -1)] + '%'
        }
        children_w_parens = add_parens(children_truncated)
        parent_truncated = parent[0..(parent.index('-') ? parent.index('-') - 1 : -1)] + '%'
        rule_text = "#{parent_truncated} --> #{children_w_parens.join(', ')}."
        rules = Rule.find(:all, :conditions =>
          ['language_id = ? and rule_text like ?', language_id, rule_text]) or raise "Couldn't find rule with text #{rule_text} in #{Language.find(language_id).name}"
        rules.reject! { |rule|
          rule.rule_text_after_arrow.split(/ /).length != children.length
        }
        rules.reject! { |rule|
          match_failed = false
          match_failed ||= !rule.parent_can_expand_to(parent)
          match_failed ||= !rule.children_can_expand_to(children)
          match_failed
        }
#raise [rule_text, rule, children, parent].inspect
        raise "Wrong number of rules matching #{new_rule.inspect}: #{rules.inspect}" unless rules.length == 1
        rules.first.source_features = parent.split('-')[1..-1]
        rule_hierarchy_out[rules.first] = children_rule_hierarchies
        return new_rule
      elsif state == EXPECT_CHILD_OR_PARENS_CLOSE && token.match(/^\[(.*)\]$/)
        #puts "Putting #{token} back"
        tokens.unshift(token) # put it back
        child_rule_hierarchy_out = {}
        child_rule = name_rules(language_id, tokens, all_rules, child_rule_hierarchy_out)
        children_rule_hierarchies.push child_rule_hierarchy_out
        children.push child_rule.keys.first
      elsif state == EXPECT_CHILD_OR_PARENS_CLOSE
        #puts "Read #{token}"
        children.push "'#{token.downcase}'"
      else
        raise "At state #{state} and don't know what to do with token #{token}"
      end
    end
  end
  def self.add_parens(children)
    children_w_parens = []
    for i in 0...children.length
      this_is_lexical = children[i].match(/'/)
      prev_is_lexical = i > 0 && children[i - 1].match(/'/)
      next_is_lexical = i < children.length - 1 && children[i + 1].match(/'/)
      prefix = (this_is_lexical && !prev_is_lexical) ? '[' : ''
      suffix = (this_is_lexical && !next_is_lexical) ? ']' : ''
      children_w_parens.push "#{prefix}#{children[i]}#{suffix}"
    end
    children_w_parens
  end
  def self.flatten(tree_in)
    raise "Bad tree" if tree_in.keys.length != 1

    words = []
    argument_index = 0
    for rule_part in tree_in.keys.first.rule_text_after_arrow.split(/, /)
      if rule_part.match(/\[?'([^']*)'\]?/)
        words.push($1)
      else
        words += flatten(tree_in.values.first[argument_index])
        argument_index += 1
      end
    end
    return words
  end
  def self.parents_features(rule_tree)
    raise "Bad tree" if rule_tree.keys.length != 1
    rule = rule_tree.keys.first
    parent_all_features = rule.parent_all_features
    variable_assignments = {}
    rule.all_features.each_with_index { |child_features, index|
      next if index == 0
      child_tree = rule_tree.values.first[index - 1]
      recursed_feature_values = parents_features(child_tree) or return false
      recursed_feature_values.each_with_index { |recursed_value, feature_index|
        child_feature_value = child_features[feature_index]
        if child_feature_value.match(/^[A-Z]/)
          if variable_assignments[child_feature_value]
            return false if recursed_value && variable_assignments[child_feature_value] != recursed_value
          else
            variable_assignments[child_feature_value] = recursed_value if recursed_value
          end
        else
          return false if recursed_value && recursed_value != child_feature_value
        end
      }
    }
    final_features = parent_all_features.collect { |value_or_variable|
      value_or_variable.match(/^[A-Z]/) ? variable_assignments[value_or_variable] : value_or_variable
    }
    (rule.source_features || []).each { |source_feature|
      return false if case source_feature
        when '1' then final_features.index('2') || final_features.index('3')
        when '2' then final_features.index('1')
        when '3' then final_features.index('1')
        when 's' then final_features.index('p')
        when 'p' then final_features.index('s')
        else false
      end
    }
    return final_features
  end
end
