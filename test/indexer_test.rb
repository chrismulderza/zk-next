require 'minitest/autorun'
require 'tempfile'
require 'fileutils'
require_relative '../lib/indexer'
require_relative '../lib/models/note'

class IndexerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @config = { 'notebook_path' => @temp_dir }
    @indexer = Indexer.new(@config)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_index_note
    content = <<~EOF
      ---
      id: 123
      type: general
      ---
      # Title
      Content
    EOF
    note_path = File.join(@temp_dir, 'test-note.md')
    File.write(note_path, content)
    note = Note.new(path: note_path)
    @indexer.index_note(note)
    db = SQLite3::Database.new(File.join(@temp_dir, '.zk', 'index.db'))
    result = db.execute('SELECT id, path, metadata FROM notes WHERE id = ?', ['123'])
    assert_equal 1, result.length
    assert_equal '123', result[0][0]
    assert_equal 'test-note.md', result[0][1]
    assert_includes result[0][2], '"id":123'
    db.close
  end

  def test_index_note_replaces_existing
    content = <<~EOF
      ---
      id: 456
      type: general
      ---
      # Original
    EOF
    note_path = File.join(@temp_dir, 'test-note.md')
    File.write(note_path, content)
    note = Note.new(path: note_path)
    @indexer.index_note(note)
    updated_content = <<~EOF
      ---
      id: 456
      type: updated
      ---
      # Updated
    EOF
    File.write(note_path, updated_content)
    updated_note = Note.new(path: note_path)
    @indexer.index_note(updated_note)
    db = SQLite3::Database.new(File.join(@temp_dir, '.zk', 'index.db'))
    result = db.execute('SELECT id, metadata FROM notes WHERE id = ?', ['456'])
    assert_equal 1, result.length
    assert_includes result[0][1], '"type":"updated"'
    db.close
  end
end
