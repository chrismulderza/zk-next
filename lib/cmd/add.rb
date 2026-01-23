#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config'
require_relative '../indexer'
require_relative '../models/note'
require_relative '../utils'
require 'erb'
require 'fileutils'
require 'ostruct'

# Add command for creating new notes
class AddCommand
  def run(*args)
    return output_completion if args.first == '--completion'

    type = args.first || 'note'
    config = Config.load
    template_config = get_template_config(config, type)
    template_file = find_template_file(config['notebook_path'], template_config['template_file'])
    content = render_template(template_file, type)
    filepath = create_note_file(config, template_config, type, content)
    index_note(config, filepath)
    puts "Note created: #{filepath}"
  end

  private

  def output_completion
    begin
      config = Config.load
      templates = config['templates'] || []
      return unless templates.is_a?(Array)

      template_types = templates.map { |t| t['type'] }.compact.uniq.sort
      puts template_types.join(' ')
    rescue StandardError
      # Fallback to default if config can't be loaded
      puts 'note'
    end
  end

  def get_template_config(config, type)
    template_config = Config.get_template(config, type)
    return template_config if template_config

    puts "Template not found: #{type}"
    exit 1
  end

  def find_template_file(notebook_path, template_filename) # rubocop:disable Metrics/MethodLength
    template_file = Utils.find_template_file(notebook_path, template_filename)
    unless template_file
      local_file = File.join(notebook_path, '.zk', 'templates', template_filename)
      global_file = File.join(Dir.home, '.config', 'zk-next', 'templates', template_filename)
      puts "Template file not found: #{template_filename}"
      puts 'Searched locations:'
      puts "  #{local_file}"
      puts "  #{global_file}"
      exit 1
    end
    template_file
  end

  def render_template(template_file, type)
    template = ERB.new(File.read(template_file))
    vars = Utils.current_time_vars
    vars['type'] = type
    template.result(OpenStruct.new(vars).instance_eval { binding })
  end

  def create_note_file(config, template_config, type, content)
    variables = build_variables(type, content)
    filename = Utils.interpolate_pattern(template_config['filename_pattern'], variables)
    subdirectory = Utils.interpolate_pattern(template_config['subdirectory'], variables)
    target_dir = determine_target_dir(config['notebook_path'], subdirectory)
    FileUtils.mkdir_p(target_dir)
    filepath = File.join(target_dir, filename)
    File.write(filepath, content)
    filepath
  end

  def build_variables(type, content)
    note_metadata, = Utils.parse_front_matter(content)
    Utils.current_time_vars.merge('type' => type).merge(note_metadata)
  end

  def determine_target_dir(notebook_path, subdirectory)
    subdirectory.empty? ? notebook_path : File.join(notebook_path, subdirectory)
  end

  def index_note(config, filepath)
    note = Note.new(path: filepath)
    indexer = Indexer.new(config)
    indexer.index_note(note)
  end
end

AddCommand.new.run(*ARGV) if __FILE__ == $PROGRAM_NAME
