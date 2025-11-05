# ZK-Next

Next generation Zettlekasten tool set.

## Project overview and structure

`zk-next` is a collection of CLI tools to manage a `Zettelkasten` style note
management system. All notes are created using Github flavoured Markdown. Notes
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
and the names of the default templates available. Default template files are
stored in `$HOME/.config/zk-next/templates`.

### Model

Provisional data model for organising notes:

Base Type: Document
Attributes: - id: - title: - type: - path: - date:

- Document Types:
  - Note:
  - Journal:
  - Resource
    - Bookmark
    - Guide
  - Contact
  - Task

### Template files

Template files are developed using Embedded Ruby (ERB), allowing for
placeholders to be replaced in the YAML front matter, and the body of the note.

### Indexing

`zk-next` provides the capability for notes to be indexed into a Sqlite
database. The indexer extracts metadata contained in the YAML front matter of a
note, and inserts this into a Sqlite table along with a unique ID and the file
path, relative to the notebook directory for each note.

### Components

- **Main CLI tool:** `bin/zk` is a Bash script that routes to different command
  implementations.
- **Commands:**
  - all command implementations should be executable using `#!/usr/bin/env ruby`
    at the top of the file.
  - `lib/cmd/add.rb` - implements the `add` command in Ruby.
- **Data Models:** `lib/models/note.rb` contains base class definition for the
  default note. All other note types inherit from this base class.

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
