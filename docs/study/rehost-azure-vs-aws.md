# Rehost of the same VM: Azure vs AWS vs cloud-to-cloud (CLOUD-37, CLOUD-38)

One source VM (`rehost-src`, RHEL 10.2, EFI, LVM root), the same two hashes as the check, two clouds, 18 and 19 Oct 2026.
Single runs by one operator on one image: these are observations, not benchmarks. Hypotheses are marked.

## Side by side

| Question | Azure (18 Oct) | AWS (19 Oct) |
|---|---|---|
| Image format accepted | Fixed VHD only, size a multiple of 1 MiB (20 GiB file) | Dynamic VHD accepted (2.84 GiB); docs also list VMDK, OVA, RAW |
| Bytes uploaded | 20 GiB file; azcopy took 3.8 min (zero ranges skipped, hypothesis) | 2.84 GiB; upload not timed |
| Who converts the image | Nobody: the disk is used as uploaded | The service: `import-image` converts, updates and boots it, 21 min 37 s |
| What had to change inside the guest | Hyper-V drivers in the initramfs, `console=ttyS0`, `net.ifnames=0`, network profile unbound from the interface name, `waagent`, cloud-init | `nvme` and `ena` drivers, cloud-init datasource `Ec2`, `waagent` off; the `net.ifnames=0` change from the Azure leg carried over |
| Source OS version vs the vendor's list | Not checked in the plan | Docs list RHEL 10.0 and 10.1; 10.2 was accepted anyway |
| Upload ends to first SSH | 44 s to create the VM, booted | 21.6 min import, 19 s to `running`, 3 min 22 s to status checks passed |
| First-boot problem | cloud-init failed: empty admin user from `--attach-os-disk`; fixed with `cloud-init.disabled` | None seen; cloud-init state not measured |
| Rollback | 49 s, everything deleted by hand; deletes are asynchronous | 36 s (terminate 33 s); one untagged 20 GiB volume survived and was deleted by hand |
| What was left behind | Nothing after listing again | The volume above; the tag index still listed 3 deleted resources for minutes |
| Cost read | 0.0074 USD for domain=rehost (public IP billed 0.947 h for a 13 min 50 s life) | Not read yet; expected well under 0.01 USD |

## What this says (and does not)

- Azure asks you to prepare the **file** (fixed, aligned) and hands you a disk you boot as is; AWS asks you to prepare the
  **guest** a little (drivers, datasource) and does the conversion itself. The first is faster to the first boot and the
  second needed less on my side, once the service stage times (about 22 min, all AWS-side) are accepted.
- Both clouds needed a driver change in the boot image. Neither would have booted the unmodified Hyper-V/VirtualBox image
  (Azure: from the missing `hv_*` drivers; AWS: not tested without `nvme`/`ena`, so "sufficient" not "necessary").
- The vendor's supported-version list did not predict the AWS outcome. Trust the run, record the list.
- Only the AWS leg left something that a tag-based teardown would not have found: the volume had no tags. Count
  volumes, snapshots and images by owner after any rollback.
- Open on both: no cost read yet for AWS; Azure's billing hours do not match lifetimes and the cause is unknown.

## Cloud to cloud: measured on 19 Oct

The disk uploaded to Azure on 18 Oct was exported again (the Azure VM was not booted first) and imported into AWS. Details in `rehost-aws.md`.

| | Measured |
|---|---|
| Re-upload to an Azure disk | 5.17 min for 20 GiB |
| Download from the Azure disk to the laptop | under 8 min for 20 GiB (5.3 GiB in the first minute); SHA-256 equal to the uploaded file |
| Single range request on the disk URL (18 Oct) | 64 MiB in 39 s, about 14 Mbps: a limit of that one request, not of the download |
| Transfer price out of Azure | the provider's page says the first 100 GB a month are free; the usage meter was not read yet (to read 20 Oct) |
| `import-image` of the exported disk | accepted |
| Boot on AWS without preparing the guest | status checks passed, SSH never answered; cloud-init was pinned to the Azure datasource and the boot stalled there (hypothesis) |

Reading: the transfer is the easy part. What differs from the local import is inside the guest (datasource, agents), not the file format or the bytes moved.
