# CLOUD-26 storage (layer 1, destroyed after every session).
# A private bucket that only CloudFront can read (Origin Access Control), with a lifecycle rule.
# The deliberate failures are captured by hand, not created here:
#   1. a presigned URL seen to expire,
#   2. a direct public read of the private object.
#
# The sample object is far below 128 KB, so S3 does not transition it by default. In a session the
# lifecycle rule is therefore CONFIGURED and read back from the API, never observed acting.
# Tags: lab and layer come from the provider default_tags; domain is set per resource.

resource "random_string" "storage_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "aws_s3_bucket" "storage" {
  bucket        = "cloud-lab-storage-${random_string.storage_suffix.result}"
  force_destroy = true

  tags = {
    domain = "storage"
  }
}

# ACLs off: the bucket owner owns every object and only policies decide access.
resource "aws_s3_bucket_ownership_controls" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Sub-resources of one bucket are chained on purpose: S3 can answer a conflicting-operation error
# when several are created at the same moment.
resource "aws_s3_bucket_public_access_block" "storage" {
  bucket                  = aws_s3_bucket.storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_ownership_controls.storage]
}

resource "aws_s3_object" "storage_sample" {
  bucket       = aws_s3_bucket.storage.id
  key          = "sample.txt"
  content      = "private object for the CLOUD-26 storage session"
  content_type = "text/plain"

  depends_on = [aws_s3_bucket_public_access_block.storage]
}

# Standard to Standard-IA needs at least 30 days; the second step is 60 days later.
resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "tier-down-then-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_public_access_block.storage]
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_origin_access_control" "storage" {
  name                              = "cloud-lab-storage-${random_string.storage_suffix.result}"
  description                       = "CLOUD-26: only this distribution may read the private bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# A distribution takes minutes to deploy and, on destroy, to disable and delete.
resource "aws_cloudfront_distribution" "storage" {
  enabled             = true
  comment             = "cloud-lab storage session (CLOUD-26)"
  default_root_object = "sample.txt"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.storage.bucket_regional_domain_name
    origin_id                = "storage"
    origin_access_control_id = aws_cloudfront_origin_access_control.storage.id
  }

  default_cache_behavior {
    target_origin_id       = "storage"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    domain = "storage"
  }
}

data "aws_iam_policy_document" "storage" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.storage.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.storage.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.storage.arn, "${aws_s3_bucket.storage.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "storage" {
  bucket = aws_s3_bucket.storage.id
  policy = data.aws_iam_policy_document.storage.json

  depends_on = [aws_s3_bucket_public_access_block.storage]
}

output "storage_bucket" {
  description = "Private bucket for the CLOUD-26 storage session."
  value       = aws_s3_bucket.storage.id
}

# Sensitive on purpose: a CloudFront domain is an endpoint and must not reach the repository.
# Read it when needed with: terraform -chdir=aws/layer1 output -raw storage_cloudfront_domain
output "storage_cloudfront_domain" {
  description = "Domain of the distribution in front of the private bucket."
  value       = aws_cloudfront_distribution.storage.domain_name
  sensitive   = true
}
