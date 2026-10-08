# CLOUD-24 identity probe (layer 1, destroyed after every session).
# A private bucket with one object. The lab role can read it; it cannot write to it.
# The bucket name prefix matches the role's policy.

resource "random_string" "probe_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "aws_s3_bucket" "probe" {
  bucket        = "cloud-lab-identity-probe-${random_string.probe_suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "probe" {
  bucket                  = aws_s3_bucket.probe.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.probe.id
  key          = "hello.txt"
  content      = "hello from the cloud lab"
  content_type = "text/plain"
}
