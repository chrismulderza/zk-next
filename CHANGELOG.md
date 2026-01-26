# Changelog

## 0.2.1

- Added template `config.path` override feature for custom file paths
- Enhanced documentation: updated AGENTS.md with test target maintenance and CommonMarker guidelines
- Updated ARCHITECTURE.md with completion system details and template config override documentation
- Improved README.md with template config.path examples and FTS5 indexing details
- Enhanced test coverage across multiple test files
- Improved Makefile test target with automatic test discovery
- Updated CommonMarker usage patterns for markdown construction

## 0.3.0

- Added SQLite FTS5 full-text search indexing
- Indexer now stores note body content, title, and filename for search
- Full-text search enabled across note titles, filenames, and body content
- Automatic FTS index maintenance via database triggers (INSERT, UPDATE, DELETE)
- Enhanced indexer schema with migration support for existing databases
- Comprehensive test coverage for FTS functionality

## 0.2.0

- Added shell completion support with command-driven architecture
- Refactored completion system: commands implement `--completion` option for dynamic completion
- New CLI router (`bin/zkn`) with improved command routing
- Added document types: Journal and Meeting models
- Enhanced AddCommand: defaults to 'note' type when no type specified
- Updated architecture documentation with completion system details
- Updated AGENTS.md with completion requirements for new commands
- Improved command extensibility: new commands automatically get completion support

## 0.1.0

- Initial release with basic note creation and SQLite indexing
- CLI tool for adding notes using ERB templates
- Configuration via YAML
- Basic test suite