# DR recovery, Azure (CLOUD-35): targets and results

## Targets written before the drill (17 Oct 2026, about 17:31 local, Alex)

- **RPO hypothesis:** the last snapshot is acceptable; up to 1 hour of work lost.
- **RTO hypothesis:** 1 hour, for both the manual recovery in the portal and the Terraform and CLI
  recovery. "Let's try one hour and see if it is possible."

These are hypotheses, not promises. The drill measures the real times and the note says where the time went.

## Results (18 Oct 2026, Azure leg; the AWS redeploy time is still to be measured)

Build 22:09 to 22:11 UTC (VM and incremental snapshot, 8 resources). Times below are to the minute for T0,
T1 and T2, and include the time spent exchanging messages with the assistant.

| Path | Start | End | Time |
|---|---|---|---|
| Manual, in the portal | T0 22:12 (VM and disk deleted) | T1 22:27 (VM running) | about 15 minutes |
| Terraform and CLI | T2 22:31 (manual VM deleted) | T3 22:37:56 (VM running) | about 7 minutes, including one failed attempt |

Both are far below the RTO hypothesis of 60 minutes. RPO was not exercised: the snapshot was taken right
after the build, so no data was lost by construction.

Where the time went (manual path): disk from the snapshot about 6 minutes after T0, VM creation started 8
minutes later, VM deployed in about 1 minute. Azure itself took about 1 minute per piece; the rest was
reading the wizards and correcting defaults.

What the drill showed:
- The disk wizard defaults to Premium SSD; the portal does not show a price on the review page. The VM
  wizard defaulted to a new virtual network, created a network security group of its own even with no
  public IP, did not tag anything it did not create, and set "delete OS disk with VM" to No.
- `az vm create` without `--location` used the resource group's region (East US 2, where B1s is not
  available to this subscription) instead of the disk's (Denmark East): a failed attempt, no cost.
- The azurerm provider could create the restored disk but not the VM that uses it; the VM was made with the
  CLI and is outside the Terraform state, so it had to be deleted first at teardown.
- An interrupted `apply` earlier in the session left the state blob leased (lock with empty metadata); it
  was cleared by breaking the lease after checking no Terraform process was running.

What would shorten recovery: tag and name the pieces in advance, keep the recovery as one script with the
region set, and keep a runbook so the first manual run is not the one that is timed.

## Log of surprises (Alex, 18 Oct 2026)

Creating resources through commands and programmatically is flexible and practical; there are many commands
and parameters to learn, but it becomes fascinating how automatable it is.
