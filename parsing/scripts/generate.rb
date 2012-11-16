#!/usr/bin/ruby

$parent2transformations = {}

rules_file = STDIN
#open('temp/english.expanded.dcg') { |rules_file|
  rules_file.each { |line|
    line.strip!
    if line.match("^$")
      next
    elsif line.match("^%")
      next
    elsif match = line.match(/^([a-z0-9_-]+) --> (.*).$/)
      parent = $1
      transformation = $2
  
#      transformation.gsub! /T-shirt/, 't_shirt'
#      transformation.gsub! /\?/, 'qmark'
#      transformation.gsub! /,/, 'comma'
#      transformation.gsub! /!/, 'bang'
  
#      transformation.gsub!(/\b([A-Z0-9>-_]+)\b/, "[\\1]")
      if not $parent2transformations.has_key?(parent)
        $parent2transformations[parent] = []
      end
      $parent2transformations[parent].push transformation
    else
      raise "Line doesn't match regex: #{line}\n"
    end
  }
#}

def random_derivation_of(parent)
  derivation = []
  transformations = $parent2transformations[parent] or raise "Can't find transformation for #{parent.inspect}"
  random_transformation = transformations[rand(transformations.length)]
  random_transformation.split(/, /).each { |child|
    if child.match(/^\[?'([^']*)'\]?$/)
      derivation.push $1
    else
      derivation.push random_derivation_of(child)
    end
  }
  return derivation.join(' ')
end

begin
  while true
    puts random_derivation_of('start').gsub(/qmark/, '?').gsub(/comma/, ',').gsub(/^" (.*) "$/, "\\1")
  end
rescue Errno::EPIPE => e
end
