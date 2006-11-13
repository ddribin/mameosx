#!/usr/bin/ruby
$VERBOSE = true

header = ARGV.shift

puts "#ifndef #{header}"
puts "#define #{header}"
puts

ARGV.each do |arg|
  arg.match(/-D(.*)\=(\d)/)
  puts "#define #{$1} #{$2}"
end

puts
puts "#endif"