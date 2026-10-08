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

### 2026-10-07: custom role rejected at apply: control-plane action used as a data action

- **Symptom:** `apply` of `azure/identity` created the resource group and the managed identity, then failed on the role definition with `InvalidDataActionOrNotDataAction: 'Microsoft.Storage/storageAccounts/blobServices/containers/read' does not match any of the actions supported by the providers`. The next `apply` of the saved plan failed with `Saved plan is stale`.
- **Root cause:** `containers/read` is a control-plane action (it belongs in `actions`), not a data action. `terraform validate` cannot catch it because the provider schema accepts any string; only Azure's role API knows which strings are valid. The partial apply changed the state, so the saved plan became stale.
- **Fix:** removed it. Reading and listing blobs needs only the data action `.../containers/blobs/read`. Then re-plan (the plan is regenerated from the state that now already holds the two created resources) and apply.
- **Still open:** no. Lesson for later roles: validate does not check permission strings; the first apply does, so apply layer 0 identity changes in small steps.
- **Source:** terraform apply output, 7 Oct 2026.

### 2026-10-07: container group rejected at apply: "ports in ipAddress cannot be empty"

- **Symptom:** `apply` of `azure/layer1` created six resources, then the container group failed with `MissingIpAddressPorts: The ports in the 'ipAddress' of container group ... cannot be empty`. A deprecation warning for `storage_account_name` on the blob also appeared (non-blocking).
- **Root cause:** `azurerm_container_group` defaults to a public IP address, which requires at least one exposed port; the probe only makes outbound calls. `validate` accepts the configuration because the rule lives in Azure's API.
- **Fix:** `ip_address_type = "None"`. Re-plan from the state that already holds the six created resources, then apply the one that is missing.
- **Still open:** the blob's deprecated `storage_account_name` / `storage_container_name` arguments (to be replaced by `storage_container_id` before AzureRM v5). Changing them probably forces a blob replacement, which is free here because layer 1 is rebuilt every session.
- **Source:** terraform apply output, 7 Oct 2026.

### 2026-10-07: destroy output leaked subscription, tenant and object IDs past the redaction (caught before commit)

- **Symptom:** the first layer 1 destroy with real resources produced output in which the redaction script missed identifiers: (1) a Terraform id for `azurerm_client_config` is base64 text that decodes to client, object, subscription and tenant IDs; (2) the "Still destroying" line truncates a GUID with `...`, so it no longer matches a full-GUID pattern.
- **Root cause:** the redaction only matched complete, plain GUIDs. The earlier destroy runs touched no resources, so they never printed either form.
- **Fix:** `scripts/teardown.sh` now also redacts `id=Y2xpZW50...` (base64 client config) and any GUID prefix, including truncated ones. The affected evidence file was redacted the same way before it was ever committed, and re-scanned, including for long base64 tokens.
- **Still open:** redaction is a filter, not a guarantee. Rule: read every file in `evidence/` before committing, and never commit raw Terraform output.
- **Source:** `evidence/destroy-azure-20261008T034336Z.txt`, 7 Oct 2026.
