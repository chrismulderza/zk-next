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

Templates can include a special `config` attribute in the front matter to override
the default filename pattern. The `config.path` attribute specifies a custom filepath
pattern that will be used when creating notes of that type. The `config` attribute is
automatically removed from the final note file.

Example template with config.path:
```yaml
---
id: <%= id %>
type: journal
date: <%= date %>
config:
    path: journal/<%= date %>.md
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
