#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config'
require_relative '../indexer'
require_relative '../models/note'
require_relative '../utils'
require 'erb'
require 'fileutils'
require 'ostruct'
require 'commonmarker'

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
    metadata, body = Utils.parse_front_matter(content)
    variables = build_variables(type, content)

    # Check for config.path override
    if metadata['config'] && metadata['config']['path']
      # Use config.path as filepath
      path_pattern = metadata['config']['path']
      filepath_relative = Utils.interpolate_pattern(path_pattern, variables)
      filepath = File.join(config['notebook_path'], filepath_relative)

      # Remove config from metadata
      metadata_without_config = metadata.dup
      metadata_without_config.delete('config')

      # Reconstruct content without config using CommonMarker
      content = reconstruct_content(metadata_without_config, body)
    else
      # Use existing logic
      filename = Utils.interpolate_pattern(template_config['filename_pattern'], variables)
      subdirectory = Utils.interpolate_pattern(template_config['subdirectory'], variables)
      target_dir = determine_target_dir(config['notebook_path'], subdirectory)
      filepath = File.join(target_dir, filename)
    end

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(filepath))
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

  def reconstruct_content(metadata, body)
    # Construct YAML front matter
    front_matter_yaml = metadata.to_yaml

    # Parse body to ensure it's valid markdown (validates structure)
    body_doc = Commonmarker.parse(body)
    validated_body = body_doc.to_commonmark

    # Construct full markdown with front matter
    markdown_string = "---\n#{front_matter_yaml}---\n\n#{validated_body}"

    # Parse the complete document to ensure proper structure
    final_doc = Commonmarker.parse(markdown_string, options: { extension: { front_matter_delimiter: '---' } })

    # Return properly formatted CommonMark
    final_doc.to_commonmark
  end

  def index_note(config, filepath)
    note = Note.new(path: filepath)
    indexer = Indexer.new(config)
    indexer.index_note(note)
  end
end

AddCommand.new.run(*ARGV) if __FILE__ == $PROGRAM_NAME
