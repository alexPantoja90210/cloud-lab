# Runbook DRAFT: rehost of a local Linux VM to Google Cloud (replica of CLOUD-37, started 20 Oct 2026)

Status: local preparation in progress. Nothing has been run in Google Cloud for this drill yet.
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

1. Convert the disk to a monolithic VMDK (`clonemedium --format VMDK --variant Standard`), note size and SHA-256. Local, free.
2. Cloud side: enable APIs, create bucket (us-east1), upload, grant the three roles, create the target project, run the import, boot a small VM, compare the two hashes, roll back, tear down. Cost and end time to be written here before running.
3. Cost stop threshold: 0.25 USD, same as Azure. Expected ceiling about 0.10 USD, not measured.
