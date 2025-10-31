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
        assert_equal ['default'], config['templates']
      end
    end
  end

  def test_run_already_initialized
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        InitCommand.new.run
        # Running again should not error
        InitCommand.new.run
        assert Dir.exist?('.zk')
      end
    end
  end
end
