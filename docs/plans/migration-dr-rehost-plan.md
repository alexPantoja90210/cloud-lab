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
resource group, and the AWS tag query. Evidence files are read before they are committed.

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
