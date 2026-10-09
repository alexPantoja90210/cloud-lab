# Credit log

One line per reading, format from `docs/closing-ritual.md`. Figures are as shown by the portal or console on the read date, never adjusted.

```
2026-10-09 | azure | credit 199.96 USD | mtd 0.04 USD | expires 2026-10-31 | portal
2026-10-09 | aws   | credit 174.88 USD | 130 days     | closes  2027-02-14 | console
```

Notes

- Azure: 22 days left on 9 Oct, so the expiry is about 31 Oct. Cost analysis for 7 to 9 Oct shows lab cost under 0.01 USD in total, so the month-to-date did not move from 0.04 USD.
- AWS: the console shows 130 days to 14 Feb 2027; counting from 9 Oct gives 128. Recorded as shown.
- AWS: the 175.04 USD baseline is from an earlier reading. The 0.16 USD drop covers all usage since then and is not attributed to a single session.
- AWS budget `finops-guardian-zero-spend`, console, 9 Oct about 10:35 local, after the CLOUD-26 teardown: actual 0.72 USD of 1.00 USD (71.70%); forecast month to date 3.40 USD (339.70%); threshold alerts shown as exceeded (2); email verification 0 of 1 verified. An earlier reading of 0.59 USD was taken before the storage session; it is not in the repo and its time was not recorded, so the 0.13 USD difference is not attributed to the session. The forecast is a straight-line extrapolation from a few days of data and is not a prediction. Cost data can lag by up to a day, so this reading may not yet include the whole session.
- AWS Cost Explorer, console, 9 Oct about 10:40 local, month to date, default view: total 0.00 USD; four services listed (EC2-Other, Glue, Tax, S3), all 0.00 USD, S3 shown as -0.00 USD. This is the net view (credits already applied), so it cannot be compared with the budget's 0.72 USD. The unblended view and the charge-type filter could not be reached from the console, so the gross cost per service was not read. The lab's layer 1 has no EC2 or Glue resources; those two lines come from other activity in the account and were not investigated.
- AWS Cost Explorer API, CLI, 9 Oct about 10:42 local: `get-cost-and-usage`, 9 to 11 Oct, daily, UnblendedCost grouped by tag `domain`. Both days returned 0 with no groups and `Estimated: true`. That is "no data yet", not "no cost": usage of the CLOUD-26 session (about 09:33 to 10:20 local on 9 Oct) normally shows up after a delay of up to a day, and `domain` was activated as a cost allocation tag the same morning. One call, about 0.01 USD. To be repeated on 10 Oct or later.
- Azure Cost Management query API, CLI, 9 Oct about 10:43 local: actual cost, 7 to 10 Oct, grouped by tag `domain` and service. Rows, in USD: identity / Container Instances 0.000724; untagged / Container Instances 0.001116; untagged / Storage 0.000067; foundation / Storage 0.000027; foundation / Bandwidth 0; untagged / Bandwidth 0. Sum 0.0019 USD, about a fifth of a cent. No `storage` row yet: the CLOUD-26 session ran on 9 Oct and Azure usage lags by 8 to 24 hours. Read again on 10 Oct.
