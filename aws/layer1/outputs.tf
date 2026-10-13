output "target_tags" {
  description = "Tag query that must return nothing after teardown."
  value       = "lab=cloud-lab, layer=1"
}

output "probe_bucket" {
  description = "Bucket the identity probe targets."
  value       = aws_s3_bucket.probe.id
}

output "compute_invoke_url" {
  description = "URL of the hello route. Open and throttled, and public while it exists."
  value       = "${aws_apigatewayv2_stage.hello.invoke_url}/hello"
}

output "compute_function_name" {
  description = "Function of the CLOUD-28 compute exercise."
  value       = aws_lambda_function.hello.function_name
}
