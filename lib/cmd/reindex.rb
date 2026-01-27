#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require_relative '../config'
require_relative '../indexer'
require_relative '../models/note'

# Reindex command for rebuilding the note index
class ReindexCommand
  def initialize
    @debug = ENV['ZKN_DEBUG'] == '1'
  end

  def run(*args)
    return output_completion if args.first == '--completion'
    return output_help if args.first == '--help' || args.first == '-h'

    config = Config.load(debug: @debug)
    notebook_path = config['notebook_path']

    unless notebook_path && Dir.exist?(notebook_path)
      puts "Error: Notebook path not found: #{notebook_path}"
      exit 1
    end

    # Find all markdown files recursively
    markdown_files = find_markdown_files(notebook_path)
    puts "Found #{markdown_files.length} markdown files"

    # Index each file
    indexer = Indexer.new(config)
    indexed_count = 0
    error_count = 0

    markdown_files.each do |file_path|
      begin
        note = Note.new(path: file_path)
        indexer.index_note(note)
        indexed_count += 1
      rescue StandardError => e
        error_count += 1
        $stderr.puts "Warning: Failed to index #{file_path}: #{e.message}"
        debug_print("Error details: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    puts "Indexed #{indexed_count} files"
    puts "Skipped #{error_count} files due to errors" if error_count > 0
  end

  private

  def debug_print(message)
    return unless @debug

    $stderr.puts("[DEBUG] #{message}")
  end

  def find_markdown_files(notebook_path)
    # Use Dir.glob to recursively find all .md files
    pattern = File.join(notebook_path, '**', '*.md')
    all_files = Dir.glob(pattern)

    # Filter out files in .zk directory
    all_files.reject do |file_path|
      # Get relative path from notebook_path
      relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(notebook_path)).to_s
      # Check if path contains .zk directory
      relative_path.start_with?('.zk/') || relative_path.include?('/.zk/')
    end
  end

  def output_completion
    # Reindex takes no arguments
    puts ''
  end

  def output_help
    puts <<~HELP
      Re-index all markdown files in the notebook

      USAGE:
          zkn reindex

      DESCRIPTION:
          Recursively scans the notebook directory for all markdown (.md) files,
          reads their YAML frontmatter, and adds/updates entries in the SQLite
          index database. Files in the .zk directory are automatically skipped.

      OPTIONS:
          --help, -h      Show this help message
          --completion    Output shell completion candidates (empty for this command)

      EXAMPLES:
          zkn reindex              Re-index all notes in the notebook
          zkn reindex --help       Show this help message

      The reindex command will:
          - Find all .md files recursively in the notebook directory
          - Parse YAML frontmatter from each file
          - Add new notes to the index or update existing entries
          - Skip files in the .zk directory
          - Report the number of files found and indexed
          - Show warnings for files that could not be indexed
    HELP
  end
end

ReindexCommand.new.run(*ARGV) if __FILE__ == $PROGRAM_NAME
