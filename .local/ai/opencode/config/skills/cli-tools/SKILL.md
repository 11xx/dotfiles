---
name: cli-tools
description: Core CLI tools preinstalled in this opencode container for file discovery, search, navigation, diffing, linting, and lightweight data work.
agents: [main_agent, coding_agent]
---

## When to use these tools

- Fast discovery and search over the project tree under `/workspace`.
- Inspecting and diffing code with readable, syntax-highlighted output.
- Linting shell scripts and Containerfiles before proposing changes.
- Performing small ad-hoc data queries without spinning up heavier tooling.

Prefer these tools over ad-hoc Python one-liners when native performance or readability matters.

## File discovery and navigation

- `fd` (from `fd-find`) for fast file lookups:

  ```bash
  fd -e ts src/              # TypeScript sources
  fd -g '*test*'             # Files with 'test' in the name
  tree -L 3 -I node_modules  # Shallow directory overview
  ```

- `universal-ctags` for symbol indexing:

  ```bash
  ctags -R .
  grep '^MyFunc' tags
  ```

## Search

- `ripgrep` (`rg`) is the primary text search engine:

  ```bash
  rg 'todo' src/
  rg 'function .*Foo' -g'*.ts'
  rg --json 'pattern' src/ | jq .
  ```

Use `rg --json` when machine-readable results are needed for further processing.

## Code reading and diffs

- `bat` for syntax-highlighted file output:

  ```bash
  bat src/index.ts
  bat -r 10:40 src/index.ts   # focused range
  ```

- `delta` for rich diff rendering:

  ```bash
  git diff | delta
  delta < patch.diff
  ```

These tools make it easier to reason about context before editing.

## Linting and diagnostics

- `shellcheck` for shell scripts:

  ```bash
  shellcheck script.sh
  shellcheck -S warning script.sh
  ```

- `hadolint` for Containerfiles:

  ```bash
  hadolint Containerfile
  hadolint --ignore DL3008 Containerfile
  ```

- `strace` for low-level diagnostics (file access, process behavior):

  ```bash
  strace -e trace=file ./binary
  ```

Use linting before suggesting non-trivial changes to scripts or images.

## Dev loop helpers

- `entr` for re-running commands on file changes:

  ```bash
  fd -e ts src/ | entr -c npm test
  ```

This is useful for keeping tests or linters running while edits are applied.

## Data and inspection

- `sqlite3` and `python3-csvkit` are available for lightweight data tasks:

  ```bash
  sqlite3 db.sqlite '.tables'
  sqlite3 -header -column db.sqlite 'SELECT * FROM users LIMIT 5;'

  csvsql --query 'SELECT COUNT(*) FROM stdin' data.csv
  ```

Use these tools for small exploratory queries instead of introducing additional services.
