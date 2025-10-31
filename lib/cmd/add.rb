#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config'
require_relative '../indexer'
require_relative '../models/note'
require 'erb'
require 'fileutils'

# Add command for creating new notes
class AddCommand
  def run(type, *_args)
    config = Config.load
    template_config = get_template_config(config, type)
    template_file = find_template_file(config['notebook_path'], template_config['template_file'])
    content = render_template(template_file, type)
    filepath = create_note_file(config, template_config, type, content)
    index_note(config, filepath)
    puts "Note created: #{filepath}"
  end

  private

  def get_template_config(config, type)
    template_config = Config.get_template(config, type)
    return template_config if template_config

    puts "Template not found: #{type}"
    exit 1
  end

  def find_template_file(notebook_path, template_filename)
    local_file = File.join(notebook_path, '.zk', 'templates', template_filename)
    global_file = File.join(Dir.home, '.config', 'zk-next', 'templates', template_filename)

    return local_file if File.exist?(local_file)
    return global_file if File.exist?(global_file)

    puts "Template file not found: #{template_filename}"
    puts 'Searched locations:'
    puts "  #{local_file}"
    puts "  #{global_file}"
    exit 1
  end

  def render_template(template_file, type)
    template = ERB.new(File.read(template_file))
    date = Time.now.strftime('%Y-%m-%d')
    year = Time.now.strftime('%Y')
    month = Time.now.strftime('%m')
    id = Time.now.to_i.to_s
    template.result(binding)
  end

  def create_note_file(config, template_config, type, content)
    variables = build_variables(type, content)
    filename = interpolate_pattern(template_config['filename_pattern'], variables)
    subdirectory = interpolate_pattern(template_config['subdirectory'], variables)
    target_dir = determine_target_dir(config['notebook_path'], subdirectory)
    FileUtils.mkdir_p(target_dir)
    filepath = File.join(target_dir, filename)
    File.write(filepath, content)
    filepath
  end

  def build_variables(type, content)
    note_metadata = extract_metadata(content)
    {
      'type' => type,
      'date' => Time.now.strftime('%Y-%m-%d'),
      'year' => Time.now.strftime('%Y'),
      'month' => Time.now.strftime('%m'),
      'id' => Time.now.to_i.to_s
    }.merge(note_metadata)
  end

  def determine_target_dir(notebook_path, subdirectory)
    subdirectory.empty? ? notebook_path : File.join(notebook_path, subdirectory)
  end

  def index_note(config, filepath)
    note = Note.new(filepath)
    indexer = Indexer.new(config)
    indexer.index_note(note)
  end

  def extract_metadata(content)
    return {} unless content.start_with?('---')

    parts = content.split('---', 3)
    return {} unless parts.size >= 3

    metadata = {}
    parts[1].scan(/^(\w+):\s*(.+)$/).each do |key, value|
      metadata[key] = value.strip
    end
    metadata
  end

  def interpolate_pattern(pattern, variables)
    result = pattern.dup
    variables.each do |key, value|
      result.gsub!("{#{key}}", value.to_s)
    end
    result
  end
end

AddCommand.new.run(*ARGV) if __FILE__ == $PROGRAM_NAME
