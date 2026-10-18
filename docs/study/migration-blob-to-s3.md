# CLOUD-34: moving objects from Azure Blob to S3 (18 Oct 2026)

Five test objects, no real data. Source: an Azure storage account built from `azure/layer1/storage.tf`
(no private endpoint, 6 resources). Destination: an S3 bucket from `aws/layer1/storage.tf`
(4 resources, no CloudFront). Both were destroyed at the end; evidence is in `evidence/`.

## Test objects (built on purpose to differ)

| Object | Size | Azure tier | Azure metadata |
|---|---|---|---|
| notes.txt | 16 B | Hot (inferred) | dept=finance |
| report.csv | 23 B | Hot (inferred) | dept=finance |
| logo.bin | 20 KiB | Hot (inferred) | project=lab |
| archive-2025.txt | 18 B | Cool (set) | none |
| config.json | 15 B | Hot (inferred) | dept=ops |

"Hot (inferred)" means nobody set the tier: it is the account default.

## Predictions (written before each step) and results

| Question | Alex's prediction | Result |
|---|---|---|
| What does not travel on a manual copy? | "I don't know" | Metadata did not travel (empty on S3 for notes.txt and config.json). Content type was re-detected from the extension, it was not copied. |
| Time to move 5 objects by hand | 5 min | About 5 min (17:15 to 17:20 local) |
| Metadata in the dry run | the ones added, ops and others | 4 of 5 objects carry metadata; the archive has none |
| Time for the script | 2 min | 23 s (23:25:05 to 23:25:28 UTC) |
| Objects left after rollback | Azure 5, S3 0 | Azure 5, S3 0 |
| Resources destroyed on Azure | 6 | 6 |

## Measurements

- Byte-for-byte check: the MD5 of the original files, of the files downloaded from Azure and the S3 ETag
  were identical for all five objects (a single-part upload without KMS has the MD5 as its ETag).
- By hand: the portal downloads one object at a time; S3 applies one storage class to a whole upload
  batch, so the archive object needed its own upload. The console offers no per-object metadata
  check in the upload summary.
- Presigned URL, 60 s: 200 with the content at 0 s, 403 at 65 s.
- Script `scripts/move-blob-to-s3.ps1`: dry run by default; `-Execute` copies with metadata, content
  type and a mapped storage class and checks MD5 against the ETag; `-Rollback` deletes the copied
  keys. Source untouched. Ran twice (before and after the rollback test): VALIDATION OK both times.
- Rollback exercised: S3 empty, Azure source still 5.

## Findings

1. A manual move carries bytes, not the object: metadata is lost, and the content type is guessed again.
2. Tier and storage class do not map by name. Cool maps to Standard-IA, but Standard-IA has a 128 KB
   minimum billable size and a 30-day minimum: an 18-byte object is billed as 128 KB. Cents here,
   a real cost with millions of small objects. Archive blobs cannot be copied until rehydrated.
3. Setting blob index tags on upload needs Storage Blob Data Owner. The lab operator holds Contributor,
   so the two uploads with `--tags` failed and were repeated without tags. Tags were therefore not
   part of the comparison.
4. The tool did in 23 s what took 5 min by hand, and kept what the manual path lost.

## Alex's log of surprises

- (to add)

## Still to read

Real cost on 19 Oct (Azure by meter, tag domain=storage; AWS by tag). Expected well under 0.01 USD
(not measured).
