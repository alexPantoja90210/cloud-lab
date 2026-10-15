# Jira project: CLOUD

- Site: alejandrobpantoja.atlassian.net, project key `CLOUD`, board 71.
- Epics: CLOUD-19 (October, both clouds), CLOUD-20 (AWS in depth, from November).
- One issue per domain per cloud period, each with acceptance criteria in pairs: what must happen, and what must not.
- Sprint 1 started 7 Oct 2026, four weeks.
- Status Done is set by the operator, only when the work was really done and the evidence is in this repository.

## Lessons about operating the board

- Issues can be moved into a sprint by setting the sprint field; creating or renaming sprints is done in the Jira UI.
- Keep issue text in English; conversation can be in any language.

## Working model (decided by the operator, 15 Oct 2026)

- The operator builds in the Azure portal and the AWS console from steps written by Claude, each step with a "what to notice" question. Nothing needs a command he cannot read; where one is unavoidable, Claude gives it with its output already filtered.
- Before creating a piece, he reads the price the creation screen shows. Afterwards he writes down what surprised him. This is a log of surprises, not a score.
- He reads the cost himself in the portal (Cost analysis, Cost Explorer). Claude produces its own report from the CLI. Where the two differ is the lesson. No daily cost read on its own.
- Claude writes the Terraform twin, applies it, destroys it and verifies the result empty in the portal. Writing Terraform himself is a later goal.
- Both clouds are built in every domain. The October asymmetry (full exercise on Azure, written comparison on AWS) is dropped. The older rule "no NAT, bastion or VPN on AWS" is replaced by: state the price per hour before creating a piece, write an end time for every hourly piece, and verify layer 1 empty at the end of each session.
- Issues rewritten on 15 Oct 2026 to this model: CLOUD-27, 29, 30, 31, 32, 33, 34, 35. CLOUD-1 to 20 (earlier AWS programme) were not touched.

