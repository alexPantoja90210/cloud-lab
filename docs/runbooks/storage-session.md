# Runbook: storage session (CLOUD-26, and the tagged probe for CLOUD-25)

One session, about 3 hours, both clouds. Layer 1 is destroyed at the end. The root also carries the
CLOUD-24 identity probe, so this session doubles as the tagged-usage reading CLOUD-25 needs.
Every capture goes through `scripts/capture.sh`, which redacts and refuses to write if anything
sensitive survives. Read each evidence file before committing.

## Cost (estimate, stated before running)

- Expected total for both clouds: well under 0.10 USD. Credits cover it.
- AWS: a bucket with a few bytes, a handful of requests, one CloudFront distribution. No hourly
  charge for the distribution is expected; this was not verified against the price list.
- Azure: the private endpoint bills by the hour and exists only in phase 2 (about 15 to 30
  minutes). The rate was not verified: the vendor pricing pages did not render figures. Recalled,
  unverified: about 0.01 USD per hour. Left running for a month it would be about 7 USD, so
  teardown is not optional.
- The real figure is read the next day: Cost analysis by `domain` on Azure, Cost Explorer
  (unblended) by tag on AWS. Record it with its read date.

## Before applying

1. AWS Billing, Cost allocation tags: activate `domain`. Activation is not retroactive, so usage
   before it is not classified by that tag. Do it before the AWS apply, not after.
2. Decide the `finops-guardian-zero-spend` budget (storage and requests can trip it).
3. Same terminal window for the whole session: `AWS_PROFILE` and `ARM_SUBSCRIPTION_ID` set,
   `az login` valid. Env vars are lost when the window closes.
4. `$bash = "C:\Program Files\Git\bin\bash.exe"`.
5. Plans exist from today: `aws/layer1/storage.tfplan` (13 to add) and `azure/layer1/storage.tfplan`
   (16 to add). If anything in `*.tf` changed since, re-plan and compare the counts first.

## 1. Apply (note the UTC time each one finishes)

```powershell
terraform "-chdir=aws/layer1" apply storage.tfplan     # CloudFront makes this the slow one
terraform "-chdir=azure/layer1" apply storage.tfplan   # includes a 90 s role-propagation wait
```

## 2. AWS tests

```powershell
$bucket = terraform "-chdir=aws/layer1" output -raw storage_bucket
$cf     = terraform "-chdir=aws/layer1" output -raw storage_cloudfront_domain

# Through the distribution: allowed. A short 403 right after apply is propagation; retry once.
$env:PROBE_URL = "https://$cf/"
& $bash scripts/capture.sh aws-cloudfront-read 'curl -s -i $PROBE_URL'

# Direct public read of the private object: must be refused (403).
$env:PROBE_URL = "https://$bucket.s3.us-east-1.amazonaws.com/sample.txt"
& $bash scripts/capture.sh aws-direct-public-read 'curl -s -i $PROBE_URL'

# Presigned URL, 60 seconds: works, then is seen to expire.
$env:PROBE_URL = aws s3 presign "s3://$bucket/sample.txt" --expires-in 60 --region us-east-1
& $bash scripts/capture.sh aws-presigned-valid 'curl -s -i $PROBE_URL'
Start-Sleep -Seconds 65
& $bash scripts/capture.sh aws-presigned-expired 'curl -s -i $PROBE_URL'

# Lifecycle: configured, read back from the API (the 128 KB rule means the sample never moves).
& $bash scripts/capture.sh aws-lifecycle-readback "aws s3api get-bucket-lifecycle-configuration --bucket $bucket --region us-east-1"
& $bash scripts/capture.sh aws-tag-query 'aws resourcegroupstaggingapi get-resources --region us-east-1 --tag-filters Key=domain,Values=storage --query "ResourceTagMappingList[].ResourceARN"'
```

Expected: read through CloudFront 200; direct read 403 AccessDenied; presigned valid 200, expired
403 with a request-expired message.

## 3. Azure tests, phase 1 (public network on)

```powershell
$acct = terraform "-chdir=azure/layer1" output -raw storage_account
$cont = terraform "-chdir=azure/layer1" output -raw storage_container

"private object for the CLOUD-26 storage session" | Out-File -Encoding ascii "$env:TEMP\sample.txt"
az storage blob upload --account-name $acct --container-name $cont --name sample.txt --file "$env:TEMP\sample.txt" --auth-mode login

# Two user-delegation SAS (account keys are off, so no other kind exists): a short one that is
# seen to expire, and a long one kept for phase 2. Neither goes into Terraform, a file or git.
$short = (Get-Date).ToUniversalTime().AddMinutes(2).ToString("yyyy-MM-ddTHH:mmZ")
$long  = (Get-Date).ToUniversalTime().AddMinutes(60).ToString("yyyy-MM-ddTHH:mmZ")
$env:PROBE_URL  = az storage blob generate-sas --account-name $acct --container-name $cont --name sample.txt --permissions r --expiry $short --as-user --auth-mode login --https-only --full-uri --output tsv
$env:PROBE_URL2 = az storage blob generate-sas --account-name $acct --container-name $cont --name sample.txt --permissions r --expiry $long  --as-user --auth-mode login --https-only --full-uri --output tsv
$env:ANON_URL   = "https://$acct.blob.core.windows.net/$cont/sample.txt"

& $bash scripts/capture.sh azure-sas-valid 'curl -s -i $PROBE_URL'
& $bash scripts/capture.sh azure-anonymous-read-phase1 'curl -s -i $ANON_URL'
Start-Sleep -Seconds 130
& $bash scripts/capture.sh azure-sas-expired 'curl -s -i $PROBE_URL'

& $bash scripts/capture.sh azure-lifecycle-readback "az storage account management-policy show --account-name $acct --resource-group rg-cloud-lab"
```

Expected: SAS valid 200; anonymous read refused (the account forbids public blob access); expired
SAS 403 with a signature-not-valid-in-time-frame message.

## 4. Azure, phase 2 (private only)

The long SAS must already exist: asking for a user-delegation key is a data-plane call and would
fail once public access is closed.

```powershell
terraform "-chdir=azure/layer1" plan "-var=private_only=true" "-out=private.tfplan"
```

Expected: `1 to add, 1 to change, 0 to destroy` (the private endpoint, and the account's public
network flag). If it differs, stop and read it.

```powershell
terraform "-chdir=azure/layer1" apply private.tfplan
& $bash scripts/capture.sh azure-valid-sas-private-only 'curl -s -i $PROBE_URL2'
& $bash scripts/capture.sh azure-anonymous-private-only 'curl -s -i $ANON_URL'
```

Expected: a still-valid SAS is refused from the public network (403, not authorized for this
operation). That shows the network door, not the signature, is what stops it. Not proved: that a
client inside the network can read, because no client lives there and there is no private DNS zone.

## 5. Teardown and verification

Do not leave the private endpoint running.

```powershell
& $bash scripts/teardown.sh aws
& $bash scripts/teardown.sh azure
```

If the Azure destroy fails with a 403 on the account, run
`terraform "-chdir=azure/layer1" apply "-var=private_only=false"` and destroy again.

Verify in the console or portal, not in the destroy output:

```powershell
az resource list --resource-group rg-cloud-lab --query "[].{name:name,type:type}" --output json
aws resourcegroupstaggingapi get-resources --region us-east-1 --tag-filters Key=lab,Values=cloud-lab Key=layer,Values=1 --query "ResourceTagMappingList[].ResourceARN" --output json
aws cloudfront list-distributions --query "DistributionList.Items[].Id" --output json
aws s3api list-buckets --query "Buckets[?starts_with(Name,'cloud-lab-storage-') || starts_with(Name,'cloud-lab-identity-probe-')].Name" --output json
```

All four must be empty (`[]` or null). Remove the session secrets from the window:
`Remove-Item Env:PROBE_URL, Env:PROBE_URL2, Env:ANON_URL`.

## 6. After

- Read every file in `evidence/` before committing.
- Next day: read the cost by `domain` on both clouds, record it with its date in
  `docs/credit-log.md`, and update the cost note.
- Write `docs/study/storage-azure-vs-aws.md`: what was verified and what was only configured
  (lifecycle, private path from inside the network), and the CloudFront default certificate,
  which fixes the minimum TLS version at TLSv1.
