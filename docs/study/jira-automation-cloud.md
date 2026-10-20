# Jira automation in the CLOUD space (CLOUD-41, 20 Oct 2026)

DRAFT from the working session of 20 Oct 2026. The issue asks for this note in the operator's own words:
edit it before closing CLOUD-41.

## The three rules

| Rule | Trigger | Condition | Action | Tested |
|---|---|---|---|---|
| CLOUD: Done reminder | Work item transitioned, To status = Done | none | Add comment: record real costs in docs/credit-log.md and confirm nothing billable is left | Yes, on a throwaway item (comment in 5 s) |
| CLOUD: Cancellation reason | Work item transitioned, To status = Cancelled | none | Add comment: `Cancelled. Reason: {{issue.customfield_10177}}` | Yes, same throwaway item (reason copied correctly) |
| CLOUD: Azure credit warning | Scheduled, Sat 24 Oct 2026 9:00 (Mexico City), 1 occurrence, JQL `key = CLOUD-30` | none | Add comment: Azure credit expires in about 7 days, read the credit, verify empty, start close-out | Not yet; first run 24 Oct |

## How a rule is built

A rule is trigger, optional conditions, then actions. The trigger says when it runs; a condition filters; an action
does something. A scheduled trigger has no work item in hand: it needs "Run a JQL search and execute actions for each
work item in the query", otherwise an action such as "Add comment" has nothing to comment on.

## Mistakes met and what fixed them (the misfires)

- Scheduled rule, first attempt: it was set to repeat weekly on Tue and Sat with no end date. Fix: End date "After 1 occurrence" and only Saturday.
- Scheduled rule, first attempt: a smart-value condition `{{issue.epic.key}} = CLOUD-30` was added. It tests the parent epic's key, not the issue's, and a scheduled rule has no issue. Fix: delete it and use the JQL option instead. The "Incompatible steps" warning went away.
- The "Cancellation reason" field is read in a rule as `{{issue.customfield_10177}}`.
- Testing a cancel rule: the workflow does not allow Done to Cancelled directly; the throwaway item was reopened to In Progress first.

## What the audit log showed (read 20 Oct 2026)

- Done reminder: config change 11:21:09; execution 11:23:28, status Success, 0.98 s.
- Cancellation reason: config change 11:32:15; execution 11:33:58, status Success, 1.02 s.
- Azure credit warning: four config changes between 11:52 and 11:56, no execution yet (scheduled for 24 Oct).
- Other rules in the log belong to the Job Pipeline space (not this lab).

## Plan limits (read 20 Oct 2026)

- Usage page, current month (October), estimate: 93 automation steps, 0 Rovo credits; all 93 come from the three Job Pipeline rules so far (the CLOUD runs had not appeared in the list yet).
- Atlassian's documentation lists the Free plan limit for Jira at 150 steps per month. A step is one executed part of a flow: the trigger, each condition and each action count, even when nothing matches. Not verified whether this subscription is Free (the page shows an Upgrade button).
- Consequence: about 57 steps left in October at that limit. Each run of these CLOUD rules costs about 2 steps. After 3 Dec 2026 the documentation says extra usage is billed at 0.50 USD per 1,000 steps, and flows stop at 100 percent if extra usage is off.

## Not done

- Rules for the Google trial (about 11 Jan 2027) and the AWS account (about 9 Feb 2027) are not built; their dates are approximate.
- The 24 Oct run of the Azure rule has not been seen.
