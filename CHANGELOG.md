# Changelog

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