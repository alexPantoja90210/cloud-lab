# Lessons learned

One entry per problem: what happened, root cause, fix, and what is still unresolved.
A problem that was not fixed is recorded as such.

## Template

### YYYY-MM-DD: short title

- **Symptom:**
- **Root cause:**
- **Fix:**
- **Still open:**
- **Source:** (command output, portal page, doc URL with date)

## Entries

### 2026-10-07: Azure free-account terms read from the portal, one point unresolved

- **Symptom:** the portal says services will pause when the free period ends, but the offer terms list 12-month free amounts (B1S / B2pts v2 / B2ats v2 burstable VMs, 750 h/month).
- **Root cause:** the two documents do not say whether the 12-month amounts survive the pause.
- **Fix:** none yet.
- **Still open:** yes. It decides whether Azure compute can be practised after the 200 USD credit window. Decide deliberately before the credit expires, not on the last night.
- **Source:** Azure portal and offer terms, read 7 Oct 2026.

### 2026-10-07: AWS cost view showing 0.00 was net of credits

- **Symptom:** Cost Explorer showed 0.00 USD across 16 services.
- **Root cause:** the default view was net of credits. Unblended cost is the number that shows what the activity would cost without credits.
- **Fix:** set the cost type explicitly (unblended) for any meter or budget used to judge consumption.
- **Source:** AWS Cost Explorer, 7 Oct 2026.

### 2026-10-07: Azure budget alert latency is two separate delays

- **Symptom:** the first budget alert was predicted for the next day, but it arrived within the hour.
- **Root cause:** cost data lag (8-24 h) and the budget evaluation (every 24 h) are separate. If the cost is already recorded, the notification follows the evaluation within about an hour.
- **Fix:** document both delays; never treat a budget as a real-time brake.
- **Source:** Azure budget docs and the observed alert (20:13 UTC, 7 Oct 2026).

### 2026-10-07: PowerShell mangles Terraform arguments

- **Symptom:** `terraform -chdir=$d init` failed with "chdir $d: The system cannot find the file specified"; `terraform plan -out=bootstrap.tfplan` failed with "Too many command line arguments".
- **Root cause:** PowerShell does not expand variables inside `-flag=$var` when calling a native program, and it splits `-out=bootstrap.tfplan` at the dot into two arguments.
- **Fix:** quote the whole argument: `terraform "-chdir=$d" ...` and `terraform ... plan "-out=bootstrap.tfplan"`.
- **Still open:** no. All Windows command examples in these docs must quote `-flag=value` arguments.
- **Source:** operator's terminal output, 7 Oct 2026 (Terraform 1.16.5, Windows).

### 2026-10-07: Plan resource count was miscounted before apply

- **Symptom:** the pre-apply expectation was "8 to add"; the plan said 7.
- **Root cause:** the count was done by hand and included one item twice. The real list is two resource groups, the storage account, the role assignment, the container, the random suffix and the 90 s wait.
- **Fix:** the criterion for the Azure bootstrap plan is 7 to add, 0 to change, 0 to destroy. Counts quoted before a plan runs are derived from the code and must be checked against the plan, not the other way round.
- **Source:** `terraform plan` output, 7 Oct 2026.

### 2026-10-07: destroy evidence contained terminal colour codes

- **Symptom:** the first saved destroy output was full of escape sequences (`[0m[1m[32m`).
- **Root cause:** Terraform colours its output even when piped.
- **Fix:** `scripts/teardown.sh` now passes `-no-color`. The first evidence file had its escape sequences stripped; its text is otherwise unchanged.
- **Source:** `evidence/destroy-azure-20261008T024957Z.txt`.
