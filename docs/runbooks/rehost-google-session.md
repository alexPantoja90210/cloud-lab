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

## Measured results, 20 Oct 2026 (times are local, UTC-6)

- Bucket role: `roles/storage.objectViewer` for the service agent verified (1 binding).
- Upload: 2,972,909,568 bytes in 135 s (about 176 Mbps). The 10 min estimate above was wrong by about 5x because it used the home line speed (44 Mbps) instead of what the upload really got.
- First import attempt failed with FAILED_PRECONDITION "TargetProject ... not found". Nothing was created, cost 0. The GA `gcloud migration vms target-projects` group only has `list`; the documentation gives no CLI or REST way to add one. It was added in the console (Migrate to Virtual Machines > Targets > Add Projects). Host project shown without a warning.
- Import: created 13:20:58, job RUNNING 13:22:43, SUCCEEDED 13:32:05 (about 9.4 min). First attempt, so BIOS-to-UEFI conversion and the monolithicSparse VMDK were accepted. Image READY, 20 GB disk, archive 2,127,641,280 bytes, features GVNIC, IDPF, VIRTIO_SCSI_MULTIQUEUE, UEFI_COMPATIBLE. The image appeared in the project at about 13:30:44.
- Temporary resources: polling every 60 s showed 0 disks and 0 instances in the project during the whole import; only the final image appeared. Any hidden cost of the import is not visible from the project; check the bill.
- The import installed the Google guest agent in the image (seen in the serial log), so `gcloud compute ssh` worked with no password.
- VM: e2-small, us-east1-b, 20 GB standard disk, no service account, created 13:47, booted to multi-user in about 70 s.
- Port 80 did not answer even though httpd was running: firewalld inside the guest had no `http` service (the local check had been done from inside the VM). Port 22 answered. Opened at runtime only with `firewall-cmd --add-service=http`; not made permanent.
- Acceptance: page HTTP 200, 28 bytes, SHA-256 starts 1bd9fcd1c25d6d63 = MATCH; data file SHA-256 starts e4ce0a5294ed84c1 and text "rehost-gcp data 2026-10-20" = MATCH.
- Security: the default network had SSH (22) and RDP (3389) open to 0.0.0.0/0. SSH was restricted to the operator's IP, the RDP rule was deleted, HTTP was allowed from the operator's IP only through a temporary rule, and the VM had no service account.
- Teardown 14:05 to 14:06: VM and disk, HTTP rule, image, image-import resource, bucket with the VMDK, and the project `ssh-keys` metadata were deleted. Verification: 0 instances, 0 disks, 0 images, 0 snapshots, 0 image-imports, 0 buckets, 0 addresses; firewall has only the three default rules (SSH now restricted to one IP).
- Left on purpose: the registered target project (no cost) and the gcloud SSH key on the operator's PC (outside the repo).
- Time: about 1 h 10 min from the first cloud command (about 12:57) to a verified-empty project; import 9.4 min; VM alive 13:47 to 14:05 (18 min).
- Cost: estimated about 0.007 USD for the VM time plus cents for storage; not measured. Real figure to be read from the billing panel on 21 Oct (it lags hours).

## Mistakes and lessons

- PowerShell: `R` is a built-in alias of Invoke-History, so my redaction helper never ran; the gcloud commands inside the parentheses still executed. Use a function name that is not an alias.
- A wrapped line in the PowerShell error text broke the redaction of the project ID once; filter at the source (`--format="value(...)"`) instead of redacting afterwards.
- The documented prerequisites were not enough: the service agent had to be created by hand and the target project had to be registered in the console.

## Real cost read in the Billing console, 21 Oct 2026

- Reports page, 1 to 21 Oct 2026, currency MXN (confirmed on the page): total usage cost MXN 0.14, all of it on 20 Oct, savings MXN 0.00. By service: Compute Engine MXN 0.09 and Networking MXN 0.05; the two lines add up to the total, so no other service (Cloud Storage, Migrate to Virtual Machines) shows a cost at this rounding.
- The cost breakdown page shows the same MXN 0.14 gross, offset by promotional credits and investment-based discounts, so the amount actually payable is MXN 0.00 (the card is blocked anyway).
- Against the estimate: about 0.007 USD for 18 minutes of VM time is roughly MXN 0.13 to 0.14 at about 19 to 20 MXN per USD (exchange rate approximate, not read from a source). The estimate and the measurement agree within the rounding of the panel.
- SKUs named by the console summary (Gemini Cloud Assist, a preview feature, so treat it with care): Compute Engine MXN 0.09, of which MXN 0.06 is "E2 Instance Core running in Americas" (the VM CPU); Networking MXN 0.05, of which MXN 0.02 is "Network Intelligence Center Network Analyzer Resource Hours". The earlier guess that Networking was the external IPv4 address was wrong for at least that MXN 0.02. The remaining MXN 0.03 of Networking and MXN 0.03 of Compute Engine are not attributed. Open question: Network Analyzer bills per resource-hour and was not started by us on purpose; check on 22 Oct whether a charge keeps appearing while only the default network and its three firewall rules remain.
- The import itself created no visible line: no separate Migrate to Virtual Machines cost and no temporary-resource cost appeared. Limits of that statement: one drill, panel rounding to MXN 0.01, and billing data can still be revised.
- Credit used by the whole drill: MXN 0.14 of the MXN 5,344 granted.

## Follow-up read, 22 Oct 2026

The open question from 21 Oct (does Network Analyzer keep billing while the default network and its firewall rules exist?) has a partial answer: the Billing overview for 1 to 22 Oct still shows cost 0.14, savings 0.14, total 0.00, with no new spike after 20 Oct. So nothing new was billed through the morning of 22 Oct. This was read from the overview, not from the SKU report, and the last day can lag; re-read the SKU report on 28 or 29 Oct before the close-out.
