# Names only. Copy into aws/layer1/backend.local.hcl (gitignored).
output "backend_config" {
  description = "Contents for aws/layer1/backend.local.hcl"
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    key          = "layer1.tfstate"
    region       = "${var.region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
