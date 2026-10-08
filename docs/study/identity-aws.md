# Identity on AWS (CLOUD-24)

Four-part bar. A line is ticked only with evidence in this repository.

- [x] Deployed from code. `aws/identity/` (role `lab-s3-reader`, trust policy naming one user, read-only permission policy, own state key) and `aws/layer1/identity_probe.tf`.
- [x] Broken on purpose once. Three denials/outcomes in `evidence/aws-identity-denial-20261008T192209Z.txt` (19:22:10 to 19:22:20 UTC, 8 Oct 2026): a user outside the trust policy denied at `sts:AssumeRole` (twice: via profile with an empty CLI cache, and calling the API directly); the assumed role read an object; the assumed role was denied `s3:PutObject`.
- [ ] Cost shape read from the bill. Not read yet; the AWS cost view lags. Estimate before running was "under one cent" (one bucket, one tiny object, a handful of requests).
- [x] Torn down from code. `evidence/destroy-aws-20261008T192351Z.txt`: 4 destroyed. Console check of "bucket gone, role still there" still to be confirmed by the operator.

Not done / not understood:

- The trust policy was verified by reading it back from the API (names exactly one user, not the intruder, not the account root); the permission policy was verified by behaviour (read allowed, write denied), not by a console review.
- The first intruder test passed because of the CLI's per-role credential cache, not because of a defect (see `docs/lessons-learned.md`).
- Policy simulator, IAM Access Analyzer, permission boundaries, explicit `Deny` and conditions were not used.
