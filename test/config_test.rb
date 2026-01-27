require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require_relative '../lib/config'

class ConfigTest < Minitest::Test
  def setup
    @temp_home = Dir.mktmpdir
    @temp_dir = Dir.mktmpdir
    @original_pwd = Dir.pwd
    @original_home = ENV['HOME']
    @original_notebook_path = ENV['ZKN_NOTEBOOK_PATH']
    ENV['HOME'] = @temp_home
    ENV.delete('ZKN_NOTEBOOK_PATH')
    @global_config_file = File.join(@temp_home, '.config', 'zk-next', 'config.yaml')
    @original_config_file = Config::CONFIG_FILE
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @global_config_file)
  end

  def teardown
    FileUtils.rm_rf(@temp_home)
    FileUtils.rm_rf(@temp_dir)
    Dir.chdir(@original_pwd)
    ENV['HOME'] = @original_home if @original_home
    if @original_notebook_path
      ENV['ZKN_NOTEBOOK_PATH'] = @original_notebook_path
    else
      ENV.delete('ZKN_NOTEBOOK_PATH')
    end
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @original_config_file)
  end

  def test_load_global_config_only
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    config_content = { 'notebook_path' => '/path/to/notebook', 'templates' => ['default'] }
    File.write(@global_config_file, config_content.to_yaml)
    Dir.chdir(@temp_dir) do
      config = Config.load
      assert_equal '/path/to/notebook', config['notebook_path']
      assert_equal ['default'], config['templates']
    end
  end

  def test_load_merges_local_config
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    global_config = { 'notebook_path' => @temp_dir, 'templates' => ['default'], 'global_key' => 'global' }
    File.write(@global_config_file, global_config.to_yaml)
    Dir.chdir(@temp_dir) do
      FileUtils.mkdir_p('.zk')
      local_config = { 'templates' => ['custom'], 'local_key' => 'local' }
      File.write('.zk/config.yaml', local_config.to_yaml)
      config = Config.load
      # Local config found via CWD should set notebook_path to CWD
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(@temp_dir), File.realpath(config['notebook_path'])
      assert_equal ['custom'], config['templates']
      assert_equal 'global', config['global_key']
      assert_equal 'local', config['local_key']
    end
  end

  def test_load_raises_when_no_config_found
    Dir.chdir(@temp_dir) do
      # No config anywhere should raise error
      error = assert_raises(RuntimeError) do
        Config.load
      end
      assert_match(/No config file found/, error.message)
      assert_match(/Searched locations/, error.message)
    end
  end

  def test_load_config_returns_nil_for_missing_file
    result = Config.load_config('/nonexistent/file.yaml')
    assert_nil result
  end

  def test_get_template_with_new_hash_format
    config = {
      'templates' => [
        {
          'type' => 'journal',
          'template_file' => 'journal.erb',
          'filename_pattern' => '{date}-journal.md',
          'subdirectory' => 'journal/{year}'
        }
      ]
    }
    template = Config.get_template(config, 'journal')
    assert_equal 'journal', template['type']
    assert_equal 'journal.erb', template['template_file']
    assert_equal '{date}-journal.md', template['filename_pattern']
    assert_equal 'journal/{year}', template['subdirectory']
  end

  def test_get_template_with_defaults
    config = {
      'templates' => [
        { 'type' => 'minimal' }
      ]
    }
    template = Config.get_template(config, 'minimal')
    assert_equal 'minimal', template['type']
    assert_equal 'minimal.erb', template['template_file']
    assert_equal '{type}-{date}.md', template['filename_pattern']
    assert_equal '', template['subdirectory']
  end

  def test_get_template_returns_nil_for_nonexistent_template
    config = { 'templates' => [{ 'type' => 'default' }] }
    template = Config.get_template(config, 'nonexistent')
    assert_nil template
  end

  def test_load_with_invalid_yaml_in_global_config
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    File.write(@global_config_file, 'invalid: yaml: content: [unclosed')
    Dir.chdir(@temp_dir) do
      assert_raises(Psych::SyntaxError) do
        Config.load
      end
    end
  end

  def test_load_with_invalid_yaml_in_local_config
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    global_config = { 'notebook_path' => @temp_dir, 'templates' => ['default'] }
    File.write(@global_config_file, global_config.to_yaml)
    Dir.chdir(@temp_dir) do
      FileUtils.mkdir_p('.zk')
      File.write('.zk/config.yaml', 'invalid: yaml: [unclosed')
      assert_raises(Psych::SyntaxError) do
        Config.load
      end
    end
  end

  def test_load_with_missing_notebook_path_in_global_config
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    config_content = { 'templates' => ['default'] }
    File.write(@global_config_file, config_content.to_yaml)
    Dir.chdir(@temp_dir) do
      # Missing notebook_path in global config should raise an error
      assert_raises(RuntimeError) do
        Config.load
      end
    end
  end

  def test_load_expands_relative_notebook_path
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    relative_path = '../relative-notebook'
    config_content = { 'notebook_path' => relative_path, 'templates' => ['default'] }
    File.write(@global_config_file, config_content.to_yaml)
    Dir.chdir(@temp_dir) do
      config = Config.load
      # Should expand to absolute path
      assert File.expand_path(relative_path, @temp_dir) == config['notebook_path'] ||
             File.expand_path(relative_path) == config['notebook_path']
    end
  end

  def test_get_template_with_string_array_old_format
    config = {
      'templates' => ['note', 'journal', 'meeting']
    }
    # Old format - should return nil since templates is not array of hashes
    template = Config.get_template(config, 'note')
    assert_nil template
  end

  def test_get_template_with_empty_templates_array
    config = { 'templates' => [] }
    template = Config.get_template(config, 'any')
    assert_nil template
  end

  def test_get_template_with_nil_templates
    config = { 'templates' => nil }
    template = Config.get_template(config, 'any')
    assert_nil template
  end

  def test_get_template_with_non_array_templates
    config = { 'templates' => 'not-an-array' }
    template = Config.get_template(config, 'any')
    assert_nil template
  end

  def test_get_template_with_non_hash_items
    config = {
      'templates' => [
        { 'type' => 'valid' },
        'invalid-string-item',
        { 'type' => 'another-valid' }
      ]
    }
    # Should find valid templates
    template1 = Config.get_template(config, 'valid')
    assert_equal 'valid', template1['type']
    
    template2 = Config.get_template(config, 'another-valid')
    assert_equal 'another-valid', template2['type']
  end

  def test_get_template_with_missing_type
    config = {
      'templates' => [
        { 'template_file' => 'missing-type.erb' }
      ]
    }
    # Template without type should not be findable by type
    template = Config.get_template(config, 'missing-type')
    assert_nil template
  end

  def test_normalize_template_with_all_defaults
    template = { 'type' => 'test' }
    normalized = Config.normalize_template(template)
    assert_equal 'test', normalized['type']
    assert_equal 'test.erb', normalized['template_file']
    assert_equal '{type}-{date}.md', normalized['filename_pattern']
    assert_equal '', normalized['subdirectory']
  end

  def test_normalize_template_with_partial_overrides
    template = {
      'type' => 'custom',
      'template_file' => 'custom-template.erb',
      # filename_pattern and subdirectory use defaults
    }
    normalized = Config.normalize_template(template)
    assert_equal 'custom', normalized['type']
    assert_equal 'custom-template.erb', normalized['template_file']
    assert_equal '{type}-{date}.md', normalized['filename_pattern']
    assert_equal '', normalized['subdirectory']
  end

  def test_normalize_template_with_all_overrides
    template = {
      'type' => 'full',
      'template_file' => 'full.erb',
      'filename_pattern' => '{id}-{type}.md',
      'subdirectory' => 'custom/path'
    }
    normalized = Config.normalize_template(template)
    assert_equal 'full', normalized['type']
    assert_equal 'full.erb', normalized['template_file']
    assert_equal '{id}-{type}.md', normalized['filename_pattern']
    assert_equal 'custom/path', normalized['subdirectory']
  end

  def test_load_expands_notebook_path_to_absolute
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    absolute_path = File.expand_path(@temp_dir)
    config_content = { 'notebook_path' => absolute_path, 'templates' => ['default'] }
    File.write(@global_config_file, config_content.to_yaml)
    Dir.chdir(@temp_dir) do
      config = Config.load
      assert_equal absolute_path, config['notebook_path']
    end
  end

  def test_load_merges_nested_structures_shallowly
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    global_config = {
      'notebook_path' => @temp_dir,
      'templates' => [
        { 'type' => 'global-template', 'template_file' => 'global.erb' }
      ],
      'other_key' => 'global-value'
    }
    File.write(@global_config_file, global_config.to_yaml)
    Dir.chdir(@temp_dir) do
      FileUtils.mkdir_p('.zk')
      local_config = {
        'templates' => [
          { 'type' => 'local-template', 'template_file' => 'local.erb' }
        ],
        'other_key' => 'local-value'
      }
      File.write('.zk/config.yaml', local_config.to_yaml)
      config = Config.load
      # Local config found via CWD, so notebook_path should be CWD
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(@temp_dir), File.realpath(config['notebook_path'])
      # Templates array should be replaced, not merged
      assert_equal 1, config['templates'].length
      assert_equal 'local-template', config['templates'].first['type']
      # Other keys should be merged
      assert_equal 'local-value', config['other_key']
    end
  end

  def test_load_finds_config_via_cwd
    Dir.chdir(@temp_dir) do
      FileUtils.mkdir_p('.zk')
      local_config = {
        'templates' => [
          { 'type' => 'note', 'template_file' => 'note.erb' }
        ]
      }
      File.write('.zk/config.yaml', local_config.to_yaml)
      config = Config.load
      # Should find config in CWD and set notebook_path to CWD
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(@temp_dir), File.realpath(config['notebook_path'])
      assert_equal 1, config['templates'].length
      assert_equal 'note', config['templates'].first['type']
    end
  end

  def test_load_finds_config_via_directory_walk
    # Create notebook in parent directory
    notebook_dir = File.join(@temp_home, 'notebook')
    FileUtils.mkdir_p(notebook_dir)
    FileUtils.mkdir_p(File.join(notebook_dir, '.zk'))
    local_config = {
      'templates' => [
        { 'type' => 'note', 'template_file' => 'note.erb' }
      ]
    }
    File.write(File.join(notebook_dir, '.zk', 'config.yaml'), local_config.to_yaml)
    
    # Create subdirectory and run from there
    subdir = File.join(notebook_dir, 'subdir', 'deep')
    FileUtils.mkdir_p(subdir)
    Dir.chdir(subdir) do
      config = Config.load
      # Should find config by walking up to notebook_dir
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(notebook_dir), File.realpath(config['notebook_path'])
      assert_equal 1, config['templates'].length
    end
  end

  def test_load_finds_config_via_env_var
    notebook_dir = File.join(@temp_home, 'notebook')
    FileUtils.mkdir_p(notebook_dir)
    FileUtils.mkdir_p(File.join(notebook_dir, '.zk'))
    local_config = {
      'templates' => [
        { 'type' => 'note', 'template_file' => 'note.erb' }
      ]
    }
    File.write(File.join(notebook_dir, '.zk', 'config.yaml'), local_config.to_yaml)
    
    ENV['ZKN_NOTEBOOK_PATH'] = notebook_dir
    Dir.chdir(@temp_dir) do
      config = Config.load
      # Should find config via env var
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(notebook_dir), File.realpath(config['notebook_path'])
      assert_equal 1, config['templates'].length
    end
  ensure
    ENV.delete('ZKN_NOTEBOOK_PATH')
  end

  def test_load_merges_local_with_global_when_found_via_cwd
    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    global_config = {
      'templates' => [
        { 'type' => 'global-template', 'template_file' => 'global.erb' }
      ],
      'global_key' => 'global-value'
    }
    File.write(@global_config_file, global_config.to_yaml)
    
    Dir.chdir(@temp_dir) do
      FileUtils.mkdir_p('.zk')
      local_config = {
        'templates' => [
          { 'type' => 'local-template', 'template_file' => 'local.erb' }
        ],
        'local_key' => 'local-value'
      }
      File.write('.zk/config.yaml', local_config.to_yaml)
      config = Config.load
      # Should merge: local overrides global
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(@temp_dir), File.realpath(config['notebook_path'])
      assert_equal 1, config['templates'].length
      assert_equal 'local-template', config['templates'].first['type']
      assert_equal 'global-value', config['global_key']
      assert_equal 'local-value', config['local_key']
    end
  end

  def test_load_stops_walk_at_home_directory
    # Create .zk in home directory
    FileUtils.mkdir_p(File.join(@temp_home, '.zk'))
    home_config = {
      'templates' => [
        { 'type' => 'home-template', 'template_file' => 'home.erb' }
      ]
    }
    File.write(File.join(@temp_home, '.zk', 'config.yaml'), home_config.to_yaml)
    
    # Create a subdirectory within home (not outside)
    subdir = File.join(@temp_home, 'subdir', 'deep')
    FileUtils.mkdir_p(subdir)
    
    Dir.chdir(subdir) do
      # Should find config in home directory by walking up
      config = Config.load
      # Use realpath to resolve symlinks (macOS /var -> /private/var)
      assert_equal File.realpath(@temp_home), File.realpath(config['notebook_path'])
      assert_equal 1, config['templates'].length
      assert_equal 'home-template', config['templates'].first['type']
    end
  end

  def test_find_zk_directory_walks_up_tree
    notebook_dir = File.join(@temp_home, 'notebook')
    FileUtils.mkdir_p(File.join(notebook_dir, '.zk'))
    
    subdir = File.join(notebook_dir, 'subdir', 'deep', 'nested')
    FileUtils.mkdir_p(subdir)
    
    found = Config.find_zk_directory(subdir)
    assert_equal File.join(notebook_dir, '.zk'), found
  end

  def test_find_zk_directory_returns_nil_when_not_found
    subdir = File.join(@temp_dir, 'subdir', 'deep')
    FileUtils.mkdir_p(subdir)
    
    found = Config.find_zk_directory(subdir)
    assert_nil found
  end

  def test_find_zk_directory_stops_at_home
    # Create .zk in a directory that would be above home if we kept walking
    # But we should stop at home
    FileUtils.mkdir_p(File.join(@temp_home, '.zk'))
    
    # Start from a subdirectory
    subdir = File.join(@temp_home, 'subdir')
    FileUtils.mkdir_p(subdir)
    
    found = Config.find_zk_directory(subdir)
    # Should find .zk in home
    assert_equal File.join(@temp_home, '.zk'), found
  end
end
