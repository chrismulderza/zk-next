# frozen_string_literal: true

require 'yaml'

# Configuration handling for zk-next
class Config
  CONFIG_DIR = File.join(Dir.home, '.config', 'zk-next')
  CONFIG_FILE = File.join(CONFIG_DIR, 'config.yaml')

  def self.load
    global_config = load_config(CONFIG_FILE)
    raise "Global config file not found: #{CONFIG_FILE}" unless global_config

    notebook_path = File.expand_path(global_config['notebook_path'])
    local_config_file = File.join(notebook_path, '.zk', 'config.yaml')
    local_config = load_config(local_config_file)
    merged_config = if local_config
                      global_config.merge(local_config)
                    else
                      global_config
                    end
    merged_config['notebook_path'] = File.expand_path(merged_config['notebook_path'])
    merged_config
  end

  def self.load_config(file)
    YAML.load_file(file) if File.exist?(file)
  end

  def self.get_template(config, name)
    templates = config['templates']
    return nil unless templates
    return nil if templates.empty?
    return nil unless templates.is_a?(Array) && templates.first.is_a?(Hash)

    template = templates.find { |t| t['type'] == name }
    normalize_template(template) if template
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
