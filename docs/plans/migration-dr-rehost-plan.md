# Plan: migration, DR and rehost drills (CLOUD-33)

Status: **APPROVED v1, 17 Oct 2026.** Drafted by Claude from the lab record; the three open decisions
(section 8) were approved by Alex on 17 Oct 2026 as proposed. The plan is committed before any drill runs and
updated after each one with what it got wrong (last section).

## 1. Scope and assumptions

Three drills, in this order, all on test data only:

| Order | Task | Drill |
|---|---|---|
| 1 | CLOUD-35 | Snapshot the B1s OS disk, delete the VM, restore by hand and by Terraform, record both recovery times, compare with an AWS redeploy |
| 2 | CLOUD-34 | Move test objects from an Azure Blob container to S3 with a plan, checksums and a rollback |
| 3 | CLOUD-37 | Rehost: a full clone of the local Linux VM `node2` goes to Azure; its disk is exported as a file for the AWS leg (CLOUD-38, November) |

Assumptions:
- Azure runs on a credit that expires about 31 Oct and does not come back. Every Azure drill ends before then.
- No real data and no production system. The source VM is a lab VM (RHEL 10.2, 2 vCPU, 2 GB, EFI, 20 GB dynamic VDI).
- `node2` itself is never modified: all preparation is done on a full clone named `rehost-src`.
- Layer 0 (state, budgets, tags, roles) is never destroyed; layer 1 is destroyed after every session.
- Home connection read on 17 Oct: 44 Mbps down, 108 Mbps up.

## 2. RACI

One person holds every human role today; the table keeps the roles apart so they can be handed over.

| Activity | Sponsor | Owner | Operator | Reviewer |
|---|---|---|---|---|
| Approve scope, cost thresholds, go/no-go | Alex | Alex | | |
| Write the plan and the Terraform | | Claude (drafts) / Alex (approves) | | Alex |
| Build and run drills in the portals | | | Alex | |
| Read cost in the portals | | | Alex | |
| Read cost and state from the CLI, verify teardown | | | Claude (reads) / Alex (runs) | Alex |
| Update the plan after each drill | | Alex | | Claude (drafts) |

Decided 17 Oct 2026 (Alex): Alex holds every human role; Claude drafts and reads. Revisit if more than one
person ever works on this.

## 3. Risk register

Every risk cites an event from the lab record.

| # | Risk | Lab event it comes from | Mitigation | Stop signal |
|---|---|---|---|---|
| R1 | A resource bills for more hours than believed | Private endpoint billed 0.85 h on 12 Oct against about 10 minutes believed; 17 Oct read: endpoint 2.66 h and one disk about 0.96 h against a VM of 0.63 h | Write create and destroy timestamps for every resource; read the activity log for real lifetimes; state an end time before apply | A resource still exists after the stated end time |
| R2 | A resource created by hand keeps billing by the hour | The Bastion created by hand and billed hourly until deleted | Every hand-built resource goes in one resource group and is listed at the end with `az resource list` | Listing is not empty after teardown |
| R3 | The credit expires with work unfinished | Azure credit ends about 31 Oct | All Azure legs scheduled before 31 Oct; the exported disk file kept on the laptop; no removal of the spending limit as a shortcut | Fewer than 3 days left and a drill not started |
| R4 | A stopped VM still bills | 12 Oct: B1s billed 2.98 h = Running 1.70 + Stopped (Allocated) 1.28 | Deallocate or destroy, never just stop | VM state is Stopped, not Deallocated |
| R5 | Untagged or foreign resources hide inside the cost view | 12 Oct: 1.03 USD of the 1.04 USD budget was four stopped EC2 instances and disks from an earlier effort; 17 Oct inventory: two untagged network watchers | Run `scripts/inventory.ps1` before and after each drill | Inventory shows an untagged resource that bills by the hour |
| R6 | Console rounding hides cost | 16 Oct: AWS console 0.00 for the domain; Azure portal 0.02 against 0.041 from the CLI | Read cost twice (portal and CLI) and keep the CLI figure | Portal and CLI differ by more than the rounding |
| R7 | Teardown takes much longer than the build | 16 Oct: a Lambda network interface blocked the VPC delete for 20 to 40 minutes | Leave 1 hour for teardown on any AWS drill that touches a VPC | VPC delete fails twice |
| R8 | A partial plan misses a dependent resource | 16 Oct: the first plan counted 18, not 19 (DNS link missing from `-target`) | Compare the plan count with the count computed from the code before applying | Count differs and the difference is not explained |

## 4. Cost plan

Predictions are made before running; actual figures are read the next day in the portal (by Alex) and
from the CLI (by Claude).

| Drill | Predicted | Basis | Where Alex reads it |
|---|---|---|---|
| CLOUD-35 | about 0.05 USD | B1s 0.012 USD an hour, snapshot of a small disk for hours, disk 0.0033 USD an hour | Cost analysis, tag `domain=compute`, group by meter |
| CLOUD-34 | under 0.05 USD | Kilobytes of transfer, a few objects | Cost analysis (Azure) and Cost Explorer (AWS) |
| CLOUD-37 (Azure leg) | about 0.10 to 0.20 USD | A 32 GiB disk and a B1s for a few hours; upload and download of 20 GB; the egress price must be read in the portal before exporting | Cost analysis, tag `domain=rehost`, group by meter |

Stop threshold, decided 17 Oct 2026 (Alex): stop the drill and run teardown if the cost read for the
day is above 0.25 USD or if the session passes its stated end time, whichever comes first.

## 5. Rehost: inventory, go/no-go, cutover, rollback

Inventory of the source (from the lab record): `node2`, RHEL 10.2 minimal, 2 vCPU, 2 GB, EFI, 20 GB dynamic
VDI, linked clone of `rhel10-template`, NAT network `labnet`, DHCP address, SSH through a forwarded port.
The base system runs no service, so the clone gets one nginx page and one data file so that validation
means something.

**Go criteria** (all measurable, checked before anything is uploaded):
1. `rehost-src` is a full clone and boots locally.
2. `curl` to the local nginx returns the expected page; its SHA-256 is written down.
3. The disk is converted to a fixed VHD whose size is a multiple of 1 MiB; its SHA-256 is written down.
4. The packages `WALinuxAgent`, `cloud-init` and `hyperv-daemons` are installed (`rpm -q`) and the
   Hyper-V drivers appear in the boot image (`lsinitrd`).
5. The Azure end time is written and the resource group is empty at the start.

**Cutover sequence:** upload the VHD to a managed disk; create a Generation 2 VM from it; boot; validate.
**Validation (same checks as local):** SSH answers; `curl` returns the same page with the same SHA-256;
`systemctl is-system-running` reports `running`.

**No-go and stop:** no SSH answer 15 minutes after the VM reports Running; the validation hash differs; the
running cost passes the threshold in section 4.

**Rollback:** the local `node2` and `rehost-src` are untouched, so rollback is deleting the Azure VM and
disk and confirming the resource group is empty. It is exercised once by doing exactly that and timing it.

## 6. Deployment

Layer 0 builds the state backend, budgets, tag scheme and role definitions and is never destroyed. Layer 1
holds everything a drill creates and is destroyed by `scripts/teardown.sh azure|aws`, which saves redacted
evidence in `evidence/`. After each session: `scripts/inventory.ps1`, `az resource list` on the layer 1
resource group, and the AWS tag query. Evidence files are read before they are committed. Local data (test files, export sample, and at the end of CLOUD-38 the VM clone `rehost-src` and the exported VHD) is removed with `scripts/local-cleanup.ps1`; the clone and the VHD stay until CLOUD-38 is finished.

## 7. Assumptions to test (from vendor documentation, not from the lab record)

These are not risks yet because no lab event backs them. The drill confirms or refutes each one.

- AWS VM Import/Export lists RHEL 10.0 to 10.1; the source is 10.2. If the import is refused, the
  fallback is importing the disk as a snapshot and registering an image.
- Azure accepts only fixed-size VHD and a generic upload needs the agents above; the Azure page does not
  clearly confirm RHEL 10.
- At 108 Mbps up, 20 GB takes about 25 to 45 minutes to upload; at 44 Mbps down, exporting it back takes
  about an hour. Both are estimates until timed.

## 8. Open decisions for the operator

Decided by Alex on 17 Oct 2026:
1. Owners for each RACI role: as in section 2.
2. The stop threshold: 0.25 USD for the day or the stated end time.
3. The order 35, 34, 37 stands.

## 9. Updated after the drills

To be filled in after each drill: what happened, and what this plan got wrong.

### CLOUD-35 (DR recovery, 18 Oct 2026) - Done

- Azure by hand about 15 min; Azure with Terraform plus CLI about 7 min including one failed attempt; AWS Lambda redeploy 32 s. The RTO hypothesis of 60 min held on every path. Details: `docs/study/dr-recovery-azure.md`.
- What the plan got wrong: it did not foresee that `az vm create` without `--location` uses the resource group region (SkuNotAvailable), that an interrupted apply leaves the state blob leased, or that the portal wizard creates its own NSG and does not tag. The runbook now covers all three.

### CLOUD-34 (Blob to S3, 18 Oct 2026) - Done

- Planned under 0.05 USD and a few cents; real cost to be read on 19 Oct. One session of about 33 minutes: by hand about 5 min, by script 23 s, rollback exercised, presigned URL read, both sides destroyed and verified empty. Details: `docs/study/migration-blob-to-s3.md`.
- What the plan got wrong: it assumed the move would carry the objects as they were. The manual path loses metadata and re-guesses the content type, and the tier does not map by name (Cool to Standard-IA brings a 128 KB minimum and 30 days). Tags could not be tested because the operator role lacks the right to write them. The script now maps tier, keeps metadata and checks MD5 against the ETag.
- Order change: CLOUD-34 was planned as a second session with a separate tool step; it fit in one. The next in order is CLOUD-37.

### CLOUD-37, Azure leg (18 Oct 2026)

- The VM booted on Azure at the first attempt and passed the three checks (SSH, same page hash, `running` after one fix). Rollback timed: 49 s. Details: `docs/study/rehost-azure.md`.
- What the plan got wrong: it said the base system runs no service (an Apache from a Linux exercise was already serving port 80); it assumed the upload time would follow the 20 GiB size (it took 4 minutes); it did not foresee that a disk attached with `--attach-os-disk` leaves `cloud-init` failing on an empty user name; and it left the full disk export open without a price. Only a 64 MiB sample was exported.
- Open: read the outbound data meter on 19 Oct and decide whether to do the full export; CLOUD-38 (AWS, November) starts from the local VHD.

### Cost read of 19 Oct 2026 and risk R1

- The three Azure drills of 18 Oct cost 0.0111 USD in total (gross, by CLI), 4 percent of the stop threshold; everything was tagged. Estimates in section 4 were 4 to 10 times too high.
- R1 gets a third data point: the public IP of CLOUD-37 lived 13 min 50 s (activity log) and billed 0.947 h. Updated mitigation: for any hourly meter budget at least one full hour; the activity log is read with `--max-events` raised, and the result is stored in a variable in Windows PowerShell 5.1.
- Still open: the outbound data meter for the export decision (read again on 20 Oct).

## 10. AWS leg of the rehost (CLOUD-38) - executed 19 Oct 2026 (v1 text kept; see 10.9 for what it got wrong)

Written 19 Oct 2026 from the vendor documentation of that day and from the two drills of 18 Oct. Everything under "expected" is a hypothesis
until the drill runs.

### 10.1 Scope and inputs

- Input A: the local VM disk (`rehost-src`, RHEL 10.2, EFI, LVM root), already validated on Azure (page hash `1bd9fcd1...4baeb98`, data file hash `ba6baac6...4039`).
- Input B: the disk exported from Azure. **Not available**: only a 64 MiB sample was exported on 18 Oct and the Azure disk was deleted. See decision D1.
- Region: us-east-1, as the rest of the lab. Network: the default VPC (to be checked with `describe-vpcs`; the lab has no AWS network of its own now).

### 10.2 What the AWS documentation says (read 19 Oct)

- Supported RHEL: 5, 6, 7, 8.0-8.9, 9.0-9.7 and **10.0-10.1** (kernel 6.12.0). The source is **10.2**: not listed.
- Formats: VHD and VHDX (fixed and dynamic), stream-optimized VMDK, OVA, RAW. Boot mode `uefi` or `legacy-bios` (`--boot-mode`).
- Linux limits: default kernels only; **predictable interface names are not supported** (the image already uses `net.ifnames=0`); a fallback `BOOTX64.EFI` must exist on the EFI partition; the AWS NVMe and ENA drivers are recommended in the image; one network interface with DHCP; **only a private IPv4 address after `import-image`**; no encrypted volumes.

### 10.3 Image preparation (local, no cost) on `rehost-src`

1. Remove `/etc/cloud/cloud.cfg.d/91-azure_datasource.cfg` (it pins the datasource to Azure) and set `datasource_list: [ Ec2, None ]`.
2. Disable `waagent` (Azure only).
3. Add `nvme` and `ena` to the boot image through the dracut file used on 18 Oct, and rebuild it. (The Azure drivers `hv_*` can stay.)
4. Check that `/boot/efi/EFI/BOOT/BOOTX64.EFI` exists.
5. Power off, confirm `VMState=poweroff`, convert to a **dynamic** VHD (about 3 GB of real data) instead of the 20 GiB fixed one: S3 stores and the upload moves every byte of a fixed file, 20 GiB at 108 Mbps is about 26 minutes against about 4 for the dynamic one (estimates). Write the SHA-256 of the file.

### 10.4 Paths

- **Path 1, the documented one:** `import-image` with `--boot-mode uefi` and `--license-type BYOL`, with the `vmimport` service role and a bucket policy. Expected: refused because of 10.2. Record the exact error and the time to refusal.
- **Path 2, fallback:** `import-snapshot`, then `register-image` (UEFI, ENA enabled), then `run-instances` on a Nitro type (t3.micro) with auto-assigned public IP. This path does not check the OS version.
- If Path 1 is accepted, the instance gets a private address only: an Elastic IP is needed (it bills by the hour).

### 10.5 Validation, rollback, teardown

- Validation, the same three checks as local and Azure: SSH by key answers; page and data file give the same hashes; `systemctl is-system-running` is `running`. SSH is allowed only from the operator's IP in a dedicated security group.
- Rollback, timed: terminate the instance, deregister the AMI, delete the snapshot, delete the S3 object, delete the role; then the tag query and `describe-*` calls return nothing. Everything created by the import is tagged `lab=cloud-lab, layer=1, domain=rehost`.
- Teardown evidence is read before it is committed; the local clone and VHD are removed with `scripts/local-cleanup.ps1 -IncludeRehost -Execute` only when CLOUD-38 is finished.

### 10.6 Cost and stop (estimates, not measured)

Under 0.10 USD for a session of about 2 hours: S3 for about 3 GB for hours, an EBS snapshot, a t3.micro (about 0.0104 USD an hour) and a public IPv4 (about 0.005 USD an hour). Stop threshold unchanged: 0.25 USD for the day or the stated end time. Rule from 19 Oct: for any hourly meter budget at least one full hour.

### 10.7 Risks specific to this leg

| # | Risk | Evidence | Mitigation | Stop signal |
|---|---|---|---|---|
| R9 | The import refuses RHEL 10.2 | Not in the supported list | Path 2 | Both paths fail |
| R10 | The instance does not boot on Nitro because the boot image lacks `nvme` or `ena` | Same failure class as the missing `hv_*` drivers on Azure (found by reading before building) | Step 3 of 10.3 and `lsinitrd` check before converting | No SSH 15 min after `running` |
| R11 | `cloud-init` pinned to Azure delays or breaks the first boot | The Azure datasource file left in the image | Step 1 of 10.3 | `is-system-running` is not `running` |
| R12 | Snapshots, AMIs or S3 objects keep billing after the drill | Lab rule: layer 1 destroyed; the tagging API lags after deletion | Tag everything; check with `describe-*`, not only the tag query | Anything listed after teardown |
| R13 | The import tasks take much longer than the build | Not measured | State the end time with margin; keep the Azure lesson that time follows data, not size | Task still `active` at the end time |

### 10.8 Decisions needed from the operator

- **D1.** Cloud-to-cloud input: (a) redo the Azure leg before about 31 Oct (re-upload 4 min, full export about 1 hour at best, outbound price still to be read on 20 Oct) and import that file in AWS; or (b) skip it, import only the local VHD, and record that the cloud-to-cloud leg was not done.
- **D2.** Use the 3 GB dynamic VHD for AWS (recommended) or the 20 GiB fixed one.
- **D3.** The session and its end time, to be set at the start of the run.

### 10.9 Result of the AWS leg (19 Oct 2026)

Details and times: `docs/study/rehost-aws.md`.
- Path 1 worked: `import-image` accepted RHEL 10.2 (expected refusal did not happen), 21 min 37 s, then t3.micro booted and both hashes matched.
- Path 2 was not needed and not run.
- Corrections to this section: the run-instances volume is untagged and survives termination (count volumes after rollback); shell variables are per window (check lengths before API calls); the tag index lags, use describe calls as proof.
- Teardown 12:40 with 8 destroyed; `redact.sed` gained a rule for the `rehost` bucket name and the random-string result line.
- Cloud-to-cloud (19 Oct): the disk uploaded to Azure was exported (download under 8 min, hash equal), converted to a dynamic VHD and imported: `import-image` accepted it, the instance passed the status checks, SSH never answered (cloud-init pinned to the Azure datasource stalled the boot, hypothesis). The Azure VM was not booted before the export. The plan's cloud-to-cloud step now needs the guest preparation as a step of its own, before the export. Details in `docs/study/rehost-aws.md`.
- Corrections to this section: a security group with one allowed address breaks when the home address changes (check it before blaming the instance); the access granted to an exported disk must be revoked before the disk can be deleted.

