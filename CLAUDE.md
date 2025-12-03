# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hansa is a Crystal language port of go-enry that detects programming languages based solely on content analysis without relying on file extensions or filenames. It uses a naive Bayes classifier with pre-computed language probabilities stored in `frequencies.json`.

## Development Commands

### Building
- `shards build` - Build the main `hansa` binary (standard build process)
- `crystal build src/main.cr` - Alternative direct build command
- The binary will be created as `./bin/hansa` when using shards, or `./main` when building directly

### Testing
- `crystal spec` - Run the full test suite
- `crystal spec spec/hansa_spec.cr` - Run specific test files
- Note: Current tests are placeholder/failing and need implementation

### Linting and Code Quality
- `ameba` - Run the Crystal linter to check code style
- `ameba --fix` - Automatically fix linting issues where possible
- Fix any linting issues before committing changes

### Project Management
- `shards install` - Install/update dependencies
- `shards version` - Show current project version

## Architecture Overview

### Core Components

**Main Module (`src/hansa.cr`)**
- `Hansa` module containing the core language classification logic
- `BakedData` class embeds `frequencies.json` into the binary at compile time
- `Classifier` struct contains language and token log probabilities

**CLI Interface (`src/main.cr`)**
- Simple command-line interface processing file arguments
- Outputs filename and detected language for each input file

**Data Files**
- `src/frequencies.json` - 7.9MB training data with language probabilities
- Based on Linguist corpus from GitHub, limited to top 100 languages

### Classification Algorithm

The system uses naive Bayes classification with these steps:

1. **Tokenization** - Extracts different token types from first 50K characters:
   - Shebang lines, SGML/HTML tags, comments/literals
   - Punctuation, regex patterns, identifiers, operators, words

2. **Probability Calculation** - Combines:
   - Language prior probabilities
   - Token likelihood probabilities
   - Returns highest-scoring language

3. **Performance Optimizations**:
   - Content limited to first 50K characters
   - Limited to 100 most common languages
   - Pre-computed log probabilities

### Dependencies

- `baked_file_system` (custom fork in lib/) - Embeds static files in binary
- Crystal >= 1.13.1 required
- No runtime dependencies - everything compiled into single binary

## Development Workflow

1. **Always build after changes**: Run `shards build` to ensure code compiles
2. **Check all binaries**: If multiple binaries exist, verify ALL build successfully
3. **Run tests**: Execute `crystal spec` before declaring tasks complete
4. **Lint and fix**: Run `ameba` and fix any issues with `ameba --fix`
5. **Test manually**: Verify language detection works with sample files

## Language Detection Behavior

- **Ruby** - Correctly identified as "Ruby"
- **JavaScript** - Correctly identified as "JavaScript"
- **Crystal** - Often detected as "Nit" (related language)
- **Python** - Sometimes confused with "Nit"
- This is expected behavior mentioned in README

## Key Development Notes

- **lib/ directory contains external dependencies** - do not modify
- **Large embedded data** - `frequencies.json` (7.9MB) is baked into binary
- **Single-file design** - Most logic in `src/hansa.cr` (197 lines)
- **Minimal test coverage** - Tests are placeholder and need implementation
- **Content-based only** - No filename/extension analysis
- **Performance focus** - Optimized for speed over perfect accuracy

## File Structure Notes

- `src/main.cr` - CLI entry point (11 lines)
- `src/hansa.cr` - Core implementation (197 lines)
- `src/frequencies.json` - Training data embedded at compile time
- `src/libenry.a` - Go library artifact (legacy)
- `lib/baked_file_system/` - External dependency for file embedding
- `spec/hansa_spec.cr` - Currently contains failing placeholder tests