require 'minitest/autorun'
require 'tmpdir'
require 'yaml'
require 'fileutils'
require 'sqlite3'
require_relative '../../lib/cmd/reindex'
require_relative '../../lib/cmd/init'
require_relative '../../lib/config'

class ReindexCommandTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @temp_home = Dir.mktmpdir
    @global_config_file = File.join(@temp_home, '.config', 'zk-next', 'config.yaml')
    @original_config_file = Config::CONFIG_FILE
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @global_config_file)

    # Mock Dir.home
    Dir.singleton_class.class_eval do
      alias_method :original_home, :home
      define_method(:home) { @temp_home }
    end
    Dir.instance_variable_set(:@temp_home, @temp_home)

    # Mock ENV['HOME']
    @original_home_env = ENV['HOME']
    ENV['HOME'] = @temp_home

    config_dir = File.join(@temp_home, '.config', 'zk-next')
    FileUtils.mkdir_p(config_dir)
    global_config = { 'notebook_path' => @tmpdir, 'templates' => [] }
    File.write(@global_config_file, global_config.to_yaml)

    Dir.chdir(@tmpdir) do
      InitCommand.new.run
    end

    @db_path = File.join(@tmpdir, '.zk', 'index.db')
  end

  def teardown
    Dir.singleton_class.class_eval do
      alias_method :home, :original_home
      remove_method :original_home
    end
    ENV['HOME'] = @original_home_env if @original_home_env
    FileUtils.remove_entry @tmpdir
    FileUtils.remove_entry @temp_home
    Config.send(:remove_const, :CONFIG_FILE)
    Config.const_set(:CONFIG_FILE, @original_config_file)
  end

  def test_reindex_indexes_all_markdown_files
    Dir.chdir(@tmpdir) do
      # Create multiple markdown files
      note1 = <<~EOF
        ---
        id: note1
        type: note
        title: First Note
        ---
        # First Note
        Content of first note
      EOF
      File.write('note1.md', note1)

      note2 = <<~EOF
        ---
        id: note2
        type: note
        title: Second Note
        ---
        # Second Note
        Content of second note
      EOF
      File.write('note2.md', note2)

      # Create a subdirectory with a note
      FileUtils.mkdir_p('subdir')
      note3 = <<~EOF
        ---
        id: note3
        type: note
        title: Third Note
        ---
        # Third Note
        Content of third note
      EOF
      File.write('subdir/note3.md', note3)

      # Run reindex
      output = capture_io { ReindexCommand.new.run }.first

      # Verify output
      assert_match(/Found 3 markdown files/, output)
      assert_match(/Indexed 3 files/, output)

      # Verify all notes are in database
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT id FROM notes ORDER BY id')
      assert_equal 3, result.length
      ids = result.map(&:first).sort
      assert_equal ['note1', 'note2', 'note3'], ids
      db.close
    end
  end

  def test_reindex_skips_zk_directory
    Dir.chdir(@tmpdir) do
      # Create a note in the root
      note1 = <<~EOF
        ---
        id: root_note
        type: note
        title: Root Note
        ---
        # Root Note
      EOF
      File.write('root_note.md', note1)

      # Create a markdown file in .zk directory (should be skipped)
      FileUtils.mkdir_p('.zk/templates')
      zk_note = <<~EOF
        ---
        id: zk_note
        type: note
        title: ZK Note
        ---
        # ZK Note
      EOF
      File.write('.zk/zk_note.md', zk_note)

      # Run reindex
      output = capture_io { ReindexCommand.new.run }.first

      # Verify output shows only 1 file
      assert_match(/Found 1 markdown files/, output)
      assert_match(/Indexed 1 files/, output)

      # Verify only root note is in database
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT id FROM notes')
      assert_equal 1, result.length
      assert_equal 'root_note', result[0][0]
      db.close
    end
  end

  def test_reindex_updates_existing_notes
    Dir.chdir(@tmpdir) do
      # Create initial note
      note_content = <<~EOF
        ---
        id: update_test
        type: note
        title: Original Title
        ---
        # Original Title
        Original content
      EOF
      File.write('update_test.md', note_content)

      # Index it first
      require_relative '../../lib/indexer'
      require_relative '../../lib/models/note'
      config = Config.load
      indexer = Indexer.new(config)
      note = Note.new(path: File.join(@tmpdir, 'update_test.md'))
      indexer.index_note(note)

      # Verify original content
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT title, body FROM notes WHERE id = ?', ['update_test'])
      assert_equal 'Original Title', result[0][0]
      assert_includes result[0][1], 'Original content'
      db.close

      # Update the note
      updated_content = <<~EOF
        ---
        id: update_test
        type: note
        title: Updated Title
        ---
        # Updated Title
        Updated content
      EOF
      File.write('update_test.md', updated_content)

      # Run reindex
      capture_io { ReindexCommand.new.run }

      # Verify updated content
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT title, body FROM notes WHERE id = ?', ['update_test'])
      assert_equal 1, result.length
      assert_equal 'Updated Title', result[0][0]
      assert_includes result[0][1], 'Updated content'
      db.close
    end
  end

  def test_reindex_handles_invalid_yaml
    Dir.chdir(@tmpdir) do
      # Create note with invalid YAML frontmatter
      invalid_note = <<~EOF
        ---
        id: invalid
        type: note
        title: Invalid Note
        invalid: [unclosed bracket
        ---
        # Invalid Note
        Content
      EOF
      File.write('invalid.md', invalid_note)

      # Create valid note
      valid_note = <<~EOF
        ---
        id: valid
        type: note
        title: Valid Note
        ---
        # Valid Note
        Content
      EOF
      File.write('valid.md', valid_note)

      # Run reindex
      output = capture_io { ReindexCommand.new.run }.first
      error_output = capture_io { ReindexCommand.new.run }.last

      # Verify output shows 2 files found, but only 1 indexed
      assert_match(/Found 2 markdown files/, output)
      assert_match(/Indexed 1 files/, output)
      assert_match(/Skipped 1 files due to errors/, output)
      assert_match(/Failed to index.*invalid\.md/, error_output)

      # Verify only valid note is in database
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT id FROM notes')
      assert_equal 1, result.length
      assert_equal 'valid', result[0][0]
      db.close
    end
  end

  def test_reindex_handles_files_without_frontmatter
    Dir.chdir(@tmpdir) do
      # Create note without frontmatter (Note class will generate an ID)
      no_frontmatter = <<~EOF
        # Note Without Frontmatter
        This note has no YAML frontmatter.
      EOF
      File.write('no_frontmatter.md', no_frontmatter)

      # Create note with frontmatter
      with_frontmatter = <<~EOF
        ---
        id: with_frontmatter
        type: note
        title: With Frontmatter
        ---
        # With Frontmatter
        Content
      EOF
      File.write('with_frontmatter.md', with_frontmatter)

      # Run reindex
      output = capture_io { ReindexCommand.new.run }.first

      # Verify both files are indexed (Note class handles missing frontmatter)
      assert_match(/Found 2 markdown files/, output)
      assert_match(/Indexed 2 files/, output)

      # Verify both notes are in database
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT id FROM notes')
      assert_equal 2, result.length
      db.close
    end
  end

  def test_reindex_provides_progress_feedback
    Dir.chdir(@tmpdir) do
      # Create multiple notes
      3.times do |i|
        note = <<~EOF
          ---
          id: note#{i}
          type: note
          title: Note #{i}
          ---
          # Note #{i}
          Content
        EOF
        File.write("note#{i}.md", note)
      end

      # Run reindex and capture output
      output = capture_io { ReindexCommand.new.run }.first

      # Verify progress feedback
      assert_match(/Found \d+ markdown files/, output)
      assert_match(/Indexed \d+ files/, output)
      assert_match(/Found 3 markdown files/, output)
      assert_match(/Indexed 3 files/, output)
    end
  end

  def test_reindex_handles_missing_notebook_path
    # Temporarily break the config
    broken_config = { 'notebook_path' => '/nonexistent/path' }
    File.write(@global_config_file, broken_config.to_yaml)

    # Run reindex - should exit with error
    assert_raises(SystemExit) do
      capture_io { ReindexCommand.new.run }
    end
  end

  def test_reindex_completion_output
    cmd = ReindexCommand.new
    output = capture_io { cmd.run('--completion') }.first
    assert_equal '', output.strip, 'Completion should return empty string'
  end

  def test_reindex_help_output
    cmd = ReindexCommand.new
    output = capture_io { cmd.run('--help') }.first
    assert_match(/Re-index all markdown files/, output)
    assert_match(/USAGE:/, output)
    assert_match(/DESCRIPTION:/, output)
    assert_match(/OPTIONS:/, output)
    assert_match(/EXAMPLES:/, output)
    assert_match(/zkn reindex/, output)
  end

  def test_reindex_help_short_flag
    cmd = ReindexCommand.new
    output = capture_io { cmd.run('-h') }.first
    assert_match(/Re-index all markdown files/, output)
    assert_match(/USAGE:/, output)
  end

  def test_reindex_handles_nested_directories
    Dir.chdir(@tmpdir) do
      # Create nested directory structure
      FileUtils.mkdir_p('level1/level2/level3')

      note1 = <<~EOF
        ---
        id: nested1
        type: note
        title: Nested Note 1
        ---
        # Nested Note 1
      EOF
      File.write('level1/note1.md', note1)

      note2 = <<~EOF
        ---
        id: nested2
        type: note
        title: Nested Note 2
        ---
        # Nested Note 2
      EOF
      File.write('level1/level2/note2.md', note2)

      note3 = <<~EOF
        ---
        id: nested3
        type: note
        title: Nested Note 3
        ---
        # Nested Note 3
      EOF
      File.write('level1/level2/level3/note3.md', note3)

      # Run reindex
      output = capture_io { ReindexCommand.new.run }.first

      # Verify all nested notes are indexed
      assert_match(/Found 3 markdown files/, output)
      assert_match(/Indexed 3 files/, output)

      # Verify all notes are in database
      db = SQLite3::Database.new(@db_path)
      result = db.execute('SELECT id FROM notes ORDER BY id')
      assert_equal 3, result.length
      ids = result.map(&:first).sort
      assert_equal ['nested1', 'nested2', 'nested3'], ids
      db.close
    end
  end

  private

  def capture_io
    require 'stringio'
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end
