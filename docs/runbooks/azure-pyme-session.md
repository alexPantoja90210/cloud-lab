# Azure PyME model session (CLOUD-36), 21 Oct 2026

Goal: rebuild the on-prem model "one folder per department, only that department opens it, users move and leave, cost per department" on Azure. Built by hand first, then as Terraform (`azure/departments/`).

Cost: groups are free; four empty storage accounts cost fractions of a cent per day. Cost by department is read in Cost analysis on 22 Oct (data lags about a day).

## Hand-built run (UTC, 21 Oct)

| Step | What | Result |
|---|---|---|
| 0 | Probe: create and delete an Entra group | Allowed; count back to 0 |
| 1 | 4 groups `grp-<dept>`, 4 storage accounts (one per department, shared keys off, no public access), tag `department` | 8 objects, read back by count |
| 2 | Create container as the Owner login | Worked (see finding 1) |
| 3 | Grant each group Storage Blob Data Reader at its own container | 4 of 4 read back |
| 4 | Upload and list blobs as the Owner login | Denied until Storage Blob Data Contributor was granted on the accounts |
| 5 | Test identity `sp-lab-alice` in `grp-operations` reads operations, then finance | Operations listed; finance denied (18:49:46) |
| 6 | Mover and leaver with alice, same login session | No change in 10 minutes (finding 2) |
| 7 | Same with a fresh login per check | Still no change in 10 minutes (finding 3) |
| 8 | New identity `sp-lab-bob`, joined the group before its first token | Allowed after 17 s |
| 9 | Move bob from operations to finance | Finance still denied after 8 min; operations still allowed after another 8 min |
| 10 | Remove bob from finance | Trivially denied (he never had finance) |

Evidence: `evidence/azure-pyme-denial-*`, `azure-pyme-mover-leaver-*` (stale session), `azure-pyme-fresh-token-*`, `azure-pyme-mover-leaver-bob-*`.

## Findings

1. Owner can create a container but not read or write inside it. Creating the container worked with no data role; listing and uploading were denied. Likely cause (not verified): the CLI creates containers through the management plane, where Owner has rights, while blob operations are data-plane actions that Owner does not include.
2. Group changes did not reach an identity that already held an access token: alice kept her old access for at least 10 minutes after leaving the group.
3. A fresh login did not help alice either. After leaving and rejoining a group she did not regain access within 10 minutes.
4. An identity that joins a group before its first token gets access fast (bob, 17 s).
5. Moving a principal between groups was not reflected within 8 minutes. For bob, removal from operations was still not effective 16 minutes later.
6. The old access did expire: a probe of bob at 03:38 UTC on 22 Oct (5 h 29 min after the change) showed operations and finance both denied. It was still allowed 16 minutes after the change, so the expiry is somewhere between 16 minutes and 5.5 hours; the exact point was not measured. Human users were not tested (a new user would be asked to register MFA at first sign-in); the result so far is about service principals.

Practical reading for a program manager: removing someone from a group is not an instant revoke. Plan for a window after a leaver, and use a direct revoke (disable the account or remove the role assignment) when it must be immediate.

## Terraform twin

`azure/departments/` (own state key, own provider set: azurerm, azuread, random, time). Plan: 22 to add. Applied, then `plan` showed no changes, then destroyed. The twin used the group prefix `tfgrp` so it could coexist with the hand-built groups. After destroy: 0 `tfgrp-` groups, one storage account per department left (the hand-built ones).

## Mistakes and lessons

- A container name needs at least 3 characters: `hr` failed, `human-resources` worked. The failed loop had already created a role assignment on the missing container, which was deleted before redoing HR.
- My first count of accounts used a condition that cancelled itself and returned 0 by mistake.
- PowerShell 5.1 splits `-backend-config=backend.local.hcl` at the dot; quote the argument.
- Re-running an `apply` block that was already applied gives "Saved plan is stale", which is expected.
- A scheduled reminder for the bob probe fired about an hour early, twice.

## Still open

- Cost by department from Cost analysis (22 Oct), compared with the CLI report.
- Narrow the expiry window for bob (optional: probe at 1 h and 2 h on a fresh identity).
- Human-user mover and leaver (needs a test user and the MFA question).
- Clean-up of the hand-built layer: 4 storage accounts, 4 `grp-` groups, `sp-lab-alice`, `sp-lab-bob`, and the local login folders `azalice` and `azbob` in the temp folder. Verify empty afterwards.
