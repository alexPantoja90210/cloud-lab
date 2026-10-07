# 0002: Layer 0 and layer 1 are separate Terraform roots

- **Date:** 2026-10-07
- **Status:** accepted

## Context

Every session ends with a destroy. A single root with a flag to exclude "keep" resources depends on nobody forgetting the flag.

## Decision

Two roots per cloud with separate state. `bootstrap/` (layer 0) holds the state backend and the empty container;
`layer1/` holds everything with an hourly meter. The layer 1 root only reads the container (a data source), so it can never delete it.
Layer 0 resources carry `prevent_destroy`.

## Consequences

- Destroy of layer 1 is safe to run with `-auto-approve`.
- The bootstrap needs local state once (a backend cannot store its own creation).
- Budgets and alerts are layer 0 and must never be added to a teardown.
