---
name: hadolint
description: Lint Containerfiles and Dockerfiles with hadolint in the opencode container to catch best-practice issues early.
agents: [main_agent, coding_agent]
---

## When to use

- Before or after modifying `Containerfile` in this project.
- Any time changes to base images, package installs, or multi-stage builds are proposed.

## Basic Usage

- `hadolint Containerfile` — lint with all default rules
- `hadolint --no-fail Containerfile` — exit 0 even with warnings (for CI info steps)
- `hadolint -f json Containerfile | jq` — machine-readable output

## Ignoring Rules

Inline:
```dockerfile
# hadolint ignore=DL3008
RUN apt-get install -y curl
```

Via flag:
- `hadolint --ignore DL3008 --ignore DL3009 Containerfile`

## Common Rules

- `DL3008` — pin apt package versions (`apt-get install curl=7.x`)
- `DL3009` — delete apt lists after install (`rm -rf /var/lib/apt/lists/*`)
- `DL3015` — avoid `--no-install-recommends` omission
- `DL4006` — set `SHELL` option when using pipes in RUN
- `SC2086` — double-quote variables to avoid word splitting

## Tips

- `DL3008` is intentionally ignored in most dev images where pinning is impractical
- Run after every Containerfile edit before rebuilding
