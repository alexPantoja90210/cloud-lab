# CLOUD-37: rehost of a local Linux VM to Azure (started 18 Oct 2026)

Source: `rehost-src`, a full clone of the lab VM `node2` (RHEL 10.2, 2 vCPU, 2 GB, EFI, 20 GB dynamic VDI, LVM root).
`node2` itself was never modified. Local preparation is free; the Azure leg has its own cost and end time.

## Local preparation (18 Oct, 21:18 to 21:51 local)

| Step | Alex's prediction | Result |
|---|---|---|
| Full clone | no time given | 1 min (21:18), 2.78 GB on disk |
| Boot and what stays the same | boots; only the IP changes | Boots; IP 10.10.10.4; hostname stayed `node2` |
| Packages Azure needs | not given | none of nginx, WALinuxAgent, cloud-init, hyperv-daemons was installed; all four available in the RHEL 10 AppStream repo |
| After rebuilding the boot image | boots, with another name | Boots; the name is not changed by that step |
| Interface after kernel parameters | same IP | `eth0` (was `enp0s3`), same IP, same page hash |
| First boot on Azure | will not boot first time | pending |
| VHD conversion | 20 GB, 10 min | 20 GiB, 20 s |

## What the plan got wrong

- Section 5 said the base system runs no service. It does: an Apache (`httpd`) serving `/srv/web` on port 80, left over
  from a Linux exercise. nginx could not bind the port. Decision: migrate the existing `httpd` page and keep nginx
  installed but disabled.
- The initramfs held only `hv_vmbus`; `hv_netvsc` and `hv_storvsc` were missing and were added with a dracut file
  (`/etc/dracut.conf.d/hyperv.conf`). Without them the VM would boot on Azure with no network and no visible disk.
- Kernel parameters `console=ttyS0,115200n8` and `net.ifnames=0` added with grubby. The network profile was unbound from
  the interface name so the NIC kept working after the rename.
- `node1`, `node2` and `rehost-src` share the same SSH host keys (all descend from `rhel10-template`).
- The RHEL cloud-init template disables password login, so an SSH key (`id_rehost`, lab only) was installed in the image.
- `hypervkvpd` and `hypervvssd` are static units: nothing to enable.
- Step 10 asked for a powered-off VM and it was still running: `clonemedium` failed with "Failed to lock source media".
  Check `VMState=poweroff` before converting.

## Go criteria (plan section 5)

1. `rehost-src` is a full clone and boots locally: yes.
2. Page served locally, hash written down: SHA-256 of the response `1bd9fcd1c25d6d6345406ddc2f0facf43a959d5f719783fcd44d5106f4baeb98` (page from `/srv/web`);
   data file `/var/lib/rehost-data.txt` SHA-256 `ba6baac637cde45740eafc2804ac7c56ba689ed52fbc85357bbd4ba43d194039`.
3. Fixed VHD, size a multiple of 1 MiB, hash written down: 20 GiB, multiple of 1 MiB (True), SHA-256
   `94752236FC251FC5AEC401D24BB112C64BF0ACD43908DE380B2EE4BB8DC4E2AC`.
4. Packages installed and Hyper-V drivers in the boot image: yes (`rpm -q`, `lsinitrd`).
5. Azure end time written and resource group empty at the start: pending.

Azure agents (`waagent`, `cloud-init`) were enabled last and not boot-tested locally on purpose: cloud-init would wait for
an Azure that does not exist on the home network. The first real test is the Azure boot.

## Azure leg (18 Oct, 21:56 to 22:18 local; UTC = local + 6 h)

Built by hand with the CLI in `rg-cloud-lab`, region denmarkeast, zone 1, tags lab/layer/domain=rehost. Not in Terraform state.
End time stated in advance: 23:30 local; upload cut-off 22:50. Actual end of the drill: 22:18 local.

| Step | Alex's prediction | Result |
|---|---|---|
| Disk for upload (`--for-upload`, 21474836992 bytes) | state: "empty" | `ReadyToUpload` (state is lifecycle, not content) |
| Upload of the 20 GiB VHD with azcopy | not given | 3.8 min (21:56:20 to 22:00:16); about 100 Mbps on the real data |
| VM created from the disk | 3 min | 44 s |
| First boot on Azure | will not boot first time | booted; SSH by key answered; page hash identical |
| `is-system-running` | not given | `degraded` at first boot, `running` after the fix and a reboot |
| Deallocate | 1 min | 37 s |
| Sample download from the disk | 1 min | 64 MiB in 39 s, about 14 Mbps (asked for 1 GiB) |
| Rollback: delete VM and every resource | 5 min | 49 s; resource group empty a few seconds later |

Validation on Azure: SHA-256 of the page `1bd9fcd1...4baeb98` and of `/var/lib/rehost-data.txt` `ba6baac6...4039` identical to local;
`waagent` active; `eth0` took 10.0.0.4 from Azure DHCP (the unbound network profile worked).

## Findings from the Azure leg

1. Upload time follows the data, not the disk size. azcopy skips zero ranges of a page blob (hypothesis, consistent with the numbers):
   20 GiB in 4 min at about 100 Mbps of real data, against 26 min estimated from the file size.
2. `cloud-init` failed on the first boot: `useradd: invalid user name ''`. A VM created with `--attach-os-disk` gets no OS profile,
   so the Azure datasource reads an empty admin user (hypothesis from the error). It made `cloud-init` and `cloud-final` fail and
   the system `degraded`. Fix applied on the Azure VM only: `/etc/cloud/cloud-init.disabled`; after a reboot the state was `running`.
   The local VHD still has cloud-init enabled and needs the same fix if it is used again as a specialized disk.
3. The drivers `hv_netvsc` and `hv_storvsc` in the boot image, the console and `net.ifnames` kernel parameters, and unbinding
   the network profile from the interface name were all needed for a first boot with network.
4. The NSG created by `az vm create` would allow SSH from anywhere; a dedicated NSG allowed port 22 only from the operator's IP.
5. The first `az resource list` after deleting listed one disk that was already gone: deletion is asynchronous.
6. A single range request on the disk URL returned 64 MiB, not the 1 GiB asked for (hypothesis: a per-request limit).
   Disk read speed about 14 Mbps on one request, below the 44 Mbps of the home line.
7. The first 64 MiB downloaded from the Azure disk are byte-identical to the local VHD (EFI and /boot included).

## Not done, and why

- Full export of the 20 GiB disk back to a file: the outbound data price was not read and one request is slow;
  only a 64 MiB sample was exported and compared. To decide after reading the data-transfer meter in Cost analysis on 19 Oct.
- A Terraform twin for the Azure leg: the restored disk and the VM are created with the CLI (the provider does not
  attach an existing OS disk reliably, as in CLOUD-35).
- The AWS leg is CLOUD-38 (November); `rehost-export\rehost-src.vhd` (20 GiB) and `sample-1GiB.bin` stay on the laptop.

## Cost read, 19 Oct 2026 (CLI, gross USD, 18 to 19 Oct)

Read with `scripts/azure-cost-read.ps1`; the portal read by the operator is still to be added.

| Tag | Total | Meters |
|---|---|---|
| domain=compute (CLOUD-35) | 0.0037 | B1s 0.0020 (0.167 h), E4 disk 0.0017 |
| domain=rehost (CLOUD-37) | 0.0074 | Standard IPv4 static public IP 0.0047 (0.947 h), B1s 0.0018 (0.15 h), E4 disk 0.0008 |
| no tag filter (all meters) | 0.0111 | the two above plus 0.00003 of other operations; storage meters are all "Free" at 0.0 |

- The whole Azure bill of the three drills of 18 Oct was 0.0111 USD, 4 percent of the 0.25 USD daily stop threshold.
- Estimates were high: CLOUD-35 about 0.03 expected against 0.0037; CLOUD-37 0.03 to 0.05 expected (the plan said 0.10 to 0.20) against 0.0074.
- Nothing carried no tag: compute plus rehost equals the unfiltered total within 0.00003 USD.
- The public IP was the most expensive meter of CLOUD-37 (64 percent), the same kind of piece as the private endpoint of 16 Oct.
- The activity log gives the real life of the IP: created 04:03:13 UTC, deleted 04:17:03 UTC, 13 min 50 s (0.23 h). Billed quantity: 0.947 h, about 4.1 times more. The cause is not explained.
  Working rule until it is: for an hourly meter budget at least one full hour, not the minutes observed.
- The outbound data meter does not answer the export question yet: "Standard Data Transfer Out - Free" shows 0.00049 and the sample read from the disk was 64 MiB (about 0.06 GB), so the disk read is not posted yet or sits in another meter. Read again on 20 Oct.
- Tooling lessons: `az monitor activity-log list` returns 50 events unless `--max-events` is raised (the creation events were cut off); in Windows PowerShell 5.1 a JSON array piped straight from `ConvertFrom-Json` arrives as one object, so store it in a variable first; the cost API answers 429 when queried several times in a row, and a failed query must not be shown as "no rows" (the script now retries and says QUERY FAILED).
