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

  def self.current_time_vars
    now = Time.now
    {
      'date' => now.strftime('%Y-%m-%d'),
      'year' => now.strftime('%Y'),
      'month' => now.strftime('%m'),
      'id' => now.to_i.to_s
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
    SecureRandom.hex(3)
  end
end
