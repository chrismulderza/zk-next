# frozen_string_literal: true

require 'yaml'

# Configuration handling for zk-next
class Config
  CONFIG_DIR = File.join(ENV['HOME'], '.config', 'zk-next')
  CONFIG_FILE = File.join(CONFIG_DIR, 'config.yaml')

  # Find .zk directory by walking up from start_path until reaching home
  def self.find_zk_directory(start_path, debug: false)
    debug_print = ->(msg) { $stderr.puts("[DEBUG] #{msg}") if debug }
    
    current = File.expand_path(start_path)
    home = File.expand_path(ENV['HOME'] || Dir.home)
    
    loop do
      zk_dir = File.join(current, '.zk')
      if File.directory?(zk_dir)
        debug_print.call("Found .zk directory at: #{zk_dir}")
        return zk_dir
      end
      
      # Stop if we've reached home directory
      break if current == home || current == File.dirname(current)
      
      current = File.dirname(current)
    end
    
    nil
  end

  # Resolve notebook path and config using hierarchical resolution
  def self.resolve_notebook_path(debug: false) # rubocop:disable Metrics/MethodLength
    debug_print = ->(msg) { $stderr.puts("[DEBUG] #{msg}") if debug }
    searched_locations = []
    
    # 1. Check current working directory
    debug_print.call("Step 1: Checking current working directory for .zk")
    cwd = Dir.pwd
    zk_dir = find_zk_directory(cwd, debug: debug)
    if zk_dir
      notebook_path = File.dirname(zk_dir)
      config_file = File.join(zk_dir, 'config.yaml')
      if File.exist?(config_file)
        debug_print.call("Found config via CWD: #{config_file}")
        return { config_file: config_file, notebook_path: notebook_path, source: 'cwd' }
      end
    end
    searched_locations << "CWD and parent directories up to home"
    
    # 2. Walk up directory tree (already done in find_zk_directory, but check explicitly)
    # This is handled by find_zk_directory which walks up automatically
    
    # 3. Check ZKN_NOTEBOOK_PATH environment variable
    if ENV['ZKN_NOTEBOOK_PATH']
      debug_print.call("Step 3: Checking ZKN_NOTEBOOK_PATH environment variable")
      env_path = File.expand_path(ENV['ZKN_NOTEBOOK_PATH'])
      zk_dir = File.join(env_path, '.zk')
      if File.directory?(zk_dir)
        config_file = File.join(zk_dir, 'config.yaml')
        if File.exist?(config_file)
          debug_print.call("Found config via ZKN_NOTEBOOK_PATH: #{config_file}")
          return { config_file: config_file, notebook_path: env_path, source: 'env' }
        end
      end
      searched_locations << "ZKN_NOTEBOOK_PATH: #{env_path}"
    end
    
    # 4. Fall back to global config
    debug_print.call("Step 4: Checking global config location")
    if File.exist?(CONFIG_FILE)
      debug_print.call("Found global config: #{CONFIG_FILE}")
      global_config = load_config(CONFIG_FILE)
      if global_config && global_config['notebook_path']
        notebook_path = File.expand_path(global_config['notebook_path'])
        return { config_file: CONFIG_FILE, notebook_path: notebook_path, source: 'global' }
      end
    end
    searched_locations << "Global config: #{CONFIG_FILE}"
    
    # No config found
    error_msg = "No config file found. Searched locations:\n"
    searched_locations.each { |loc| error_msg += "  - #{loc}\n" }
    raise error_msg
  end

  def self.load(debug: false) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    debug_print = ->(msg) { $stderr.puts("[DEBUG] #{msg}") if debug }
    
    # Resolve notebook path using hierarchical resolution
    resolution = resolve_notebook_path(debug: debug)
    config_file = resolution[:config_file]
    notebook_path = File.expand_path(resolution[:notebook_path])
    source = resolution[:source]
    
    debug_print.call("Config resolution: found via #{source}")
    debug_print.call("Config file: #{config_file}")
    debug_print.call("Notebook path: #{notebook_path}")
    
    # Load the primary config
    primary_config = load_config(config_file)
    raise "Config file found but could not be loaded: #{config_file}" unless primary_config
    
    # If config was found via directory walk or env var, set notebook_path to parent of .zk
    # Otherwise, use notebook_path from config file (for global config)
    if source == 'cwd' || source == 'env'
      primary_config['notebook_path'] = notebook_path
      debug_print.call("Set notebook_path to resolved path: #{notebook_path}")
    elsif source == 'global'
      # Use notebook_path from global config, but expand it
      if primary_config['notebook_path']
        primary_config['notebook_path'] = File.expand_path(primary_config['notebook_path'])
        notebook_path = primary_config['notebook_path']
        debug_print.call("Using notebook_path from global config: #{notebook_path}")
      end
    end
    
    # Try to merge with global config if we found a local config
    merged_config = primary_config.dup
    if source == 'cwd' || source == 'env'
      # Check for global config to merge with
      if File.exist?(CONFIG_FILE) && config_file != CONFIG_FILE
        debug_print.call("Merging with global config: #{CONFIG_FILE}")
        global_config = load_config(CONFIG_FILE)
        if global_config
          merged_config = global_config.merge(primary_config)
          debug_print.call("Merged: local config overrides global")
        end
      end
    elsif source == 'global'
      # Check for local config at the notebook_path
      local_config_file = File.join(notebook_path, '.zk', 'config.yaml')
      debug_print.call("Checking for local config at notebook_path: #{local_config_file}")
      local_config = load_config(local_config_file)
      if local_config
        debug_print.call("Local config found, merging with global")
        merged_config = primary_config.merge(local_config)
      else
        debug_print.call("No local config found, using global only")
      end
    end
    
    # Ensure notebook_path is set and expanded
    merged_config['notebook_path'] = File.expand_path(notebook_path)
    
    if debug && merged_config['templates']
      templates = merged_config['templates']
      if templates.is_a?(Array)
        template_types = templates.map { |t| t['type'] }.compact.uniq
        debug_print.call("Final config templates: #{template_types.join(', ')}")
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
