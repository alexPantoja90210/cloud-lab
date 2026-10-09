# Tag scheme

Defined in layer 0 and applied from Terraform on both clouds. Nothing is tagged by hand.

| Key | Values | Meaning |
|---|---|---|
| `lab` | `cloud-lab` | Everything in this lab. |
| `layer` | `0`, `1` | `0` is never destroyed. `1` is destroyed after every session. |
| `domain` | `foundation`, `compute`, `storage`, `identity`, `networking`, `cost`, `monitoring` | Which practice exercise caused the cost. |

`foundation` is layer 0 only (state backends). It is the fixed baseline, so a cost
query by `domain` separates baseline from practice.

`domain` on a layer 1 resource says which exercise created it, not which service it
bills as. The identity probe bills as storage and container instances but is tagged
`domain = identity`. The service view and the tag view answer different questions.

## How it is applied

- **AWS:** `default_tags` in each root's provider for `lab` and `layer` (and `domain` in
  layer 0 roots). Layer 1 sets `domain` per resource, because that layer hosts many domains.
- **Azure:** a `locals.tags` map per root, set on each taggable resource. Layer 1 uses
  `merge(local.tags, { domain = "..." })`.
- **Azure resource group tags do not reach cost records** unless tag inheritance is
  enabled in Cost Management. Resources are tagged directly so cost does not depend on it.

## AWS cost allocation tags

A tag key must be activated in Billing and Cost Management before it appears in cost data.
Activation is not retroactive and can take up to 24 hours to show.

| Key | Activated |
|---|---|
| `lab` | 2026-10-08 |
| `layer` | 2026-10-08 |
| `domain` | 2026-10-09 (listed as inactive at about 09:00 local, activated the same morning) |
