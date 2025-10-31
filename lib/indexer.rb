# frozen_string_literal: true

require 'sqlite3'
require 'json'
require 'pathname'
require 'fileutils'

# Indexer for notes using SQLite
class Indexer
  def initialize(config)
    @config = config
    @db_path = File.join(@config['notebook_path'], '.zk', 'index.db')
    FileUtils.mkdir_p(File.dirname(@db_path))
  end

  def index_note(note)
    db = SQLite3::Database.new(@db_path)
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        path TEXT,
        metadata TEXT
      )
    SQL
    relative_path = Pathname.new(note.path).relative_path_from(Pathname.new(@config['notebook_path'])).to_s
    db.execute('INSERT OR REPLACE INTO notes VALUES (?, ?, ?)', [note.id, relative_path, note.metadata.to_json])
    db.close
  end
end
