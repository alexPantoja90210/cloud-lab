# CLOUD-27 networking (layer 1, destroyed after every session).
# The Terraform twin of the console build of 15 Oct 2026 (see docs/study/networking-aws-console.md):
# a VPC with a public and a private subnet, an internet gateway, security groups, a private bucket,
# an S3 gateway endpoint, and a Lambda attached to the private subnet that tests the path to the bucket.
# Nothing here bills by the hour: VPC, subnets, route tables, internet gateway, security groups,
# the gateway endpoint and the attached Lambda are free at rest. There is no NAT gateway on purpose.
# Tags: lab and layer come from the provider default_tags; domain is set per resource.
#
# Differences from the console build, on purpose:
#   - The private subnet gets its own route table (local route only) instead of using the VPC's main
#     route table, so everything it depends on is declared here. The S3 endpoint is attached to it.
#   - The deliberate failure is a switch: deny_private_subnet = true adds a custom network ACL with no
#     rules to the private subnet. A new ACL denies everything, so the same Lambda call goes from ok to
#     a timeout with no error message. The default is false, so the first apply builds the working path.
#   - The Lambda has its own security group (egress only) because the exercise needs a group on the
#     function; the console build's choice of group is not recorded.
#   - Names end in -tf so the twin can exist next to a console-built network if one is still around.
#   - AWS reserves the sg- prefix for security group names, so the groups are named net-web-tf, net-db-tf
#     and net-client-tf; the Name tag keeps the sg-*-tf form used in the console build.
#   - Not included: a bucket policy that accepts only the endpoint. A Deny unless aws:SourceVpce would
#     also block the operator and terraform destroy (which has to empty the bucket). The refusal of the
#     public path is shown by the bucket's public access block instead, and by hand.

variable "net_vpc_cidr" {
  description = "CIDR of the networking exercise VPC."
  type        = string
  default     = "10.80.0.0/16"
}

variable "net_public_cidr" {
  description = "CIDR of the public subnet."
  type        = string
  default     = "10.80.1.0/24"
}

variable "net_private_cidr" {
  description = "CIDR of the private subnet."
  type        = string
  default     = "10.80.2.0/24"
}

variable "deny_private_subnet" {
  description = "When true, a custom network ACL with no rules is attached to the private subnet. A new ACL denies all traffic, which is the deliberate failure of the exercise."
  type        = bool
  default     = false
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  net_az = data.aws_availability_zones.available.names[0]
}

resource "aws_vpc" "net" {
  cidr_block           = var.net_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name   = "vpc-net-tf"
    domain = "networking"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.net.id
  cidr_block        = var.net_public_cidr
  availability_zone = local.net_az

  tags = {
    Name   = "snet-public-tf"
    domain = "networking"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.net.id
  cidr_block        = var.net_private_cidr
  availability_zone = local.net_az

  tags = {
    Name   = "snet-private-tf"
    domain = "networking"
  }
}

resource "aws_internet_gateway" "net" {
  vpc_id = aws_vpc.net.id

  tags = {
    Name   = "igw-net-tf"
    domain = "networking"
  }
}

# What makes a subnet public is this route, not its name.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.net.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.net.id
  }

  tags = {
    Name   = "rt-public-tf"
    domain = "networking"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Local route only (added by AWS). The S3 gateway endpoint adds its own route to this table.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.net.id

  tags = {
    Name   = "rt-private-tf"
    domain = "networking"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "web" {
  name        = "net-web-tf"
  description = "CLOUD-27: 443 from anywhere"
  vpc_id      = aws_vpc.net.id

  tags = {
    Name   = "sg-web-tf"
    domain = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_security_group" "db" {
  name        = "net-db-tf"
  description = "CLOUD-27: 1433 only from sg-web"
  vpc_id      = aws_vpc.net.id

  tags = {
    Name   = "sg-db-tf"
    domain = "networking"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_web" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 1433
  to_port                      = 1433
}

resource "aws_security_group" "client" {
  name        = "net-client-tf"
  description = "CLOUD-27: the client function, egress only"
  vpc_id      = aws_vpc.net.id

  tags = {
    Name   = "sg-client-tf"
    domain = "networking"
  }
}

resource "aws_vpc_security_group_egress_rule" "client_all" {
  security_group_id = aws_security_group.client.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# The deliberate failure, as a switch. A custom ACL starts with no rules and denies everything;
# it is stateless, so a real allow would need rules for the return ports as well.
resource "aws_network_acl" "private_deny" {
  count  = var.deny_private_subnet ? 1 : 0
  vpc_id = aws_vpc.net.id

  subnet_ids = [aws_subnet.private.id]

  tags = {
    Name   = "nacl-net-private-tf"
    domain = "networking"
  }
}

resource "random_string" "net_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "aws_s3_bucket" "net" {
  bucket        = "cloud-lab-net-${random_string.net_suffix.result}"
  force_destroy = true

  tags = {
    domain = "networking"
  }
}

resource "aws_s3_bucket_ownership_controls" "net" {
  bucket = aws_s3_bucket.net.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "net" {
  bucket                  = aws_s3_bucket.net.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_ownership_controls.net]
}

# Gateway endpoint: free, and it works through a route in the table it is attached to. The console
# build created it without a route table and nothing warned about it; here the association is declared.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.net.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name   = "vpce-s3-tf"
    domain = "networking"
  }
}

variable "net_lambda_name" {
  description = "Client function inside the private subnet. Ends in -tf so it does not collide with a console-built function."
  type        = string
  default     = "lambda-net-client-tf"
}

data "archive_file" "net_client" {
  type        = "zip"
  source_file = "${path.module}/lambda/net_client.py"
  output_path = "${path.module}/.build/net_client.zip"
}

data "aws_iam_policy_document" "net_lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "net_client" {
  name               = "${var.net_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.net_lambda_assume.json

  tags = {
    domain = "networking"
  }
}

# Logs plus the network interfaces a function needs to live inside a VPC.
resource "aws_iam_role_policy_attachment" "net_client_vpc" {
  role       = aws_iam_role.net_client.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "net_client_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.net.arn]
  }
}

resource "aws_iam_role_policy" "net_client_s3" {
  name   = "list-net-bucket"
  role   = aws_iam_role.net_client.id
  policy = data.aws_iam_policy_document.net_client_s3.json
}

resource "aws_cloudwatch_log_group" "net_client" {
  name              = "/aws/lambda/${var.net_lambda_name}"
  retention_in_days = 7

  tags = {
    domain = "networking"
  }
}

resource "aws_lambda_function" "net_client" {
  function_name    = var.net_lambda_name
  role             = aws_iam_role.net_client.arn
  handler          = "net_client.handler"
  runtime          = var.lambda_runtime
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 15
  filename         = data.archive_file.net_client.output_path
  source_code_hash = data.archive_file.net_client.output_base64sha256

  environment {
    variables = {
      BUCKET = aws_s3_bucket.net.id
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.client.id]
  }

  tags = {
    domain = "networking"
  }

  depends_on = [
    aws_cloudwatch_log_group.net_client,
    aws_iam_role_policy_attachment.net_client_vpc,
    aws_vpc_endpoint.s3,
  ]
}

output "net_bucket" {
  description = "Private bucket the client function lists."
  value       = aws_s3_bucket.net.id
}

output "net_client_function" {
  description = "Function inside the private subnet. Invoke it to test the path to S3."
  value       = aws_lambda_function.net_client.function_name
}

output "net_private_subnet_denied" {
  description = "True when the custom network ACL with no rules is attached to the private subnet."
  value       = var.deny_private_subnet
}
