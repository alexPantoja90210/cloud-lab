# CLOUD-38 rehost (layer 1, destroyed after every session).
# The pieces the VM import service needs: a private bucket for the disk file, the service role it
# assumes (named vmimport, the name the import commands use by default), and a security group that
# lets SSH in only from the operator's address. The import tasks, the snapshot, the image and the
# instance are created with the CLI during the drill (they are the experiment, not infrastructure),
# and every one of them is tagged lab=cloud-lab, layer=1, domain=rehost.

variable "ssh_cidr" {
  description = "CLOUD-38 drill: the single address allowed to reach SSH, as x.x.x.x/32. Set it from the environment, never commit it."
  type        = string
  default     = "192.0.2.1/32" # documentation address: a plan with the default opens SSH to nobody

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0)) && endswith(var.ssh_cidr, "/32")
    error_message = "ssh_cidr must be a single address in the form x.x.x.x/32."
  }
}

resource "random_string" "rehost_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "aws_s3_bucket" "rehost" {
  bucket        = "cloud-lab-rehost-${random_string.rehost_suffix.result}"
  force_destroy = true

  tags = {
    domain = "rehost"
  }
}

resource "aws_s3_bucket_public_access_block" "rehost" {
  bucket                  = aws_s3_bucket.rehost.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "vmimport" {
  name = "vmimport"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vmie.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "sts:Externalid" = "vmimport" } }
    }]
  })

  tags = {
    domain = "rehost"
  }
}

resource "aws_iam_role_policy" "vmimport" {
  name = "vmimport-lab"
  role = aws_iam_role.vmimport.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.rehost.arn, "${aws_s3_bucket.rehost.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:ModifySnapshotAttribute", "ec2:CopySnapshot", "ec2:RegisterImage", "ec2:CreateTags", "ec2:Describe*"]
        Resource = "*"
      }
    ]
  })
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "rehost" {
  name        = "cloud-lab-rehost-ssh"
  description = "CLOUD-38 rehost drill: SSH from the operator only"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    domain = "rehost"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rehost_ssh" {
  security_group_id = aws_security_group.rehost.id
  description       = "SSH from the operator"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr

  tags = {
    domain = "rehost"
  }
}

resource "aws_vpc_security_group_egress_rule" "rehost_all" {
  security_group_id = aws_security_group.rehost.id
  description       = "Outbound for package and metadata access"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    domain = "rehost"
  }
}

output "rehost_bucket" {
  description = "Bucket that receives the disk file for the VM import."
  value       = aws_s3_bucket.rehost.bucket
}

output "rehost_security_group" {
  description = "Security group for the imported instance."
  value       = aws_security_group.rehost.id
}
