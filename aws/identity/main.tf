# Layer 0: identity definitions. Free, and never part of a teardown.
# This root has its own state (key identity.tfstate); aws/layer1 cannot reach it.

data "aws_caller_identity" "current" {}

locals {
  # Built at plan time, so no account ID is ever written in a file.
  trusted_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.trusted_user_name}"
}

# Trust policy: WHO may assume the role. Exactly one named user, nobody else
# (a second user in the same account is denied at sts:AssumeRole, which is the first denial to capture).
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AssumeFromOneUser"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [local.trusted_user_arn]
    }
  }
}

# Permission policy: WHAT the role may do. Read objects in buckets whose name starts with the
# lab probe prefix. No write, no delete, no other service.
data "aws_iam_policy_document" "s3_read_probe" {
  statement {
    sid       = "ListProbeBuckets"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::cloud-lab-identity-probe-*"]
  }

  statement {
    sid       = "ReadProbeObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::cloud-lab-identity-probe-*/*"]
  }
}

resource "aws_iam_role" "s3_reader" {
  name                 = "lab-s3-reader"
  description          = "Cloud lab: read objects in probe buckets. No writes."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "s3_read_probe" {
  name   = "read-probe-buckets"
  role   = aws_iam_role.s3_reader.id
  policy = data.aws_iam_policy_document.s3_read_probe.json
}
