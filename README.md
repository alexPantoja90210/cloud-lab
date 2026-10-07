# Cloud Lab: Azure and AWS by service domain

An independent home lab for practising cloud services on Azure and AWS with Terraform, one service domain at a time:
compute, storage, identity, networking, cost and monitoring.

It is unrelated to any other project. It shares no state, resources, tags or budgets with them.

## How a domain counts as "practised"

All four, or it does not count:

1. Deployed from code.
2. Broken on purpose once, and the failure read and fixed.
3. Cost shape read from the bill, not guessed.
4. Torn down from code, and verified empty in the portal or console.

## Layout

```
azure/bootstrap/   layer 0: state backend + empty resource group. Never destroyed.
azure/layer1/      layer 1: billable by the hour. Destroyed after every session.
aws/bootstrap/     layer 0: state bucket. Never destroyed.
aws/layer1/        layer 1: billable by the hour. Destroyed after every session.
docs/              everything below
evidence/          redacted output of destroy runs
scripts/           teardown helper
```

## Documentation

| File | Purpose |
|------|---------|
| `docs/lab-setup.md` | Build from zero: tools, authentication, bootstrap, first destroy. |
| `docs/layers.md` | What survives a teardown (layer 0) and what does not (layer 1). |
| `docs/closing-ritual.md` | The four steps that end every session. |
| `docs/lessons-learned.md` | Problems, root causes and fixes. |
| `docs/decisions/` | Architecture decision records. |
| `docs/jira-project.md` | How the lab is tracked in Jira (project CLOUD). |
| `docs/sprints/` | Sprint logs: goal, work items, retrospective. |
| `docs/study/` | Per-domain self-assessment against the four-part bar. |
| `docs/runbooks/` | One runbook per exercise, written at the end of it. |

## Ground rules

- Every exercise ends with a runbook in `docs/runbooks/` and a closing ritual.
- Anything destroyed must be regenerable from code.
- No credentials, keys, account or subscription IDs, or endpoints in any file. Authentication comes from the environment.
- State, backups and plan files never reach the repository. Verify with `git check-ignore -v`.
- Every number in the docs has a source and a date.
- Problems are recorded with root cause and fix, including the ones that were not fixed.
- Requires Terraform >= 1.10.
