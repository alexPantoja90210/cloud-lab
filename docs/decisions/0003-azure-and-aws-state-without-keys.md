# 0003: State backends without long-lived keys

- **Date:** 2026-10-07
- **Status:** accepted

## Decision

- Azure: the storage account has shared key access disabled; the backend authenticates with Entra ID (`use_azuread_auth`), and the operator holds Storage Blob Data Contributor on the account.
- AWS: private, versioned, encrypted, TLS-only S3 bucket; locking with S3 native lock files (`use_lockfile`), so no DynamoDB table.
- Backend names live in gitignored `backend.local.hcl`, and bucket names use a random suffix rather than an account ID.

## Consequences

- No access key or secret ever exists to leak.
- Role assignments take time to propagate, so the Azure bootstrap waits 90 s before creating the container.
