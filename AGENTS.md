# AGENTS.md

Quick reference for AI coding agents working in this repository.

## Build/Test Commands
- **All tests:** `make test` - Runs all Ruby unit tests and shell script tests
- **Single Ruby test:** `ruby -Ilib test/models/note_test.rb`
- **Single test file with test method:** `ruby -Ilib test/cmd/add_test.rb -n test_run_creates_note`
- **Shell tests:** `bats test/zk.bats`
- **Ruby lint:** `rubocop lib/`
- **Bash lint:** `shellcheck bin/zkn`

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

## Template Quoting Requirements

**CRITICAL**: When creating or modifying ERB templates (`.erb` files in `lib/templates/` or user template directories), you MUST follow YAML quoting rules to prevent parsing errors.

### Required Quoting Rules

1. **String values MUST be quoted** if they may contain special YAML characters (`:`, `#`, `[`, `]`, `&`, `*`, `!`, `|`, `>`, `'`, `"`, `%`, `@`, `` ` ``):
   ```yaml
   title: "<%= title %>"      # ✓ Correct: quoted
   date: "<%= date %>"         # ✓ Correct: quoted
   aliases: "<%= aliases %>"   # ✓ Correct: quoted
   id: "<%= id %>"             # ✓ Correct: quoted
   ```

2. **The `config.path` field MUST always be quoted** since it may contain special characters from interpolated variables:
   ```yaml
   config:
       path: "<%= id %>-<%= title %>.md"  # ✓ Correct: quoted
       path: <%= id %>-<%= title %>.md     # ✗ WRONG: unquoted (will fail with special chars)
   ```

3. **The `tags` field MUST NOT be quoted** since it's rendered as an inline YAML array by the `add` command:
   ```yaml
   tags: <%= tags %>           # ✓ Correct: unquoted (renders as ["tag1", "tag2"])
   tags: "<%= tags %>"         # ✗ WRONG: quoted (would render as string, not array)
   ```

### Why This Matters

- **Unquoted values with special characters** (especially `:` in titles) cause YAML parsing errors: `"did not find expected key while parsing a block mapping"`
- **Quoted `tags`** prevents proper array parsing, storing tags as strings instead of arrays
- **Unquoted `config.path`** breaks when titles contain `:`, `#`, or other special characters

### Template Examples

**Correct template structure:**
```yaml
---
id: "<%= id %>"
type: note
date: "<%= date %>"
title: "<%= title %>"
aliases: "<%= aliases %>"
tags: <%= tags %>
config:
    path: "<%= id %>-<%= title %>.md"
---

# <%= title %>

<%= content %>
```

**When modifying templates:**
- Always quote string fields that use ERB interpolation: `"<%= variable %>"`
- Always quote `config.path` values: `path: "<%= pattern %>"`
- Never quote the `tags` field: `tags: <%= tags %>`
- Test templates with special characters in titles (e.g., `"Test: Note #1"`) to verify YAML parsing

### Template Locations

Templates are searched in this order:
1. Local: `.zk/templates/{template_file}` (within notebook directory)
2. Global: `~/.config/zk-next/templates/{template_file}`

When updating templates in the source code (`lib/templates/`), ensure users' global templates are also updated during installation or provide migration instructions.

See [README.md](README.md#template-files) and [ARCHITECTURE.md](ARCHITECTURE.md) for more details on template structure and requirements.

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
- **CRITICAL**: When creating or modifying ERB templates, follow [Template Quoting Requirements](#template-quoting-requirements) to prevent YAML parsing errors
- **MANDATORY**: After adding new features or making changes, **always run `make test`** to validate all unit tests pass. Never commit changes without verifying tests pass. If tests fail, fix the issues before proceeding.
- **REQUIRED**: When adding new features, updating existing functionality, or adding to the model layer, **evaluate test coverage** and create new tests as needed. Review existing tests to identify gaps, add tests for new code paths, edge cases, and error conditions. Ensure all new functionality has corresponding test coverage before completing the work.

## Help System Requirements

The CLI provides a comprehensive help system via the `--help` or `-h` flags. All commands should support these flags.

### Help Implementation

- **Top-level help**: `zkn --help` or `zkn -h` displays general usage and all available commands
- **Command-specific help**: `zkn <command> --help` or `zkn <command> -h` displays help (currently shows general help; commands can implement custom help)
- **Help function**: The `show_help()` function in `bin/zkn` contains the help text and should be updated when adding new commands

### Help Requirements for New Commands

When adding a new command:

1. **Update `show_help()` function** in `bin/zkn`:
   - Add the new command to the COMMANDS section with description
   - Add usage examples if appropriate
   - Ensure the command is listed in the correct order

2. **Add `--help` handling** in command route:
   ```bash
   commandname)
     if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
       show_help
       exit 0
     fi
     ruby "$DIR/../lib/cmd/commandname.rb" "$@"
     ;;
   ```

3. **Optional: Command-specific help**:
   - Commands can implement custom help by handling `--help` in their Ruby code
   - If not implemented, the command will show general help
   - Custom help should follow the same format as general help for consistency

### Help Content Guidelines

- Help text should be clear and concise
- Include usage syntax for each command
- Provide examples for common use cases
- Keep formatting consistent with existing help output
- Use heredoc (`cat << 'EOF'`) for multi-line help text in shell functions

## Adding New Commands

When adding a new command to `lib/cmd/`, follow this checklist:

1. **Create command file**: `lib/cmd/{command_name}.rb`
   - Use executable Ruby script pattern (`#!/usr/bin/env ruby`)
   - Include `frozen_string_literal: true`
   - Implement command class with `run` method

2. **Add route in `bin/zkn`**:
   ```bash
   commandname)
     if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
       show_help
       exit 0
     fi
     ruby "$DIR/../lib/cmd/commandname.rb" "$@"
     ;;
   ```

3. **Update help function** (REQUIRED):
   - Add the new command to the `show_help()` function in `bin/zkn`
   - Include command description and usage examples
   - See [Help System Requirements](#help-system-requirements) for details

4. **Implement completion** (REQUIRED):
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

5. **Evaluate test coverage and add tests**: `test/cmd/{command_name}_test.rb`
   - **Evaluate existing test coverage**: Review related test files to identify gaps
   - **Create comprehensive tests** for:
     - All code paths and branches
     - Edge cases and error conditions
     - Input validation and argument parsing
     - Integration with other components
   - Test files are automatically discovered by `make test` (no Makefile update needed)
   - Follow naming convention: `*_test.rb`
   - Use Minitest framework
   - **Run `make test` to verify all tests pass before committing**

6. **Update documentation**: See [ARCHITECTURE.md](ARCHITECTURE.md#adding-new-commands) for details

7. **Validate tests** (REQUIRED):
   - Run `make test` to ensure all tests pass
   - Fix any test failures before proceeding
   - Verify new tests execute correctly
   - Ensure no tests trigger interactive prompts (all inputs must be provided via command-line arguments)
   - **Evaluate test coverage**: Ensure new functionality is adequately tested

**Completion Requirements**:
- All commands MUST implement `--completion` option
- Commands with no arguments should return empty string (`puts ''`)
- Commands with arguments should return space-separated candidates
- Completion is automatically integrated - no manual bash script updates needed

## Test Coverage Requirements

When adding new features, updating existing functionality, or adding to the model layer, you MUST evaluate and ensure adequate test coverage:

### Test Coverage Evaluation Process

1. **Review existing tests**:
   - Check related test files in `test/` directory
   - Identify what's already covered
   - Find gaps in coverage for new/changed functionality

2. **Create comprehensive tests** for:
   - **New features**: All code paths, branches, and public methods
   - **Model additions**: Initialization, attribute access, inheritance, edge cases
   - **Command updates**: Argument parsing, error handling, integration points
   - **Edge cases**: Invalid inputs, boundary conditions, error scenarios
   - **Integration**: Interactions between components

3. **Test file locations**:
   - Commands: `test/cmd/{command_name}_test.rb`
   - Models: `test/models/{model_name}_test.rb`
   - Utilities: `test/utils_test.rb`
   - Configuration: `test/config_test.rb`
   - Integration: `test/zk.bats` (shell script tests)

4. **Test requirements**:
   - All tests must pass (`make test`)
   - No tests should trigger interactive prompts (provide all inputs via arguments)
   - Tests should be isolated and not depend on external state
   - Follow existing test patterns and naming conventions

5. **Coverage checklist**:
   - [ ] New code paths are tested
   - [ ] Error conditions are tested
   - [ ] Edge cases are covered
   - [ ] Integration with other components is tested
   - [ ] All tests pass before committing

### Model-Specific Test Coverage

When adding or updating models (`lib/models/`):
- Test initialization with various input formats (symbol keys, string keys)
- Test attribute access and assignment
- Test inheritance relationships (if extending Document or Note)
- Test file parsing and front matter extraction
- Test error handling (missing files, invalid data)
- Test metadata handling and special characters
- Review existing model tests (`test/models/*_test.rb`) for patterns

## Commit Types
- `feat`: New features/API changes
- `fix`: Bug fixes
- `refactor`: Code restructuring
- `test`: Test additions/corrections
- `docs`: Documentation only
- `style`: Code style/formatting
- `build/ops/chore`: Build/operational/misc changes
