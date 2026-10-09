# Storage: Azure vs AWS, from one lab session

Scope: the CLOUD-26 session of 9 Oct 2026 (about 3 hours, both clouds, then torn down and verified empty). Everything marked **observed** is backed by a file in `evidence/` from that day. Claims marked **[general]** come from general knowledge, were not tested here, and should be checked against the vendor documentation before they are quoted. Cost is not covered yet: it is read the next day (see the last section).

## The same job, two builds

One private object store, readable only through an intended door, with a lifecycle rule and the `domain=storage` tag.

| | Azure | AWS |
|---|---|---|
| Store | Storage account, one private container | S3 bucket, ownership enforced, all four public-access blocks on |
| The intended door | A user-delegation SAS (shared keys are off, so no other SAS exists) | CloudFront with origin access control; the bucket policy allows only that distribution |
| A second door tested | Presigned-style access is the SAS itself | A presigned URL signed with the operator's credentials |
| Lifecycle | cool at 30 days, archive at 90, delete at 365 | STANDARD_IA at 30, GLACIER at 90, expire at 365, abort multipart at 1 day |
| Closing the network | Public network access turned off, plus a private endpoint (second phase) | Not applicable: the bucket was never opened to the network, CloudFront is the public edge |

## What was observed

| Test | Azure | AWS |
|---|---|---|
| Read through the intended door | 200 with a user-delegation SAS | 200 through CloudFront |
| Anonymous read, direct | **409** `PublicAccessNotPermitted`: the account setting rejects it | **403** `AccessDenied` from the S3 endpoint |
| Expired signature | **403** `AuthenticationFailed`; the detail says the signed expiry is before the request time, and the word "expired" does not appear | **403** `AccessDenied`, message "Request has expired", with the expiry and the server time in the body |
| Read with a still-valid signature after the network was closed | **403** `AuthorizationFailure`, same body as the anonymous read | Not applicable |
| Anonymous read after the network was closed | **403** `AuthorizationFailure` (it was 409 before) | Not applicable |
| Lifecycle read back from the service | Matches what Terraform applied | Matches what Terraform applied |
| Tag query | Not run on Azure | Two resources returned for `domain=storage` (CloudFront distribution and bucket), each with `domain`, `lab`, `layer` |
| Teardown | 17 destroyed, no 403 on the account | 13 destroyed (CloudFront took about 3 minutes) |

Points worth keeping:

1. **The same refusal, at different layers.** An anonymous read is rejected on both clouds, but not by the same thing. On Azure the account's own setting answers first (409); once the network is closed, the network answers instead (403) and the 409 disappears. On AWS the bucket policy and the public-access blocks answer (403). The status code alone does not say which layer refused.
2. **After the network was closed, a valid signature and no signature got the same response.** That shows the network door was the one refusing. It does not prove the long SAS was still valid at that moment; its validity was shown earlier with a short one (200).
3. **Expiry is reported very differently.** AWS says "Request has expired" and prints both times. Azure reports an authentication failure and leaves the cause to a detail line about start and expiry times. Anyone reading only the error code on Azure would not know the signature merely expired.
4. **AWS applied the expiration rule to the object right away.** The object response carried an `x-amz-expiration` header naming the rule and an expiry date one year out. That is the only direct sign of lifecycle behavior in the whole session.
5. **Azure needed a role just to sign.** With shared keys off, creating a user-delegation SAS needs the Storage Blob Delegator role, and the build waits 90 seconds for the role assignments to propagate (whether that wait was needed was not measured). The AWS presigned URL needed no extra role beyond the operator's own credentials.
6. **CloudFront's default certificate fixes the minimum TLS version at TLSv1.** Observed in the planned and destroyed configuration of the distribution. The Azure account was set to TLS 1.2 minimum. **[general]** A custom certificate is what allows a higher CloudFront minimum.

## Configured but not observed

- **Lifecycle transitions on both clouds.** Only the rules were read back. Nothing was old enough to move. **[general]** On AWS, objects under 128 KB do not transition by default, and the sample object is far under that, so even after 30 days it would not move. On Azure no equivalent signal exists, so Azure lifecycle is "configured, not observed" with nothing else to show.
- **A client inside the private network.** None existed and no private DNS zone was built, so nobody could read through the private endpoint. Only the closing of the public path was shown.
- **The deny rule for plain HTTP on the AWS bucket policy.** It is in the configuration; no request was made to trigger it.
- **A signature that was valid but refused for another reason** (wrong object, wrong permission). Not tested on either cloud.

## Cost

Not read yet. The session ran about three hours on each cloud, with a private endpoint on Azure for a short part of it. The cost by `domain` is read on 10 Oct (Azure Cost analysis; AWS Cost Explorer, unblended, by tag). Until then, no figure here is a result.

## Still open

- Read cost by `domain` on both clouds and record it with its read date in `docs/credit-log.md` and `docs/study/cost-azure-vs-aws.md`.
- Decide what to do with the `finops-guardian-zero-spend` budget (keep or delete) after seeing how it moved during the session.
- If the lifecycle behavior matters, it needs data that is old enough or a test that does not wait 30 days; this session did not have one.
