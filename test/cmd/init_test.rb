require 'minitest/autorun'
require 'tmpdir'
require 'yaml'
require_relative '../../lib/cmd/init'

class InitCommandTest < Minitest::Test
  def test_run_initializes_notebook
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        InitCommand.new.run
        assert Dir.exist?('.zk'), '.zk directory should be created'
        assert File.exist?('.zk/config.yaml'), 'config.yaml should be created'
        config = YAML.load_file('.zk/config.yaml')
        assert_equal Dir.pwd, config['notebook_path']
        # Templates are now stored as array of hashes, not array of strings
        assert config['templates'].is_a?(Array)
        assert_equal 1, config['templates'].length
        assert_equal 'note', config['templates'].first['type']
      end
    end
  end

  def test_run_already_initialized
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        InitCommand.new.run
        # Running again should not error
        output = capture_io { InitCommand.new.run }.first
        assert_includes output, 'Notebook already initialized'
        assert Dir.exist?('.zk')
      end
    end
  end

  def test_completion_output
    cmd = InitCommand.new
    output = capture_io { cmd.run('--completion') }.first
    assert_equal '', output.strip, 'Completion should return empty string'
  end

  def test_run_creates_correct_config_structure
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        InitCommand.new.run
        config = YAML.load_file('.zk/config.yaml')
        assert config.is_a?(Hash)
        assert_equal Dir.pwd, config['notebook_path']
        assert config['templates'].is_a?(Array)
        assert_equal 1, config['templates'].length
        template = config['templates'].first
        assert template.is_a?(Hash)
        assert_equal 'note', template['type']
        assert_equal 'note.erb', template['template_file']
        assert_equal '{type}-{date}.md', template['filename_pattern']
        assert_equal '', template['subdirectory']
      end
    end
  end

  def test_run_preserves_existing_config_when_already_initialized
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        InitCommand.new.run
        # Modify config
        config = YAML.load_file('.zk/config.yaml')
        config['custom_key'] = 'custom_value'
        File.write('.zk/config.yaml', config.to_yaml)
        
        # Run init again
        InitCommand.new.run
        
        # Config should still have custom key
        config_after = YAML.load_file('.zk/config.yaml')
        assert_equal 'custom_value', config_after['custom_key']
      end
    end
  end

  private

  def capture_io
    require 'stringio'
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    [$stdout.string, '']
  ensure
    $stdout = old_stdout
  end
end
