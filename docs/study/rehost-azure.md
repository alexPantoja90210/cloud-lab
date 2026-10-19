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

## Azure leg

Pending.
