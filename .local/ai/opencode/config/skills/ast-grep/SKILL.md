---
name: ast-grep
description: AST-aware structural code search and rewrites using ast-grep. Prefer this over regex when code structure matters.
agents: [main_agent, coding_agent]
---

## When to use

- Find or rewrite code patterns that depend on syntax, not just text.
- Audit usage of specific APIs across large codebases.
- Perform safe, automated refactors guided by patterns.

## Basic Search

- `ast-grep --lang ts -p '$F($$$)' src/` — any function call
- `ast-grep --lang ts -p 'const $X = require($M)' .` — CommonJS requires
- `ast-grep --lang py -p 'import $M' .` — Python imports
- `ast-grep --lang rs -p 'fn $F($$$) -> $R { $$$}' src/` — Rust fn defs

## Rewriting

- `ast-grep --lang ts -p 'var $X = $Y' --rewrite 'const $X = $Y' .` — dry run
- `ast-grep --lang ts -p 'var $X = $Y' --rewrite 'const $X = $Y' --update-all .` — apply

## Supported Languages

ts, tsx, js, jsx, py, rs, go, java, c, cpp, cs, html, css, json, yaml

## Metavariables

- `$X` — matches a single AST node
- `$$$` — matches zero or more nodes (variadic)
- `$_` — matches any single node without binding

## Tips

- Wrap patterns in single quotes to avoid shell glob expansion
- Use `--json` for machine-readable output parseable with `jq`
- `ast-grep scan` with a rules YAML file for multi-pattern audits
