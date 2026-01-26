# frozen_string_literal: true

require 'sqlite3'
require 'json'
require 'pathname'
require 'fileutils'

# Indexer for notes using SQLite with FTS5 full-text search
class Indexer
  def initialize(config)
    @config = config
    @db_path = File.join(@config['notebook_path'], '.zk', 'index.db')
    FileUtils.mkdir_p(File.dirname(@db_path))
  end

  def index_note(note)
    db = SQLite3::Database.new(@db_path)
    setup_schema(db)
    
    relative_path = Pathname.new(note.path).relative_path_from(Pathname.new(@config['notebook_path'])).to_s
    filename = extract_filename(relative_path)
    title = note.title || ''
    body = note.body || ''
    
    # Check if note already exists
    existing = db.execute('SELECT id FROM notes WHERE id = ?', [note.id])
    
    if existing.empty?
      # New note - INSERT will trigger fts_insert
      db.execute(
        'INSERT INTO notes (id, path, metadata, title, body, filename) VALUES (?, ?, ?, ?, ?, ?)',
        [note.id, relative_path, note.metadata.to_json, title, body, filename]
      )
    else
      # Existing note - manually delete from FTS, then use INSERT OR REPLACE
      # This ensures old content is removed before new content is added
      db.execute('DELETE FROM notes_fts WHERE id = ?', [note.id])
      db.execute(
        'INSERT OR REPLACE INTO notes (id, path, metadata, title, body, filename) VALUES (?, ?, ?, ?, ?, ?)',
        [note.id, relative_path, note.metadata.to_json, title, body, filename]
      )
      # INSERT trigger will add to FTS
    end
    db.close
  end

  private

  def setup_schema(db)
    setup_notes_table(db)
    setup_fts_index(db)
    setup_triggers(db)
  end

  def setup_notes_table(db)
    db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        path TEXT,
        metadata TEXT,
        title TEXT,
        body TEXT,
        filename TEXT
      )
    SQL
    
    # Add new columns to existing table if they don't exist (migration)
    begin
      db.execute('ALTER TABLE notes ADD COLUMN title TEXT')
    rescue SQLite3::SQLException
      # Column already exists, ignore
    end
    
    begin
      db.execute('ALTER TABLE notes ADD COLUMN body TEXT')
    rescue SQLite3::SQLException
      # Column already exists, ignore
    end
    
    begin
      db.execute('ALTER TABLE notes ADD COLUMN filename TEXT')
    rescue SQLite3::SQLException
      # Column already exists, ignore
    end
  end

  def setup_fts_index(db)
    db.execute <<-SQL
      CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
        title,
        filename,
        full_text,
        id UNINDEXED
      )
    SQL
  end

  def setup_triggers(db)
    # Drop existing triggers if they exist (for idempotency)
    db.execute('DROP TRIGGER IF EXISTS fts_insert')
    db.execute('DROP TRIGGER IF EXISTS fts_update')
    db.execute('DROP TRIGGER IF EXISTS fts_delete')

    # Create INSERT trigger
    db.execute <<-SQL
      CREATE TRIGGER fts_insert
        AFTER INSERT ON notes
      BEGIN
        INSERT INTO notes_fts(id, title, filename, full_text)
        VALUES (NEW.id, COALESCE(NEW.title, ''), COALESCE(NEW.filename, ''), COALESCE(NEW.body, ''));
      END
    SQL

    # Create UPDATE trigger
    db.execute <<-SQL
      CREATE TRIGGER fts_update
        AFTER UPDATE ON notes
      BEGIN
        UPDATE notes_fts
        SET title = COALESCE(NEW.title, ''),
            filename = COALESCE(NEW.filename, ''),
            full_text = COALESCE(NEW.body, '')
        WHERE id = NEW.id;
      END
    SQL

    # Create DELETE trigger
    db.execute <<-SQL
      CREATE TRIGGER fts_delete
        AFTER DELETE ON notes
      BEGIN
        DELETE FROM notes_fts WHERE id = OLD.id;
      END
    SQL
  end

  def extract_filename(path)
    return '' if path.nil? || path.empty?
    File.basename(path)
  end
end
