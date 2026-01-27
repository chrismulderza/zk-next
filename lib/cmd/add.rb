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
  def initialize
    @debug = ENV['ZKN_DEBUG'] == '1'
  end

  def run(*args)
    return output_completion if args.first == '--completion'

    type, title, tags, title_provided, tags_provided = parse_args(args)
    debug_print("Type: #{type}")

    # Prompt for missing values only if they were not explicitly provided
    # Empty strings are treated as "explicitly provided but empty" (no prompt)
    if !title_provided && !tags_provided
      # Neither provided, prompt for both
      title, tags = prompt_interactive
    elsif !title_provided
      # Only tags provided, prompt for title
      title = prompt_title
    elsif !tags_provided
      # Only title provided, prompt for tags
      tags = prompt_tags
    end

    # Use defaults if still nil
    title ||= ''
    tags = parse_tags(tags) if tags.is_a?(String)
    tags ||= []

    config = Config.load(debug: @debug)
    template_config = get_template_config(config, type)
    template_file = find_template_file(config['notebook_path'], template_config['template_file'])
    content = render_template(template_file, type, title: title, tags: tags, config: config)
    filepath = create_note_file(config, template_config, type, content)
    index_note(config, filepath)
    puts "Note created: #{filepath}"
  end

  private

  def debug_print(message)
    return unless @debug

    $stderr.puts("[DEBUG] #{message}")
  end

  def parse_args(args)
    title = nil
    tags = nil
    type = nil
    title_provided = false
    tags_provided = false

    i = 0
    while i < args.length
      case args[i]
      when '--title', '-t'
        title_provided = true
        # Get value if it exists
        if i + 1 < args.length
          value = args[i + 1]
          title = value unless value.to_s.strip.empty?
        end
        i += 2
      when '--tags'
        tags_provided = true
        # Get value if it exists
        if i + 1 < args.length
          value = args[i + 1]
          tags = value unless value.to_s.strip.empty?
        end
        i += 2
      else
        # First non-flag argument is the type
        if type.nil? && !args[i].start_with?('--')
          type = args[i]
        end
        i += 1
      end
    end

    # Default to 'note' if no type argument was provided
    type ||= 'note'

    # Return flags indicating whether arguments were explicitly provided
    # This allows distinguishing between "not provided" (should prompt) and "provided as empty" (should not prompt)
    [type, title, tags, title_provided, tags_provided]
  end

  def parse_tags(tags_string)
    return [] if tags_string.nil? || tags_string.strip.empty?

    tags_string.split(',')
               .map(&:strip)
               .reject(&:empty?)
  end

  def prompt_interactive
    title = prompt_title
    tags = prompt_tags
    [title, tags]
  end

  def prompt_title
    if system('command -v gum > /dev/null 2>&1')
      `gum input --placeholder "Enter note title"`.strip
    else
      print 'Enter note title: '
      $stdin.gets.chomp
    end
  end

  def prompt_tags
    if system('command -v gum > /dev/null 2>&1')
      input = `gum input --placeholder "Enter tags (comma-separated)"`.strip
      parse_tags(input)
    else
      print 'Enter tags (comma-separated): '
      input = $stdin.gets.chomp
      parse_tags(input)
    end
  end

  def format_tags_for_yaml(tags)
    return '[]' if tags.nil? || tags.empty?

    # Return inline array format that can be inserted directly into YAML
    # Escape quotes in tag values
    "[#{tags.map { |t| "\"#{t.to_s.gsub('"', '\\"')}\"" }.join(', ')}]"
  end

  def output_completion
    begin
      config = Config.load(debug: @debug)
      templates = config['templates'] || []
      debug_print("Completion: templates array size: #{templates.size}")
      return unless templates.is_a?(Array)

      template_types = templates.map { |t| t['type'] }.compact.uniq.sort
      debug_print("Completion: available template types: #{template_types.join(', ')}")
      puts template_types.join(' ')
    rescue StandardError => e
      debug_print("Completion: error loading config: #{e.message}")
      # Fallback to default if config can't be loaded
      puts 'note'
    end
  end

  def get_template_config(config, type)
    templates = config['templates'] || []
    debug_print("Searching for template type: #{type}")
    
    if templates.is_a?(Array)
      available_types = templates.map { |t| t['type'] }.compact.uniq.sort
      debug_print("Available template types: #{available_types.join(', ')}")
    else
      debug_print("Templates is not an array: #{templates.class}")
    end
    
    template_config = Config.get_template(config, type, debug: @debug)
    if template_config
      debug_print("Template config found: #{template_config.inspect}")
      return template_config
    end

    debug_print("Template config not found for type: #{type}")
    puts "Template not found: #{type}"
    exit 1
  end

  def find_template_file(notebook_path, template_filename) # rubocop:disable Metrics/MethodLength
    debug_print("Searching template file: #{template_filename}")
    template_file = Utils.find_template_file(notebook_path, template_filename, debug: @debug)
    unless template_file
      local_file = File.join(notebook_path, '.zk', 'templates', template_filename)
      global_file = File.join(Dir.home, '.config', 'zk-next', 'templates', template_filename)
      puts "Template file not found: #{template_filename}"
      puts 'Searched locations:'
      puts "  #{local_file}"
      puts "  #{global_file}"
      exit 1
    end
    debug_print("Template file found: #{template_file}")
    template_file
  end

  def render_template(template_file, type, title: '', tags: [], config: nil)
    template = ERB.new(File.read(template_file))
    date_format = config ? Config.get_date_format(config) : Config.default_date_format
    vars = Utils.current_time_vars(date_format: date_format)
    vars['type'] = type
    vars['title'] = title
    formatted_tags = format_tags_for_yaml(tags)
    vars['tags'] = formatted_tags
    # Generate alias using configured pattern
    alias_pattern = config ? Config.get_alias_pattern(config) : Config.default_alias_pattern
    vars['aliases'] = Utils.interpolate_pattern(alias_pattern, vars)
    # Provide default values for template variables to prevent undefined variable errors
    vars['content'] ||= ''
    # Create binding context with slugify available
    context = OpenStruct.new(vars)
    replacement_char = config ? Config.get_slugify_replacement(config) : Config.default_slugify_replacement
    context.define_singleton_method(:slugify) { |text| Utils.slugify(text, replacement_char: replacement_char) }
    begin
      result = template.result(context.instance_eval { binding })
      result
    rescue SyntaxError => e
      raise
    end
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
    # Strip leading --- delimiter since to_yaml already includes it
    front_matter_yaml = metadata.to_yaml.sub(/^---\n/, '')

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
