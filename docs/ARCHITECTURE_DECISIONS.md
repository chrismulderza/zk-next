# Architecture Decision Records (ADRs)

This document records the key architectural decisions made for the zk-next project. ADRs help document the context, decision, and consequences of important architectural choices.

## ADR Format

Each ADR follows this structure:
- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Context**: The issue motivating this decision
- **Decision**: The change we're proposing or have agreed to implement
- **Consequences**: What becomes easier or more difficult because of this change

---

## ADR-001: Bash CLI Router vs Pure Ruby CLI

**Status**: Accepted

**Context**: 
We needed a simple command-line interface that could route to different command implementations. The options were:
1. Pure Ruby CLI using a gem like `thor` or `commander`
2. Bash script that routes to Ruby command classes
3. Individual executable scripts for each command

**Decision**: 
Use a Bash script (`bin/zkn`) as the CLI router that delegates to Ruby command classes. Each command is implemented as an executable Ruby script with a class-based structure.

**Consequences**:
- **Positive**:
  - Simple, lightweight - no additional Ruby dependencies
  - Fast startup time for command routing
  - Easy to understand and modify
  - Each command can be run standalone for testing
  - Minimal overhead
- **Negative**:
  - Less sophisticated argument parsing (no automatic help generation)
  - Manual command registration required
  - No built-in command discovery
  - Cross-platform concerns (though Bash is widely available)

**Alternatives Considered**:
- **Thor/Commander**: Would provide better CLI features but adds dependency and complexity
- **Individual executables**: Would require PATH management and lose unified interface

---

## ADR-002: ERB Templates vs Other Templating Systems

**Status**: Accepted

**Context**:
We needed a templating system for generating notes with variable substitution. Options included:
1. ERB (Embedded Ruby) - standard library
2. Mustache/Handlebars - logic-less templates
3. Liquid - Shopify's template language
4. Custom template parser

**Decision**: 
Use ERB (Embedded Ruby) for templates, which is part of Ruby's standard library.

**Consequences**:
- **Positive**:
  - No external dependencies - part of Ruby standard library
  - Full Ruby expression support in templates
  - Familiar to Ruby developers
  - Flexible and powerful
  - Easy to extend with helper methods
- **Negative**:
  - Requires Ruby knowledge to write templates
  - Can be too powerful (security concerns if templates are user-provided)
  - Less structured than logic-less templates

**Alternatives Considered**:
- **Mustache**: Logic-less is safer but less flexible
- **Liquid**: Good balance but requires gem dependency
- **Custom parser**: Too much work for minimal benefit

---

## ADR-003: SQLite for Indexing

**Status**: Accepted

**Context**:
We needed a way to index note metadata for fast retrieval and future search capabilities. Options:
1. SQLite - file-based SQL database
2. JSON file - simple key-value storage
3. NoSQL database (Redis, etc.)
4. Full-text search engine (Elasticsearch, etc.)

**Decision**: 
Use SQLite for indexing note metadata. Store metadata as JSON strings in a simple table structure.

**Consequences**:
- **Positive**:
  - File-based, no server required
  - SQL queries for flexible querying
  - ACID compliance for data integrity
  - Widely available and well-supported
  - Can add FTS5 for full-text search later
  - Portable database file
- **Negative**:
  - JSON parsing required for metadata queries
  - Schema changes require migration
  - Limited concurrent write performance (acceptable for single-user tool)
  - No built-in full-text search in current schema

**Alternatives Considered**:
- **JSON file**: Too slow for large notebooks, no query capabilities
- **Redis**: Requires server, overkill for local tool
- **Elasticsearch**: Too heavy, requires server setup

---

## ADR-004: CommonMarker for Front Matter Parsing

**Status**: Accepted

**Context**:
We needed to parse YAML front matter from Markdown files. Options:
1. CommonMarker - CommonMark parser with extensions
2. Kramdown - Ruby Markdown parser
3. Redcarpet - Fast Markdown parser
4. Custom regex-based parsing

**Decision**: 
Use CommonMarker gem for parsing Markdown and extracting front matter. Use its front matter extension support.

**Consequences**:
- **Positive**:
  - Standards-compliant CommonMark parsing
  - Built-in front matter support
  - Well-maintained gem
  - Good performance
  - Extensible with plugins
- **Negative**:
  - External gem dependency
  - Requires understanding of CommonMarker API
  - Less flexible than custom parser for edge cases

**Alternatives Considered**:
- **Kramdown**: Good but heavier, different API
- **Redcarpet**: Fast but less maintained
- **Custom regex**: Fragile, doesn't handle edge cases well

---

## ADR-005: Global + Local Configuration Merge Strategy

**Status**: Accepted

**Context**:
We needed a configuration system that supports both user-wide defaults and notebook-specific overrides. Options:
1. Global config only
2. Local config only
3. Global + Local merge (local overrides)
4. Hierarchical config with multiple levels

**Decision**: 
Implement a two-level configuration system:
- Global config: `~/.config/zk-next/config.yaml` (user defaults)
- Local config: `.zk/config.yaml` (notebook-specific overrides)
- Merge strategy: Local values override global values (shallow merge)

**Consequences**:
- **Positive**:
  - User can set defaults once
  - Notebooks can customize without affecting global settings
  - Simple merge logic
  - Clear precedence rules
- **Negative**:
  - Shallow merge means template arrays are replaced, not merged
  - No deep merging of nested structures
  - Users must understand precedence
  - Potential for confusion if local config is incomplete

**Alternatives Considered**:
- **Global only**: Too restrictive, no notebook customization
- **Local only**: Too much duplication, no defaults
- **Deep merge**: More complex, harder to reason about

---

## ADR-006: Document Inheritance Model

**Status**: Accepted

**Context**:
We needed a model structure for different document types (notes, journals, meetings, etc.). Options:
1. Single class with type field
2. Inheritance hierarchy (Document → Note → Specialized)
3. Composition with mixins
4. Separate classes with shared utilities

**Decision**: 
Use inheritance hierarchy: `Document` (base) → `Note` (file-based) → `Journal`/`Meeting` (specialized types).

**Consequences**:
- **Positive**:
  - Clear type hierarchy
  - Code reuse through inheritance
  - Easy to add new types
  - Type safety through class structure
  - Polymorphic behavior possible
- **Negative**:
  - Inheritance can be limiting (single inheritance)
  - Empty classes (Journal/Meeting) are placeholders
  - Potential for deep inheritance chains
  - Ruby's duck typing makes inheritance less necessary

**Alternatives Considered**:
- **Single class**: Would require type checking and conditional logic
- **Composition**: More flexible but more complex
- **Modules/mixins**: Good for shared behavior but less clear type hierarchy

---

## ADR-007: Template Resolution: Local-First Strategy

**Status**: Accepted

**Context**:
We needed a strategy for resolving template files. Options:
1. Global templates only
2. Local templates only
3. Local-first with global fallback
4. Global-first with local override

**Decision**: 
Use local-first resolution: check `.zk/templates/` first, fall back to `~/.config/zk-next/templates/`.

**Consequences**:
- **Positive**:
  - Notebooks can override global templates
  - Notebooks can have custom templates without affecting global
  - Clear precedence: local wins
  - Graceful fallback to defaults
- **Negative**:
  - Template updates in global don't affect notebooks with local templates
  - Potential for template drift
  - Users must understand search order

**Alternatives Considered**:
- **Global only**: No notebook customization
- **Local only**: Too much duplication
- **Global-first**: Less intuitive, harder to override

---

## ADR-008: Relative Path Storage in Index

**Status**: Accepted

**Context**:
We needed to decide how to store file paths in the SQLite index. Options:
1. Absolute paths
2. Relative paths from notebook root
3. Filenames only

**Decision**: 
Store relative paths from the notebook root directory.

**Consequences**:
- **Positive**:
  - Portable - database can move with notebook
  - Shorter paths in database
  - Notebook can be moved without reindexing
  - Consistent with notebook-centric design
- **Negative**:
  - Requires notebook_path context to resolve full path
  - Relative path resolution needed when reading

**Alternatives Considered**:
- **Absolute paths**: Not portable, breaks if notebook moves
- **Filenames only**: Too ambiguous, can't handle subdirectories

---

## ADR-009: Executable Ruby Scripts for Commands

**Status**: Accepted

**Context**:
We needed a pattern for implementing commands. Options:
1. Methods in a single command class
2. Separate executable scripts per command
3. Command classes loaded by router
4. Plugin system

**Decision**: 
Each command is an executable Ruby script (`#!/usr/bin/env ruby`) with a class that can be run standalone or called by the router.

**Consequences**:
- **Positive**:
  - Commands can be tested independently
  - Commands can be run directly for debugging
  - Clear separation of concerns
  - Easy to add new commands
  - No class loading complexity
- **Negative**:
  - Some code duplication (require statements)
  - Each command must be executable
  - No shared command infrastructure

**Alternatives Considered**:
- **Single command class**: Would become large and hard to maintain
- **Plugin system**: Too complex for current needs
- **Class loading**: More complex, harder to test standalone

---

## ADR-010: JSON Metadata Storage in Index

**Status**: Accepted

**Context**:
We needed to store flexible metadata in the SQLite index. Options:
1. Separate columns for each metadata field
2. JSON string in single column
3. Separate metadata table
4. Key-value table

**Decision**: 
Store metadata as a JSON-encoded string in a single `metadata` column.

**Consequences**:
- **Positive**:
  - Flexible schema - can store any metadata structure
  - No schema changes needed for new metadata fields
  - Simple table structure
  - Easy to extend
- **Negative**:
  - Can't query metadata fields directly in SQL
  - Requires JSON parsing for queries
  - No type safety for metadata
  - Potential for JSON parsing overhead

**Alternatives Considered**:
- **Separate columns**: Too rigid, requires schema changes
- **Key-value table**: More normalized but more complex queries
- **Separate metadata table**: Over-engineered for current needs

**Future Consideration**: 
May add computed columns or views for common metadata fields if query performance becomes an issue.
