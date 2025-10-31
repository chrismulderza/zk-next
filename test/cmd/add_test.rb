require 'minitest/autorun'
require 'tmpdir'
require 'yaml'
require 'fileutils'
require_relative '../../lib/cmd/add'
require_relative '../../lib/cmd/init'
require_relative '../../lib/config'

class AddCommandTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @temp_home = Dir.mktmpdir
    @global_config_file = File.join(@temp_home, '.config', 'zk-next', 'config.yaml')
    @original_config_file = Config::CONFIG_FILE
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @global_config_file)

    Dir.singleton_class.class_eval do
      alias_method :original_home, :home
      define_method(:home) { @temp_home }
    end
    Dir.instance_variable_set(:@temp_home, @temp_home)

    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    global_config = { 'notebook_path' => @tmpdir, 'templates' => [] }
    File.write(@global_config_file, global_config.to_yaml)

    Dir.chdir(@tmpdir) do
      InitCommand.new.run
      template_dir = File.join(@temp_home, '.config', 'zk-next', 'templates')
      FileUtils.mkdir_p(template_dir)
      template_content = <<~ERB
        ---
        id: <%= id %>
        type: <%= type %>
        ---
        # <%= type %>
        Content
      ERB
      File.write(File.join(template_dir, 'default.erb'), template_content)
    end
  end

  def teardown
    Dir.singleton_class.class_eval do
      alias_method :home, :original_home
      remove_method :original_home
    end
    FileUtils.remove_entry @tmpdir
    FileUtils.remove_entry @temp_home
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @original_config_file)
  end

  def test_run_creates_note
    Dir.chdir(@tmpdir) do
      AddCommand.new.run('default')
      files = Dir.glob('*.md')
      assert_equal 1, files.size
      file = files.first
      assert_match(/default-\d{4}-\d{2}-\d{2}\.md/, file)
      content = File.read(file)
      assert_match(/# default/, content)
      assert_match(/Content/, content)
    end
  end

  def test_run_creates_note_with_custom_filename_pattern
    Dir.chdir(@tmpdir) do
      config = YAML.load_file('.zk/config.yaml')
      config['templates'] = [
        {
          'type' => 'custom',
          'template_file' => 'custom.erb',
          'filename_pattern' => '{id}-{type}.md',
          'subdirectory' => ''
        }
      ]
      File.write('.zk/config.yaml', config.to_yaml)

      template_dir = File.join(@temp_home, '.config', 'zk-next', 'templates')
      template_content = <<~ERB
        ---
        id: <%= id %>
        type: <%= type %>
        ---
        # Custom
      ERB
      File.write(File.join(template_dir, 'custom.erb'), template_content)

      AddCommand.new.run('custom')
      files = Dir.glob('*.md')
      assert_equal 1, files.size
      assert_match(/^\d+-custom\.md$/, files.first)
    end
  end

  def test_run_creates_note_in_subdirectory
    Dir.chdir(@tmpdir) do
      config = YAML.load_file('.zk/config.yaml')
      config['templates'] = [
        {
          'type' => 'journal',
          'template_file' => 'journal.erb',
          'filename_pattern' => '{date}-journal.md',
          'subdirectory' => 'journal/{year}'
        }
      ]
      File.write('.zk/config.yaml', config.to_yaml)

      template_dir = File.join(@temp_home, '.config', 'zk-next', 'templates')
      template_content = <<~ERB
        ---
        id: <%= id %>
        type: journal
        date: <%= date %>
        ---
        # Journal Entry
      ERB
      File.write(File.join(template_dir, 'journal.erb'), template_content)

      AddCommand.new.run('journal')
      year = Time.now.strftime('%Y')
      journal_dir = File.join('journal', year)
      assert Dir.exist?(journal_dir)
      files = Dir.glob(File.join(journal_dir, '*.md'))
      assert_equal 1, files.size
      assert_match(/\d{4}-\d{2}-\d{2}-journal\.md/, File.basename(files.first))
    end
  end

  def test_run_with_metadata_in_filename_pattern
    Dir.chdir(@tmpdir) do
      config = YAML.load_file('.zk/config.yaml')
      config['templates'] = [
        {
          'type' => 'meeting',
          'template_file' => 'meeting.erb',
          'filename_pattern' => 'meeting-{date}-{title}.md',
          'subdirectory' => 'meetings/{year}/{month}'
        }
      ]
      File.write('.zk/config.yaml', config.to_yaml)

      template_dir = File.join(@temp_home, '.config', 'zk-next', 'templates')
      template_content = <<~ERB
        ---
        id: <%= id %>
        type: meeting
        title: standup
        date: <%= date %>
        ---
        # Meeting Notes
      ERB
      File.write(File.join(template_dir, 'meeting.erb'), template_content)

      AddCommand.new.run('meeting')
      assert Dir.exist?('meetings')
      files = Dir.glob(File.join('meetings', '**', '*.md'))
      assert_equal 1, files.size
      assert_match(/meeting-\d{4}-\d{2}-\d{2}-standup\.md/, File.basename(files.first))
    end
  end
end
