#!/usr/bin/env ruby

require 'English'
require 'yaml'
require 'tempfile'

Dir[File.join(__dir__, '..', 'tasks/**/*.sh')].each do |script|
  print "shellcheck #{script} - "
  output = `shellcheck #{script}`
  if $CHILD_STATUS.exitstatus == 0
    puts 'passed'
  else
    puts 'failed'
    print output if ENV['VERBOSE'] == '1'
  end
end

Dir[File.join(__dir__, '..', 'tasks/**/*.yml')].each do |file|
    task = YAML.load_file(file)

    if task.dig('run', 'path') == 'bash'
        print "shellcheck #{file} - "

        script = Tempfile.new('script')
        script.write(task.dig('run', 'args', 1))
        script.close

        output = `shellcheck -s bash #{script.path}`
        if $CHILD_STATUS.exitstatus == 0
          puts 'passed'
        else
          puts 'failed'
          print output if ENV['VERBOSE'] == '1'
        end
    end
end
