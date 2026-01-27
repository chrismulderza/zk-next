# frozen_string_literal: true

require 'yaml'
require 'date'
require 'securerandom'
require 'commonmarker'

module Utils
  def self.parse_front_matter(content)
    doc = Commonmarker.parse(content, options: { extension: { front_matter_delimiter: '---' } })
    frontmatter_str = nil
    doc.walk do |node|
      if node.type == :frontmatter
        frontmatter_str = node.to_commonmark
        break
      end
    end
    metadata = if frontmatter_str
                 YAML.safe_load(frontmatter_str, permitted_classes: [Date]) || {}
               else
                 {}
               end
    # Keep content_without as original, just remove frontmatter block
    if content.start_with?('---')
      parts = content.split('---', 3)
      content_without = parts.size >= 3 ? parts[2] : content
    else
      content_without = content
    end
    [metadata, content_without]
  end

  def self.current_time_vars(date_format: nil)
    require_relative 'config'
    now = Time.now
    format = date_format || Config.default_date_format
    {
      'date' => now.strftime(format),
      'year' => now.strftime('%Y'),
      'month' => now.strftime('%m'),
      'id' => Utils.generate_id
    }
  end

  def self.interpolate_pattern(pattern, variables)
    result = pattern.dup
    variables.each do |key, value|
      result.gsub!("{#{key}}", value.to_s)
    end
    result
  end

  def self.find_template_file(notebook_path, template_filename, debug: false)
    debug_print = ->(msg) { $stderr.puts("[DEBUG] #{msg}") if debug }
    
    local_file = File.join(notebook_path, '.zk', 'templates', template_filename)
    debug_print.call("Local path: #{local_file}")
    if File.exist?(local_file)
      debug_print.call("Local template file found")
      return local_file
    end
    debug_print.call("Local template file not found")

    global_file = File.join(ENV['HOME'], '.config', 'zk-next', 'templates', template_filename)
    debug_print.call("Global path: #{global_file}")
    if File.exist?(global_file)
      debug_print.call("Global template file found")
      return global_file
    end
    debug_print.call("Global template file not found")

    nil
  end

  def self.generate_id
    SecureRandom.hex(4)  # 8-character hex ID
  end

  def self.slugify(text, replacement_char: '-')
    return '' if text.nil? || text.to_s.empty?

    result = text.to_s.downcase
        .gsub(/[^a-z0-9\-_]/, replacement_char)  # Use replacement_char instead of underscore
        .gsub(/\s+/, replacement_char)            # Replace spaces with replacement_char
    
    # Handle empty replacement_char (remove characters)
    if replacement_char.empty?
      result = result.gsub(/[^a-z0-9]/, '')  # Remove all non-alphanumeric
    else
      # Escape the replacement character for use in regex
      escaped_char = Regexp.escape(replacement_char)
      result = result
          .gsub(/#{escaped_char}+/, replacement_char)  # Collapse multiple replacement chars
          .gsub(/^#{escaped_char}+|#{escaped_char}+$/, '')  # Remove leading/trailing replacement chars
    end
    
    result
  end
end
