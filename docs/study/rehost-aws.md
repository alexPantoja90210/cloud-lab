# CLOUD-38: AWS leg of the rehost (19 Oct 2026)

Input: `rehost-aws.vhd`, a dynamic VHD (2.84 GiB, 3,045,851,136 bytes) converted from the prepared `rehost-src` (RHEL 10.2, EFI, LVM root).
Path used: `import-image` (Path 1 of plan section 10). Path 2 (`import-snapshot`, `register-image`) was not needed and was not run.
All times are local (UTC-6) on 19 Oct 2026.

## Result in one line

Local VM to AWS: `import-image` accepted RHEL 10.2, the instance booted, and the page and data-file hashes matched the local VM and the Azure VM.
Cloud to cloud (the disk as it was uploaded to Azure, exported and imported): `import-image` accepted it too, the instance passed the EC2 status checks, but SSH never answered (port 22 closed): the boot stalled in cloud-init, which was pinned to the Azure datasource. It did not pass the validation.

## Timeline

| Step | Start / end | Measured |
|---|---|---|
| Terraform apply (bucket, role, security group) | before 11:54 | 8 added |
| Upload of the VHD to S3 | ended 11:54:03 | 3,045,851,136 bytes, equal to the local file |
| `import-image` | 12:07:24 to 12:29:01 | 21 min 37 s, status `completed` |
| ...stage `converting` | 12:07:58 to 12:14:17 (9%) | about 7 min |
| ...stage `updating` | 12:14:49 to 12:21:07 (43%) | about 7 min |
| ...stage `booting` | 12:21:39 to 12:27:26 (62%) | about 6 min |
| ...stage `preparing ami` | 12:27:58 to 12:28:29 (81%) | about 1 min |
| `run-instances` (t3.micro) to `running` | 12:31:18 to 12:31:37 | 19 s |
| Status checks passed | 12:34:40 | 3 min 22 s after launch |
| Rollback (terminate, deregister AMI, delete snapshot) | 12:36:34 to 12:37:10 | 36 s; terminate alone 33 s |
| Teardown of layer 1 (`scripts/teardown.sh aws`) | 12:40:12 to 12:40:58 | 8 destroyed, 46 s |

## Validation on AWS

- `systemctl is-system-running`: `running`.
- SHA-256 of the page served on port 80: `1bd9fcd1...4baeb98`, identical to local and Azure.
- SHA-256 of `/var/lib/rehost-data.txt`: `ba6baac6...4039`, identical.
- Interface `eth0` (the `net.ifnames=0` change held), `ena` module loaded, kernel `6.12.0-211.61.1.el10_2`, root filesystem 16 GB with 13% used.
- **Not measured:** the cloud-init state on AWS. `sudo` asked for a password over SSH and my command had already chained the rollback after it.

## What the plan got wrong

- Hypothesis: `import-image` would refuse RHEL 10.2 because the documentation lists only 10.0 and 10.1. **It accepted it.** The supported-versions list is a statement of what AWS tests, not a gate that the service enforces, at least for this image. One image, one date: do not generalize.
- The plan did not say that the volume created by `run-instances` is not tagged by the instance tags and **survived the termination** (20 GiB gp2, `available`, created 12:31:21, no tags). It was found only because I counted volumes after the rollback, and deleted by hand at about 12:39. A teardown that finds resources by tag would not have found it.
- Plan section 10 never said `$bucket` and other shell variables live per PowerShell window. An empty `$bucket` made `import-image` answer "Please specify either a UserBucket or a Url or a Snapshot", which points at the wrong cause. Check variable lengths before the call.
- My block chained a read that could fail (`sudo`) with the destructive rollback. Nothing could be stopped in between. Destructive steps go in their own block.
- The tag index (`resourcegroupstaggingapi`) still listed 3 resources with `layer=1` three minutes after the teardown: the terminated instance and two security-group rules, all gone by `describe-*`. Describe calls are the proof; the tag index lags.

## Image preparation: what was changed, what was not isolated

Changes made before the conversion (`scripts/prepare-image-for-aws.sh`): cloud-init datasource list set to `Ec2, None`, Azure datasource file removed, `cloud-init.disabled` removed, `waagent` disabled, `nvme`/`nvme_core`/`ena` added to the initramfs.
The image booted with all of them. I did not test which ones were required, so this is "sufficient", not "necessary".

## Cost

Expected, not yet read: instance about 5.5 minutes of t3.micro, public IPv4, a 20 GiB gp2 volume for about 8 minutes, 2.84 GiB in S3 for about 45 minutes, import snapshot for about 8 minutes. Well under 0.01 USD. The account has no free EC2 hours. Real figure to be read by tag after the Cost Explorer lag.

## Not done

- Path 2 (`import-snapshot`, `register-image`, `run-instances`) was not exercised.
- cloud-init state on the first (prepared) image.
- The exported Azure disk was never booted successfully on AWS: the fix (datasource `Ec2`) was not applied to it and re-tested, because the first import is that disk plus the preparation script.
- Cost read, tag-index re-check, Terraform twin and runbook.

## Cloud-to-cloud leg: the disk that ran on Azure (19 Oct, 12:53 to 14:08)

Scope: the same disk as it was uploaded to Azure (`rehost-src.vhd`, fixed 20 GiB, **not** prepared for AWS), exported from Azure and imported into AWS.
Deviations from CLOUD-38 as written: the Azure VM was **not** booted before the export (time and cost; the exported bytes are those uploaded, without anything the VM would have written), and the file was converted to a dynamic VHD before the S3 upload.

| Step | Measured |
|---|---|
| Azure disk for upload created, azcopy upload of 20 GiB | 12:53 start; upload 12:55:25 to 13:00:38, 5.17 min, 21,474,836,992 bytes (18 Oct: 3.8 min) |
| Read access to the disk, azcopy download to the laptop | started 13:03:10, finished before 13:10:32; 26.3% (about 5.3 GiB) in the first minute; `Completed`, 21,474,836,992 bytes |
| Integrity | SHA-256 of the download equals the SHA-256 of the VHD uploaded on 18 Oct (hash took 48 s) |
| Azure disk deleted | after revoking the read access; resource group empty at about 13:15 (disk lived about 22 min) |
| Convert to dynamic VHD (VBoxManage) | 23 s, 20 GiB to 2.84 GiB |
| Terraform for the AWS side again (8 resources) | 13:18:23 to 13:19:13 |
| Upload to S3 and `import-image` | `completed` at 13:45:57; the start times were not recorded |
| `run-instances` to `running` | 13:47:53 to 13:48:12, 19 s |
| EC2 status checks passed | 13:50:46, 2 min 53 s after launch |
| SSH | timed out, then refused (see below) |
| Rollback (terminate, volume, AMI, snapshot) | 14:03:40 to 14:08:22; terminate took 4 min 36 s (33 s on the first instance) |

### What happened on AWS

- The first SSH attempt timed out because the home IP address had changed since the first test and the security group rule held the old one. Fixed with Terraform (`0 to add, 1 to change`) and the attempt repeated.
- Then SSH was refused and port 22 was closed. The EC2 console log shows the kernel booted from the NVMe root disk with the `ena` driver in use and a DHCP lease on `eth0`, then `cloud-init` in the local stage failed: `Azure datasource failure`, `failure to find primary DHCP interface`, then a `401 Unauthorized` from the metadata service (the instance had `HttpTokens=required`). The last console line is at second 40.9 of the boot; a read 14 minutes later showed nothing new.
- **Hypothesis, not confirmed:** the boot stalled in `cloud-init-local` because its datasource is pinned to Azure, which blocks the network and `sshd`. I could not log in to check. The longer terminate time is consistent with a hung boot, not proof of it.
- The first import worked because `prepare-image-for-aws.sh` set the datasource list to `Ec2, None`, removed the Azure datasource file, and added the `nvme` and `ena` drivers. This run shows the datasource change is what decides the boot; whether the drivers were needed was not isolated (the kernel used `ena` without our change: either the import service added the drivers or the image already had them).

### What this changes in the comparison

- **An accepted import is not a working VM.** `import-image` accepted both disks. Only the one whose datasource had been changed served the page.
- **The cost of moving between clouds is the preparation, not the transfer.** The Azure export of 20 GiB took under 8 minutes to download and the hash matched; the work that makes the disk boot on the other cloud is inside the guest.
- **Azure to AWS with this file moved 20 GiB twice** (down to the laptop, then up as a dynamic 2.84 GiB after a conversion). A direct copy between the clouds was not tried.

### Mistakes of mine in this leg

- The first Azure block called `azcopy`, which was not on the PATH of that window (installed after it was opened); the upload ran 2 minutes later than planned.
- The plan without `-target` showed 30 resources to add; the guard on the count stopped it, and the plan was redone with the four targets.
- I asked for the read access to the Azure disk and gave no closing step; the delete failed until the access was revoked.
- A VBoxManage conversion failed because the exported file carries the same internal identifier as `rehost-src.vhd`; `internalcommands sethduuid` changed it (so the hash of that file is no longer the one verified).

## Alex's surprises

To be added by Alex.
