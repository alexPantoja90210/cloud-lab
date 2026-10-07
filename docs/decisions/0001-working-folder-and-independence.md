# 0001: Working folder and independence from other projects

- **Date:** 2026-10-07
- **Status:** accepted

## Context

The lab runs Terraform on Windows. `terraform init` downloads provider binaries into `.terraform/`;
the AWS and AzureRM providers are hundreds of megabytes each. A folder under OneDrive would sync them.
Local state for the bootstrap folders would also be synced and could be overwritten by a stale copy.

Another repository (an evidence-mirror site on S3 + CloudFront with local Terraform state) already exists and belongs to a different activity.

## Decision

- The working folder is `C:\dev\cloud-lab`, outside OneDrive. The remote is a GitHub repository named `cloud-lab`.
- The existing evidence-mirror repository stays where it is, with its own local state. It is not migrated, imported or referenced by the lab.
- Lab resources use their own tag scheme (`lab=cloud-lab`) and their own state backends.

## Consequences

- No file sync touches state or provider caches.
- A destroy in this lab cannot reach resources belonging to another activity.
- Backups of bootstrap state are the operator's job, kept outside the repository.
