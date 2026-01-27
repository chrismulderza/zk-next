# frozen_string_literal: true

require 'yaml'

# Configuration handling for zk-next
class Config
  CONFIG_DIR = File.join(ENV['HOME'], '.config', 'zk-next')
  CONFIG_FILE = File.join(CONFIG_DIR, 'config.yaml')

  def self.load(debug: false) # rubocop:disable Metrics/MethodLength
    debug_print = ->(msg) { $stderr.puts("[DEBUG] #{msg}") if debug }
    
    debug_print.call("Loading config from: #{CONFIG_FILE}")
    global_config = load_config(CONFIG_FILE)
    raise "Global config file not found: #{CONFIG_FILE}" unless global_config
    debug_print.call("Global config loaded")

    notebook_path = File.expand_path(global_config['notebook_path'])
    local_config_file = File.join(notebook_path, '.zk', 'config.yaml')
    debug_print.call("Checking local config: #{local_config_file}")
    local_config = load_config(local_config_file)
    
    merged_config = if local_config
                      debug_print.call("Local config found, merging with global")
                      global_config.merge(local_config)
                    else
                      debug_print.call("Local config not found, using global only")
                      global_config
                    end
    merged_config['notebook_path'] = File.expand_path(merged_config['notebook_path'])
    
    if debug && merged_config['templates']
      templates = merged_config['templates']
      if templates.is_a?(Array)
        template_types = templates.map { |t| t['type'] }.compact.uniq
        debug_print.call("Merged config templates: #{template_types.join(', ')}")
        debug_print.call("Templates array size: #{templates.size}")
      else
        debug_print.call("Templates is not an array: #{templates.class}")
      end
    end
    
    merged_config
  end

  def self.load_config(file)
    YAML.load_file(file) if File.exist?(file)
  end

  def self.get_template(config, name, debug: false)
    debug_print = ->(msg) { $stderr.puts("[DEBUG] #{msg}") if debug }
    
    templates = config['templates']
    unless templates
      debug_print.call("Config has no 'templates' key")
      return nil
    end
    
    if templates.empty?
      debug_print.call("Templates array is empty")
      return nil
    end
    
    unless templates.is_a?(Array) && templates.first.is_a?(Hash)
      debug_print.call("Templates is not an array of hashes: #{templates.class}")
      return nil
    end

    template = templates.find { |t| t['type'] == name }
    if template
      debug_print.call("Found template with type '#{name}'")
      normalize_template(template)
    else
      debug_print.call("No template found with type '#{name}'")
      nil
    end
  end

  def self.normalize_template(template)
    {
      'type' => template['type'],
      'template_file' => template['template_file'] || "#{template['type']}.erb",
      'filename_pattern' => template['filename_pattern'] || '{type}-{date}.md',
      'subdirectory' => template['subdirectory'] || ''
    }
  end
end
