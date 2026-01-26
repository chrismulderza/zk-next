# AGENTS.md

Quick reference for AI coding agents working in this repository.

## Build/Test Commands
- **All tests:** `make test` - Runs all Ruby unit tests and shell script tests
- **Single Ruby test:** `ruby -Ilib test/models/note_test.rb`
- **Single test file with test method:** `ruby -Ilib test/cmd/add_test.rb -n test_run_creates_note`
- **Shell tests:** `bats test/zk.bats`
- **Ruby lint:** `rubocop lib/`
- **Bash lint:** `shellcheck bin/zk`

### Test Target Maintenance

The `make test` target automatically discovers and runs all test files matching the pattern `test/**/*_test.rb`. When adding new test files:

1. **Follow naming convention**: Test files must be named `*_test.rb` and placed in the `test/` directory (or subdirectories)
2. **Automatic discovery**: The Makefile uses a `for` loop to find all test files - no manual updates needed
3. **Test structure**: Tests should follow the existing pattern using Minitest
4. **Verification**: After adding tests, run `make test` to ensure they execute correctly

## Code Style Guidelines
- **Ruby:** CamelCase classes, snake_case methods/variables, `require_relative` for local files, `require` for external. Use `frozen_string_literal: true`
- **Bash:** POSIX compliant, use `#!/bin/bash` or `#!/usr/bin/env ruby` for Ruby scripts, double quotes for variables
- **Error handling:** `exit 1` for failures, `puts` for user messages
- **Imports:** Group requires at top, use relative paths for local modules
- **Naming:** Descriptive names, consistent with existing codebase
- **Comments:** Comment classes/functions, avoid inline comments
- **Formatting:** Follow Rubocop standards, consistent indentation
- **Testing:** Use Minitest for Ruby unit tests, bats for shell script testing
- **Markdown Construction:** Always use CommonMarker library to construct markdown documents programmatically. Avoid creating markdown by concatenating strings. Parse content with CommonMarker to validate and format, then use CommonMarker's document objects and `to_commonmark` method for output.

## Project Overview
`zk-next` is a CLI tool for Zettelkasten note management using CommonMark Markdown with YAML front matter. Uses ERB templates, SQLite indexing.

## Architecture Documentation

- **Main documentation**: [ARCHITECTURE.md](ARCHITECTURE.md) - Comprehensive architecture guide
- **Design decisions**: [docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md) - ADRs for key choices

### Architecture Documentation Maintenance

When making architectural changes:

1. **Update ARCHITECTURE.md** when:
   - Adding new components (commands, models, services)
   - Changing component behavior significantly
   - Introducing new patterns
   - Changing dependencies or file structure

2. **Update ARCHITECTURE_DECISIONS.md** when:
   - Making significant architectural decisions
   - Revisiting or changing existing decisions

3. **Review checklist**:
   - Diagrams render correctly
   - Code examples are current
   - File paths are correct
   - Component descriptions match implementation

See [ARCHITECTURE.md](ARCHITECTURE.md#architecture-documentation-maintenance) for detailed maintenance guidelines.

## Directives
- Follow established patterns and architecture
- Ensure test coverage for new features
- Keep changes focused and modular
- Use external tools: gum, fzf, ripgrep, bat, sqlite
- Update architecture documentation when making architectural changes

## Adding New Commands

When adding a new command to `lib/cmd/`, follow this checklist:

1. **Create command file**: `lib/cmd/{command_name}.rb`
   - Use executable Ruby script pattern (`#!/usr/bin/env ruby`)
   - Include `frozen_string_literal: true`
   - Implement command class with `run` method

2. **Add route in `bin/zkn`**:
   ```bash
   commandname)
     ruby "$DIR/../lib/cmd/commandname.rb" "$@"
     ;;
   ```

3. **Implement completion** (REQUIRED):
   - Add `--completion` option handling in `run` method:
     ```ruby
     def run(*args)
       return output_completion if args.first == '--completion'
       # Normal command logic
     end
     ```
   - Implement `output_completion` private method:
     ```ruby
     private
     
     def output_completion
       # Return space-separated completion candidates
       # Example: puts 'arg1 arg2 arg3'
       # Or empty if no arguments: puts ''
       puts ''
     end
     ```
   - Commands automatically appear in shell completion
   - No bash script changes needed - completion is dynamically discovered

4. **Add tests**: `test/cmd/{command_name}_test.rb`
   - Test files are automatically discovered by `make test` (no Makefile update needed)
   - Follow naming convention: `*_test.rb`
   - Use Minitest framework

5. **Update documentation**: See [ARCHITECTURE.md](ARCHITECTURE.md#adding-new-commands) for details

**Completion Requirements**:
- All commands MUST implement `--completion` option
- Commands with no arguments should return empty string (`puts ''`)
- Commands with arguments should return space-separated candidates
- Completion is automatically integrated - no manual bash script updates needed

## Commit Types
- `feat`: New features/API changes
- `fix`: Bug fixes
- `refactor`: Code restructuring
- `test`: Test additions/corrections
- `docs`: Documentation only
- `style`: Code style/formatting
- `build/ops/chore`: Build/operational/misc changes
