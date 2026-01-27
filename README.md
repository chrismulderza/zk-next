# ZK-Next

Next generation Zettlekasten tool set.

## Project overview and structure

`zk-next` is a collection of CLI tools to manage a `Zettelkasten` style note
management system. All notes are created using CommonMark Markdown. Notes
can have YAML front matter to provide metadata.

The primary function of `zk-next` is to provide a templating system for creating
notes of different types. Users can create different types of notes using
templates, for example:

- A daily journal type
- A meeting type
- A general note type

`zk-next` is configured using a YAML configuration file named `config.yaml`
stored in a directory named `zk-next` under the default XDG configuration directory,
`$HOME/.config`.

The configuration contains the path to the user's default Zettel notebook store,
and the names of the default templates available. Template files are searched in
two locations (in order):
1. Local templates: `.zk/templates/` (within the notebook directory)
2. Global templates: `$HOME/.config/zk-next/templates/`

This allows notebook-specific templates to override global defaults.

### Model

Provisional data model for organising notes:

Base Type: Document
Attributes: - id: - title: - type: - path: - date:

- Document Types:
  - **Note**: Base note class (implemented, extends Document)
  - **Journal**: Journal entry class (implemented as stub, extends Note)
  - **Meeting**: Meeting notes class (implemented as stub, extends Note)
  - **Resource** (planned, not implemented)
    - Bookmark
    - Guide
  - **Contact** (planned, not implemented)
  - **Task** (planned, not implemented)

Note: `Journal` and `Meeting` classes currently exist but are stubs with no specialized functionality beyond the base `Note` class.

### Template files

Template files are developed using Embedded Ruby (ERB), allowing for
placeholders to be replaced in the YAML front matter, and the body of the note.

**YAML Quoting Requirements:**

When writing ERB templates, it's important to properly quote YAML values to avoid parsing errors:

1. **String values must be quoted** if they may contain special YAML characters (`:`, `#`, `[`, `]`, etc.):
   ```yaml
   title: "<%= title %>"
   date: "<%= date %>"
   aliases: "<%= aliases %>"
   ```

2. **The `config.path` field must always be quoted** since it may contain special characters from interpolated variables:
   ```yaml
   config:
       path: "<%= id %>-<%= title %>.md"
   ```

3. **The `tags` field should NOT be quoted** since it's rendered as an inline YAML array:
   ```yaml
   tags: <%= tags %>
   ```
   The `tags` variable is automatically formatted as `["tag1", "tag2"]` by the add command.

**Filename Normalization with `slugify`:**

Templates can use the `slugify` function to normalize strings for use in filenames. The `slugify` function:
- Converts text to lowercase
- Replaces spaces and special characters with the configured replacement character (default: `-` hyphen)
- Collapses multiple consecutive replacement characters
- Removes leading/trailing replacement characters
- Preserves hyphens and existing underscores

The replacement character can be configured in `config.yaml`:
```yaml
slugify_replacement: '-'  # Options: '-', '_', or '' (empty string to remove)
```

Example usage in `config.path`:
```yaml
config:
    path: "<%= slugify(id) %>-<%= slugify(title) %>.md"
```

This ensures filenames are filesystem-friendly and URL-safe, even when titles contain special characters like colons, hashes, or spaces.

**Date Format Configuration:**

The date format used in templates can be configured using Ruby's `strftime` format:
```yaml
date_format: '%Y-%m-%d'  # Default: ISO 8601 format
```

This affects the `date` variable available in templates. Common formats:
- `'%Y-%m-%d'` - ISO 8601 (2024-01-15) - default
- `'%m/%d/%Y'` - US format (01/15/2024)
- `'%d-%m-%Y'` - European format (15-01-2024)

**Alias Pattern Configuration:**

Aliases are automatically generated for each note using a configurable pattern. This is useful for searching with tools like `fzf` or `grep`:
```yaml
alias_pattern: '{type}> {date}: {title}'  # Default format
```

The pattern supports variable interpolation using `{variable}` syntax:
- `{type}` - Note type (e.g., "note", "journal", "meeting")
- `{date}` - Formatted date (uses `date_format` configuration)
- `{title}` - Note title
- `{year}` - 4-digit year
- `{month}` - 2-digit month
- `{id}` - Note ID (8-character hexadecimal)

Example: With default pattern `'{type}> {date}: {title}'`, a note created on 2024-01-15 with title "Meeting Notes" would have alias: `"note> 2024-01-15: Meeting Notes"`

This makes it easy to search for notes using tools like:
- `grep "note>" *.md` - Find all notes
- `fzf` - Interactive search with alias pattern

Templates can include a special `config` attribute in the front matter to override
the default filename pattern. The `config.path` attribute specifies a custom filepath
pattern that will be used when creating notes of that type. The `config` attribute is
automatically removed from the final note file.

Example template with config.path:
```yaml
---
id: "<%= id %>"
type: journal
date: "<%= date %>"
title: "<%= title %>"
tags: <%= tags %>
config:
    path: "journal/<%= date %>.md"
---
```

### Indexing

`zk-next` provides the capability for notes to be indexed into a Sqlite
database. The indexer extracts metadata contained in the YAML front matter of a
note, and inserts this into a Sqlite table along with a unique ID and the file
path, relative to the notebook directory for each note.

The indexer uses SQLite FTS5 (Full-Text Search) to enable fast full-text
searching across note titles, filenames, and body content. The FTS index is
automatically maintained through database triggers, ensuring search results
stay synchronized with note updates.

**Note**: While the FTS5 indexing infrastructure is in place, there is
currently no CLI command to query or search the index. The indexing system is
prepared for future search functionality.

### Components

- **Main CLI tool:** `bin/zkn` is a Bash script that routes to different command
  implementations.
- **Commands:**
  - all command implementations should be executable using `#!/usr/bin/env ruby`
    at the top of the file.
  - `lib/cmd/add.rb` - implements the `add` command in Ruby.
- **Data Models:** 
  - `lib/models/note.rb` is the base note class definition for the
  default note. This class extends `document.rb` which is an abstract class.
  All other note types inherit from this base class.

## Architecture Documentation

For detailed information about the system architecture, design decisions, and extension points, see:

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Comprehensive architecture documentation including:
  - System overview and component architecture
  - Data flow diagrams
  - Configuration system
  - Extension points for adding new commands, document types, and templates
  - Future architecture considerations

- **[docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md)**: Architecture Decision Records (ADRs) documenting key design choices:
  - Why certain technologies were chosen
  - Trade-offs and consequences of architectural decisions
  - Context for future architectural changes

## Directives

- **Follow coding standards:** Adhere to all guidelines outlined in the `Code
Style` section.
- **Explain reasoning:** Briefly explain your thought process or plan before
  suggesting or making a code change.
- **Use existing patterns:** Prioritize using existing architecture, design
  patterns, and utility functions.
- **Ensure test coverage:** When adding new features, include new or updated
  unit tests to ensure adequate coverage.
- **Keep changes focused:** Aim for small, modular, and logical code changes.

## Code Style

- **Language:** Bash for cli commands and function wrappers, Ruby for library
  and implementation. Try to be POSIX compliant.
- **Code Style:** Use `Rubocop` for Ruby style and linting. Use `shellcheck` for
  bash linting.
- **Comments:** Comment functions and files.
- **External tools:** Use external tools such as `gum`, fzf`, `ripgrep`, `bat` for
  providing user interaction. Sqlite is used for database and indexing
  operations.

## Commit and pull request guidelines

- Changes relevant to the API or UI:
  - `feat` Commits that add, adjust or remove a new feature to the API or UI
  - `fix` Commits that fix an API or UI bug of a preceded feat commit
- `refactor` Commits that rewrite or restructure code without altering API or UI
  behavior
  - `perf` Commits are special type of refactor commits that specifically
    improve performance
- `style` Commits that address code style (e.g., white-space, formatting,
  missing semi-colons) and do not affect application behavior
- `test` Commits that add missing tests or correct existing ones
- `docs` Commits that exclusively affect documentation
- `build` Commits that affect build-related components such as build tools,
  dependencies, project version, CI/CD pipelines, ...
- `ops` Commits that affect operational components like infrastructure,
  deployment, backup, recovery procedures, ...
- `chore` Miscellaneous commits e.g. modifying `.gitignore`, ...

## Build and test

- Use `Minitest` for Ruby unit tests,
- Use `bats` for shell script testing.
