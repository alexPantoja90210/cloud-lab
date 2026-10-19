# Runbook: rehost a local VM to AWS with import-image (CLOUD-38)

Cost: well under 0.01 USD for a 2.84 GiB image and a t3.micro for minutes (no free EC2 hours on this account). Time: about 1 hour
including the 22-minute service import. Region us-east-1. Stop and tear down if the import has not progressed after 1 hour.

## Before (local, free)
1. Full clone of the VM (a linked clone cannot be exported), power it off, check `VMState=poweroff`.
2. Inside the VM, as root: `scripts/prepare-image-for-aws.sh` (Ec2 datasource, `nvme`/`ena` in the initramfs, Azure agent off).
3. Power off, `VBoxManage clonemedium disk <vdi> rehost-aws.vhd --format VHD --variant Standard`; write down its SHA-256.
4. Write down the page hash and the data-file hash from the running VM.

## Build (layer 1)
5. `$env:TF_VAR_ssh_cidr = "<your public IP>/32"`; `terraform -chdir=aws/layer1 plan -out rehost.tfplan` (expect 8 to add); `apply rehost.tfplan`.
6. In this window: `$bucket = terraform -chdir=aws/layer1 output -raw rehost_bucket`; check `$bucket.Length -gt 0` before any call that uses it.
7. `aws s3 cp rehost-aws.vhd s3://$bucket/rehost-aws.vhd --only-show-errors`; compare `head-object` ContentLength with the local size.

## Import and run
8. `aws ec2 import-image --platform Linux --architecture x86_64 --license-type BYOL --boot-mode uefi --disk-containers "Format=vhd,UserBucket={S3Bucket=$bucket,S3Key=rehost-aws.vhd},Description=rehost-lab"`; store the task id in a variable, do not print it.
9. Poll `describe-import-image-tasks` (Status, Progress, StatusMessage) every 30 s until the status is not `active`. Stages seen: converting, updating, booting, preparing ami.
10. `run-instances` with a t3.micro, the layer-1 security group (not an `--associate-public-ip-address` flag together with security group ids), `HttpTokens=required`, and tags for the instance **and** for `ResourceType=volume`.
11. `wait instance-running`, `wait instance-status-ok`, then SSH with the lab key and compare: `systemctl is-system-running`, `curl -s localhost | sha256sum`, `sha256sum` of the data file.

## Roll back, in its own block (never chained to a read that can fail)
12. Terminate the instance and wait; deregister the AMI; delete the snapshot of the image; then count images, snapshots, volumes and instances by owner (all 0). Delete any leftover volume by hand.

## Close
13. `scripts/teardown.sh aws` (8 destroyed); read `evidence/destroy-aws-*.txt` for names and ids; follow `docs/closing-ritual.md`.
14. Local cleanup: `scripts/local-cleanup.ps1` (dry run first). Re-read the tag index a few minutes later; trust `describe-*` calls over it.
