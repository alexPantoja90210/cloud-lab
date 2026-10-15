# Networking on AWS, built by hand (CLOUD-27, 15 Oct 2026, in progress)

Built in the console by the operator from written steps, in us-east-1. Nothing here bills by the hour:
the VPC, subnets, route tables, internet gateway, security groups, the S3 gateway endpoint, an empty
bucket and a Lambda attached to the private subnet are all at no charge at rest. Nothing has been
destroyed yet: the cleanup (by tag `lab=cloud-lab`, `layer=1`) is still to do.

## What was built

One VPC (`10.80.0.0/16`) with `snet-public` (`10.80.1.0/24`) and `snet-private` (`10.80.2.0/24`) in one
availability zone; an internet gateway and a second route table with a `0.0.0.0/0` route to it,
associated to the public subnet only; two security groups (`sg-web` allows 443 from anywhere, `sg-db`
allows 1433 from `sg-web`); a bucket with public access blocked; an S3 gateway endpoint; a Lambda
(`lambda-net-client`) attached to the private subnet with a role that can list that one bucket.

## What the screens showed

- The VPC creation screen showed no price. AWS created four things by itself with the VPC: the VPC, the
  main route table, a default network ACL and a default security group.
- The default network ACL allows everything (rule 100); the final `*` deny never acts because rule 100
  matches first. The security group has no deny option at all: denial lives in the network ACL, which is
  attached to a subnet and is stateless.
- What makes a subnet public is a route to an internet gateway in its route table, not its name or a rule.
  The private subnet's table held only the local route.

## What the readings showed

- First run of the client Lambda with no route to S3: `Sandbox.Timedout` after 15 seconds, billed 15299 ms,
  no error message from the network, only silence. My code set a 3 second connect timeout, but the S3
  name resolves to several addresses and the client tries them one by one, so the limit never produced a
  clean `failed` answer. A flaw of the test design, not of the build.
- The endpoint was `available` with type Gateway but `route_tables` was 0: it had been created without
  being associated to a route table, so there was no route and no path. Reading it back with
  `describe-vpc-endpoints` found it; the console had shown no warning.
- After associating the endpoint to the main route table: `result: ok`, `key_count: 0` (empty bucket),
  2460 ms billed, from a subnet with no internet route.

## Log of surprises (the operator, 15 Oct 2026)

- AWS felt more complex than Azure for the same exercise. Part of that is the design of the two clouds
  (route tables, gateways, IAM roles as separate pieces) and part is the exercise: the client was a
  Lambda, which needs an IAM role and a VPC attachment, where the Azure client was a VM with Run Command.
- The operator got lost around the Lambda configuration steps (role, VPC attachment, code, test) and the
  session stopped there. Too many steps in one message was the cause; steps went one at a time after that.

## Still to do

The deliberate denial with a custom network ACL on the private subnet (a new ACL denies everything by
default); the refusal of the public path (bucket policy that only accepts the endpoint); the cleanup by
tag and its verification; the cost read in Cost Explorer filtered by `domain = networking`, next day, with
its date; the comparison with Azure; and the Terraform twin of both.
