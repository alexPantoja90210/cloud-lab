# Networking, Azure vs AWS (CLOUD-27, 15 and 16 Oct 2026)

The same exercise built by hand on both clouds: a network with a web side and a db side, rules that
allow some traffic and deny the rest, a private door to object storage, a client inside the network that
tests it, and one denial seen from the inside. Details of each build are in
`networking-azure-console.md` and `networking-aws-console.md`.

## The same pieces under different names

| Piece | Azure | AWS |
|---|---|---|
| Network | Virtual network | VPC |
| Two zones | Two subnets | Two subnets |
| Rules per zone | NSG with priorities (allow and deny) | Security group (allow only, per machine) plus network ACL (allow and deny, per subnet, stateless) |
| Public or private | Nothing is public by default; a public IP is a separate resource | Defined by the route table: a route to an internet gateway makes a subnet public |
| Private door to storage | Private endpoint, 0.01 USD an hour, plus a private DNS zone | Gateway endpoint for S3, free; works through a route in the route table |
| Client inside the network | VM read with Run Command, no login | First a Lambda (needs an IAM role and a VPC attachment), then a small EC2 instance whose start-up script wrote its result to the console output, no login |
| Deleting it all | One resource group deleted whole | Pieces in dependency order: instance, function, bucket, role, log group, then the VPC |

## What looked the same

- A blocked path gives no message, only silence until a timeout. Azure `/dev/tcp` timeout, AWS Lambda
  `Sandbox.Timedout` after 15 seconds, AWS instance probe `blocked`.
- Rules are read by number, lowest first, and the first match wins: Azure priority, AWS ACL rule number.
- A free piece shows no price on its creation screen on either cloud. The one that bills by the hour (the
  Azure private endpoint, the AWS instance) did not show it either; only the Azure VM wizard did.

## What was different

- In Azure the default let traffic through between subnets of one network (rule 65000), so a "db"
  subnet was open to "web" until an explicit deny was added. In AWS the default ACL allows everything and
  the default security group only trusts itself.
- In Azure a private endpoint skipped the NSG until a subnet setting (private endpoint network policies)
  was changed. In AWS an endpoint did nothing until it was associated with a route table; it showed
  `available` while doing nothing.
- In AWS a new network ACL denies everything, the opposite of the default one, and it applied in under a
  minute to a running instance.
- The Azure resources lived in one resource group, deleted in one action. AWS has no equivalent: cleanup
  followed dependencies, and a network interface left by the Lambda held the VPC for a while.

## The operator's reading (16 Oct 2026)

- Why a private route to storage: security, and cost. A function in a private subnet without the endpoint
  would need a NAT gateway, which bills by the hour and by the gigabyte; the gateway endpoint is free.
  (Performance was the operator's other answer; it is a minor effect.)
- Security group protects a machine, network ACL protects a subnet.
- Of the two ways to block, the Azure priority rule was easier to follow: the lowest number runs first.
  The AWS ACL starts denying everything and is stateless, which made it harder.
- The AWS build felt more complex than Azure for the same exercise. Part of that is the clouds (separate
  route tables, gateways and roles), part is the choice of a Lambda as the first client.

## Not yet done

Cost of both builds read in the portals (Azure Cost analysis, AWS Cost Explorer, filter
`domain = networking`) and compared with the CLI report, next day, with its date. Terraform twin of the
AWS build. The Azure twin (`azure/layer1/networking.tf`) was applied and destroyed on 16 Oct 2026; the AWS twin is `aws/layer1/networking.tf`, applied and destroyed on 22 Oct 2026 (24 resources applied with targets, 25 destroyed; see `docs/runbooks/networking-session.md`).
