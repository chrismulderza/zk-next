require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require_relative '../lib/config'

class ConfigTest < Minitest::Test
  def setup
    @temp_home = Dir.mktmpdir
    @temp_dir = Dir.mktmpdir
    @original_pwd = Dir.pwd
    @global_config_file = File.join(@temp_home, '.config', 'zk-next', 'config.yaml')
    @original_config_file = Config::CONFIG_FILE
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @global_config_file)
  end

  def teardown
    FileUtils.rm_rf(@temp_home)
    FileUtils.rm_rf(@temp_dir)
    Dir.chdir(@original_pwd)
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
      assert_equal @temp_dir, config['notebook_path']
      assert_equal ['custom'], config['templates']
      assert_equal 'global', config['global_key']
      assert_equal 'local', config['local_key']
    end
  end

  def test_load_raises_when_no_global_config
    Dir.chdir(@temp_dir) do
      assert_raises(RuntimeError) do
        Config.load
      end
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
end
