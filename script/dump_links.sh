#!/bin/sh
echo "select from_language.name from_language_name, from_rule.rule_text from_rule_text, to_language.name to_language_name, to_rule.rule_text to_rule_text, links.argument_mapping, links.bidirectional from links join rules from_rule on from_rule.id = links.from_rule_id join rules to_rule on to_rule.id = links.to_rule_id join languages from_language on from_language.id = from_rule.language_id join languages to_language on to_language.id = to_rule.language_id;" | mysql RuleLink --default-character-set=utf8 | sort > ../parsing/links.tsv
