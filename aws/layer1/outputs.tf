output "target_tags" {
  description = "Tag query that must return nothing after teardown."
  value       = "lab=cloud-lab, layer=1"
}

output "probe_bucket" {
  description = "Bucket the identity probe targets."
  value       = aws_s3_bucket.probe.id
}
