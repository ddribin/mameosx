#!/usr/bin/ruby

require 'erb'
require 'optparse'
require 'ostruct'

class MakeVariables
  def initialize
    @vars = {}
    @pwd = Dir.pwd
    read_vars
  end
  
  def read_vars
    IO.popen("make -qpI mame -f tools/source_dump.mk") do |f|
      f.each do |line|
        next if line =~ /^\s*$/
        next if line =~ /^\S*#/

        if line =~ /^(\S+)\s*(=|:=|:)\s*(.*)/
          @vars[$1] = $3
        end
      end
    end
  end
  
  def [](name)
    return @vars[name]
  end
  
  def obj_to_src(obj)
    obj =~ /obj\/mame\/(.*)\.o/
    return @pwd + "/mame/src/" + $1 + ".c"
  end
  
  def objects_to_sources(objects)
    return objects.sort!.uniq!.map { |o| obj_to_src(o) }
  end
  
  def driver_sources
    driver_libs = @vars['OSX_DRVLIBS'].split
    objects = []
    driver_libs.each do |lib|
      o = @vars[lib].split
      objects.push(*o)
    end
    return objects_to_sources(objects) 
  end
  
  def cpu_sources
    objects = @vars['OSX_CPUOBJS'].split.sort!
    return objects_to_sources(objects) 
  end
  
  def debug_cpu_sources
    objects = @vars['OSX_DBGOBJS'].split.sort!
    return objects_to_sources(objects) 
  end

  def sound_sources
    objects = @vars['OSX_SOUNDOBJS'].split.sort!
    return objects_to_sources(objects) 
  end
  
  def parse(args)
    @options = OpenStruct.new
    @options.driver_sources = false
    @options.cpu_sources = false
    @options.debug_cpu_sources = false
    @options.sound_sources = false
    opts = OptionParser.new do |opts|
      opts.on("-c", "--cpu-sources", "Print CPU sources") do
        @options.cpu_sources = true
      end
      opts.on("-C", "--debug-cpu-sources", "Print debug CPU sources") do
        @options.debug_cpu_sources = true
      end
      opts.on("-s", "--sound-sources", "Print sound sources") do
        @options.sound_sources = true
      end
      opts.on("-d", "--driver-sources", "Print driver sources") do
        @options.driver_sources = true
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

    end
    opts.parse!(args)
  end

  def run(args)
    parse(args)
    puts cpu_sources if @options.cpu_sources
    puts debug_cpu_sources if @options.debug_cpu_sources
    puts sound_sources if @options.sound_sources
    puts driver_sources if @options.driver_sources
  end
end

def run_applescript(applescript)
  IO.popen("osascript", "w") { |osa| osa.print applescript }
end

def remove_files(target, group)
  applescript = <<-END_OF_APPLESCRIPT
  tell application "Xcode"
    set myProject to project "mameosx"
    set myTarget to target "#{target}" of myProject
    set myRoot to root group of myProject
    set myMameGroup to group "mame" of myRoot
    set myGroup to group "#{group}" of myMameGroup
    delete (every file reference of myGroup)
  end tell  
  END_OF_APPLESCRIPT
  run_applescript(applescript)
end

def add_file(target, group, full_path)
  name = File.basename(full_path)
  applescript = <<-END_OF_APPLESCRIPT
  tell application "Xcode"
    set myProject to project "mameosx"
    set myTarget to target "#{target}" of myProject
    set myRoot to root group of myProject
    set myMameGroup to group "mame" of myRoot
    set myGroup to group "#{group}" of myMameGroup

    tell myGroup
      set fileID to make new file reference with properties {full path: "#{full_path}", name: "#{name}"}
      add fileID to myTarget
    end
  end tell  
  END_OF_APPLESCRIPT
  run_applescript(applescript)
end

vars = MakeVariables.new
vars.run(ARGV)

#puts vars.sound_sources
#puts vars.cpu_sources
#puts vars.driver_sources

if false
  target = "sounds"
group = "sound"
remove_files(target, group)
full_paths = vars.sound_sources
size = full_paths.size
full_paths.each_with_index do |full_path, i|
  printf "%d/%d: %s\n", i, size, full_path
  add_file(target, group, full_path)
end
end
#full_paths = vars.sound_sources

#scpt = ERB.new(DATA.read, nil, '-').result
#IO.popen("osascript", "w") { |osa| osa.puts scpt }

__END__

tell application "Xcode"
  set myProject to project "mameosx"
  set myTarget to target "<%= target %>" of myProject
  set myRoot to root group of myProject
  set myMameGroup to group "mame" of myRoot
  set myGroup to group "<%= group %>" of myMameGroup
  delete (every file reference of myGroup)

  tell myGroup
    <%- for full_path in full_paths -%>
    <%- name = File.basename(full_path) -%>
    set fileID to make new file reference with properties {full path: "<%= full_path %>", name: "<%= name %>"}
    add fileID to myTarget

    <%- end -%>
  end
end
