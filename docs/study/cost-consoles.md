# Where to find cost in the three web consoles (CLOUD-40, 20 Oct 2026)

Read by the operator on 20 Oct 2026 for 1 to 20 Oct, then compared with the CLI figures in `docs/credit-log.md`.
Menu paths are the operator's own words, translated.

| Cloud | Where the operator found cost | Console figure | CLI figure |
|---|---|---|---|
| AWS | Billing, then Cost Explorer (group by Service; Charge type filter to exclude Credit) | 1.19 USD (EC2 - Other 1.09, Cost Explorer 0.08, EC2 - Instances 0.01) | 1.1892 USD gross |
| Azure | Cost admin, then Cost analysis (Actual cost, group by Meter) | 0.20 USD | 0.202 USD gross |
| Google Cloud | Billing, then Overview | 0.00 USD (panel lags hours) | none (no billing export set up) |

## What the operator noticed

- AWS: the Charge type filter was the hard part to find; first time used besides excluding. EC2 compute-related lines being the largest looked normal.
- AWS: the `AWS Cost Explorer` line (0.08 USD) is the cost of the CLI reads themselves, about 0.01 USD per call.
- Azure: the ~20 GiB export does not show. Cost analysis shows cost, and outbound data inside the free allowance costs 0, so the free meter draws nothing. Only the quantity (CLI, `Data Transfer Out - Free` 0.0038) shows it, and that value is still unexplained; re-read on 22 Oct.
- Azure: the console forecast (0.34 USD) is a linear projection, not real cost, because nothing is running.
- Google: Overview shows cost, not the 850 MXN card authorization hold; that hold is not a cost and is checked on 29 Oct.

## Nothing billable left, by eye in the console

- AWS (us-east-1, 20 Oct): operator read EC2 by eye: Instances, Volumes and Elastic IPs empty; Snapshots showed nothing (the screen read by Claude also showed no owned snapshots). Matches the CLI counts.
- Google Cloud (20 Oct): operator read Cloud Storage: no buckets.
- Azure: not confirmed. The operator's All resources screen showed a list of providers and services, not the resource list; the CLI inventory (20 Oct) shows 4 inert resources. To be read again by eye.
