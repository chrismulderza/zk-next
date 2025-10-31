# AGENTS.md

Quick reference for AI coding agents working in this repository.

## Build/Test Commands
- **All tests:** `make test`
- **Single Ruby test:** `ruby -Ilib test/models/note_test.rb`
- **Single test file with test method:** `ruby -Ilib test/cmd/add_test.rb -n test_run_creates_note`
- **Shell tests:** `bats test/zk.bats`
- **Ruby lint:** `rubocop lib/`
- **Bash lint:** `shellcheck bin/zk`

## Code Style Guidelines
- **Ruby:** CamelCase classes, snake_case methods/variables, `require_relative` for local files, `require` for external. Use `frozen_string_literal: true`
- **Bash:** POSIX compliant, use `#!/bin/bash` or `#!/usr/bin/env ruby` for Ruby scripts, double quotes for variables
- **Error handling:** `exit 1` for failures, `puts` for user messages
- **Imports:** Group requires at top, use relative paths for local modules
- **Naming:** Descriptive names, consistent with existing codebase
- **Comments:** Comment classes/functions, avoid inline comments
- **Formatting:** Follow Rubocop standards, consistent indentation
- **Testing:** Use Minitest for Ruby unit tests, bats for shell script testing

## Project Overview
`zk-next` is a CLI tool for Zettelkasten note management using GitHub-flavored Markdown with YAML front matter. Uses ERB templates, SQLite indexing.

## Directives
- Follow established patterns and architecture
- Ensure test coverage for new features
- Keep changes focused and modular
- Use external tools: gum, fzf, ripgrep, bat, sqlite

## Commit Types
- `feat`: New features/API changes
- `fix`: Bug fixes
- `refactor`: Code restructuring
- `test`: Test additions/corrections
- `docs`: Documentation only
- `style`: Code style/formatting
- `build/ops/chore`: Build/operational/misc changes
