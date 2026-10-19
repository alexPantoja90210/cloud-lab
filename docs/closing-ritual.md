# Closing ritual (about 10 minutes per session)

1. **Destroy.** `scripts/teardown.sh azure` and/or `scripts/teardown.sh aws`. Layer 1 only.
2. **Verify in the portal or console, not in the destroy output.** Azure: the lab resource group must be empty. AWS: Resource Groups Tagging API / Tag Editor for `lab=cloud-lab, layer=1` must return nothing. Check for orphaned public IPs and disks.
3. **Read the day's cost** from the bill (Azure Cost analysis; AWS Cost Explorer, unblended cost, not net of credits).
4. **Commit.** Code, redacted destroy output in `evidence/`, and one line in the credit log.

5. **Clean up local data.** `powershell -File scripts/local-cleanup.ps1` (dry run), then add `-Execute`. It removes the
   CLOUD-34 test data and the export sample. When CLOUD-38 is finished, run it with `-IncludeRehost` as well: that removes the
   VM clone `rehost-src`, the exported 20 GiB VHD, the lab SSH key and the labnet port-forward rule. Until CLOUD-38 is done the
   clone and the VHD are kept on purpose: they are the source of the AWS leg.

Credit log line shape:

```
YYYY-MM-DD | azure | credit X USD | mtd Y USD | expires YYYY-MM-DD | portal
YYYY-MM-DD | aws   | credit X USD | N days    | closes  YYYY-MM-DD | console
```
