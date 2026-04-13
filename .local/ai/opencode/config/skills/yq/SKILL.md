---
name: yq
description: Query and transform YAML and JSON files from the CLI using yq (mikefarah/yq) inside the opencode container.
agents: [main_agent, coding_agent]
---

## When to use

- Reading or modifying `compose.yaml` and other YAML manifests in-place.
- Converting between YAML and JSON for downstream tools.
- Performing structural queries that would be brittle with plain text search.

## Read Values

- `yq '.services' compose.yaml` — read a key
- `yq '.services.opencode.image' compose.yaml` — nested key
- `yq '.packages[]' package.json` — iterate array
- `yq '.[0].name' items.yaml` — first array element

## Filter & Select

- `yq '.services | keys' compose.yaml` — list service names
- `yq '.dependencies | to_entries | .[] | select(.value | test("\\^1"))' package.json` — filter by value pattern

## Modify In-Place

- `yq -i '.services.opencode.image = "localhost/opencode:v2"' compose.yaml`
- `yq -i '.version = "2.0.0"' package.json`

## Convert Between Formats

- `yq -o=json compose.yaml` — YAML → JSON
- `yq -p=json -o=yaml data.json` — JSON → YAML
- `cat data.json | yq -p=json '.'` — read JSON from stdin

## Multi-document Files

- `yq 'select(.kind == "Deployment")' k8s.yaml` — filter by field in multi-doc YAML

## Tips

- `yq` uses the same expression syntax as `jq` for most operations
- Always quote expressions containing `|` to prevent shell pipe interpretation
