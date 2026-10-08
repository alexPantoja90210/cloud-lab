# Identity on Azure (CLOUD-24)

Four-part bar. A line is ticked only with evidence in this repository.

- [x] Deployed from code. `azure/identity/` (custom role `lab-blob-reader`, managed identity, assignment, own state key) and `azure/layer1/identity_probe.tf`.
- [x] Broken on purpose once. A container running as the managed identity read a blob and was denied a write: `evidence/azure-identity-denial-20261008T034326Z.txt` (03:38:02 to 03:38:10 UTC, 8 Oct 2026).
- [ ] Cost shape read from the bill. Not read yet: Azure cost data lags 8 to 24 hours. Estimate before running was "cents or less", from per-second container pricing recalled from memory and not checked on the day.
- [x] Torn down from code. `evidence/destroy-azure-20261008T034336Z.txt`: 7 destroyed; portal check: `rg-cloud-lab` empty, `rg-cloud-lab-identity` still holds the identity.

Not done / not understood:

- The denial text is the Azure CLI's wording, not the raw service error code.
- The "account key" escape route (`--auth-mode key`) was not exercised; it should fail because shared keys are disabled and the role has no `listKeys`.
- Deny assignments, conditions on role assignments and the portal's access-check view were not used.
- Three API rules that `validate` cannot see were found only at apply time (see `docs/lessons-learned.md`).
