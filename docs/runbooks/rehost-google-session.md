# Runbook DRAFT: rehost of a local Linux VM to Google Cloud (replica of CLOUD-37, started 20 Oct 2026)

Status: local preparation done (20 Oct 2026, 12:42 local). Nothing has been run in Google Cloud for this drill yet.
Costs and times below are estimates unless marked measured.

## What the Google documentation says (read 20 Oct 2026)

- Image import with "Migrate to Virtual Machines" lists RHEL 10.0 to 10.2 as supported, default license BYOL, BIOS to UEFI conversion supported.
- `image-imports create` accepts a `.vmdk` or a `.tar.gz` containing one `disk.raw` in Cloud Storage (`--source-file=gs://...`). VHD is not accepted by this command.
- Prerequisites: VM Migration API enabled; a target project; `roles/storage.objectViewer` on the bucket for the Migrate to Virtual Machines service account; `roles/vmmigration.admin` for the user; `roles/vmmigration.serviceAgent` on the target project for that service account.
- Not stated in the documentation: whether the import tool is charged, whether it creates temporary resources, import duration, cleanup. Treat all four as unknown until measured.
- The command name appears as `gcloud migration vms image-imports create` (reference) and `gcloud compute migration image-imports create` (guide); check with `--help` on the installed version.

## Local source

- `rehost-gcp`: full clone of `node2` (RHEL 10.2, registered with Red Hat), made 20 Oct 2026; `node2` was not modified.
- Baseline on the clone, 20 Oct 2026: `httpd` active; SHA-256 of the page served on port 80 starts with `1bd9fcd1c25d6d63` (identical to the Azure and AWS legs); `/var/lib/rehost-data.txt` created with the text `rehost-gcp data 2026-10-20`, SHA-256 starts with `e4ce0a5294ed84c1` (new file: the old data file existed only on the previous rehost VM).

## Plan, not yet run

1. DONE 20 Oct 2026: disk of `rehost-gcp` converted to VMDK with `clonemedium --format VMDK --variant Standard` (VirtualBox variant Standard). Result: 2,972,909,568 bytes (2.77 GiB), SHA-256 starts with `10cecf237d15fcf2`. Local, free. File kept in the folder `gcp-export` of the user profile (removed with `scripts/local-cleanup.ps1 -IncludeGcp`, together with the VM `rehost-gcp`). Not yet confirmed that Google accepts this VMDK subtype as monolithic.
2. Cloud side: enable APIs, create bucket (us-east1), upload, grant the three roles, create the target project, run the import, boot a small VM, compare the two hashes, roll back, tear down. Cost and end time to be written here before running.
3. Cost stop threshold: 0.25 USD, same as Azure. Expected ceiling about 0.10 USD, not measured.

## Does Google accept this image? (20 Oct 2026)

- Not confirmed. The documentation lists VMDK as accepted and recommended ("only monolithic VMDK files are supported") but never names the subtypes (monolithicSparse, streamOptimized, split). VirtualBox `--variant Standard` writes a single-file VMDK. Read locally on 20 Oct 2026: magic `KDMV`, `createType="monolithicSparse"` (one growable file, the monolithic kind). This is consistent with the documentation but does not prove acceptance. The only real test is the import itself; plan B is `disk.raw` in a `.tar.gz`.

## Estimated cost (not measured; prices read 20 Oct 2026 unless marked)

| Item | Price | Estimate for this drill |
|---|---|---|
| Migrate to Virtual Machines | "no charge for migrations into Google Cloud"; test or validation resources are charged | 0 for the tool; temporary resources of the import: unknown |
| Cloud Storage Standard, us-east1 | about 0.02 USD per GiB-month; upload free; Always Free 5 GB-months | 2.77 GiB for about one day: under 0.01 USD, probably 0 |
| Image storage | 0.05 USD per GiB-month | under 0.01 USD for a day |
| VM e2-micro | 0.0084 USD per hour (1 GB of RAM, too small); e2-small about double (derived, not read) | about 0.017 USD per hour, 2 h about 0.04 USD |
| Boot disk 20 GB | standard 0.04, balanced 0.10 USD per GB-month | about 0.001 to 0.003 USD per hour |
| External IPv4 | about 0.005 USD per hour (from memory, not confirmed) | 2 h about 0.01 USD |
| Egress | uploads free; SSH and hash checks negligible | about 0 |

Total estimate: about 0.05 to 0.08 USD (about 1 to 1.5 MXN); ceiling 0.10 USD, stop threshold 0.25 USD. Main unknown: temporary resources created by the import.

## Estimated time

Set-up of APIs and roles 15 to 20 min; upload about 10 min (2.77 GiB at about 44 Mbps); import 10 to 30 min (AWS took 22 min; the Google page shows 4.5 min only as an illustration); create and boot the VM 5 to 10 min; validation 10 min; rollback and teardown 5 to 10 min. Total about 1.5 to 2 h.

## Cloud-side set-up log, 20 Oct 2026 (operator runs the commands; output filtered)

- 12:57: APIs enabled in the trial project: Compute Engine, VM Migration, Cloud Storage (verified by listing). Billing was linked (`billingEnabled` True). Cost 0.
- 12:58: bucket created in us-east1 with uniform access and public access prevention (one bucket listed). Cost 0 until data is uploaded.
- 13:00 to 13:05, finding: granting `roles/vmmigration.serviceAgent` to the Migrate to Virtual Machines service agent failed twice with the generic message "Policy modification failed ... lint-condition". The cause was that the service agent did not exist yet (enabling the API does not create it). `gcloud beta services identity create --service=vmmigration.googleapis.com` created it (the `beta` component had to be installed first; `--quiet` fails with the bundled Python, run it interactively), and the same grant then worked (verified: 1 binding). Lesson: the error text points at conditions, the real cause was a missing identity; and discarding the output of the failing command hid it.
