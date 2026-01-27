#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require_relative '../config'

# Init command for initializing a new notebook
class InitCommand
  def run(*args)
    return output_completion if args.first == '--completion'

    zk_dir = '.zk'
    Dir.mkdir(zk_dir) unless Dir.exist?(zk_dir)

    config_file = File.join(zk_dir, 'config.yaml')
    if File.exist?(config_file)
      puts 'Notebook already initialized'
    else
      config = {
        'notebook_path' => Dir.pwd,
        'date_format' => Config.default_date_format,
        'slugify_replacement' => Config.default_slugify_replacement,
        'alias_pattern' => Config.default_alias_pattern,
        'templates' => [
          {
            'type' => 'note',
            'template_file' => 'note.erb',
            'filename_pattern' => '{type}-{date}.md',
            'subdirectory' => ''
          }
        ]
      }
      File.write(config_file, config.to_yaml)
      puts "Initialized notebook in #{Dir.pwd}"
      puts 'Created .zk/config.yaml'
    end
  end

  private

  def output_completion
    # Init takes no arguments
    puts ''
  end
end

InitCommand.new.run(*ARGV) if __FILE__ == $PROGRAM_NAME
