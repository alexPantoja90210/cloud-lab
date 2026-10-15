# Sprint 1 (CLOUD): 7 Oct 2026 to 4 Nov 2026

## Goal

_Paste the agreed sprint goal here (taken from the Jira sprint)._

## Work items

| Issue | What | Status |
|-------|------|--------|
| CLOUD-21 | Pin both clocks (credit expiry on each cloud) | Done |
| CLOUD-22 | Prove both budget alerts fire | Criteria met, awaiting Done |
| CLOUD-23 | Two teardowns, one Terraform workspace per cloud | In progress |
| CLOUD-24 | Identity, 8-11 Oct | To do |
| CLOUD-25 | Cost, 12-15 Oct | To do |
| CLOUD-26 | Storage, 16-20 Oct | To do |
| CLOUD-27 | Networking, 21-24 Oct | To do |
| CLOUD-28 | Compute, 25-28 Oct | To do |
| CLOUD-29 | Monitoring, 29-30 Oct | To do |
| CLOUD-30 | Azure close-out, 31 Oct | To do |

## Retrospective

_Written at the end of the sprint: what went as planned, what did not, what changes._

## Extra practice (decided by the operator, not in any acceptance criteria)

- **15 Oct 2026, CLOUD-27:** after the Azure networking exercise, build the same shape on AWS in the console (VPC, two subnets, a security group and a NACL that deny, a VPC endpoint to S3, a client inside the network), then the Terraform twin. CLOUD-27 itself keeps AWS as a written comparison; this practice does not change its criteria.
- Guard rails that stay: no NAT Gateway, bastion or VPN gateway on AWS. Layer 1 destroyed and checked empty at the end of each session.
- Open design point, to settle before building: how to run a command inside the VPC without a bastion or a NAT. Systems Manager needs three interface endpoints that bill by the hour; the cost is to be stated before it is created.
- When the comparison is written, say which half was built and which was read.
